#!/usr/bin/env bash
# Functional test: OAuth 2.1 authorization server in a real Mautic 7.
#   tests/functional/run.sh    (see tests/functional/lib.sh for the environment)
# shellcheck source=tests/functional/lib.sh
source "$(dirname "$0")/lib.sh"

install_mautic
configure_oauth
start_server

echo "OAuth 2.1 authorization server"
meta="$(curl -s "$BASE/.well-known/oauth-authorization-server")"
jq -e --arg b "$BASE" '.issuer == $b and .code_challenge_methods_supported == ["S256"] and .token_endpoint_auth_methods_supported == ["none"]' <<<"$meta" >/dev/null \
  && pass "RFC 8414 metadata" || { echo "$meta"; fail "metadata"; }
jwks_n="$(curl -s "$BASE/oauth2/jwks.json" | jq -r '.keys[0].n')"
key_n="$(openssl rsa -in "$OAUTH_KEY" -noout -modulus 2>/dev/null | cut -d= -f2 | php -r 'echo rtrim(strtr(base64_encode(hex2bin(trim(stream_get_contents(STDIN)))), "+/", "-_"), "=");')"
[[ "$jwks_n" == "$key_n" ]] && pass "JWKS publishes the signing key" || fail "JWKS"
[[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/oauth2/register" -H 'Content-Type: application/json' -d '{"redirect_uris":["https://evil.example/cb"]}')" == 400 ]] \
  && pass "registration with a foreign redirect host rejected" || fail "foreign redirect host accepted"

client="$(oauth_client)"
[[ "$client" =~ ^[0-9a-f]{32}$ ]] && pass "dynamic client registration" || fail "registration"
verifier="$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=\n')"
challenge="$(printf '%s' "$verifier" | openssl dgst -sha256 -binary | b64url)"
[[ "$(authorize "$client" "$challenge" S256 'mcp:read')" == *"/s/login"* ]] && pass "authorization requires Mautic login" || fail "no login required"
login >/dev/null
[[ "$(authorize "$client" "$challenge" plain 'mcp:read')" == "302 $REDIRECT?"*"error=invalid_request"* ]] && pass "PKCE plain rejected" || fail "PKCE plain accepted"
[[ "$(authorize "$client" "$challenge" S256 'mcp:read mcp:write mcp:campaigns:live')" == "200 " ]] \
  && grep -q 'value="mcp:campaigns:live">' "$WORK/page" && pass "consent page, opt-in scope unticked" || fail "consent page"
location="$(consent approve)"; code="$(sed -n 's/.*[?&]code=\([^&]*\).*/\1/p' <<<"$location")"
[[ "$(token "$client" "$code" wrong-verifier-wrong-verifier-wrong-verifier-1234)" == 400 ]] && pass "wrong PKCE verifier rejected" || fail "wrong verifier accepted"
[[ "$(token "$client" "$code" "$verifier")" == 200 ]] && pass "code exchanged for tokens" || { cat "$WORK/token"; fail "token"; }
access="$(jq -r .access_token "$WORK/token")"; refresh="$(jq -r .refresh_token "$WORK/token")"
[[ "$(token "$client" "$code" "$verifier")" == 400 ]] && pass "code is single-use" || fail "code reused"
IFS=. read -r h p s <<<"$access"
b64url_decode "$s" >"$WORK/sig"; openssl rsa -in "$OAUTH_KEY" -pubout -out "$WORK/pub.pem" 2>/dev/null
jq -e '.typ == "at+jwt"' <<<"$(b64url_decode "$h")" >/dev/null \
  && jq -e --arg b "$BASE" '.iss == $b and .aud == ($b + "/mcp") and .scope == "mcp:read mcp:write"' <<<"$(b64url_decode "$p")" >/dev/null \
  && printf '%s.%s' "$h" "$p" | openssl dgst -sha256 -verify "$WORK/pub.pem" -signature "$WORK/sig" >/dev/null \
  && pass "RFC 9068 JWT: claims, signature; live scope not granted by default" || fail "JWT"
refresh_grant() { curl -s -o "$WORK/token" -w '%{http_code}' -X POST "$BASE/oauth2/token" --data-urlencode grant_type=refresh_token --data-urlencode "refresh_token=$1" --data-urlencode "client_id=$client"; }
first="$(refresh_grant "$refresh")"; second="$(refresh_grant "$refresh")"
[[ "$first/$second" == "200/400" ]] && pass "refresh tokens rotate" || fail "refresh rotation ($first/$second)"
echo "all OAuth checks passed"

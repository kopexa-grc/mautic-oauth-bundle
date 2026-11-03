#!/usr/bin/env bash
# Functional test: OAuth 2.1 authorization server in a real Mautic 7.
#   tests/functional/run.sh    (see tests/functional/lib.sh for the environment)
# shellcheck source=tests/functional/lib.sh
source "$(dirname "$0")/lib.sh"

install_mautic
configure_oauth
start_server

echo "OAuth 2.1 authorization server"
# Mautic's REST API stays disabled (its default): the OAuth endpoints must
# work anyway, and the API itself must stay blocked.
[[ "$(curl -s "$BASE/api/contacts" | jq -r '.errors[0].type')" == api_disabled ]] \
  && pass "Mautic REST API disabled, still blocked" || fail "REST API not blocked"
meta="$(curl -s "$BASE/.well-known/oauth-authorization-server")"
jq -e --arg b "$BASE" '.issuer == $b and .scopes_supported == ["mcp:read", "mcp:write", "mcp:campaigns:live"] and .code_challenge_methods_supported == ["S256"] and .token_endpoint_auth_methods_supported == ["none"]' <<<"$meta" >/dev/null \
  && pass "RFC 8414 metadata" || { echo "$meta"; fail "metadata"; }
jwks_n="$(curl -s "$BASE/oauth2/jwks.json" | jq -r '.keys[0].n')"
key_n="$(openssl rsa -in "$OAUTH_KEY" -noout -modulus 2>/dev/null | cut -d= -f2 | php -r 'echo rtrim(strtr(base64_encode(hex2bin(trim(stream_get_contents(STDIN)))), "+/", "-_"), "=");')"
[[ "$jwks_n" == "$key_n" ]] && pass "JWKS publishes the signing key" || fail "JWKS"
[[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/oauth2/register" -H 'Content-Type: application/json' -d '{"redirect_uris":["https://evil.example/cb"]}')" == 400 ]] \
  && pass "registration with a foreign redirect host rejected" || fail "foreign redirect host accepted"
[[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/oauth2/register" -H 'Content-Type: application/json' -d '{"redirect_uris":["http://evil.example/cb"]}')" == 400 ]] \
  && pass "registration with a non-https redirect rejected (loopback excepted)" || fail "http redirect accepted"

client="$(oauth_client)"
[[ "$client" =~ ^[0-9a-f]{32}$ ]] && pass "dynamic client registration" || fail "registration"
verifier="$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=\n')"
challenge="$(printf '%s' "$verifier" | openssl dgst -sha256 -binary | b64url)"
[[ "$(authorize "$client" "$challenge" S256 'mcp:read')" == *"/s/login"* ]] && pass "authorization requires Mautic login" || fail "no login required"
# Logging in returns to the authorization request (Mautic's target path).
csrf="$(curl -s -c "$JAR" -b "$JAR" "$BASE/s/login" | sed -n 's/.*name="_csrf_token" value="\([^"]*\)".*/\1/p' | head -1)"
back="$(curl -s -o /dev/null -w '%{redirect_url}' -c "$JAR" -b "$JAR" -H "Origin: $BASE" -H "Referer: $BASE/s/login" \
  --data-urlencode _username=admin --data-urlencode "_password=$ADMIN_PW" --data-urlencode "_csrf_token=$csrf" "$BASE/s/login_check")"
[[ "$back" == *"/s/oauth2/authorize?"*"client_id=$client"* ]] && pass "login returns to the authorization request" || { echo "$back"; fail "login does not return to the consent page"; }
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
# Scopes ticked on the consent page end up in the token (the form a browser posts).
chk="$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=\n')"; chc="$(printf '%s' "$chk" | openssl dgst -sha256 -binary | b64url)"
authorize "$client" "$chc" S256 'mcp:read mcp:write' >/dev/null
loc="$(consent approve)"; c2="$(sed -n 's/.*[?&]code=\([^&]*\).*/\1/p' <<<"$loc")"
[[ "$(token "$client" "$c2" "$chk")" == 200 ]] && [[ "$(b64url_decode "$(jq -r .access_token "$WORK/token" | cut -d. -f2)" | jq -r .scope)" == "mcp:read mcp:write" ]] \
  && pass "ticked scopes (mcp:write) are granted" || { b64url_decode "$(jq -r .access_token "$WORK/token" | cut -d. -f2)"; fail "ticked scope not granted"; }
authorize "$client" "$chc" S256 'mcp:read mcp:write mcp:campaigns:live' >/dev/null
loc="$(consent approve mcp:campaigns:live)"; c2="$(sed -n 's/.*[?&]code=\([^&]*\).*/\1/p' <<<"$loc")"
[[ "$(token "$client" "$c2" "$chk")" == 200 ]] && [[ "$(b64url_decode "$(jq -r .access_token "$WORK/token" | cut -d. -f2)" | jq -r .scope)" == "mcp:read mcp:write mcp:campaigns:live" ]] \
  && pass "opt-in scope granted when ticked" || fail "ticked opt-in scope not granted"
refresh_grant() { curl -s -o "$WORK/token" -w '%{http_code}' -X POST "$BASE/oauth2/token" --data-urlencode grant_type=refresh_token --data-urlencode "refresh_token=$1" --data-urlencode "client_id=$client"; }
first="$(refresh_grant "$refresh")"; refresh2="$(jq -r .refresh_token "$WORK/token")"; second="$(refresh_grant "$refresh")"
[[ "$first/$second" == "200/400" ]] && pass "refresh tokens rotate" || fail "refresh rotation ($first/$second)"
[[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/oauth2/revoke" --data-urlencode "token=$refresh2" --data-urlencode "client_id=$client")" == 200 ]] \
  && [[ "$(refresh_grant "$refresh2")" == 400 ]] && pass "revoked refresh token rejected (RFC 7009)" || fail "revocation"
authorize "$client" "$chc" S256 'mcp:read' >/dev/null
[[ "$(consent deny)" == "$REDIRECT?"*"error=access_denied"* ]] && pass "denied consent returns access_denied" || fail "deny"
echo "all OAuth checks passed"

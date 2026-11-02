# kopexa/mautic-oauth-bundle

OAuth 2.1 authorization server for Mautic 7, so MCP clients (Claude,
ChatGPT, …) can connect with the standard MCP authorization flow.

## Installation

Mautic 7 (Composer-based installation):

```bash
composer require kopexa/mautic-oauth-bundle
php bin/console mautic:plugins:reload
```

Until the package is on Packagist, add the repository first:

```bash
composer config repositories.mautic-oauth-bundle vcs https://github.com/kopexa-grc/mautic-oauth-bundle
```

Configure the signing and encryption keys (`kopexa_oauth_private_key`, `kopexa_oauth_encryption_key`) in Mautic's `config/local.php` or, in the kopexa image, via environment variables.

Already included in the hardened Mautic image
[`ghcr.io/kopexa-grc/mautic`](https://github.com/kopexa-grc/mautic-stack).


It provides:

- authorization code grant with PKCE (S256 only) and rotating refresh tokens
- dynamic client registration (RFC 7591)
- authorization server metadata (RFC 8414)
- JWKS
- RFC 9068 JWT access tokens with an RFC 8707 audience
- revocation (RFC 7009)

Consent is shown under `/s/`, so Mautic's own login (password or SAML)
authenticates the user.

Built on [league/oauth2-server](https://oauth2.thephpleague.com).

Configuration, security model and endpoints:
[docs/oauth.md](https://github.com/kopexa-grc/mautic-stack/blob/main/docs/oauth.md).

| Parameter | Env (kopexa image) | |
|---|---|---|
| `kopexa_oauth_private_key` | `MAUTIC_OAUTH_PRIVATE_KEY` | RSA private key (PEM) |
| `kopexa_oauth_encryption_key` | `MAUTIC_OAUTH_ENCRYPTION_KEY` | secret for codes / refresh tokens |
| `kopexa_oauth_redirect_hosts` | `MAUTIC_OAUTH_REDIRECT_HOSTS` | allowed redirect hosts |
| `kopexa_oauth_resource` | `MAUTIC_OAUTH_RESOURCE` | token audience (default `<site_url>/mcp`) |
| `kopexa_oauth_access_ttl` / `kopexa_oauth_refresh_ttl` | via `MAUTIC_CONFIG_PARAMETERS` | seconds (3600 / 2592000) |


## Development

- `bin/check.sh` checks the package (PHP lint, `composer validate`, version
  consistency). CI runs it on every push and pull request.
- Integration tests run in
  [kopexa-grc/mautic-stack](https://github.com/kopexa-grc/mautic-stack): its
  smoke test installs this package into the Mautic image and exercises it
  end to end.
- **Commits** follow [Conventional Commits](https://www.conventionalcommits.org)
  (`feat:`, `fix:`, `docs:`, `chore:` …); they drive versions and the changelog.
- **Releases** are automated with
  [release-please](https://github.com/googleapis/release-please): it keeps a
  release PR open that bumps `VERSION`, the plugin version and
  `CHANGELOG.md`. Merging it tags `v<version>` and creates the GitHub
  release. Packagist and mautic-stack's Renovate pick the tag up.
- **Dependencies** are kept current by Renovate. Composer constraint updates
  are committed as `fix(deps):` and so lead to a patch release; CI-only
  updates (`ci:`) do not.

Apache-2.0 · [Kopexa](https://kopexa.com)

# Changelog

## [0.3.0](https://github.com/kopexa-grc/mautic-oauth-bundle/compare/v0.2.2...v0.3.0) (2026-11-02)


### Features

* scope mcp:contacts:write for contact and segment changes via MCP ([4e6e1a4](https://github.com/kopexa-grc/mautic-oauth-bundle/commit/4e6e1a458bdd610505048dde81aa643d5769d81f))

## [0.2.2](https://github.com/kopexa-grc/mautic-oauth-bundle/compare/v0.2.1...v0.2.2) (2026-11-02)


### Bug fixes

* OAuth endpoints work while Mautic's REST API is disabled ([4a5ea92](https://github.com/kopexa-grc/mautic-oauth-bundle/commit/4a5ea92e3f6c59f77090a40d6eb6cd10ff610185))

## [0.2.1](https://github.com/kopexa-grc/mautic-oauth-bundle/compare/v0.2.0...v0.2.1) (2026-11-02)


### Bug fixes

* require Mautic ^7.2, the versions this plugin is tested with ([9d1c12e](https://github.com/kopexa-grc/mautic-oauth-bundle/commit/9d1c12e49d59146fe39b56294bd73edb4200fb91))
* require PHP ~8.4, the versions this plugin is tested on ([08bdb35](https://github.com/kopexa-grc/mautic-oauth-bundle/commit/08bdb35190e56f906c92022c978461757b0f44f8))

## 0.2.0 – 2026-11-02

- The consent page lists the requested scopes as checkboxes. Users can grant fewer scopes than requested.
- Opt-in scopes (`kopexa_oauth_optin_scopes`) are highlighted and unticked by default.
- New scope `mcp:campaigns:live` (opt-in), used by `kopexa/mautic-mcp-bundle` for changes to running campaigns.
- `Settings::publicKeyPem()` exposes the public signing key to resource servers in the same instance.

## 0.1.0 – 2026-11-01

- OAuth 2.1 authorization server:
  - authorization code with PKCE (S256 only)
  - rotating refresh tokens
  - dynamic client registration (RFC 7591)
  - metadata (RFC 8414) and JWKS
  - RFC 9068 JWT access tokens with an RFC 8707 audience
  - revocation (RFC 7009)
- Consent page behind Mautic's login (password or SAML). Decisions go to the audit log.

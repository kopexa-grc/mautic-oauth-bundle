<?php

declare(strict_types=1);

use MauticPlugin\KopexaOAuthBundle\Controller\AuthorizeController;
use MauticPlugin\KopexaOAuthBundle\Controller\ServerController;

return [
    'name'        => 'OAuth 2.1',
    'description' => 'OAuth 2.1 authorization server (authorization code + PKCE, dynamic client registration) for MCP clients.',
    'version'     => '0.4.0', // x-release-please-version
    'author'      => 'Kopexa',
    'routes'      => [
        // Public endpoints (no Mautic session).
        'public' => [
            'kopexa_oauth_metadata' => [
                'path'       => '/.well-known/oauth-authorization-server',
                'controller' => ServerController::class.'::metadataAction',
                'method'     => 'GET',
            ],
            'kopexa_oauth_jwks' => [
                'path'       => '/oauth2/jwks.json',
                'controller' => ServerController::class.'::jwksAction',
                'method'     => 'GET',
            ],
            'kopexa_oauth_register' => [
                'path'       => '/oauth2/register',
                'controller' => ServerController::class.'::registerAction',
                'method'     => 'POST',
            ],
            'kopexa_oauth_token' => [
                'path'       => '/oauth2/token',
                'controller' => ServerController::class.'::tokenAction',
                'method'     => 'POST',
            ],
            'kopexa_oauth_revoke' => [
                'path'       => '/oauth2/revoke',
                'controller' => ServerController::class.'::revokeAction',
                'method'     => 'POST',
            ],
        ],
        // Under /s/: Mautic's login (password or SAML SSO) protects consent.
        'main' => [
            'kopexa_oauth_authorize' => [
                'path'       => '/oauth2/authorize',
                'controller' => AuthorizeController::class.'::authorizeAction',
            ],
        ],
    ],
    'parameters' => [
        // RSA private key (PEM) that signs access tokens; published via JWKS.
        'kopexa_oauth_private_key'    => '',
        // Secret used to encrypt authorization codes and refresh tokens.
        'kopexa_oauth_encryption_key' => '',
        // Hosts that dynamically registered clients may redirect to.
        'kopexa_oauth_redirect_hosts' => ['claude.ai', 'claude.com', 'chatgpt.com', 'chat.openai.com', 'localhost', '127.0.0.1'],
        // Scopes are declared by the bundles that enforce them
        // (Scope\ScopeProviderInterface, e.g. kopexa/mautic-mcp-bundle).
        // Operator overrides: scope => description (adds scopes or
        // replaces descriptions), further default and opt-in scopes.
        'kopexa_oauth_scopes'         => [],
        'kopexa_oauth_default_scopes' => [],
        // Scopes the consent page shows unticked and highlighted: the user
        // has to allow them explicitly, even if the client asks for them.
        'kopexa_oauth_optin_scopes'   => [],
        // Resource (audience) tokens are issued for; default <site_url>/mcp.
        'kopexa_oauth_resource'       => '',
        'kopexa_oauth_access_ttl'     => 3600,
        'kopexa_oauth_refresh_ttl'    => 2592000,
    ],
];

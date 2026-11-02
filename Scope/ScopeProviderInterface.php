<?php

declare(strict_types=1);

namespace MauticPlugin\KopexaOAuthBundle\Scope;

use Symfony\Component\DependencyInjection\Attribute\AutoconfigureTag;

/**
 * Implemented by bundles that protect resources with this authorization
 * server (e.g. kopexa/mautic-mcp-bundle) to declare their scopes. Services
 * implementing it are collected automatically (autoconfigure).
 */
#[AutoconfigureTag(self::TAG)]
interface ScopeProviderInterface
{
    public const TAG = 'kopexa_oauth.scope_provider';

    /** @return iterable<ScopeDefinition> */
    public function scopes(): iterable;
}

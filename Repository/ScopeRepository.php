<?php

declare(strict_types=1);

namespace MauticPlugin\KopexaOAuthBundle\Repository;

use League\OAuth2\Server\Entities\ClientEntityInterface;
use League\OAuth2\Server\Entities\ScopeEntityInterface;
use League\OAuth2\Server\Repositories\ScopeRepositoryInterface;
use MauticPlugin\KopexaOAuthBundle\Entity\Scope;
use MauticPlugin\KopexaOAuthBundle\Scope\ScopeRegistry;

class ScopeRepository implements ScopeRepositoryInterface
{
    public function __construct(private readonly ScopeRegistry $registry)
    {
    }

    public function getScopeEntityByIdentifier(string $identifier): ?ScopeEntityInterface
    {
        return $this->registry->has($identifier) ? new Scope($identifier) : null;
    }

    public function finalizeScopes(array $scopes, string $grantType, ClientEntityInterface $clientEntity, ?string $userIdentifier = null, ?string $authCodeId = null): array
    {
        // No scope requested: grant the default scopes.
        if ([] === $scopes && 'authorization_code' === $grantType) {
            return array_map(fn (string $name): Scope => new Scope($name), $this->registry->defaults());
        }

        return array_values(array_filter($scopes, fn (ScopeEntityInterface $s): bool => $this->registry->has($s->getIdentifier())));
    }
}

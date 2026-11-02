<?php

declare(strict_types=1);

namespace MauticPlugin\KopexaOAuthBundle\Scope;

use Mautic\CoreBundle\Helper\CoreParametersHelper;
use Symfony\Component\DependencyInjection\Attribute\AutowireIterator;

/**
 * All scopes this server issues: those declared by scope providers, plus
 * operator overrides from the Mautic parameters
 *   kopexa_oauth_scopes          scope => description (adds scopes, replaces descriptions)
 *   kopexa_oauth_default_scopes  further default scopes
 *   kopexa_oauth_optin_scopes    further opt-in scopes
 */
class ScopeRegistry
{
    /** @var array<string, ScopeDefinition>|null */
    private ?array $scopes = null;

    /**
     * @param iterable<ScopeProviderInterface> $providers
     */
    public function __construct(
        #[AutowireIterator(ScopeProviderInterface::TAG)] private readonly iterable $providers,
        private readonly CoreParametersHelper $parameters,
    ) {
    }

    /** @return array<string, ScopeDefinition> */
    public function all(): array
    {
        if (null !== $this->scopes) {
            return $this->scopes;
        }

        $scopes = [];
        foreach ($this->providers as $provider) {
            foreach ($provider->scopes() as $scope) {
                if (isset($scopes[$scope->name])) {
                    throw new \LogicException(sprintf('OAuth scope "%s" is declared by %s and another scope provider.', $scope->name, $provider::class));
                }
                $scopes[$scope->name] = $scope;
            }
        }

        $descriptions = $this->parameters->get('kopexa_oauth_scopes');
        foreach (is_array($descriptions) ? $descriptions : [] as $name => $description) {
            $old            = $scopes[$name] ?? null;
            $scopes[$name]  = new ScopeDefinition((string) $name, (string) $description, $old?->default ?? false, $old?->optIn ?? false);
        }
        foreach ($this->names('kopexa_oauth_default_scopes') as $name) {
            if (isset($scopes[$name])) {
                $scopes[$name] = new ScopeDefinition($name, $scopes[$name]->description, true, false);
            }
        }
        foreach ($this->names('kopexa_oauth_optin_scopes') as $name) {
            if (isset($scopes[$name]) && !$scopes[$name]->default) {
                $scopes[$name] = new ScopeDefinition($name, $scopes[$name]->description, false, true);
            }
        }

        return $this->scopes = $scopes;
    }

    public function has(string $name): bool
    {
        return isset($this->all()[$name]);
    }

    /** @return list<string> */
    public function names(string $parameter = ''): array
    {
        if ('' === $parameter) {
            return array_keys($this->all());
        }
        $value = $this->parameters->get($parameter);

        return array_values(array_filter(is_array($value) ? $value : [], 'is_string'));
    }

    /** @return list<string> scopes granted when none are requested */
    public function defaults(): array
    {
        return array_keys(array_filter($this->all(), fn (ScopeDefinition $s): bool => $s->default));
    }

    public function isDefault(string $name): bool
    {
        return $this->all()[$name]->default ?? false;
    }

    public function isOptIn(string $name): bool
    {
        return $this->all()[$name]->optIn ?? false;
    }

    public function description(string $name): string
    {
        return $this->all()[$name]->description ?? '';
    }
}

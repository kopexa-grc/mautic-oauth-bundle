<?php

declare(strict_types=1);

namespace MauticPlugin\KopexaOAuthBundle\Scope;

/**
 * A scope this authorization server issues, declared by the bundle that
 * enforces it (see ScopeProviderInterface).
 */
final readonly class ScopeDefinition
{
    /**
     * @param string $name        Scope as it appears in tokens, e.g. "mcp:read"
     * @param string $description Shown on the consent page
     * @param bool   $default     Granted when a client requests no scope; always kept on the consent page (cannot be unticked)
     * @param bool   $optIn       Shown highlighted and unticked on the consent page: the user has to tick it explicitly
     */
    public function __construct(
        public string $name,
        public string $description,
        public bool $default = false,
        public bool $optIn = false,
    ) {
        if (1 !== preg_match('/^[\x21\x23-\x5B\x5D-\x7E]+$/', $name)) {
            throw new \InvalidArgumentException(sprintf('Invalid OAuth scope name "%s" (RFC 6749, section 3.3).', $name));
        }
        if ($default && $optIn) {
            throw new \InvalidArgumentException(sprintf('Scope "%s" cannot be both default and opt-in.', $name));
        }
    }
}

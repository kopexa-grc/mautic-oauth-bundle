<?php

declare(strict_types=1);

namespace MauticPlugin\KopexaOAuthBundle\EventListener;

use Mautic\ApiBundle\EventListener\ApiSubscriber;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\Event\ResponseEvent;

/**
 * Keeps Mautic's API subscriber away from this server's endpoints.
 *
 * Mautic treats every URL containing "/oauth" or "/api" as a request to its
 * own REST API: with the API disabled it answers 403 "api_disabled", and it
 * rewrites JSON error responses. Both hit the OAuth 2.1 endpoints
 * (/.well-known/oauth-*, /oauth2/*) and break MCP client discovery, although
 * they have nothing to do with Mautic's REST API. Every other request is
 * passed to Mautic's subscriber unchanged.
 */
final class ApiSubscriberDecorator implements EventSubscriberInterface
{
    private const PATHS = '#^/(?:s/)?oauth2/|^/\.well-known/oauth-(?:authorization-server|protected-resource)(?:/|$)#';

    public function __construct(private readonly ApiSubscriber $inner)
    {
    }

    public static function getSubscribedEvents(): array
    {
        return ApiSubscriber::getSubscribedEvents();
    }

    public static function isOwnEndpoint(Request $request): bool
    {
        return 1 === preg_match(self::PATHS, $request->getPathInfo());
    }

    public function onKernelRequest(RequestEvent $event): void
    {
        if (!self::isOwnEndpoint($event->getRequest())) {
            $this->inner->onKernelRequest($event);
        }
    }

    public function onKernelResponse(ResponseEvent $event): void
    {
        if (!self::isOwnEndpoint($event->getRequest())) {
            $this->inner->onKernelResponse($event);
        }
    }
}

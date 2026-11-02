<?php

declare(strict_types=1);

use Mautic\ApiBundle\EventListener\ApiSubscriber;
use Mautic\CoreBundle\DependencyInjection\MauticCoreExtension;
use MauticPlugin\KopexaOAuthBundle\EventListener\ApiSubscriberDecorator;
use Symfony\Component\DependencyInjection\Loader\Configurator\ContainerConfigurator;

use function Symfony\Component\DependencyInjection\Loader\Configurator\service;

return function (ContainerConfigurator $configurator): void {
    $services = $configurator->services()
        ->defaults()
        ->autowire()
        ->autoconfigure()
        ->public();

    $services->load('MauticPlugin\\KopexaOAuthBundle\\', '../')
        ->exclude('../{'.implode(',', array_merge(MauticCoreExtension::DEFAULT_EXCLUDES, ['Tests', 'DependencyInjection', 'Entity', 'EventListener'])).'}');

    // Mautic's API subscriber blocks every URL containing "/oauth" while its
    // REST API is disabled; the decorator exempts this server's endpoints.
    // Not autoconfigured: it takes over the event-subscriber tag of the
    // decorated service, so it is registered once.
    $services->set(ApiSubscriberDecorator::class)
        ->autoconfigure(false)
        ->decorate(ApiSubscriber::class)
        ->args([service('.inner')]);

    $services->load('MauticPlugin\\KopexaOAuthBundle\\Controller\\', '../Controller')
        ->tag('controller.service_arguments');
};

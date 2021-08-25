#!/usr/bin/env bash

if [ "$APP_CLUSTERCOCKPIT_INIT" = true ]; then


    rm -rf /var/www/symfony/* /var/www/symfony/.??*
    git clone https://github.com/ClusterCockpit/ClusterCockpit .

    if [ "$APP_ENV" = dev ]; then
        git checkout develop
        composer install --no-progress --optimize-autoloader
        yarn install
        yarn encore dev
    else
        composer install --no-dev --no-progress --optimize-autoloader
        yarn install
        yarn encore production
    fi

    ln -s /var/lib/job-archive var/job-archive
fi

# Reports php environment on container startup
php bin/console about

exec "$@"

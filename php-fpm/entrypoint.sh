#!/usr/bin/env bash

if [ "$APP_CLUSTERCOCKPIT_INIT" = true ]; then
    rm -rf /var/www/symfony/* /var/www/symfony/.??*
    git clone https://github.com/ClusterCockpit/ClusterCockpit .
    yarn install

    if [ "$APP_ENV" = dev ]; then
        composer install --no-progress --optimize-autoloader
        yarn encore dev
    else
        composer install --no-dev --no-progress --optimize-autoloader
        yarn encore production
    fi

    ln -s /var/lib/job-archive var/job-archive
fi

php bin/console about

exec "$@"

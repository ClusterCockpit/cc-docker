#!/usr/bin/env bash

if [ "$APP_CLUSTERCOCKPIT_INIT" = true ]; then
    rm -rf /var/www/symfony/* /var/www/symfony/.??*
    git clone https://github.com/ClusterCockpit/ClusterCockpit .

    composer install --no-dev --no-progress --optimize-autoloader
    yarn install
    yarn encore production
    #php bin/console doctrine:schema:create  --no-interaction
    #php bin/console doctrine:migrations:migrate --no-interaction
    #php bin/console doctrine:fix:load --no-interaction
    ln -s /var/lib/job-archive var/job-archive
fi

php bin/console about

exec "$@"

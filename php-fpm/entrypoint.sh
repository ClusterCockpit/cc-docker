#!/usr/bin/env bash

if [ "$APP_CLUSTERCOCKPIT_INIT" = true ]; then

    # Wait for docker dns able to resolve gitub
    # Solves weird special case of container loading faster than github can be reached
    until ping -c 1 github.com > /dev/null ; do
      echo "Could not reach github.com yet ..."
      sleep 1
    done

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

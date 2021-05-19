#!/usr/bin/env bash

rm -rf /var/www/symfony/* /var/www/symfony/.*
# git clone https://github.com/ClusterCockpit/ClusterCockpit.git /var/www/symfony/.

cd /var/www/symfony

git init
git remote add origin https://github.com/ClusterCockpit/ClusterCockpit.git
git fetch
git checkout feature-47-introduce-graphql-api
composer install --no-dev --no-progress --optimize-autoloader
yarn install
yarn encore production
# bin/console doc:mig:mig --no-interaction
# bin/console doc:fix:load --no-interaction

exec "$@"

#!/usr/bin/env bash

rm -rf /var/www/symfony/* /var/www/symfony/.*
cd /var/www/symfony

git init
git remote add origin https://github.com/ClusterCockpit/ClusterCockpit.git
git fetch
git checkout feature-47-introduce-graphql-api
composer install --no-dev --no-progress --optimize-autoloader
yarn install
yarn encore production
php bin/console doctrine:schema:create  --no-interaction
#php bin/console doctrine:migrations:migrate --no-interaction
#php bin/console doc:fix:load --no-interaction

exec "$@"

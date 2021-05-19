#!/usr/bin/env bash

git clone https://github.com/ClusterCockpit/ClusterCockpit.git /var/www/symfony/.
cd /var/www/symfony
git checkout  feature-47-introduce-graphql-api
composer install --no-dev --optimize-autoloader
yarn install
yarn encore production
# bin/console doc:mig:mig --no-interaction
# bin/console doc:fix:load --no-interaction

exec "$@"

FROM php:8.0-fpm

RUN apt-get update && apt-get install -y \
    $PHPIZE_DEPS \
    git \
    wget \
    gettext \
    bash \
    libldb-dev \
    libldap-2.4-2 \
    libldap-common \
    libldap2-dev \
    npm \
    nodejs

RUN apt-get clean

RUN npm install --global yarn

RUN docker-php-ext-install ldap \
    mysqli \
    pdo_mysql \
    opcache

# Enable php8-xdebug if $PHP_XDEBUG_INIT is true
ARG PHP_XDEBUG_INIT="false"
ARG PHP_XDEBUG_MODE=off
ARG PHP_XDEBUG_CLIENT_PORT=5902
ARG PHP_XDEBUG_CLIENT_HOST=host.docker.internal
COPY xdebug.ini  /etc/php8/conf.d/xdebug.ini.template
COPY error_reporting.ini /usr/local/etc/php/conf.d/error_reporting.ini
RUN if [[ "$PHP_XDEBUG_INIT" == "true" ]]; then \
        pecl install xdebug-3.0.4; \
        docker-php-ext-enable xdebug; \
        export PHP_XDEBUG_MODE=$PHP_XDEBUG_MODE; \
        export PHP_XDEBUG_CLIENT_PORT=$PHP_XDEBUG_CLIENT_PORT; \
        export PHP_XDEBUG_CLIENT_HOST=$PHP_XDEBUG_CLIENT_HOST; \
        envsubst < /etc/php8/conf.d/xdebug.ini.template > /etc/php8/conf.d/xdebug.ini; \
        cp /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini.back; \
        cp /etc/php8/conf.d/xdebug.ini /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini; \
        rm -f /etc/php8/conf.d/xdebug.ini.template; \
    fi

RUN curl -sS https://getcomposer.org/installer | tee composer-setup.php \
    && php composer-setup.php && rm composer-setup.php* \
    && chmod +x composer.phar && mv composer.phar /usr/bin/composer

ARG SYMFONY_CLI_VERSION
RUN wget https://github.com/symfony/cli/releases/download/v$SYMFONY_CLI_VERSION/symfony_linux_amd64.gz \
    && gzip -d symfony_linux_amd64.gz \
    && mv symfony_linux_amd64 symfony \
    && chmod +x symfony \
    && mv symfony /usr/local/bin/

RUN mkdir -p /var/lib/job-archive
RUN mkdir -p /var/www/symfony
VOLUME /var/www/symfony /var/lib/job-archive

COPY php.ini /usr/local/etc/php/
COPY symfony.ini /usr/local/etc/php/conf.d/
COPY symfony.ini /usr/local/etc/php/cli/conf.d/
COPY symfony.pool.conf /usr/local/etc/php/php-fpm.d/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ARG APP_ENVIRONMENT
ENV APP_ENV=${APP_ENVIRONMENT}
ENV APP_SECRET=${APP_SECRET}
ENV APP_JWT_PUB_KEY="${APP_JWT_PUB_KEY}"
ENV APP_JWT_PRIV_KEY="${APP_JWT_PRIV_KEY}"
ENV APP_DEBUG=1
ENV REDIS_URL=redis://cc-redis
ENV LDAP_URL=ldap://cc-ldap
ARG INFLUXDB_PORT
ARG INFLUXDB_PASSWORD
ARG INFLUXDB_ADMIN_TOKEN
ARG INFLUXDB_ORG
ARG INFLUXDB_BUCKET
ARG INFLUXDB_SSL
ENV INFLUXDB_URL=http://cc-influxdb:${INFLUXDB_PORT}
ENV INFLUXDB_SSL=${INFLUXDB_SSL}
ENV INFLUXDB_TOKEN=${INFLUXDB_ADMIN_TOKEN}
ENV INFLUXDB_ORG=${INFLUXDB_ORG}
ENV INFLUXDB_BUCKET=${INFLUXDB_BUCKET}
ARG LDAP_PASSWORD
ENV LDAP_PW=${LDAP_PASSWORD}
ARG MYSQL_USER
ARG MYSQL_PASSWORD
ARG MYSQL_DATABASE
ENV DATABASE_URL=mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@cc-db:3306/${MYSQL_DATABASE}
ENV CORS_ALLOW_ORIGIN=^https?://(localhost|127\\.0\\.0\\.1)(:[0-9]+)?$

WORKDIR /var/www/symfony

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm", "-F", "-y/usr/local/etc/php/php-fpm.d/symfony.pool.conf"]

EXPOSE 9001

FROM alpine:3.13

LABEL maintainer="Vincent Composieux <vincent.composieux@gmail.com>"

RUN apk add --no-cache \
    coreutils \
    gettext \
    php8-fpm \
    php8-ctype \
    php8-curl \
    php8-dom \
    php8-gd \
    php8-iconv \
    php8-json \
    php8-intl \
    php8-fileinfo\
    php8-mbstring \
    php8-opcache \
    php8-openssl \
    php8-pdo \
    php8-pdo_mysql \
    php8-mysqli \
    php8-xml \
    php8-xsl \
    php8-zlib \
    php8-phar \
    php8-tokenizer \
    php8-session \
    php8-simplexml \
    php8-zip \
    php8-xmlwriter \
    php8-sodium \
    php8-pecl-apcu \
    php8-ldap \
    bash \
    make \
    git \
    curl

RUN curl -sS https://getcomposer.org/installer | tee composer-setup.php \
    && php8 composer-setup.php && rm composer-setup.php* \
    && chmod +x composer.phar && mv composer.phar /usr/bin/composer \
    && ln -s /usr/bin/php8 /usr/local/bin/php

ARG SYMFONY_CLI_VERSION
RUN wget https://github.com/symfony/cli/releases/download/v$SYMFONY_CLI_VERSION/symfony_linux_amd64.gz \
    && gzip -d symfony_linux_amd64.gz \
    && mv symfony_linux_amd64 symfony \
    && chmod +x symfony \
    && mv symfony /usr/local/bin/

RUN apk add --update nodejs npm \
    && npm install --global yarn

RUN mkdir -p /var/lib/job-archive
RUN mkdir -p /var/www/symfony
VOLUME /var/www/symfony /var/lib/job-archive

COPY symfony.ini /etc/php8/conf.d/
COPY symfony.ini /etc/php8/cli/conf.d/

COPY symfony.pool.conf /etc/php8/php-fpm.d/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN addgroup -S www
RUN adduser -S -D -H -g "php-fpm user" -G www -s /sbin/nologin www

ARG APP_ENVIRONMENT
ENV APP_ENV=${APP_ENVIRONMENT}
ENV APP_SECRET=67d829bf61dc5f87a73fd814e2c9f629
ENV APP_DEBUG=1
ENV REDIS_URL=redis://cc-redis
ARG INFLUXDB_PORT
ARG INFLUXDB_PASSWORD
ARG INFLUXDB_ADMIN_TOKEN
ENV INFLUXDB_URL=http://cc-influxdb:${INFLUXDB_PORT}
ENV INFLUXDB_TOKEN=${INFLUXDB_ADMIN_TOKEN}
ARG MYSQL_USER
ARG MYSQL_PASSWORD
ARG MYSQL_DATABASE
ENV DATABASE_URL=mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@cc-db:3306/${MYSQL_DATABASE}
ENV CORS_ALLOW_ORIGIN=^https?://(localhost|127\\.0\\.0\\.1)(:[0-9]+)?$

WORKDIR /var/www/symfony

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm8", "-F"]

EXPOSE 9001

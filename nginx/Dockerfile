FROM nginx:1.19.6

LABEL maintainer="Vincent Composieux <vincent.composieux@gmail.com>"

RUN mkdir -p /etc/nginx/templates

COPY nginx.conf /etc/nginx/
COPY templates/* /etc/nginx/templates/

ARG NGINX_SYMFONY_SERVER_NAME
ENV APP_ENV=prod
ENV APP_SECRET=67d829bf61dc5f87a73fd814e2c9f629
ENV APP_DEBUG=1
ARG INFLUXDB_PASSWORD
ARG MYSQL_PASSWORD
ENV INFLUXDB_URL=influxdb://symfony:${INFLUXDB_PASSWORD}@influxdb:8086/ClusterCockpit
ENV DATABASE_URL=mysql://symfony:${MYSQL_PASSWORD}@db:3306/ClusterCockpit
ENV CORS_ALLOW_ORIGIN=^https?://(localhost|127\\.0\\.0\\.1)(:[0-9]+)?$

CMD ["nginx"]

EXPOSE 80
EXPOSE 443

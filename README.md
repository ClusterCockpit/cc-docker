# cc-docker

This is a setup for `docker compose` to try out a complete ClusterCockpit Application Stack including all external components. This docker setup is intended for demo purposes, but can be easily configured to be used as a development environement for ClusterCockpit.

It creates containers for:
* mysql
* influxdb
* php-fpm
* nginx
* phpmyadmin (only in dev mode)

Ports and Passwords are configured in `.env`.

TODOS (There are probably a lot more!):
* Some of the Volume directories need to be created first.
* ClusterCockpit is at the moment still using the influxDB V1 API, the InfluxDB container is already V2
* For a complete demo database setup, InfluxDB data fixtures are missing (MySQL demo database is available)

## Known Issues

* `docker-compose` installed on Ubuntu (18.04, 20.04) via `apt-get` can not correctly parse `docker-compose.yml` due to version differences. Install latest version of `docker-compose` from https://docs.docker.com/compose/install/ instead.
* You need to ensure that no other web server is running on port 80 (e.g. Apache2). If port 80 is already in use, edit NGINX_PORT environment variable in `.env`.
* Existing VPN connections sometimes cause problems with docker. If `docker-compose` does not start up correctly, try disabling any active VPN connection. Refer to https://stackoverflow.com/questions/45692255/how-make-openvpn-work-with-docker for further information.

## Using for DEMO purpose
### Info
* Demo starts in production environment.
* Uses prepared fixture data for databases (Changes will not be preserved).
* ClusterCockpit is initialized from scratch on every container start (Changes will not be preserved).

### Setup
The fixture data needs to be prepared once before first start of containers:
* `$ cd data`
* `$ ./init.sh`

After that from the root of the repository you can start up the containers with:
* `docker-compose up`
* Wait... and wait a little longer

By default, you can access ClusterCockpit in your browser at http://localhost . If the `NGINX_PORT` environment variable was changed, use `http://localhost:$PORT` .

Credentials for admin user are:
* User: `admin`
* Password: `AdminDev`

You can shutdown the containers by pressing `CTRL-C`.

To reuse an existing Symfony tree at `./data/symfony` you may change the environment variable `APP_CLUSTERCOCKPIT_INIT` in `.env` from `true` to `false`.

## Using for DEVELOP purpose
### Info
* `APP_ENVIRONMENT` variable in `.env` used to switch `php-fpm` container to development environement.
* `APP_CLUSTERCOCKPIT_INIT` variable in `.env` used to prevent container from initializing a new ClusterCockpit instance on every start.
* In this case, an existing Symfony tree at `./data/symfony` is required.
* By default, this also uses prepared fixture data for databases. In order to use an existing database, changes in `.env` and `docker-compose.yml` are required (see below).

### Setup
If not using an existing database, the fixture data needs to be prepared before the first start of the containers:
* `$ cd data`
* `$ ./init.sh`

* Comment or delete the line `- ${DATADIR}/sql:/docker-entrypoint-initdb.d` for `cc-db` to disable initialisation of the MySQL database. You may also place your own MySQL database dump in `./data/sql`.

In `.env`, change the following variables under `APP`
* `APP_CLUSTERCOCKPIT_INIT` to `false`
* `APP_ENVIRONMENT` to `dev`

After that from the root of the repository you can start up the containers with:
* `docker-compose -f docker-compose.yml -f docker-compose-dev.yml up`
* Wait... and wait a little longer

By default, you can access ClusterCockpit in your browser at `http://localhost`.
If `NGINX_PORT` environment variable was changed, `use http://localhost:$PORT`.
The InfluxDB Web interface can be accessed at `http://localhost:8086` using the credentials set in `.env`.

If default database fixture were used, the credentials for admin user are:
* User: `admin`
* Password: `AdminDev`

You can shutdown the containers by pressing `CTRL-C`.

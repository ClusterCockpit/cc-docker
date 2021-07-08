# cc-docker

This is a setup for `docker compose` to try out a complete ClusterCockpit Application Stack including all external components. This docker setup is intended for demo purposes, but can be easily configured to be used as a development environment for ClusterCockpit.

It creates containers for:
* mysql
* php-fpm
* nginx
* influxdb (only in dev mode)
* phpmyadmin (only in dev mode), this did not work with Chrome for me.

Ports and Passwords are configured in `.env`.

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
This description assumes you will let the docker setup initialize the symfony tree and data fixtures for you.
If not using an existing database, the fixture data needs to be prepared before the first start of the containers:
* `$ cd data`
* `$ ./init.sh dev`

In `.env`, change the following variables under `APP`
* `APP_ENVIRONMENT` to `dev`

In case you want to switch from Demo to Develop you have to purge previous images. This command will purge **ALL** your docker images:
```
$ docker images -a -q | xargs docker rmi -f
```

Check with:
```
$ docker images
```
that all images are gone.

After that from the root of the repository you can start up the containers with (use -d switch to startup in detached mode):
* `docker-compose -f docker-compose.yml -f docker-compose-dev.yml up`
* Wait... and wait a little longer

After the initial setup you have to:
* Comment or delete the line `- ${DATADIR}/sql:/docker-entrypoint-initdb.d` for `cc-db` to disable initialisation of the MySQL database.
* Set `APP_CLUSTERCOCKPIT_INIT` to `false` in the .env file

On subsequent start of the containers you will then reuse the persisted volume data located in the `./data` directory.

By default, you can access ClusterCockpit in your browser at `http://localhost`.
If `NGINX_PORT` environment variable was changed, `use http://localhost:$PORT`.
The InfluxDB Web interface can be accessed at `http://localhost:8086` using the credentials set in `.env`.
PHPMyAdmin can be reached at `http://localhost:8080`.

If default database fixture were used, the credentials for admin user are:
* User: `admin`
* Password: `AdminDev`

You can shutdown the containers by pressing `CTRL-C` if not started in detached mode.

# cc-docker

This is a `docker compose` setup to try out the complete ClusterCockpit Application Stack including all external components. This docker setup can be easily configured to be used as demo or as a development environment.

It includes the following containers:
* mysql
* php-fpm
* nginx
* redis
* openldap
* influxdb
* phpmyadmin

Settings are configured in `.env`.
The setup comes with fixture data for a Job archive, InfluxDB, MySQL, and a LDAP user directory.

## Known Issues

* `docker-compose` installed on Ubuntu (18.04, 20.04) via `apt-get` can not correctly parse `docker-compose.yml` due to version differences. Install latest version of `docker-compose` from https://docs.docker.com/compose/install/ instead.
* You need to ensure that no other web server is running on port 80 (e.g. Apache2). If port 80 is already in use, edit NGINX_PORT environment variable in `.env`.
* Existing VPN connections sometimes cause problems with docker. If `docker-compose` does not start up correctly, try disabling any active VPN connection. Refer to https://stackoverflow.com/questions/45692255/how-make-openvpn-work-with-docker for further information.

## Configuration

While many aspects of this docker compose setup can be configured you usually only need to adapt the following three settings in `.env`:
* `CLUSTERCOCKPIT_BRANCH` (Default: `develop`): The branch to checkout from ClusterCockpit git repository. May also be a tag.
* `APP_CLUSTERCOCKPIT_INIT` (Default: true): Wether the Symfony tree (located at `./data/symfony`) should be deleted and freshly cloned and initialized on every container startup.
* `APP_ENVIRONMENT` (Default: `dev`): The Symfony app environment. With `dev` you get the symfony debug toolbar and more extensive error handling. The `prod` environment is a setup for productions use.

## Setup

* `$ cd data`
* `$ ./init.sh`:  **NOTICE** The script will download files of a total size of 338MB (mostly for the InfluxDB data).

If you want to test the REST API and also write to the job archive from Cluster Cockpit you have to comment out the following lines in `./data/init.sh`:
```
echo "This script needs to chown the job-archive directory so that the application can write to it:"
sudo chown -R 82:82 ./job-archive
```

After that from the root of the cc-docker sandbox you can start up the containers with:
* `$ docker-compose up`
* Wait... and wait a little longer

Before you can use ClusterCockpit the following disclaimer must be shown. To download and build all ClusterCockpit components may take up to several minutes:
```
-------------------- ---------------------------------
  Symfony
 -------------------- ---------------------------------
  Version              5.3.7
  Long-Term Support    No
  End of maintenance   01/2022 (in +140 days)
  End of life          01/2022 (in +140 days)
 -------------------- ---------------------------------
  Kernel
 -------------------- ---------------------------------
  Type                 App\Kernel
  Environment          dev
  Debug                true
  Charset              UTF-8
  Cache directory      ./var/cache/dev (6.5 MiB)
  Build directory      ./var/cache/dev (6.5 MiB)
  Log directory        ./var/log (249 B)
 -------------------- ---------------------------------
  PHP
 -------------------- ---------------------------------
  Version              8.0.10
  Architecture         64 bits
  Intl locale          n/a
  Timezone             UTC (2021-09-13T09:41:33+00:00)
  OPcache              true
  APCu                 false
  Xdebug               false
 -------------------- ---------------------------------
 ```
 
By default, you can access ClusterCockpit in your browser at `http://localhost`. If the `NGINX_PORT` environment variable was changed, you have to use `http://localhost:$PORT` . You can shutdown the containers by pressing `CTRL-C`. Refer to the common docker documentation how to start the environment in the background.

## Usage

Credentials for the preconfigured admin user are:
* User: `admin`
* Password: `AdminDev`

You can also login as regular user using any credential in the LDAP user directory at `./data/ldap/users.ldif`.

The job archive with 1867 jobs originates from the second half of 2020.
Roughly 2700 jobs from the first week of 2021 are loaded with data from InfluxDB.
Some views of ClusterCockpit (e.g. the Users view) show the last week or month.
To show some data there you have to set the filter to time periods with jobs (August 2020 to January 2021).

# cc-docker

This is a setup for `docker compose` to try out a complete ClusterCockpit Application Stack including all external components. This docker setup can be easily configured to be used as demo or as a development environment for ClusterCockpit.

It creates containers for:
* mysql
* php-fpm
* nginx
* redis
* openldap
* influxdb
* phpmyadmin

All settings are configured in `.env`. The setup comes with fixture data for a job archive, influxDB, mySQL and a LDAP user directory.

## Known Issues

* `docker-compose` installed on Ubuntu (18.04, 20.04) via `apt-get` can not correctly parse `docker-compose.yml` due to version differences. Install latest version of `docker-compose` from https://docs.docker.com/compose/install/ instead.
* You need to ensure that no other web server is running on port 80 (e.g. Apache2). If port 80 is already in use, edit NGINX_PORT environment variable in `.env`.
* Existing VPN connections sometimes cause problems with docker. If `docker-compose` does not start up correctly, try disabling any active VPN connection. Refer to https://stackoverflow.com/questions/45692255/how-make-openvpn-work-with-docker for further information.

## Configuration

While many aspects of this docker compose setup can be configured you ussually only need to adapt the following three settings in `.env`:
* `CLUSTERCOCKPIT_BRANCH` (Default: `develop`): The branch to checkout from ClusterCockpit git repository. May also be a tag.
* `APP_CLUSTERCOCKPIT_INIT` (Default: true): Wether the Symfony tree (located at `./data/symfony`) should be deleted and freshly cloned and setup on every container startup.
* `APP_ENVIRONMENT` (Default: `dev`): The Symfony App environment. With `dev` you get a Debugging Toolbar and more extensive error handling. Using `prod` is a setup for productions usage.

## Setup

* `$ cd data`
* `$ ./init.sh`: The script asks for sudo rights as the file ownership needs to changed for some folders. **NOTICE** The script will download files of total size of 338MB (most for the InfluxDB data).

After that from the root of the repository you can start up the containers with:
* `docker-compose up`
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
 
By default, you can access ClusterCockpit in your browser at http://localhost . If the `NGINX_PORT` environment variable was changed, use `http://localhost:$PORT` . You can shutdown the containers by pressing `CTRL-C`.

## Usage

Credentials for the preconfigured admin user are:
* User: `admin`
* Password: `AdminDev`

You can also login as regular user using any credential in the LDAP user directory at `./data/ldap/users.ldif`.

# cc-docker
WARNING: This does not yet work!

This is a setup for `docker compose` to deploy a complete ClusterCockpit Application Stack including all external components.

At the end it will create containers for:
* mysql
* influxdb
* php-fpm (including the Symfony application)
* phpmyadmin
* nginx

Everything is configured in `.env`.

There exist multiple persistent (shared) volumes:
* `symfony` mapping to `/var/www/symfony` for the ClusterCockpit source tree
* `sql` mapping to `/var/lib/mysql`
* `influxdb/data` mapping to `/var/lib/influxdb2`
* `influxdb/config` mapping to `/etc//influxdb2`
* `logs/nginx` mapping to `/var/log/nginx`
* `logs/symfony` mapping to `/var/www/symfony/var/log`

The containers are build and started using the command:
```
docker compose up
```

Desired modes for the future are:

* **Demo** Includes everything to try out ClusterCockpit including initial Database Fixtures. No SSL and no reverse Proxy.
* **Develop** Only includes all external components of ClusterCockpit. A functional PHP environment and the ClusterCockpit source must be maintained on host machine.
* **Production** Includes everything to run ClusterCockpit in a Production environment including SSL and traefic reverse proxy and container orchestration.

TODOS (There are probably a lot more!):
* Some of the Volume directories need to be created first.
* ClusterCockpit is at the moment still using the influxDB V1 API, the InfluxDB container is already V2
* For a complete demo database setup, InfluxDB data fixtures are missing (MySQL demo database is available)

## Using for DEMO purpose

Before starting the containers the fixture data needs to be prepared:
* `$ cd data`
* `$ ./init.sh`

Known Issues:
* You need to ensure that no other web server is running on port 80 (e.g. Apache2). If port 80 is already in use, edit NGINX_PORT environment variable in `.env`.
* Existing VPN connections sometimes cause problems with docker. If `docker-compose` does not start up correctly, try disabling any active VPN connection. Refer to https://stackoverflow.com/questions/45692255/how-make-openvpn-work-with-docker for further information.

After that from the root of the repository you can start up the containers with:
* `docker-compose up`
* Wait... and wait a little longer

By default, you can access ClusterCockpit in your browser at http://localhost . If NGINX_PORT environment variable was changed, use http://localhost:$PORT .

Credentials for admin user are:
* User: `admin`
* Password: `AdminDev`

You can shutdown the containers by pressing `CTRL-C`.
Nothing is preserved! After shutting down the container everything is initialized from scratch.

To reuse an existing Symfony tree at `./data/symfony` you may remove the environment variable `DOCKER_CLUSTERCOCKPIT_INIT` in `docker-composer.yml` file.

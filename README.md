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
* For a running demo database fixtures for MySQL and InfluxDB are missing

## Using for DEMO purpose

Before starting the containers the fixture data needs to be prepared:
* `$ cd data`
* `$ ./init.sh`

After that from the root of the repository you can start up the containers with:
* `docker-compose up`
* Wait... and wait a little longer

You can access ClusterCockpit in your browser at http://localhost .
Credentials for admin user are:
* User: `admin`
* Password: `AdminDev`

Nothing is preserved! After shutting down the container everything is initialized from scratch.

To reuse an existing Symfony tree at `./data/symfony` you may remove the environment variable `DOCKER_CLUSTERCOCKPIT_INIT` in the docker file.

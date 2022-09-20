# cc-docker

**Please note: This repo is under ongoing construction**

This is a `docker-compose` setup which provides a quickly started environment for ClusterCockpit development and testing, using the modules `cc-backend` (GoLang) and `cc-frontend` (Svelte). A number of services is readily available as docker container (nats, cc-metric-store, InfluxDB, LDAP), or easily added by manual configuration (MySQL).

It includes the following containers:
* nats (Default)
* cc-metric-store (Default)
* influxdb (Default)
* openldap (Default)
* mysql (Optional)
* mariadb (Optional)
* phpmyadmin (Optional)

The setup comes with fixture data for a Job archive, cc-metric-store checkpoints, InfluxDB, MySQL, and a LDAP user directory.

## Known Issues

* `docker-compose` installed on Ubuntu (18.04, 20.04) via `apt-get` can not correctly parse `docker-compose.yml` due to version differences. Install latest version of `docker-compose` from https://docs.docker.com/compose/install/ instead.
* You need to ensure that no other web server is running on ports 8080 (cc-backend), 8081 (phpmyadmin), 8084 (cc-metric-store), 8086 (nfluxDB), 4222 and 8222 (Nats), or 3306 (MySQL). If one or more ports are already in use, you habe to adapt the related config accordingly.
* Existing VPN connections sometimes cause problems with docker. If `docker-compose` does not start up correctly, try disabling any active VPN connection. Refer to https://stackoverflow.com/questions/45692255/how-make-openvpn-work-with-docker for further information.

## Configuration Templates

Located in `./templates`  
* `docker-compose.yml.default`: Docker-Compose file to setup cc-metric-store, InfluxDB, MariaDB, PhpMyadmin, and LDAP containers (Default). Used in `setupDev.sh`.
* `docker-compose.yml.mysql`: Docker-Compose configuration template if MySQL is desired instead of MariaDB.
* `env.default`: Environment variables for setup with cc-metric-store, InfluxDB, MariaDB, PhpMyadmin, and LDAP containers (Default). Used in `setupDev.sh`.
* `env.mysql`: Additional environment variables required if MySQL is desired instead of MariaDB.

## Setup

1. Clone `cc-backend` repository in chosen base folder: `$> git clone https://github.com/ClusterCockpit/cc-backend.git`

2. Run `$ ./setupDev.sh`:  **NOTICE** The script will download files of a total size of 338MB (mostly for the InfluxDB data).  

3. The setup-script launches the supporting container stack in the background automatically if everything went well. Run `$> ./cc-backend/cc-backend` to start `cc-backend.`

4. By default, you can access `cc-backend` in your browser at `http://localhost:8080`. You can shut down the cc-backend server by pressing `CTRL-C`, remember to also shut down all containers via `$> docker-compose down` afterwards.

5. You can restart the containers with: `$> docker-compose up -d`.

## Post-Setup Adjustment for using `influxdb`

When using `influxdb` as a metric database, one must adjust the following files:  
* `cc-backend/var/job-archive/emmy/cluster.json`
* `cc-backend/var/job-archive/woody/cluster.json`

In the JSON, exchange the content of the `metricDataRepository`-Entry (By default configured for `cc-metric-store`) with:
```
"metricDataRepository": {
    "kind": "influxdb",
    "url": "http://localhost:8086",
    "token": "egLfcf7fx0FESqFYU3RpAAbj",
    "bucket": "ClusterCockpit",
    "org": "ClusterCockpit",
    "skiptls": false
}
```


## Usage

Credentials for the preconfigured demo user are:
* User: `demo`
* Password: `AdminDev`

You can also login as regular user using any credential in the LDAP user directory at `./data/ldap/users.ldif`.

The job archive with 1867 jobs originates from the second half of 2020.
Roughly 2700 jobs from the first week of 2021 are loaded with data from InfluxDB.
Some views of ClusterCockpit (e.g. the Users view) show the last week or month.
To show some data there you have to set the filter to time periods with jobs (August 2020 to January 2021).

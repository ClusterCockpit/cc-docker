# cc-docker

This is a `docker-compose` setup which provides a quickly started environment for ClusterCockpit development and testing, using `cc-backend`.
A number of services is readily available as docker container (nats, cc-metric-store, InfluxDB, LDAP, SLURM), or easily added by manual configuration (MariaDB).

It includes the following containers:
|Service full name|docker service name|port|
| --- | --- | --- |
|Slurm Controller service|slurmctld|6818|
|Slurm Database service|slurmdbd|6817|
|Slurm Rest service with JWT authentication|slurmrestd|6820|
|Slurm Worker|node01|6818|
|MariaDB service|mariadb|3306|
|InfluxDB serice|influxdb|8086|
|NATS service|nats|4222, 6222, 8222|
|cc-metric-store service|cc-metric-store|8084|
|OpenLDAP|openldap|389, 636|

The setup comes with fixture data for a Job archive, cc-metric-store checkpoints, InfluxDB, MariaDB, and a LDAP user directory.

## Prerequisites

For all the docker services to work correctly, you will need the following tools installed:

1. `docker` and `docker-compose`
2. `golang` (for compiling cc-metric-store)
3. `perl` (for migrateTimestamp.pl) with Cpanel::JSON::XS, Data::Dumper, Time::Piece, Sort::Versions and File::Slurp perl modules.
4. `npm` (for cc-backend)
5. `make` (for building slurm base image)

It is also recommended to add docker service to sudouser group since the setupDev.sh script assumes sudo permissions for docker and docker-compose services.

You can use:

```
sudo groupadd docker
sudo usermod -aG docker $USER 

# restart after adding your docker with your user to sudo group
sudo shutdown -r -t 0
```

Note: You can install all these dependencies via predefined installation steps in `prerequisite_installation_script.sh`.

If you are using different linux flavors, you will have to adapt `prerequisite_installation_script.sh` as well as `setupDev.sh`.

## Setup

1. Clone `cc-backend` repository in chosen base folder: `$> git clone https://github.com/ClusterCockpit/cc-backend.git`

2. Run `$ ./setupDev.sh`:  **NOTICE** The script will download files of a total size of 338MB (mostly for the cc-metric-store data).

3. The setup-script launches the supporting container stack in the background automatically if everything went well. Run `$> ./cc-backend/cc-backend -server -dev` to start `cc-backend`.

4. By default, you can access `cc-backend` in your browser at `http://localhost:8080`. You can shut down the cc-backend server by pressing `CTRL-C`, remember to also shut down all containers via `$> docker-compose down` afterwards.

5. You can restart the containers with: `$> docker-compose up -d`.

## Credentials for logging into clustercockpit

Credentials for the preconfigured demo user are:
* User: `demo`
* Password: `demo`

Credentials for the preconfigured LDAP user are:
* User: `ldapuser`
* Password: `ldapuser`

You can also login as regular user using any credential in the LDAP user directory at `./data/ldap/users.ldif`.

## Preconfigured setup between docker services and ClusterCockpit components

When you are done cloning the cc-backend repo and once you execute `setupDev.sh` file, it will copy a preconfigured `config.json` from `misc/config.json` and replace the `cc-backend/config.json`, which will be used by cc-backend, once you start the server. 
The preconfigured config.json attaches to:
#### 1. MariaDB docker service on port 3306 (database: ccbackend)
#### 2. OpenLDAP docker service on port 389
#### 3. cc-metric-store docker service on port 8084

cc-metric-store also has a preconfigured `config.json` in `cc-metric-store/config.json` which attaches to NATS docker service on port 4222 and subscribes to topic 'hpc-nats'.

Basically, all the ClusterCockpit components and the docker services attach to each other like lego pieces.

## Docker commands to access the services

> Note: You need to be in cc-docker directory in order to execute any docker command

You can view all docker processes running on either of the VM instance by using this command:

```
$ docker ps
```

Now that you can see the docker services, and if you want to manually access the docker services, you have to run **`bash`** command in those running services.

> **`Example`**: You want to run slurm commands like `sinfo` or `squeue` or `scontrol` on slurm controller, you cannot directly access it.

You need to **`bash`** into the running service by using the following command:

```
$ docker exec -it <docker service name> bash

#example
$ docker exec -it slurmctld bash

#or
$ docker exec -it mariadb bash
```

Once you start a **`bash`** on any docker service, then you may execute any service related commands in that **`bash`**.

But for Cluster Cockpit development, you only need ports to access these docker services. You have to use `localhost:<port>` when trying to access any docker service. You may need to configure the `cc-backend/config.json` based on these docker services and ports.

## Slurm setup in cc-docker

### 1. Slurm controller

Currently slurm controller is aware of the 1 node that we have setup in our mini cluster i.e. node01.

In order to execute slurm commands, you may need to **`bash`** into the **`slurmctld`** docker service.

```
$ docker exec -it slurmctld bash
```

Then you may be able to run slurm controller commands. A few examples without output are:

```
$ sinfo

or

$ squeue

or 

$ scontrol show nodes
```

### 2. Slurm rest service

You do not need to **`bash`** into the slurmrestd service but can directly access the rest API via localhost:6820. A simple example on how to CURL to the slurm rest API is given in the `curl_slurmrestd.sh`.

You can directly use `curl_slurmrestd.sh` with a never expiring JWT token ( can be found in /data/slurm/secret/jwt_token.txt )

You may also use the never expiring token directly from the file for any of your custom CURL commands.

## Known Issues

* `docker-compose` installed on Ubuntu (18.04, 20.04) via `apt-get` can not correctly parse `docker-compose.yml` due to version differences. Install latest version of `docker-compose` from https://docs.docker.com/compose/install/ instead.
* You need to ensure that no other web server is running on ports 8080 (cc-backend), 8082 (cc-metric-store), 8086 (InfluxDB), 4222 and 8222 (Nats), or 3306 (MariaDB). If one or more ports are already in use, you have to adapt the related config accordingly.
* Existing VPN connections sometimes cause problems with docker. If `docker-compose` does not start up correctly, try disabling any active VPN connection. Refer to https://stackoverflow.com/questions/45692255/how-make-openvpn-work-with-docker for further information.

## Docker services and restarting the services

You can find all the docker services in `docker-compose.yml`. Feel free to modify it.

Whenever you modify it, please use

```
$ docker compose down
```

in order to shut down all the services in all the VM’s (maininstance, nodeinstance, nodeinstance2) and then start all the services by using

```
$ docker compose up
```



TODO: Update job archive and all other metric data.
The job archive with 1867 jobs originates from the second half of 2020.
Roughly 2700 jobs from the first week of 2021 are loaded with data from InfluxDB.
Some views of ClusterCockpit (e.g. the Users view) show the last week or month.
To show some data there you have to set the filter to time periods with jobs (August 2020 to January 2021).
#!/bin/bash
echo ""
echo "|--------------------------------------------------------------------------------------|"
echo "| Welcome to cc-docker automatic deployment script.                                    |"
echo "| Make sure you have sudo rights to run docker services                                |"
echo "| This script assumes that docker command is added to sudo group                       |"
echo "| This means that docker commands do not explicitly require                            |"
echo "| 'sudo' keyword to run. You can use this following command:                           |"
echo "|                                                                                      |"
echo "| > sudo groupadd docker                                                               |"
echo "| > sudo usermod -aG docker $USER                                                      |"
echo "|                                                                                      |"
echo "| This will add docker to the sudo usergroup and all the docker                        |"
echo "| command will run as sudo by default without requiring                                |"
echo "| 'sudo' keyword.                                                                      |"
echo "|--------------------------------------------------------------------------------------|"
echo ""

# Check cc-backend if exists
if [ ! -d cc-backend ]; then
    echo "'cc-backend' not yet prepared! Please clone cc-backend repository before starting this script."
    echo -n "Stopped."
    exit
fi

# Creates data directory if it does not exists.
# Contains all the mount points required by all the docker services
# and their static files.
if [ ! -d data ]; then
    mkdir -m777 data
fi

# Invokes the dataGenerationScript.sh, which then populates the required
# static files by the docker services. These static files are required by docker services after startup.
chmod u+x dataGenerationScript.sh
./dataGenerationScript.sh

# Update timestamps for all the checkpoints in data/cc-metric-store-source
# and dumps new files in data/cc-metric-store.
perl ./migrateTimestamps.pl

# Create archive folder for rewritten ccms checkpoints
if [ ! -d data/cc-metric-store/archive ]; then
    mkdir -p data/cc-metric-store/archive
fi

# cleanup sources
if [ -d data/cc-metric-store-source ]; then
    rm -r data/cc-metric-store-source
fi

# Just in case user forgot manually shutdown the docker services.
docker-compose down
docker-compose down --remove-orphans

# This automatically builds the base docker image for slurm.
# All the slurm docker service in docker-compose.yml refer to
# the base image created from this directory.
cd slurm/base/
make
cd ../..

# Starts all the docker services from docker-compose.yml.
docker-compose build
docker-compose up -d

cd cc-backend
if [ ! -d var ]; then
    wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/job-archive-demo.tar
    tar xf job-archive-demo.tar
    rm ./job-archive-demo.tar

    cp ./configs/env-template.txt .env
    cp -f ../misc/config.json config.json

    make

    ./cc-backend -migrate-db
    ./cc-backend --init-db --add-user demo:admin:demo
    cd ..
else
    cd ..
    echo "'cc-backend/var' exists. Cautiously exiting."
    echo -n "Stopped."
    exit
fi

echo ""
echo "|--------------------------------------------------------------------------------------|"
echo "| Check logs for each slurm service by using these commands:                           |"
echo "| docker-compose logs slurmctld                                                        |"
echo "| docker-compose logs slurmdbd                                                         |"
echo "| docker-compose logs slurmrestd                                                       |"
echo "| docker-compose logs node01                                                           |"
echo "|======================================================================================|"
echo "| Setup complete, containers are up by default: Shut down with 'docker-compose down'.  |"
echo "| Use './cc-backend/cc-backend -server' to start cc-backend.                           |"
echo "| Use scripts in /scripts to load data into influx or mariadb.                         |"
echo "|--------------------------------------------------------------------------------------|"
echo ""

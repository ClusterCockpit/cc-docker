#!/bin/bash

# Check cc-backend, touch job.db if exists
if [ ! -d cc-backend ]; then
    echo "'cc-backend' not yet prepared! Please clone cc-backend repository before starting this script."
    echo -n "Stopped."
    exit
else
    cd cc-backend
    if [ ! -d var ]; then
        mkdir var
        touch var/job.db
        make
    else
        echo "'cc-backend/var' exists. Cautiously exiting."
        echo -n "Stopped."
        exit
    fi
fi

# Download unedited job-archive to ./data/job-archive-source
if [ ! -d data/job-archive-source ]; then
    wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/job-archive-demo.tar
    tar xf job-archive-demo.tar
    # mv ./var/job-archive ./job-archive-source
    # mv -f ./var/job.db ./cc-backend/var/
    # rm -rf ./var
    rm ./job-archive-demo.tar
    cd ..
else
    echo "'data/job-archive-source' already exists!"
fi

# Download unedited checkpoint files to ./data/cc-metric-store-source/checkpoints
if [ ! -d data/cc-metric-store-source ]; then
    mkdir -p data/cc-metric-store-source/checkpoints
    cd data/cc-metric-store-source/checkpoints
    wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/cc-metric-store-checkpoints.tar.xz
    tar xf cc-metric-store-checkpoints.tar.xz
    rm cc-metric-store-checkpoints.tar.xz
    cd ../../../
else
    echo "'data/cc-metric-store-source' already exists!"
fi

# Update timestamps
perl ./migrateTimestamps.pl

# Create archive folder for rewritten ccms checkpoints
if [ ! -d data/cc-metric-store/archive ]; then
    mkdir -p data/cc-metric-store/archive
fi

# cleanup sources
# rm -r ./data/job-archive-source
rm -r ./data/cc-metric-store-source

# prepare folders for influxdb2
if [ ! -d data/influxdb ]; then
    mkdir -p data/influxdb/data
    mkdir -p data/influxdb/config/influx-configs
else
    echo "'data/influxdb' already exists!"
fi

# Check dotenv-file and docker-compose-yml, copy accordingly if not present and build docker services
if [ ! -d .env ]; then
    cp templates/env.default ./.env
fi

if [ ! -f docker-compose.yml ]; then
    cp templates/docker-compose.yml.default ./docker-compose.yml
fi

docker-compose build
./cc-backend/cc-backend --init-db --add-user demo:admin:AdminDev
docker-compose up -d

# echo ""
# echo "Setup complete, containers are up by default: Shut down with 'docker-compose down'."
# echo "Use './cc-backend/cc-backend' to start cc-backend."
# echo "Use scripts in /scripts to load data into influx or mariadb."
# # ./cc-backend/cc-backend

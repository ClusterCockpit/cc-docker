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
    else
        echo "'cc-backend/var' exists. Cautiously exiting."
        echo -n "Stopped."
        exit
    fi
fi


# Download unedited job-archibe to /data
if [ ! -d data/job-archive ]; then
    cd data
    wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/job-archive.tar.xz
    tar xJf job-archive.tar.xz
    rm ./job-archive.tar.xz
    cd ..
fi



# Download data for influxdb2
if [ ! -d data/influxdb ]; then
    mkdir -p data/influxdb/data
    cd data/influxdb/data
    wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/influxdbv2-data.tar.xz
    tar xJf influxdbv2-data.tar.xz
    rm influxdbv2-data.tar.xz
    cd ../../../
else
    echo "'data/influxdb' already exists!"
    echo -n "Remove existing folder and redownload? [yes to redownload / no to continue]  "
    read -r answer
    if [ "$answer" == "yes" ]; then
        echo "Removing 'data/influxdb' ..."
        rm -rf data/influxdb
        echo "Reinstall 'data/influxdb'..."
        mkdir -p data/influxdb/data
        cd data/influxdb/data
        wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/influxdbv2-data.tar.xz
        tar xJf influxdbv2-data.tar.xz
        rm influxdbv2-data.tar.xz
        cd ../../../
        echo "done."
    else
        echo "'data/influxdb' unchanged."
    fi
fi

# Download checkpoint files for cc-metric-store
if [ ! -d data/cc-metric-store ]; then
  mkdir -p data/cc-metric-store/checkpoints
  mkdir -p data/cc-metric-store/archive
  cd data/cc-metric-store/checkpoints
  wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/cc-metric-store-checkpoints.tar.xz
  tar xf cc-metric-store-checkpoints.tar.xz
  rm cc-metric-store-checkpoints.tar.xz
  cd ../../../
else
    echo "'data/cc-metric-store' already exists!"
    echo -n "Remove existing folder and redownload? [yes to redownload / no to continue]  "
    read -r answer
    if [ "$answer" == "yes" ]; then
        echo "Removing 'data/cc-metric-store' ..."
        rm -rf data/cc-metric-store
        echo "Reinstall 'data/cc-metric-store'..."
        mkdir -p data/cc-metric-store/checkpoints
        mkdir -p data/cc-metric-store/archive
        cd data/cc-metric-store/checkpoints
        wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/cc-metric-store-checkpoints.tar.xz
        tar xf cc-metric-store-checkpoints.tar.xz
        rm cc-metric-store-checkpoints.tar.xz
        cd ../../../
        echo "done."
    else
        echo "'data/cc-metric-store' unchanged."
    fi
fi

# Check dotenv-file and docker-compose-yml, copy accordingly if not present and build docker services
# !! By default, this decides which metric database is used based on the selected argument !!
if [ ! -d .env ]; then
    cp templates/env.default ./.env
fi

if [ ! -d docker-compose.yml ]; then
    cp templates/docker-compose.yml.default ./docker-compose.yml
fi

docker-compose build

echo ""
echo "Setup complete. Use 'startDev.sh' to boot containers and start cc-backend."

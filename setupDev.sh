#!/bin/bash

if [ -z "$1" ]; then
    echo "No argument supplied. Use 'help', 'ccms' (Default), or 'influxdb'."
    exit
elif [ "$1" == "help" ]; then
    echo "Script to setup cc-backend devel environment. Use 'help', 'ccms' (Default), or 'influxdb' as argument."
    echo "'help' : This help."
    echo "'ccms' : Setup cc-metric-store example data and build docker container."
    echo "'influxdb' : Setup influxdb example data and build docker container. Requires additional configuration afterwards."
    exit
else
    echo "Starting setup for '$1' ..."
fi

# Download data for influxdb2
if [ "$1" == "influxdb" ]; then
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
fi

# Download checkpoint files for cc-metric-store
if [ "$1" == "ccms" ]; then
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
fi

# Download && Setup cc-backend
if [ ! -d cc-backend ]; then
    ## Get backend git [can use --recursive to load frontend via ssh directly]
    git clone https://github.com/ClusterCockpit/cc-backend.git
    cd cc-backend
    ## Get frontend git [http variant]
    cd frontend
    ### Comment ths if --recursive
    git clone https://github.com/ClusterCockpit/cc-frontend.git .
    yarn install
    yarn build
    cd ..
    ## Download Demo-Archive and prepare SQLite DB
    mkdir ./var
    cd ./var
    wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/job-archive.tar.xz
    tar xJf job-archive.tar.xz
    rm ./job-archive.tar.xz
    touch ./job.db
    cd ..
    ## Install backend
    go get
    go build
    ## initialize job archive and SQLite
    ./cc-backend --init-db --add-user demo:admin:AdminDev --no-server
    cd ..
else
    echo "'cc-backend' already exists!"
    echo -n "Remove existing folder and reinstall? [yes to reinstall / no to continue]  "
    read -r answer
    if [ "$answer" == "yes" ]; then
        echo "Removing 'cc-backend' ..."
        rm -rf cc-backend
        echo "Reinstall 'cc-backend'..."
        ## Get backend git [can use --recursive to load frontend via ssh directly]
        git clone https://github.com/ClusterCockpit/cc-backend.git
        cd cc-backend
        ## Get frontend git [http variant]
        cd frontend
        ### Comment ths if --recursive
        git clone https://github.com/ClusterCockpit/cc-frontend.git .
        yarn install
        yarn build
        cd ..
        ## Download Demo-Archive and prepare SQLite DB
        mkdir ./var
        cd ./var
        wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/job-archive.tar.xz
        tar xJf job-archive.tar.xz
        rm ./job-archive.tar.xz
        touch ./job.db
        cd ..
        ## Install backend
        go get
        go build
        ## initialize job archive and SQLite
        ./cc-backend --init-db --add-user demo:admin:AdminDev --no-server
        cd ..
    else
        echo "'cc-backend' unchanged."
    fi
fi


# Check dotenv-file and docker-compose-yml, copy accordingly if not present and build docker services
# !! By default, this decides which metric database is used based on the selected argument !!
if [ ! -d .env ]; then
    cp templates/env.$1 ./.env
fi

if [ ! -d docker-compose.yml ]; then
    cp templates/docker-compose.yml.$1 ./docker-compose.yml
fi

docker-compose build

echo ""
echo "Setup complete. Use 'startDev.sh' to boot containers and start cc-backend."

#!/usr/bin/env bash

if [ -d influxdb ]; then
    echo "Data already initialized!"
    echo -n "Perform a fresh initialisation? [yes to proceed / no to exit]  "
    read -r answer
    if [ "$answer" == "yes" ]; then
        echo "Cleaning directories ..."
        rm -rf job-archive
        rm -rf influxdb/data/*
        rm -rf sqldata/*
        echo "done."
    else
        echo "Aborting ..."
        exit
    fi
fi

# Download example job job-archive
wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/job-archive.tar.xz
tar xJf job-archive.tar.xz
rm ./job-archive.tar.xz

# Download data for influxdb2
mkdir -p influxdb/data
wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/influxdbv2-data.tar.xz
cd influxdb/data
tar xJf ../../influxdbv2-data.tar.xz
rm ../../influxdbv2-data.tar.xz
cd ../..

# Download checkpoint files for cc-metric-store
mkdir -p cc-metric-store/checkpoints
mkdir -p cc-metric-store/archive
cd cc-metric-store/checkpoints
wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/cc-metric-store-checkpoints.tar.xz
tar xf cc-metric-store-checkpoints.tar.xz
rm cc-metric-store-checkpoints.tar.xz
cd ../..

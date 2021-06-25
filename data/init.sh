#!/usr/bin/env bash

mkdir symfony
wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/job-archive.tar.xz
tar xJf job-archive.tar.xz
rm ./job-archive.tar.xz

if [ $# -gt 0 ]; then
    if [ $1 == "dev" ]; then
        mkdir -p influxdb/data
        wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/influxdbv2-data.tar.xz
        cd influxdb/data
        tar xJf ../../influxdbv2-data.tar.xz
        rm ../../influxdbv2-data.tar.xz
    fi
fi

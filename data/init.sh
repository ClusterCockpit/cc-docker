#!/usr/bin/env bash

mkdir symfony
wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/job-archive.tar.xz
tar xJf job-archive.tar.xz
rm ./job-archive.tar.xz

# Default: Copy SQL source for demo use - Includes no INFLUX-Job Metadata
cp ./sql-source/ClusterCockpit-demo.sql ./sql-init/ClusterCockpit.sql

if [ $# -gt 0 ]; then
    if [ $1 == "dev" ]; then
        # 101 is the uid and gid of the user and group www in the cc-php container running php-fpm.
        # For a demo with no new jobs it is enough to give www read permissions on that directory.
        sudo chown -R 101:101 ./job-archive

        mkdir -p influxdb/data
        wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/influxdbv2-data.tar.xz
        cd influxdb/data
        tar xJf ../../influxdbv2-data.tar.xz
        rm ../../influxdbv2-data.tar.xz

        cd ../..
        # If development: Use SQL source including INFLUX-Job Metadata instead
        cp ./sql-source/ClusterCockpit-dev.sql ./sql-init/ClusterCockpit.sql
    fi
fi

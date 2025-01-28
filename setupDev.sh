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

export UID_U=$(id -u $USER)
export GID_G=$(id -g $USER)

# Check cc-backend, touch job.db if exists
if [ ! -d cc-backend ]; then
    echo "'cc-backend' not yet prepared! Please clone cc-backend repository before starting this script."
    echo -n "Stopped."
    exit
else
    cd cc-backend
    if [ ! -d var ]; then
        wget https://hpc-mover.rrze.uni-erlangen.de/HPC-Data/0x7b58aefb/eig7ahyo6fo2bais0ephuf2aitohv1ai/job-archive-demo.tar
        tar xf job-archive-demo.tar
        rm ./job-archive-demo.tar

        cp ./configs/env-template.txt .env
        cp ./configs/config-demo.json config.json

        make

        ./cc-backend -migrate-db
        ./cc-backend --init-db --add-user demo:admin:AdminDev
        cd ..
    else
        cd ..
    #     echo "'cc-backend/var' exists. Cautiously exiting."
    #     echo -n "Stopped."
    #     exit
    fi
fi

mkdir -m777 data

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
# rm -r ./data/cc-metric-store-source

if [ ! -d data/mariadb ]; then
    mkdir -p data/mariadb
    cat > data/mariadb/01.databases.sql <<EOF
CREATE DATABASE IF NOT EXISTS \`ccbackend\`;
EOF
else
    echo "'data/mariadb' already exists!"
fi

if [ ! -d data/ldap ]; then
    mkdir -p data/ldap
    cat > data/ldap/add_users.ldif <<EOF
dn: ou=users,dc=example,dc=com
objectClass: organizationalUnit
ou: users

dn: uid=ldapuser,ou=users,dc=example,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
cn: Ldap User
sn: User
uid: ldapuser
uidNumber: 1
gidNumber: 1
homeDirectory: /home/ldapuser
userPassword: {SSHA}sQRqFQtuiupej7J/rbrQrTwYEHDduV+N
EOF

else
    echo "'data/ldap' already exists!"
fi

# prepare folders for influxdb2
if [ ! -d data/influxdb ]; then
    mkdir -p data/influxdb/data
    mkdir -p data/influxdb/config
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

docker-compose down
docker-compose down --remove-orphans

cd slurm/base/
make
cd ../..

docker-compose build
docker-compose up -d

cp -f config.json cc-backend/config.json

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

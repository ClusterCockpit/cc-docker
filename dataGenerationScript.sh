#!/bin/bash
echo ""
echo "|--------------------------------------------------------------------------------------|"
echo "| This is Data generation script for docker services                                   |"
echo "| Starting file required by docker services in data/                                   |"
echo "|--------------------------------------------------------------------------------------|"

# Download unedited checkpoint files to ./data/cc-metric-store-source/checkpoints
# After this, migrateTimestamp.pl will run from setupDev.sh. This will update the timestamps
# for all the checkpoint files, which then can be read by cc-metric-store.
# cc-metric-store reads only data upto certain time, like 48 hours of data.
# These checkpoint files have timestamp older than 48 hours and needs to be updated with
# migrateTimestamp.pl file, which will be automatically invoked from setupDev.sh.
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

# A simple configuration file for mariadb docker service.
# Required because you can specify only one database per docker service.
# This file mentions the database to be created for cc-backend.
# This file automatically picked by mariadb after the docker service starts.
if [ ! -d data/mariadb ]; then
    mkdir -p data/mariadb
    cat > data/mariadb/01.databases.sql <<EOF
CREATE DATABASE IF NOT EXISTS \`ccbackend\`;
EOF
else
    echo "'data/mariadb' already exists!"
fi

# A simple configuration file for openldap docker service.
# Creates a simple user 'ldapuser' with password 'ldapuser'.
# This file automatically picked by openldap after the docker service starts.
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

# A simple configuration file for nats docker service.
# Required because we need to execute custom commands after nats docker service starts.
# This file automatically executed when the nats docker service starts.
# After docker service starts, there is an infinite while loop that publises data for 'fritz' and 'alex' cluster 
# to subject 'hpc-nats' every 1 minute. Random data is generated only for node level metrics, not hardware level metrics.
if [ ! -d data/nats ]; then
    mkdir -p data/nats
    cat > data/nats/docker-entrypoint.sh <<EOF
#!/bin/sh
set -e

# Start NATS server in the background
nats-server --user root --pass root --http_port 8222 &

# Wait for NATS to be ready
until nc -z 0.0.0.0 4222; do
    echo "Waiting for NATS to start..."
    sleep 1
done

echo "NATS is up and running. Executing custom script..."

apk add curl
curl -sf https://binaries.nats.dev/nats-io/natscli/nats@latest | sh

# Run your custom script
while true; do

    timestamp="\$(date '+%s')"

    for metric in cpu_irq cpu_load mem_cached net_bytes_in cpu_user cpu_idle nfs4_read mem_used nfs4_write nfs4_total ib_xmit ib_xmit_pkts net_bytes_out cpu_iowait ib_recv cpu_system ib_recv_pkts; do
        for hostname in a0603 a0903 a0832 a0329 a0702 a0122 a1624 a0731 a0224 a0704 a0631 a0225 a0222 a0427 a0603 a0429 a0833 a0705 a0901 a0601 a0227 a0804 a0322 a0226 a0126 a0129 a0605 a0801 a0934; do
            echo "\$metric,cluster=alex,hostname=\$hostname,type=node value=$((1 + RANDOM % 100)).0 \$timestamp" >sample_alex.txt
        done
    done

    ./nats pub hpc-nats "\$(cat sample_alex.txt)" -s nats://0.0.0.0:4222 --user root --password root

    for metric in cpu_irq cpu_load mem_cached net_bytes_in cpu_user cpu_idle nfs4_read mem_used nfs4_write nfs4_total ib_xmit ib_xmit_pkts net_bytes_out cpu_iowait ib_recv cpu_system ib_recv_pkts; do
        for hostname in f0201 f0202 f0203 f0204 f0205 f0206 f0207 f0208 f0209 f0210 f0211 f0212 f0213 f0214 f0215 f0217 f0218 f0219 f0220 f0221 f0222 f0223 f0224 f0225 f0226 f0227 f0228 f0229; do
            echo "\$metric,cluster=fritz,hostname=\$hostname,type=node value=$((1 + RANDOM % 100)).0 \$timestamp" >sample_fritz.txt
        done
    done

    ./nats pub hpc-nats "\$(cat sample_fritz.txt)" -s nats://0.0.0.0:4222 --user root --password root

    sleep 1m

done
EOF

else
    echo "'data/nats' already exists!"
fi

# prepare folders for influxdb3
if [ ! -d data/influxdb ]; then
    mkdir -p data/influxdb/data
    mkdir -p data/influxdb/config
else
    echo "'data/influxdb' already exists!"
fi

echo ""
echo "|--------------------------------------------------------------------------------------|"
echo "| Finished generating relevant files for docker services in data/                      |"
echo "|--------------------------------------------------------------------------------------|"
#!/bin/bash
set -euo pipefail

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
    cat >data/mariadb/01.databases.sql <<EOF
CREATE DATABASE IF NOT EXISTS \`ccbackend\`;
EOF
else
    echo "'data/mariadb' already exists!"
fi

# Configuration file for the openldap docker service.
# Creates the dev users (password == uid) and the cc-* role groups used by
# auth.ldap.role-filters in config.json.
# This file is automatically picked up by openldap on first start.
if [ ! -d data/ldap ]; then
    mkdir -p data/ldap
    cat >data/ldap/add_users.ldif <<'LDIF'
# ClusterCockpit dev LDAP directory
# =================================
# Applied by the osixia/openldap container on first init via
# /container/service/slapd/assets/config/bootstrap/ldif/custom.
#
# Every account's password equals its uid (e.g. ccadmin / ccadmin).
# Hashes are {SSHA}; regenerate with `slappasswd -h {SSHA} -s <password>`.
#
# Role sync (auth.ldap.role-filters in config.json) matches on the memberOf
# attribute of the *user* entry. The memberof overlay of this image maintains
# memberOf for groupOfUniqueNames/uniqueMember, so the group entries below must
# come after the user entries they reference.

# ---------------------------------------------------------------------------
# Organizational units
# ---------------------------------------------------------------------------

dn: ou=users,dc=example,dc=com
objectClass: organizationalUnit
objectClass: top
ou: users

dn: ou=groups,dc=example,dc=com
objectClass: organizationalUnit
objectClass: top
ou: groups

# ---------------------------------------------------------------------------
# Users
# ---------------------------------------------------------------------------

dn: uid=ldapuser,ou=users,dc=example,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
cn: Ldap User
sn: User
uid: ldapuser
uidNumber: 1
gidNumber: 100
homeDirectory: /home/ldapuser
userPassword: {SSHA}0OhsiEb+IXanz71bd7jyFhvy0xhPJ34e

dn: uid=ccadmin,ou=users,dc=example,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
cn: CC Admin
sn: Admin
uid: ccadmin
uidNumber: 2000
gidNumber: 100
homeDirectory: /home/ccadmin
userPassword: {SSHA}HfIVI9GeNot9ea5bSXgKNcF6kP0MUyfv

dn: uid=ccsupport,ou=users,dc=example,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
cn: CC Support
sn: Support
uid: ccsupport
uidNumber: 2001
gidNumber: 100
homeDirectory: /home/ccsupport
userPassword: {SSHA}7zCZNDYQZPZl8jcBSkU+UnmxCR8lD9sm

dn: uid=ccmanager,ou=users,dc=example,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
cn: CC Manager
sn: Manager
uid: ccmanager
uidNumber: 2002
gidNumber: 100
homeDirectory: /home/ccmanager
userPassword: {SSHA}DKcUb2h8DWbDtTjXtIvwDi4Bf29vzhKK

dn: uid=ccapi,ou=users,dc=example,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
cn: CC Api
sn: Api
uid: ccapi
uidNumber: 2003
gidNumber: 100
homeDirectory: /home/ccapi
userPassword: {SSHA}dhcxIxs883hX2CTpkQp7cNgc0+puJ23z

dn: uid=ccuser,ou=users,dc=example,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
cn: CC User
sn: User
uid: ccuser
uidNumber: 2004
gidNumber: 100
homeDirectory: /home/ccuser
userPassword: {SSHA}UKYfiDmhT/H01R20rtYYOBj7t/w7yLyW

# ---------------------------------------------------------------------------
# Role groups
# The memberof overlay of this image is configured for groupOfUniqueNames /
# uniqueMember, so these classes are required for memberOf to be maintained.
# ---------------------------------------------------------------------------

dn: cn=cc-admin,ou=groups,dc=example,dc=com
objectClass: groupOfUniqueNames
objectClass: top
cn: cc-admin
description: Grants the ClusterCockpit admin role
uniqueMember: uid=ccadmin,ou=users,dc=example,dc=com

dn: cn=cc-support,ou=groups,dc=example,dc=com
objectClass: groupOfUniqueNames
objectClass: top
cn: cc-support
description: Grants the ClusterCockpit support role
uniqueMember: uid=ccsupport,ou=users,dc=example,dc=com

dn: cn=cc-manager,ou=groups,dc=example,dc=com
objectClass: groupOfUniqueNames
objectClass: top
cn: cc-manager
description: Grants the ClusterCockpit manager role
uniqueMember: uid=ccmanager,ou=users,dc=example,dc=com

dn: cn=cc-api,ou=groups,dc=example,dc=com
objectClass: groupOfUniqueNames
objectClass: top
cn: cc-api
description: Grants the ClusterCockpit api role
uniqueMember: uid=ccapi,ou=users,dc=example,dc=com
LDIF

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
    cat >data/nats/docker-entrypoint.sh <<EOF
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

# This is a dummy data generation loop, that inserts data for given nodes at 1 min interval
while true; do

    # Timestamp in seconds
    timestamp="\$(date '+%s')"

    # Generate data for alex cluster. Push to sample_alex.txt
    for metric in cpu_irq cpu_load mem_cached net_bytes_in cpu_user cpu_idle nfs4_read mem_used nfs4_write nfs4_total ib_xmit ib_xmit_pkts net_bytes_out cpu_iowait ib_recv cpu_system ib_recv_pkts; do
        for hostname in a0603 a0903 a0832 a0329 a0702 a0122 a1624 a0731 a0224 a0704 a0631 a0225 a0222 a0427 a0603 a0429 a0833 a0705 a0901 a0601 a0227 a0804 a0322 a0226 a0126 a0129 a0605 a0801 a0934; do
            echo "\$metric,cluster=alex,hostname=\$hostname,type=node value=\$((1 + RANDOM % 100)).0 \$timestamp" >>sample_alex.txt
        done
    done

    # Nats client will publish the data from sample_alex.txt to 'hpc-nats' subject on this nats server
    ./nats pub hpc-nats "\$(cat sample_alex.txt)" -s nats://0.0.0.0:4222 --user root --password root

    # Generate data for fritz cluster. Push to sample_fritz.txt
    for metric in cpu_irq cpu_load mem_cached net_bytes_in cpu_user cpu_idle nfs4_read mem_used nfs4_write nfs4_total ib_xmit ib_xmit_pkts net_bytes_out cpu_iowait ib_recv cpu_system ib_recv_pkts; do
        for hostname in f0201 f0202 f0203 f0204 f0205 f0206 f0207 f0208 f0209 f0210 f0211 f0212 f0213 f0214 f0215 f0217 f0218 f0219 f0220 f0221 f0222 f0223 f0224 f0225 f0226 f0227 f0228 f0229; do
            echo "\$metric,cluster=fritz,hostname=\$hostname,type=node value=\$((1 + RANDOM % 100)).0 \$timestamp" >>sample_fritz.txt
        done
    done

    # Nats client will publish the data from sample_fritz.txt to 'hpc-nats' subject on this nats server
    ./nats pub hpc-nats "\$(cat sample_fritz.txt)" -s nats://0.0.0.0:4222 --user root --password root

    rm sample_alex.txt
    rm sample_fritz.txt

    sleep 1m

done
EOF

else
    echo "'data/nats' already exists!"
fi

if [ ! -d data/slurm/home/worker/CCSA ]; then
    mkdir -p data/slurm/home/worker/CCSA

    cat >data/slurm/home/worker/CCSA/config.json <<EOF
{
    "pidFilePath": "/home/worker/CCSA/daemon.pid",
    "ipcSockPath": "/home/worker/CCSA/daemon.sock",
    "lastRunPath": "/home/worker/CCSA/last_run",
    "slurmPollInterval": 10,
    "ccRestUrl": "http://host.docker.internal:8080",
    "ccRestJwt": ""
}
EOF

chmod 777 data/slurm/home/worker/CCSA/config.json

else
    echo "'data/slurm/worker' already exists!"
fi

echo ""
echo "|--------------------------------------------------------------------------------------|"
echo "| Finished generating relevant files for docker services in data/                      |"
echo "|--------------------------------------------------------------------------------------|"

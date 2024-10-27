#!/usr/bin/env bash
set -e

# Determine the system architecture dynamically
ARCH=$(uname -m)
SLURM_VERSION="24.05.3"
# SLURMRESTD="/tmp/slurmrestd.socket"
SLURM_JWT=daemon

# start sshd server
_sshd_host() {
    if [ ! -d /var/run/sshd ]; then
        mkdir /var/run/sshd
        ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
    fi
    /usr/sbin/sshd
}

# start munge using existing key
_munge_start_using_key() {
    if [ ! -f /.secret/munge.key ]; then
        echo -n "checking for munge.key"
        while [ ! -f /.secret/munge.key ]; do
            echo -n "."
            sleep 1
        done
        echo ""
    fi
    cp /.secret/munge.key /etc/munge/munge.key
    chown -R munge: /etc/munge /var/lib/munge /var/log/munge /var/run/munge
    chmod 0700 /etc/munge
    chmod 0711 /var/lib/munge
    chmod 0700 /var/log/munge
    chmod 0755 /var/run/munge
    sudo -u munge /sbin/munged
    munge -n
    munge -n | unmunge
    remunge
}

_enable_slurmrestd() {

    cat >/usr/lib/systemd/system/slurmrestd.service <<EOF
[Unit]
Description=Slurm REST daemon
After=network-online.target slurmctld.service
Wants=network-online.target
ConditionPathExists=/etc/slurm/slurm.conf

[Service]
Type=simple
EnvironmentFile=-/etc/sysconfig/slurmrestd
EnvironmentFile=-/etc/default/slurmrestd
# slurmrestd should not run as root or the slurm user.
# Please either use the -u and -g options in /etc/sysconfig/slurmrestd or
# /etc/default/slurmrestd, or explicitly set the User and Group in this file
# an unpriviledged user to run as.
User=slurm
Restart=always
RestartSec=5
# Group=
# Default to listen on both socket and slurmrestd port
ExecStart=/usr/sbin/slurmrestd -f /etc/config/slurmrestd.conf -a rest_auth/jwt $SLURMRESTD_OPTIONS -vvvvvv -s dbv0.0.39,v0.0.39 0.0.0.0:6820
# Enable auth/jwt be default, comment out the line to disable it for slurmrestd
Environment="SLURM_JWT=daemon"
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target

EOF
}

# run slurmrestd
_slurmrestd() {
    cd /root/rpmbuild/RPMS/$ARCH
    yum -y --nogpgcheck localinstall slurm-$SLURM_VERSION*.$ARCH.rpm \
        slurm-perlapi-$SLURM_VERSION*.$ARCH.rpm \
        slurm-slurmd-$SLURM_VERSION*.$ARCH.rpm \
        slurm-torque-$SLURM_VERSION*.$ARCH.rpm \
        slurm-slurmctld-$SLURM_VERSION*.$ARCH.rpm \
        slurm-slurmrestd-$SLURM_VERSION*.$ARCH.rpm

    echo -n "checking for slurmdbd.conf"
    while [ ! -f /.secret/slurmdbd.conf ]; do
        echo -n "."
        sleep 1
    done
    echo ""

    mkdir -p /etc/config /var/spool/slurm /var/spool/slurm/restd /var/spool/slurm/restd/rest /var/run/slurm
    chown -R slurm: /etc/config /var/spool/slurm /var/spool/slurm/restd /var/spool/slurm/restd/rest /var/run/slurm
    chmod 755 /var/run/slurm

    touch /var/log/slurmrestd.log
    chown slurm: /var/log/slurmrestd.log

    if [[ ! -f /home/config/slurmrestd.conf ]]; then
        echo "### Missing slurm.conf ###"
        exit
    else
        echo "### use provided slurmrestd.conf ###"
        cp /home/config/slurmrestd.conf /etc/config/slurmrestd.conf
        cp /home/config/slurm.conf /etc/config/slurm.conf
    fi

    echo "checking for jwt.key"
    while [ ! -f /.secret/jwt_hs256.key ]; do
        echo "."
        sleep 1
    done

    sudo yum install -y nc
    sudo yum install -y procps
    sudo yum install -y iputils
    sudo yum install -y lsof
    sudo yum install -y socat

    mkdir -p /var/spool/slurm/statesave
    chown slurm:slurm /var/spool/slurm/statesave
    chmod 0755 /var/spool/slurm/statesave
    cp /.secret/jwt_hs256.key /var/spool/slurm/statesave/jwt_hs256.key
    chown slurm: /var/spool/slurm/statesave/jwt_hs256.key
    chmod 0400 /var/spool/slurm/statesave/jwt_hs256.key

    echo ""

    sleep 2s
    echo "Starting slurmrestd"
    # _enable_slurmrestd
    # sudo ln -s /usr/lib/systemd/system/slurmrestd.service /etc/systemd/system/multi-user.target.wants/slurmrestd.service

    SLURMRESTD_SECURITY=disable_user_check SLURMRESTD_DEBUG=9 /usr/sbin/slurmrestd -f /etc/config/slurmrestd.conf -a rest_auth/jwt -s dbv0.0.39,v0.0.39 -u slurm 0.0.0.0:6820
    echo "Started slurmrestd"
}

### main ###
_sshd_host
_munge_start_using_key
_slurmrestd

tail -f /dev/null

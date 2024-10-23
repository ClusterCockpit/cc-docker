#!/usr/bin/env bash
set -e

# Determine the system architecture dynamically
ARCH=$(uname -m)
SLURM_VERSION="24.05.3"

# start sshd server
_sshd_host() {
    if [ ! -d /var/run/sshd ]; then
        mkdir /var/run/sshd
        ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
    fi
    /usr/sbin/sshd
}

# start munge and generate key
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
    # mkdir -p /var/spool/slurm/ctld /var/spool/slurm/d /var/log/slurm /etc/slurm
    # chown -R slurm: /var/spool/slurm/ctld /var/spool/slurm/d /var/log/slurm

    mkdir -p /etc/config /var/spool/slurm /var/spool/slurm/restd /var/spool/slurm/restd/rest
    chown -R slurm: /etc/config /var/spool/slurm /var/spool/slurm/restd /var/spool/slurm/restd/rest

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
    sleep 2s
    export SLURMRESTD=/var/spool/slurm/restd/rest
    /usr/sbin/slurmrestd -f /etc/config/slurmrestd.conf -s dbv0.0.39,v0.0.39 -vv -u slurm 0.0.0.0:6820
}

### main ###
_sshd_host
_munge_start_using_key
_slurmrestd

tail -f /dev/null

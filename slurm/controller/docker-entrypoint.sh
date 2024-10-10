#!/usr/bin/env bash
set -e

# Determine the system architecture dynamically
ARCH=$(uname -m)

# start sshd server
_sshd_host() {
  if [ ! -d /var/run/sshd ]; then
    mkdir /var/run/sshd
    ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
  fi
  echo "Starting sshd"
  /usr/sbin/sshd
}

# setup worker ssh to be passwordless
_ssh_worker() {
    if [[ ! -d /home/worker  ]]; then
        mkdir -p /home/worker
        chown -R worker:worker /home/worker
    fi
    cat > /home/worker/setup-worker-ssh.sh <<EOF2
mkdir -p ~/.ssh
chmod 0700 ~/.ssh
ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N "" -C "$(whoami)@$(hostname)-$(date -I)"
cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys
chmod 0640 ~/.ssh/authorized_keys
cat >> ~/.ssh/config <<EOF
Host *
StrictHostKeyChecking no
UserKnownHostsFile /dev/null
LogLevel QUIET
EOF
chmod 0644 ~/.ssh/config
cd ~/
tar -czvf ~/worker-secret.tar.gz .ssh
cd -
EOF2
    chmod +x /home/worker/setup-worker-ssh.sh
    chown worker: /home/worker/setup-worker-ssh.sh
    sudo -u worker /home/worker/setup-worker-ssh.sh
}

# start munge and generate key
_munge_start() {
    echo  "Starting munge"
    chown -R munge: /etc/munge /var/lib/munge /var/log/munge /var/run/munge
    chmod 0700 /etc/munge
    chmod 0711 /var/lib/munge
    chmod 0700 /var/log/munge
    chmod 0755 /var/run/munge
    /sbin/create-munge-key -f
    rngd -r /dev/urandom
    /usr/sbin/create-munge-key -r -f
    sh -c  "dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key"
    chown munge: /etc/munge/munge.key
    chmod 400 /etc/munge/munge.key
    sudo -u munge /sbin/munged
    munge -n
    munge -n | unmunge
    remunge
}

# copy secrets to /.secret directory for other nodes
_copy_secrets() {
  cp /home/worker/worker-secret.tar.gz /.secret/worker-secret.tar.gz
  cp /home/worker/setup-worker-ssh.sh /.secret/setup-worker-ssh.sh
  cp /etc/munge/munge.key /.secret/munge.key
  rm -f /home/worker/worker-secret.tar.gz
  rm -f /home/worker/setup-worker-ssh.sh
}

# run slurmctld
_slurmctld() {
    cd /root/rpmbuild/RPMS/$ARCH
    yum -y --nogpgcheck localinstall slurm-22.05.6-1.el8.$ARCH.rpm \
        slurm-perlapi-22.05.6-1.el8.$ARCH.rpm \
        slurm-slurmd-22.05.6-1.el8.$ARCH.rpm \
        slurm-torque-22.05.6-1.el8.$ARCH.rpm \
        slurm-slurmctld-22.05.6-1.el8.$ARCH.rpm
    echo "checking for slurmdbd.conf"
    while [ ! -f /.secret/slurmdbd.conf ]; do
        echo -n "."
        sleep 1
    done
    echo ""
    mkdir -p /var/spool/slurm/ctld /var/spool/slurm/d  /var/log/slurm /etc/slurm
    chown -R slurm: /var/spool/slurm/ctld /var/spool/slurm/d  /var/log/slurm
    touch /var/log/slurmctld.log
    chown slurm: /var/log/slurmctld.log
    if [[ ! -f /home/config/slurm.conf ]]; then
        echo "### Missing slurm.conf ###"
        exit
    else
        echo "### use provided slurm.conf ###"
        cp /home/config/slurm.conf /etc/slurm/slurm.conf
        chown slurm: /etc/slurm/slurm.conf
        chmod 600 /etc/slurm/slurm.conf
    fi
    sacctmgr -i add cluster "snowflake"
    sleep 2s
    echo  "Starting slurmctld"
    cp -f /etc/slurm/slurm.conf /.secret/
    /usr/sbin/slurmctld
}

### main ###
_sshd_host
_ssh_worker
_munge_start
_copy_secrets
_slurmctld

tail -f /dev/null
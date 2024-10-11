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
  /usr/sbin/sshd
}

# start munge using existing key
_munge_start_using_key() {
  echo -n "cheking for munge.key"
  while [ ! -f /.secret/munge.key ]; do
    echo -n "."
    sleep 1
  done
  echo ""
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

# wait for worker user in shared /home volume
_wait_for_worker() {
  if [ ! -f /home/worker/.ssh/id_rsa.pub ]; then
    echo -n "checking for id_rsa.pub"
    while [ ! -f /home/worker/.ssh/id_rsa.pub ]; do
      echo -n "."
      sleep 1
    done
    echo ""
  fi
}

_start_dbus() {
    dbus-uuidgen > /var/lib/dbus/machine-id
    mkdir -p /var/run/dbus
    dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address
}

# run slurmd
_slurmd() {
    cd /root/rpmbuild/RPMS/$ARCH
    yum -y --nogpgcheck localinstall slurm-22.05.6-1.el8.$ARCH.rpm \
        slurm-perlapi-22.05.6-1.el8.$ARCH.rpm \
        slurm-slurmd-22.05.6-1.el8.$ARCH.rpm \
        slurm-torque-22.05.6-1.el8.$ARCH.rpm
    if [ ! -f /.secret/slurm.conf ]; then
        echo -n "checking for slurm.conf"
        while [ ! -f /.secret/slurm.conf ]; do
          echo -n "."
          sleep 1
        done
        echo ""
    fi
    mkdir -p /var/spool/slurm/d /etc/slurm
    chown slurm: /var/spool/slurm/d
    cp /home/config/cgroup.conf /etc/slurm/cgroup.conf
    chown slurm: /etc/slurm/cgroup.conf
    chmod 600 /etc/slurm/cgroup.conf
    cp /home/config/slurm.conf /etc/slurm/slurm.conf
    chown slurm: /etc/slurm/slurm.conf
    chmod 600 /etc/slurm/slurm.conf
    touch /var/log/slurmd.log
    chown slurm: /var/log/slurmd.log
    echo -n "Starting slurmd"
    /usr/sbin/slurmd
    echo -n "Started slurmd"
}

### main ###
_sshd_host
_munge_start_using_key
_wait_for_worker
_start_dbus
_slurmd

tail -f /dev/null

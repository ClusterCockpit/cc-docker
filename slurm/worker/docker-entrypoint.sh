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
  sudo yum install -y nc
  sudo yum install -y procps
  sudo yum install -y iputils

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
  echo "checking for id_rsa.pub"
  if [ ! -f /home/worker/.ssh/id_rsa.pub ]; then
    echo "checking for id_rsa.pub"
    while [ ! -f /home/worker/.ssh/id_rsa.pub ]; do
      echo -n "."
      sleep 1
    done
    echo ""
  fi
  echo "done checking for id_rsa.pub"

}

_start_dbus() {
  dbus-uuidgen >/var/lib/dbus/machine-id
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

  echo "checking for slurm.conf"
  if [ ! -f /.secret/slurm.conf ]; then
    echo "checking for slurm.conf"
    while [ ! -f /.secret/slurm.conf ]; do
      echo -n "."
      sleep 1
    done
    echo ""
  fi
  echo "found slurm.conf"

  mkdir -p /var/spool/slurm/d /etc/slurm /var/run/slurm/d /var/log/slurm
  chown slurm: /var/spool/slurm/d /var/run/slurm/d /var/log/slurm
  cp /home/config/cgroup.conf /etc/slurm/cgroup.conf
  chown slurm: /etc/slurm/cgroup.conf
  chmod 600 /etc/slurm/cgroup.conf
  cp /home/config/slurm.conf /etc/slurm/slurm.conf
  chown slurm: /etc/slurm/slurm.conf
  chmod 600 /etc/slurm/slurm.conf
  touch /var/log/slurm/slurmd.log
  chown slurm: /var/log/slurm/slurmd.log

  touch /var/run/slurm/d/slurmd.pid
  chmod 600 /var/run/slurm/d/slurmd.pid
  chown slurm: /var/run/slurm/d/slurmd.pid

  echo "Starting slurmd"
  /usr/sbin/slurmd -Dvv
  echo "Started slurmd"
}

### main ###
_sshd_host
_munge_start_using_key
_wait_for_worker
_start_dbus
_slurmd

tail -f /dev/null

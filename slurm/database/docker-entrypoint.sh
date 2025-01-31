#!/usr/bin/env bash
set -e

# Determine the system architecture dynamically
ARCH=$(uname -m)
SLURM_VERSION="24.05.3"
SLURM_JWT=daemon
SLURM_ACCT_DB_SQL=/slurm_acct_db.sql

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

# run slurmdbd
_slurmdbd() {
  cd /root/rpmbuild/RPMS/$ARCH
  yum -y --nogpgcheck localinstall slurm-$SLURM_VERSION*.$ARCH.rpm \
    slurm-perlapi-$SLURM_VERSION*.$ARCH.rpm \
    slurm-slurmdbd-$SLURM_VERSION*.$ARCH.rpm
  mkdir -p /var/spool/slurm/d /var/log/slurm /etc/slurm
  chown -R slurm: /var/spool/slurm/d /var/log/slurm

  mkdir -p /etc/config
  chown -R slurm: /etc/config

  if [[ ! -f /home/config/slurmdbd.conf ]]; then
    echo "### Missing slurmdbd.conf ###"
    exit
  else
    echo "### use provided slurmdbd.conf ###"
    cp /home/config/slurmdbd.conf /etc/slurm/slurmdbd.conf
    chown slurm: /etc/slurm/slurmdbd.conf
    chmod 600 /etc/slurm/slurmdbd.conf
    cp /etc/slurm/slurmdbd.conf /.secret/slurmdbd.conf
  fi

  echo "checking for jwt.key"
  while [ ! -f /.secret/jwt_hs256.key ]; do
    echo "."
    sleep 1
  done

  mkdir -p /var/spool/slurm/statesave
  chown slurm:slurm /var/spool/slurm/statesave
  chmod 0755 /var/spool/slurm/statesave
  cp /.secret/jwt_hs256.key /var/spool/slurm/statesave/jwt_hs256.key
  chown slurm: /var/spool/slurm/statesave/jwt_hs256.key
  chmod 0600 /var/spool/slurm/statesave/jwt_hs256.key

  echo ""

  sudo yum install -y nc
  sudo yum install -y procps
  sudo yum install -y iputils

  echo "Starting slurmdbd"
  /usr/sbin/slurmdbd -Dvv
  echo "Started slurmdbd"
}

### main ###
_sshd_host
_munge_start_using_key
_wait_for_worker
_slurmdbd

tail -f /dev/null

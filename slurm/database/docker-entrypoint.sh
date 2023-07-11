#!/usr/bin/env bash
set -e

SLURM_ACCT_DB_SQL=/slurm_acct_db.sql

# start sshd server
_sshd_host() {
  if [ ! -d /var/run/sshd ]; then
    mkdir /var/run/sshd
    ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
  fi
  /usr/sbin/sshd
}

# slurm database user settings
_slurm_acct_db() {
  {
    echo "create database slurm_acct_db;"
    echo "create user 'slurm'@slurmdb'';"
    echo "set password for 'slurm'@'slurmdb' = password('demo');"
    echo "grant usage on *.* to 'slurm'@'slurmdb';"
    echo "grant all privileges on slurm_acct_db.* to 'slurm'@'slurmdb';"
    echo "flush privileges;"
  } >> $SLURM_ACCT_DB_SQL
}

# start database
_mariadb_start() {
  # mariadb somehow expects `resolveip` to be found under this path; see https://github.com/SciDAS/slurm-in-docker/issues/26
  ln -s /usr/bin/resolveip /usr/libexec/resolveip
  mysql_install_db
  chown -R mysql: /var/lib/mysql/ /var/log/mariadb/ /var/run/mariadb
  cd /var/lib/mysql
  mysqld_safe --user=mysql &
  cd /
  _slurm_acct_db
  sleep 5s
  mysql -uroot < $SLURM_ACCT_DB_SQL
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
  mkdir -p /var/spool/slurm/d \
    /var/log/slurm
  chown slurm: /var/spool/slurm/d \
    /var/log/slurm
  if [[ ! -f /home/config/slurmdbd.conf ]]; then
    echo "### Missing slurmdbd.conf ###"
    exit
  else
    echo "### use provided slurmdbd.conf ###"
    cp /home/config/slurmdbd.conf /etc/slurm/slurmdbd.conf
  fi
  /usr/sbin/slurmdbd
  cp /etc/slurm/slurmdbd.conf /.secret/slurmdbd.conf
}

### main ###
_sshd_host
_mariadb_start
_munge_start_using_key
_wait_for_worker
_slurmdbd

tail -f /dev/null

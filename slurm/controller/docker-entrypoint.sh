#!/usr/bin/env bash
set -e

# Determine the system architecture dynamically
ARCH=$(uname -m)
SLURM_VERSION="24.05.3"
SLURM_JWT=daemon
SLURMRESTD_SECURITY=disable_user_check

_delete_secrets() {
    if [ -f /.secret/munge.key ]; then
        echo "Removing secrets"
        sudo rm -rf /.secret/munge.key
        sudo rm -rf /.secret/worker-secret.tar.gz
        sudo rm -rf /.secret/setup-worker-ssh.sh
        sudo rm -rf /.secret/jwt_hs256.key
        sudo rm -rf /.secret/jwt_token.txt

        echo "Done removing secrets"
        ls /.secret/
    fi
}

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
    if [[ ! -d /home/worker ]]; then
        mkdir -p /home/worker
        chown -R worker:worker /home/worker
    fi
    cat >/home/worker/setup-worker-ssh.sh <<EOF2
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
    echo "Starting munge"
    chown -R munge: /etc/munge /var/lib/munge /var/log/munge /var/run/munge
    chmod 0700 /etc/munge
    chmod 0711 /var/lib/munge
    chmod 0700 /var/log/munge
    chmod 0755 /var/run/munge
    /sbin/create-munge-key -f
    rngd -r /dev/urandom
    /usr/sbin/create-munge-key -r -f
    sh -c "dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key"
    chown munge: /etc/munge/munge.key
    chmod 600 /etc/munge/munge.key
    sudo -u munge /sbin/munged
    munge -n
    munge -n | unmunge
    remunge
}

# copy secrets to /.secret directory for other nodes
_copy_secrets() {
    while [ ! -f /home/worker/worker-secret.tar.gz ]; do
        echo -n "."
        sleep 1
    done
    cp /home/worker/worker-secret.tar.gz /.secret/worker-secret.tar.gz
    cp /home/worker/setup-worker-ssh.sh /.secret/setup-worker-ssh.sh
    cp /etc/munge/munge.key /.secret/munge.key
    rm -f /home/worker/worker-secret.tar.gz
    rm -f /home/worker/setup-worker-ssh.sh
}

_openssl_jwt_key() {

    mkdir -p /var/spool/slurm/statesave
    dd if=/dev/random of=/var/spool/slurm/statesave/jwt_hs256.key bs=32 count=1
    chown slurm:slurm /var/spool/slurm/statesave/jwt_hs256.key
    chmod 0600 /var/spool/slurm/statesave/jwt_hs256.key
    chown slurm:slurm /var/spool/slurm/statesave
    chmod 0755 /var/spool/slurm/statesave
    cp /var/spool/slurm/statesave/jwt_hs256.key /.secret/jwt_hs256.key
    chmod 777 /.secret/jwt_hs256.key
}

_generate_jwt_token() {

    secret_key=$(cat /var/spool/slurm/statesave/jwt_hs256.key)
    start_time=$(date +%s)
    exp_time=$((start_time + 100000000))
    base64url() {
        # Don't wrap, make URL-safe, delete trailer.
        base64 -w 0 | tr '+/' '-_' | tr -d '='
    }

    jwt_header=$(echo -n '{"alg":"HS256","typ":"JWT"}' | base64url)

    jwt_claims=$(cat <<EOF |
{
  "sun": "root",
  "exp": $exp_time,
  "iat": $start_time
}
EOF
        jq -Mcj '.' | base64url)
    # jq -Mcj => Monochrome output, compact output, join lines

    jwt_signature=$(echo -n "${jwt_header}.${jwt_claims}" |
        openssl dgst -sha256 -hmac "$secret_key" -binary | base64url)

    # Use the same colours as jwt.io, more-or-less.
    echo "$(tput setaf 1)${jwt_header}$(tput sgr0).$(tput setaf 5)${jwt_claims}$(tput sgr0).$(tput setaf 6)${jwt_signature}$(tput sgr0)"

    jwt="${jwt_header}.${jwt_claims}.${jwt_signature}"

    echo $jwt | cat >/.secret/jwt_token.txt
    chmod 777 /.secret/jwt_token.txt
}

# run slurmctld
_slurmctld() {
    cd /root/rpmbuild/RPMS/$ARCH

    yum -y --nogpgcheck localinstall slurm-$SLURM_VERSION*.$ARCH.rpm \
        slurm-perlapi-$SLURM_VERSION*.$ARCH.rpm \
        slurm-slurmd-$SLURM_VERSION*.$ARCH.rpm \
        slurm-torque-$SLURM_VERSION*.$ARCH.rpm \
        slurm-slurmctld-$SLURM_VERSION*.$ARCH.rpm
    echo "checking for slurmdbd.conf"
    while [ ! -f /.secret/slurmdbd.conf ]; do
        echo "."
        sleep 1
    done
    echo ""
    mkdir -p /var/spool/slurm/ctld /var/spool/slurm/d /var/log/slurm /etc/slurm /var/run/slurm/d /var/run/slurm/ctld /var/lib/slurm/d /var/lib/slurm/ctld
    chown -R slurm: /var/spool/slurm/ctld /var/spool/slurm/d /var/log/slurm /var/spool /var/lib /var/run/slurm/d /var/run/slurm/ctld /var/lib/slurm/d /var/lib/slurm/ctld
    mkdir -p /etc/config
    chown -R slurm: /etc/config

    touch /var/log/slurmctld.log
    chown -R slurm: /var/log/slurmctld.log
    touch /var/log/slurmd.log
    chown -R slurm: /var/log/slurmd.log

    touch /var/lib/slurm/d/job_state
    chown -R slurm: /var/lib/slurm/d/job_state
    touch /var/lib/slurm/d/fed_mgr_state
    chown -R slurm: /var/lib/slurm/d/fed_mgr_state
    touch /var/run/slurm/d/slurmctld.pid
    chown -R slurm: /var/run/slurm/d/slurmctld.pid
    touch /var/run/slurm/d/slurmd.pid
    chown -R slurm: /var/run/slurm/d/slurmd.pid

    if [[ ! -f /home/config/slurm.conf ]]; then
        echo "### Missing slurm.conf ###"
        exit
    else
        echo "### use provided slurm.conf ###"
        cp /home/config/slurm.conf /etc/slurm/slurm.conf
        chown slurm: /etc/slurm/slurm.conf
        chmod 600 /etc/slurm/slurm.conf
    fi

    sudo yum install -y nc
    sudo yum install -y procps
    sudo yum install -y iputils
    sudo yum install -y lsof
    sudo yum install -y jq

    _openssl_jwt_key

    if [ ! -f /.secret/jwt_hs256.key ]; then
        echo "### Missing jwt.key ###"
        exit 1
    else
        cp /.secret/jwt_hs256.key /etc/config/jwt_hs256.key
        chown slurm: /etc/config/jwt_hs256.key
        chmod 0600 /etc/config/jwt_hs256.key
    fi

    _generate_jwt_token

    while ! nc -z slurmdbd 6819; do
        echo "Waiting for slurmdbd to be ready..."
        sleep 2
    done

    sacctmgr -i add cluster name=linux
    sleep 2s
    echo "Starting slurmctld"
    cp -f /etc/slurm/slurm.conf /.secret/
    /usr/sbin/slurmctld -Dvv
    echo "Started slurmctld"
}

### main ###
_delete_secrets
_sshd_host

_ssh_worker
_munge_start
_copy_secrets
_slurmctld

tail -f /dev/null

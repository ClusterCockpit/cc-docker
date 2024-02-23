FROM rockylinux:9

LABEL org.opencontainers.image.source="https://github.com/ClusterCockpit/cc-docker/" \
      org.opencontainers.image.title="slurm-docker-cluster" \
      org.opencontainers.image.description="Slurm Docker cluster on Rocky Linux 9" \
      org.label-schema.docker.cmd="docker-compose up -d" \
      maintainer="Bole Ma, Giovanni Torres"

ARG SLURM_TAG=slurm-22-05-2-1
ARG GOSU_VERSION=1.17
ARG SLURM_PATH=/opt

RUN set -ex \
    && dnf makecache \
    && dnf -y update \
    && dnf -y install dnf-plugins-core \
    && dnf config-manager --enable crb \
    && dnf -y install \
       wget \
       bzip2 \
       cmake \
       perl \
       gcc \
       gcc-c++\
       git \
       gnupg \
       make \
       munge \
       munge-devel \
       nano \
       python3-devel \
       python3-pip \
       python3 \
       mariadb-server \
       mariadb-devel \
       psmisc \
       bash-completion \
       vim-enhanced \
       jansson-devel \
       jq \
       http-parser-devel \
       libseccomp-devel \
       libassuan-devel \
       libyaml-devel \
       pam-devel \
       lua-devel \
       iproute \
       procps-ng \
       rsync \
       crun \
       gpgme-devel \
       net-tools \
       socat \
       gettext-devel \
       libseccomp-devel \
       numactl-devel \
       dbus-devel \
       glib2-devel \
       json-c-devel \
    && dnf clean all \
    && rm -rf /var/cache/dnf

#RUN alternatives --set python /usr/bin/python3

RUN pip3 install Cython nose

RUN set -ex \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -rf "${GNUPGHOME}" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

WORKDIR /home

RUN set -x \
    && git clone https://gitlab.hrz.tu-chemnitz.de/pika/pika-packages.git \
    && git clone https://github.com/nats-io/nats.c.git \
    && git clone -b ${SLURM_TAG} --single-branch --depth=1 https://github.com/SchedMD/slurm.git \
    && pushd slurm \
    && ./configure  --enable-slurmrestd  --enable-developer --disable-optimizations --with-ebpf --enable-debug --prefix=/usr --sysconfdir=/etc/slurm \
        --with-mysql_config=/usr/bin  --libdir=/usr/lib64 \
    && make install \
    && install -D -m644 etc/cgroup.conf.example /etc/slurm/cgroup.conf \
    && install -D -m644 etc/slurm.conf.example /etc/slurm/slurm.conf.example \
    && install -D -m644 etc/slurmdbd.conf.example /etc/slurm/slurmdbd.conf.example \
    && install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh \
    && popd \
    && cp -r slurm /opt \
    && groupadd -r --gid=990 slurm \
    && useradd -r -g slurm --uid=990 slurm \
    && mkdir /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/run/slurmd \
        /var/run/slurmdbd \
        /var/lib/slurmd \
        /var/log/slurm \
        /tmp/pika_debug \
        /data \
    && touch /var/lib/slurmd/node_state \
        /var/lib/slurmd/front_end_state \
        /var/lib/slurmd/job_state \
        /var/lib/slurmd/resv_state \
        /var/lib/slurmd/trigger_state \
        /var/lib/slurmd/assoc_mgr_state \
        /var/lib/slurmd/assoc_usage \
        /var/lib/slurmd/qos_usage \
        /var/lib/slurmd/fed_mgr_state \
    && chown -R slurm:slurm /var/*/slurm* \
    && /sbin/create-munge-key \
    && pushd nats.c \
    && cmake . -DNATS_BUILD_STREAMING=OFF \
    && make install \
    && popd

COPY slurm-prep-pika_v4.c /opt/slurm-prep-pika_v4.c
COPY makefile /opt/makefile

COPY slurm.conf /etc/slurm/slurm.conf
COPY cgroup.conf /etc/slurm/cgroup.conf
COPY slurmdbd.conf /etc/slurm/slurmdbd.conf
RUN set -x \
    && chown slurm:slurm /etc/slurm/slurmdbd.conf \
    && chmod 600 /etc/slurm/slurmdbd.conf


COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["slurmdbd"]

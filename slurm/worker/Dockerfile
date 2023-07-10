FROM rockylinux:8
MAINTAINER Jan Eitzinger <jan.eitzinger@fau.de>

ENV SLURM_VERSION=19.05.1 \
  MUNGE_UID=981 \
  SLURM_UID=982 \
  WORKER_UID=1000

RUN yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y

RUN groupadd -g $MUNGE_UID munge \
  && useradd  -m -c "MUNGE Uid 'N' Gid Emporium" -d /var/lib/munge -u $MUNGE_UID -g munge  -s /sbin/nologin munge \
  && groupadd -g $SLURM_UID slurm \
  && useradd  -m -c "Slurm workload manager" -d /var/lib/slurm -u $SLURM_UID -g slurm  -s /bin/bash slurm \
  && groupadd -g $WORKER_UID worker \
  && useradd  -m -c "Workflow user" -d /home/worker -u $WORKER_UID -g worker  -s /bin/bash worker

RUN yum install -y munge munge-libs
RUN dnf --enablerepo=powertools install munge-devel -y
RUN yum install rng-tools -y

RUN yum install -y python3 gcc openssl openssl-devel \
pam-devel numactl numactl-devel hwloc sudo \
lua readline-devel ncurses-devel man2html \
libibmad libibumad rpm-build  perl-ExtUtils-MakeMaker.noarch rpm-build make wget

RUN dnf --enablerepo=powertools install rrdtool-devel lua-devel hwloc-devel rpm-build -y
RUN dnf install mariadb-server mariadb-devel -y
RUN mkdir /usr/local/slurm-tmp
RUN cd /usr/local/slurm-tmp
RUN wget https://download.schedmd.com/slurm/slurm-22.05.6.tar.bz2
RUN rpmbuild -ta slurm-22.05.6.tar.bz2

VOLUME ["/home", "/.secret"]
#   22:         SSH
# 3306:         MariaDB
# 6817:         SlurmCtlD
# 6818:         SlurmD
# 6819:         SlurmDBD
EXPOSE 22 3306 6817 6818 6819
WORKDIR /home/worker
COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

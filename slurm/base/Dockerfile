FROM rockylinux:8
MAINTAINER Jan Eitzinger <jan.eitzinger@fau.de>

ENV SLURM_VERSION=22.05.6
ENV ARCH=aarch64

RUN yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y

RUN groupadd -g 981 munge \
  && useradd  -m -c "MUNGE Uid 'N' Gid Emporium" -d /var/lib/munge -u 981 -g munge  -s /sbin/nologin munge \
  && groupadd -g 982 slurm \
  && useradd  -m -c "Slurm workload manager" -d /var/lib/slurm -u 982 -g slurm  -s /bin/bash slurm \
  && groupadd -g 1000 worker \
  && useradd  -m -c "Workflow user" -d /home/worker -u 1000 -g worker  -s /bin/bash worker

RUN yum install -y munge munge-libs
RUN dnf --enablerepo=powertools install munge-devel -y
RUN yum install rng-tools -y

RUN yum install -y python3 gcc openssl openssl-devel \
openssh-server openssh-clients dbus-devel \
pam-devel numactl numactl-devel hwloc sudo \
lua readline-devel ncurses-devel man2html \
libibmad libibumad rpm-build  perl-ExtUtils-MakeMaker.noarch rpm-build make wget

RUN dnf --enablerepo=powertools install rrdtool-devel lua-devel hwloc-devel rpm-build -y
RUN dnf install mariadb-server mariadb-devel -y
RUN mkdir /usr/local/slurm-tmp
RUN cd /usr/local/slurm-tmp
RUN wget https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2
RUN rpmbuild -ta slurm-${SLURM_VERSION}.tar.bz2

WORKDIR  /root/rpmbuild/RPMS/${ARCH}
RUN yum -y --nogpgcheck localinstall \
        slurm-${SLURM_VERSION}-1.el8.${ARCH}.rpm \
        slurm-perlapi-${SLURM_VERSION}-1.el8.${ARCH}.rpm \
        slurm-slurmctld-${SLURM_VERSION}-1.el8.${ARCH}.rpm
WORKDIR /

VOLUME ["/home", "/.secret"]
#   22:         SSH
# 3306:         MariaDB
# 6817:         SlurmCtlD
# 6818:         SlurmD
# 6819:         SlurmDBD
EXPOSE 22 6817 6818 6819

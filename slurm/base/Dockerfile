FROM rockylinux:8
LABEL org.opencontainers.image.authors="jan.eitzinger@fau.de"

ENV SLURM_VERSION=22.05.6

RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

RUN groupadd -g 981 munge \
  && useradd  -m -c "MUNGE Uid 'N' Gid Emporium" -d /var/lib/munge -u 981 -g munge  -s /sbin/nologin munge \
  && groupadd -g 982 slurm \
  && useradd  -m -c "Slurm workload manager" -d /var/lib/slurm -u 982 -g slurm  -s /bin/bash slurm \
  && groupadd -g 1000 worker \
  && useradd  -m -c "Workflow user" -d /home/worker -u 1000 -g worker  -s /bin/bash worker

RUN yum install -y munge munge-libs rng-tools \
    python3 gcc openssl openssl-devel \
    openssh-server openssh-clients dbus-devel \
    pam-devel numactl numactl-devel hwloc sudo \
    lua readline-devel ncurses-devel man2html \
    libibmad libibumad rpm-build  perl-ExtUtils-MakeMaker.noarch rpm-build make wget

RUN dnf --enablerepo=powertools install -y munge-devel rrdtool-devel lua-devel hwloc-devel mariadb-server mariadb-devel

RUN mkdir -p /usr/local/slurm-tmp \
    && cd /usr/local/slurm-tmp \
    && wget https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 \
    && rpmbuild -ta slurm-${SLURM_VERSION}.tar.bz2

RUN ARCH=$(uname -m) \
    && yum -y --nogpgcheck localinstall \
        /root/rpmbuild/RPMS/$ARCH/slurm-${SLURM_VERSION}-1.el8.$ARCH.rpm \
        /root/rpmbuild/RPMS/$ARCH/slurm-perlapi-${SLURM_VERSION}-1.el8.$ARCH.rpm \
        /root/rpmbuild/RPMS/$ARCH/slurm-slurmctld-${SLURM_VERSION}-1.el8.$ARCH.rpm

VOLUME ["/home", "/.secret"]
#   22:         SSH
# 3306:         MariaDB
# 6817:         SlurmCtlD
# 6818:         SlurmD
# 6819:         SlurmDBD
EXPOSE 22 6817 6818 6819

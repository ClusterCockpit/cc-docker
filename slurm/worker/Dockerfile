FROM clustercockpit/slurm.base:latest
MAINTAINER Jan Eitzinger <jan.eitzinger@fau.de>

# clean up
RUN rm -f /root/rpmbuild/RPMS/slurm-*.rpm \
  && yum clean all \
  && rm -rf /var/cache/yum

WORKDIR /home/worker
COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

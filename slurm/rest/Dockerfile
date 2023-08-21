FROM clustercockpit/slurm.base:22.05.6
MAINTAINER Jan Eitzinger <jan.eitzinger@fau.de>

# clean up
RUN rm -f /root/rpmbuild/RPMS/slurm-*.rpm \
  && yum clean all \
  && rm -rf /var/cache/yum

COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

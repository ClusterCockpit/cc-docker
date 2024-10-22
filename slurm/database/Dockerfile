FROM clustercockpit/slurm.base:24.05.3
LABEL org.opencontainers.image.authors="jan.eitzinger@fau.de"

# clean up
RUN rm -f /root/rpmbuild/RPMS/slurm-*.rpm \
  && yum clean all \
  && rm -rf /var/cache/yum

COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

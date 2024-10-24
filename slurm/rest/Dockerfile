FROM clustercockpit/slurm.base:24.05.3
LABEL org.opencontainers.image.authors="jan.eitzinger@fau.de"

ARG uid_u
ARG gid_g
ENV uid_u=${uid_u}
ENV gid_g=${gid_g}

# clean up
RUN rm -f /root/rpmbuild/RPMS/slurm-*.rpm \
  && yum clean all \
  && rm -rf /var/cache/yum

COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT /docker-entrypoint.sh $uid_u $gid_g

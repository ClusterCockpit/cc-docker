FROM quay.io/keycloak/keycloak:latest as builder

# Enable health and metrics support
ENV KC_METRICS_ENABLED=true
ENV KC_HEALTH_ENABLED=true
# Configure a database vendor
ENV KC_DB=postgres

WORKDIR /opt/keycloak
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:latest
COPY --from=builder /opt/keycloak/ /opt/keycloak/

# ENV KC_DB_URL_HOST=${PG_KC_URL}
# ENV KC_DB_USERNAME=${PG_KC_USER}
# ENV KC_DB_PASSWORD=${PG_KC_PASS}
# ENV KEYCLOAK_ADMIN_PASSWORD=${KC_ADMIN_PASS}
ENV KC_DB_URL_HOST=postgres
ENV KC_DB_URL_PORT=5432
ENV KC_DB_URL_DATABASE=keycloak
ENV KC_DB_USERNAME=keycloak
ENV KC_DB_PASSWORD=password
ENV KEYCLOAK_ADMIN_PASSWORD=admin
ENV KC_PROXY=edge
ENV KC_HOSTNAME=
ENV KC_HOSTNAME_STRICT=false
ENV KC_HOSTNAME_STRICT_BACKCHANNEL=false
ENV KC_HTTP_ENABLED=true
ENV KC_PROXY=edge
ENV KEYCLOAK_ADMIN=admin
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]

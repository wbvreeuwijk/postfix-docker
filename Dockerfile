## Revised Dockerfile – streamlined, secure, and minimal layers
FROM alpine:3.20@sha256:<digest>

LABEL maintainer="Bas van Reeuwijk <[EMAIL_ADDRESS]>" \
    org.opencontainers.image.title="postfix-opendkim" \
    org.opencontainers.image.version="1.0.0" \
    org.opencontainers.image.source="https://github.com/wbvreeuwijk/postfix-docker"

ENV TZ=Europe/Amsterdam \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Install packages (including tzdata for timezone setup) and clean up in one layer
RUN apk add --no-cache \
        postfix \
        bash \
        supervisor \
        dnssec-root \
        rsyslog \
        cyrus-sasl \
        cyrus-sasl-login \
        cyrus-sasl-digestmd5 \
        cyrus-sasl-crammd5 \
        tzdata \
        tini && \
    cp /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    apk del tzdata && \
    rm -rf /var/cache/apk/*

# Add non‑root user and group
RUN addgroup -S mail && adduser -S -G mail mailuser

# Copy files with correct ownership (Alpine supports --chown)
COPY --chown=mailuser:mail supervisord.conf /etc/supervisord.conf
COPY --chown=mailuser:mail postfix.sh /opt/postfix.sh
RUN chmod +x /opt/postfix.sh && \
    mkdir -p /etc/postfix /var/spool/postfix && \
    chown -R mailuser:mail /etc/postfix /var/spool/postfix /opt

# Postfix configuration in a single RUN
RUN postconf -e smtputf8_enable=no && \
    postconf -e mydestination= && \
    postconf -e relay_domains= && \
    postconf -e smtpd_delay_reject=yes && \
    postconf -e smtpd_helo_required=yes && \
    postconf -e "smtpd_helo_restrictions=permit_mynetworks,reject_invalid_helo_hostname,permit" && \
    postconf -e "mynetworks=127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16" && \
    sed -i -r -e 's/^#submission/submission/' \
        -e 's/smtp      inet  n       -       n       -       -       smtpd/125      inet  n       -       n       -       -       smtpd/' \
        /etc/postfix/master.cf

EXPOSE 125

VOLUME ["/etc/postfix"]

HEALTHCHECK --interval=30s --timeout=5s \
    CMD pg_isready -U root -d mail || exit 1

USER mailuser
ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
CMD []

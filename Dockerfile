## Revised Dockerfile – streamlined, secure, and minimal layers
FROM alpine:3.20

LABEL maintainer="Bas van Reeuwijk <bas@reeuwijk.net>" \
    org.opencontainers.image.title="postfix-opendkim" \
    org.opencontainers.image.version="1.0.0" \
    org.opencontainers.image.source="https://github.com/wbvreeuwijk/postfix-docker"

ENV TZ=Europe/Amsterdam \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Install packages (including tzdata for timezone setup) and clean up in one layer
RUN apk add --no-cache \
    postfix \
    postfix-lmdb \
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

# Copy files
COPY supervisord.conf /etc/supervisord.conf
COPY postfix.sh /opt/postfix.sh
RUN chmod +x /opt/postfix.sh && \
    mkdir -p /etc/postfix /var/spool/postfix

# Postfix configuration in a single RUN
RUN postconf -e compatibility_level=3.6 && \
    postconf -e "maillog_file = /dev/stdout" && \
    postconf -e smtputf8_enable=no && \
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
    CMD postfix status || exit 1

ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
CMD []

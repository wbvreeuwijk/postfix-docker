#Creating Image for postfix/opendkim service
#FROM alpine
FROM alpine

ENV TZ=Europe/Amsterdam
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apk update && apk upgrade
RUN true && \
    apk add --update --no-cache tzdata postfix postfix-lmdb bash supervisor dnssec-root rsyslog \
                                cyrus-sasl cyrus-sasl-plain cyrus-sasl-login cyrus-sasl-digestmd5 cyrus-sasl-crammd5 && \
    (rm "/tmp/"* 2>/dev/null || true) && (rm -rf /var/cache/apk/* 2>/dev/null || true)

# Build SASL
# RUN true && \
#   cpanm Pod::POM::View::Restructured && \
#   wget https://github.com/cyrusimap/cyrus-sasl/releases/download/cyrus-sasl-2.1.28/cyrus-sasl-2.1.28.tar.gz && \
#    tar xzvf cyrus-sasl-2.1.28.tar.gz && \
#    cd cyrus-sasl-2.1.28/ && \
#    ./configure && \
#    make && \
#    make install && \
#    ln -s /usr/local/lib/sasl2 /usr/lib/sasl2 && \
#    cd .. && \
#    rm -rf cyrus-sasl-2.1.28


# Configure supervisord
RUN { \
        echo '[supervisord]'; \
        echo 'nodaemon        = true'; \
#       echo 'logfile         = /dev/null'; \
#       echo 'logfile_maxbytes= 0'; \
        echo; \
        echo '[program:postfix]'; \
        echo 'process_name    = postfix'; \
        echo 'autostart       = true'; \
        echo 'autorestart     = false'; \
        echo 'directory       = /opt'; \
        echo 'command         = /opt/postfix.sh'; \
        echo 'startsecs       = 0'; \
        echo; \
        echo '[program:syslog]'; \
        echo 'process_name    = syslog'; \
        echo 'autostart       = true'; \
        echo 'autorestart     = false'; \
        echo 'directory       = /etc'; \
        echo 'command         = /sbin/syslogd'; \
        echo 'startsecs       = 0'; \
        } | tee /etc/supervisord.conf

# Configure postfix
RUN postconf -e smtputf8_enable=no
RUN postalias /etc/postfix/aliases
RUN postconf -e mydestination=
RUN postconf -e relay_domains=
RUN postconf -e smtpd_delay_reject=yes
RUN postconf -e smtpd_helo_required=yes
RUN postconf -e "smtpd_helo_restrictions=permit_mynetworks,reject_invalid_helo_hostname,permit"
RUN postconf -e "mynetworks=127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
RUN sed -i -r -e 's/^#submission/submission/' -e 's/smtp      inet  n       -       n       -       -       smtpd/125      inet  n       -       n       -       -       smtpd/' /etc/postfix/master.cf

RUN mkdir -p /opt

# Create postfix.sh
RUN { \
    echo '#!/bin/bash -e'; \
    echo '# Fix permissions'; \
    echo 'chmod 0600 /etc/postfix'; \
    echo 'chown root /var/spool/postfix/'; \
    echo 'chown root /var/spool/postfix/pid'; \
    echo 'chown root /etc/postfix/* '; \
    echo 'chmod 0600 /etc/postfix/* '; \
    echo 'chmod 0700 /etc/postfix/dynamicmaps.cf.d /etc/postfix/postfix-files.d /etc/postfix/sasl'; \
    echo ; \
    echo 'mkdir -p /var/spool/postfix/etc'; \
    echo ; \
    echo 'FILES="localtime services resolv.conf hosts"'; \
    echo 'for file in $FILES; do'; \
    echo '    cp /etc/${file} /var/spool/postfix/etc/${file}'; \
    echo '    chmod a+rX /var/spool/postfix/etc/${file}'; \
    echo 'done'; \
    echo ; \
    echo '/usr/sbin/postfix -c /etc/postfix start'; \
} | tee /opt/postfix.sh

RUN chmod +x /opt/postfix.sh

EXPOSE 125

#Adding volumes
VOLUME ["/etc/postfix"]

# Running final script
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

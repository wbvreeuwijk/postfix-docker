#!/bin/bash -e

# Fix permissions safely
chmod 0600 /etc/postfix
chown root /var/spool/postfix/

# Safely chown/chmod existing postfix files/directories
for path in /var/spool/postfix/pid /etc/postfix/*; do
    if [ -e "$path" ]; then
        if [ -d "$path" ]; then
            case "$(basename "$path")" in
                dynamicmaps.cf.d|postfix-files.d|sasl)
                    chmod 0700 "$path"
                    ;;
                *)
                    chmod 0755 "$path"
                    ;;
            esac
            chown -R root "$path"
        else
            chmod 0600 "$path"
            chown root "$path"
        fi
    fi
done

mkdir -p /var/spool/postfix/etc

FILES="localtime services resolv.conf hosts"
for file in $FILES; do
    if [ -f "/etc/${file}" ]; then
        cp "/etc/${file}" "/var/spool/postfix/etc/${file}"
        chmod a+rX "/var/spool/postfix/etc/${file}"
    fi
done

/usr/sbin/postfix -c /etc/postfix start

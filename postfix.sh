#!/bin/bash -e

# Restore default system files to /etc/postfix if they are missing (e.g. due to a volume mount)
if [ -d /etc/postfix.backup ]; then
    echo "Restoring system configuration files to /etc/postfix..."
    # Always overwrite system-level configurations to match package binaries
    for file in dynamicmaps.cf dynamicmaps.cf.d postfix-files postfix-files.d; do
        if [ -e "/etc/postfix.backup/$file" ]; then
            rm -rf "/etc/postfix/$file"
            cp -r "/etc/postfix.backup/$file" "/etc/postfix/"
        fi
    done
    # Only restore user configurations if they are completely missing
    for file in main.cf master.cf; do
        if [ ! -e "/etc/postfix/$file" ] && [ -e "/etc/postfix.backup/$file" ]; then
            cp -r "/etc/postfix.backup/$file" "/etc/postfix/"
        fi
    done
fi

# Fix permissions safely
chmod 0600 /etc/postfix
chown root /var/spool/postfix/

# Automatically convert hash/btree databases to lmdb
if [ -f /etc/postfix/main.cf ]; then
    echo "Updating configuration in /etc/postfix/main.cf to use lmdb instead of hash/btree..."
    # Ensure compatibility level and database/cache types are set
    postconf -c /etc/postfix -e "compatibility_level=3.6"
    postconf -c /etc/postfix -e "default_database_type=lmdb"
    postconf -c /etc/postfix -e "default_cache_db_type=lmdb"
    postconf -c /etc/postfix -e "maillog_file=/dev/stdout"

    # Replace hash: and btree: with lmdb: in main.cf and master.cf
    sed -i 's/\bhash:/lmdb:/g' /etc/postfix/main.cf
    sed -i 's/\bbtree:/lmdb:/g' /etc/postfix/main.cf
    if [ -f /etc/postfix/master.cf ]; then
        sed -i 's/\bhash:/lmdb:/g' /etc/postfix/master.cf
        sed -i 's/\bbtree:/lmdb:/g' /etc/postfix/master.cf
        if ! grep -q "^postlog" /etc/postfix/master.cf; then
            echo "postlog   unix-dgram n  -       n       -       1       postlogd" >> /etc/postfix/master.cf
        fi
    fi

    # Find all lmdb files referenced in main.cf and rebuild them
    maps=$(grep -oE 'lmdb:[a-zA-Z0-9_/.-]+' /etc/postfix/main.cf | cut -d: -f2 | sort -u)
    for mapfile in $maps; do
        if [ -f "$mapfile" ]; then
            echo "Rebuilding map: $mapfile"
            if [[ "$mapfile" == *aliases* ]]; then
                postalias "lmdb:$mapfile"
            else
                postmap "lmdb:$mapfile"
            fi
        fi
    done
fi


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

exec /usr/sbin/postfix -c /etc/postfix start-fg

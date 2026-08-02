#!/system/bin/sh

SSH_DIR=/data/ssh
AUTH_DIR="$SSH_DIR/.ssh"
HOST_KEY="$SSH_DIR/dropbear_ed25519_host_key"

/system/bin/mkdir -p "$AUTH_DIR"
/system/bin/chown root:root "$SSH_DIR" "$AUTH_DIR"
/system/bin/chmod 0700 "$SSH_DIR" "$AUTH_DIR"

# The maintenance key is part of the firmware contract. Reinstall it on every
# boot so stale userdata from another image cannot lock out recovery access.
/system/bin/cp /aquario-ssh/authorized_keys "$AUTH_DIR/authorized_keys"
/system/bin/chown root:root "$AUTH_DIR/authorized_keys"
/system/bin/chmod 0600 "$AUTH_DIR/authorized_keys"

if [ ! -s "$HOST_KEY" ]; then
    /sbin/dropbearkey -t ed25519 -f "$HOST_KEY"
fi
/system/bin/chown root:root "$HOST_KEY"
/system/bin/chmod 0600 "$HOST_KEY"

exec /sbin/dropbear -F -E -p 2222 -r "$HOST_KEY" -D "$AUTH_DIR" -s \
    -P "$SSH_DIR/dropbear.pid"

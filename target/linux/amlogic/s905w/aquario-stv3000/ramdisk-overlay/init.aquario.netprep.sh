#!/system/bin/sh

# The MikroTik lease and DNAT rules identify this maintenance MAC. Configure it
# before EthernetService creates IpClient, avoiding a link flap after boot.
for delay in 0 1 1 2 3; do
    /system/bin/sleep "$delay"
    [ -d /sys/class/net/eth0 ] || continue
    /system/bin/ip link set eth0 down
    /system/bin/ip link set eth0 address 62:2c:d3:ac:57:a9
    /system/bin/ip link set eth0 up
    exit 0
done

exit 0

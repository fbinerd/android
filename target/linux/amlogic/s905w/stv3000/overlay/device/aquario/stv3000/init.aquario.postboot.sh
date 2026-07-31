#!/system/bin/sh

# Some vendor services reset TVP after post-fs. Re-enable it once Android has
# completed boot, before the user can start protected video playback.
echo 1 > /sys/class/codec_mm/tvp_enable

# Prefer a 60 Hz UI mode. A 4K30 link doubles pointer and transition latency.
CAPS=/sys/class/amhdmitx/amhdmitx0/disp_cap
HDMI_MODE=720p60hz
if /system/bin/grep -q '^1080p60hz' "$CAPS"; then
    HDMI_MODE=1080p60hz
elif /system/bin/grep -q '^1080p50hz' "$CAPS"; then
    HDMI_MODE=1080p50hz
elif /system/bin/grep -q '^2160p30hz' "$CAPS"; then
    HDMI_MODE=2160p30hz
elif /system/bin/grep -q '^2160p25hz' "$CAPS"; then
    HDMI_MODE=2160p25hz
elif /system/bin/grep -q '^2160p24hz' "$CAPS"; then
    HDMI_MODE=2160p24hz
fi

echo "$HDMI_MODE" > /sys/class/display/mode
/system/bin/setprop persist.aquario.hdmi.mode "$HDMI_MODE"
case "$HDMI_MODE" in
    2160p*|1080p*) /system/bin/wm size 1920x1080 ;;
    *) /system/bin/wm size 1280x720 ;;
esac

/system/bin/settings put global bluetooth_on 0
/system/bin/pm disable-user --user 0 com.android.bluetooth
/system/bin/settings put global stay_on_while_plugged_in 0
/system/bin/settings put global window_animation_scale 0.5
/system/bin/settings put global transition_animation_scale 0.5
/system/bin/settings put global animator_duration_scale 1.0

# Keep zram at the higher priority and add only real swap partitions from
# removable block devices. Ordinary filesystems are never mounted or changed.
for sysdev in /sys/class/block/*; do
    [ -f "$sysdev/partition" ] || continue
    dev="/dev/block/${sysdev##*/}"
    [ -b "$dev" ] || continue
    /system/bin/blkid "$dev" 2>/dev/null | /system/bin/grep -q 'TYPE="swap"' || continue
    /system/bin/grep -q "^$dev " /proc/swaps && continue
    /system/bin/swapon -p -10 "$dev" >/dev/null 2>&1
done

# Keep a stable maintenance path through the MikroTik VRF/NAT rules.
/system/bin/ip link set eth0 down
/system/bin/ip link set eth0 address 62:2c:d3:ac:57:a9
/system/bin/ip link set eth0 up
/system/bin/ip addr replace 192.168.1.139/24 dev eth0
/system/bin/ip route replace default via 192.168.1.2 dev eth0
/system/bin/setprop service.adb.tcp.port 5555
/system/bin/stop adbd
/system/bin/start adbd

# Start the launcher monitor without waiting for Android's network retries.
/system/bin/sleep 3
/system/bin/am start -a android.intent.action.MAIN \
    -c android.intent.category.HOME >/dev/null 2>&1
/system/bin/cmd deviceidle whitelist +com.aquario.monitor >/dev/null 2>&1
/system/bin/am set-inactive --user 0 com.aquario.monitor false >/dev/null 2>&1
/system/bin/appops set com.aquario.monitor RUN_IN_BACKGROUND allow >/dev/null 2>&1
/system/bin/appops set com.aquario.monitor RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1
/system/bin/am start -n com.aquario.monitor/.StarterActivity >/dev/null 2>&1

# Keep the official YouTube recommendation scheduler active so its preview
# channel continues to refresh on the Android TV launcher.
/system/bin/cmd deviceidle whitelist +com.google.android.youtube.tv >/dev/null 2>&1
/system/bin/am set-inactive --user 0 com.google.android.youtube.tv false >/dev/null 2>&1
/system/bin/appops set com.google.android.youtube.tv RUN_IN_BACKGROUND allow >/dev/null 2>&1
/system/bin/appops set com.google.android.youtube.tv RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1

# Aurora is a system app, but REQUEST_INSTALL_PACKAGES is an app-op stored in
# /data and must be restored after a factory reset.
/system/bin/appops set com.aurora.store REQUEST_INSTALL_PACKAGES allow >/dev/null 2>&1

# These optional stores/streaming apps register boot receivers and consume
# scarce RAM and SD I/O. Force-stop keeps them dormant until the user opens one.
for package in \
    com.amazon.amazonvideo.livingroom \
    com.aurora.store \
    com.globo.globotv; do
    /system/bin/am force-stop "$package" >/dev/null 2>&1
done

for delay in 0 2 5 10 15; do
    /system/bin/sleep "$delay"
    /system/bin/ip route replace 192.168.1.0/24 dev eth0 scope link src 192.168.1.139 table main
    /system/bin/ip route replace default via 192.168.1.2 dev eth0 table main
    /system/bin/ip route replace default via 192.168.1.2 dev eth0 table eth0
    /system/bin/ndc network route add 100 eth0 0.0.0.0/0 192.168.1.2 >/dev/null 2>&1
    /system/bin/ndc resolver setnetdns 100 local 1.1.1.1 8.8.8.8 >/dev/null 2>&1
done

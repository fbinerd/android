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

# A stale Amlogic env may leave 2160p60/420 selected even though display/mode
# reports 1080p60. Program color first and validate the physical HDMI VIC.
echo rgb,8bit > /sys/class/amhdmitx/amhdmitx0/attr
if [ "$HDMI_MODE" = 1080p60hz ] && \
   ! /system/bin/grep -q '^cur_VIC: 16$' /sys/class/amhdmitx/amhdmitx0/config; then
    echo 720p60hz > /sys/class/display/mode
fi
echo "$HDMI_MODE" > /sys/class/display/mode
case "$HDMI_MODE" in
    2160p*|1080p*) /system/bin/wm size 1920x1080 ;;
    *) /system/bin/wm size 1280x720 ;;
esac

/system/bin/settings put global bluetooth_on 0
/system/bin/pm disable-user --user 0 com.android.bluetooth

# The old phone profile left Launcher3's removed listener in /data. Make the
# Android TV recommendation listener authoritative on upgrades and clean data.
/system/bin/cmd notification disallow_listener \
    com.android.launcher3/com.android.launcher3.notification.NotificationListener \
    >/dev/null 2>&1
/system/bin/cmd notification allow_listener \
    com.google.android.tvrecommendations/com.google.android.tvrecommendations.NotificationsService \
    >/dev/null 2>&1

# A TV must always have a D-pad-capable on-screen keyboard after a data wipe.
TV_IME=com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME
/system/bin/ime disable com.android.inputmethod.latin/.LatinIME >/dev/null 2>&1
/system/bin/ime enable "$TV_IME" >/dev/null 2>&1
/system/bin/ime set "$TV_IME" >/dev/null 2>&1

# Keep a powered TV box awake. Explicit standby from the IR power button is
# unaffected, while a newly formatted /data no longer suspends HDMI/Ethernet.
/system/bin/settings put global stay_on_while_plugged_in 7
/system/bin/settings put system screen_off_timeout 2147483647
/system/bin/settings put secure sleep_timeout -1
/system/bin/svc power stayon true

/system/bin/settings put global window_animation_scale 0.5
/system/bin/settings put global transition_animation_scale 0.5
/system/bin/settings put global animator_duration_scale 1.0

# Prefer zram and use removable swap only as low-priority overflow.
for sysdev in /sys/class/block/*; do
    [ -f "$sysdev/partition" ] || continue
    dev="/dev/block/${sysdev##*/}"
    [ -b "$dev" ] || continue
    /system/bin/blkid "$dev" 2>/dev/null | /system/bin/grep -q 'TYPE="swap"' || continue
    /system/bin/grep -q "^$dev " /proc/swaps && continue
    /system/bin/swapon -p -10 "$dev" >/dev/null 2>&1
done

# Keep a stable maintenance path through the MikroTik VRF/NAT rules. The MAC
# is prepared before system_server starts, so postboot does not flap Ethernet.
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

# Keep YouTube recommendations active on the Android TV launcher.
/system/bin/cmd deviceidle whitelist +com.google.android.youtube.tv >/dev/null 2>&1
/system/bin/am set-inactive --user 0 com.google.android.youtube.tv false >/dev/null 2>&1
/system/bin/appops set com.google.android.youtube.tv RUN_IN_BACKGROUND allow >/dev/null 2>&1
/system/bin/appops set com.google.android.youtube.tv RUN_ANY_IN_BACKGROUND allow >/dev/null 2>&1

# Restore the Aurora installer permission after a factory reset.
/system/bin/appops set com.aurora.store REQUEST_INSTALL_PACKAGES allow >/dev/null 2>&1

# Keep optional streaming/store apps dormant until explicitly opened.
for package in \
    com.amazon.amazonvideo.livingroom \
    com.aurora.store \
    com.globo.globotv; do
    /system/bin/am force-stop "$package" >/dev/null 2>&1
done

# Android routes application traffic through a per-network table. Retry while
# netd and EthernetManager finish registering eth0.
for delay in 0 2 5 10 15; do
    /system/bin/sleep "$delay"
    /system/bin/ip route replace 192.168.1.0/24 dev eth0 scope link src 192.168.1.139 table main
    /system/bin/ip route replace default via 192.168.1.2 dev eth0 table main
    /system/bin/ip route replace default via 192.168.1.2 dev eth0 table eth0
    /system/bin/ndc network route add 100 eth0 0.0.0.0/0 192.168.1.2 >/dev/null 2>&1
    /system/bin/ndc resolver setnetdns 100 local 1.1.1.1 8.8.8.8 >/dev/null 2>&1
done

exit 0

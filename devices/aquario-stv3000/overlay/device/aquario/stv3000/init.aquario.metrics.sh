#!/system/bin/sh

METRICS=/data/system/aquario_metrics
GPU=/sys/kernel/debug/mali/utilization_gp_pp

set -- $(/system/bin/head -n 1 /proc/stat)
prev_total=$(($2+$3+$4+$5+$6+$7+$8+$9))
prev_idle=$(($5+$6))

: > "$METRICS"
/system/bin/chmod 0644 "$METRICS"

while true; do
    /system/bin/sleep 5

    set -- $(/system/bin/head -n 1 /proc/stat)
    total=$(($2+$3+$4+$5+$6+$7+$8+$9))
    idle=$(($5+$6))
    delta_total=$((total-prev_total))
    delta_idle=$((idle-prev_idle))
    cpu=0
    [ "$delta_total" -gt 0 ] && cpu=$(((delta_total-delta_idle)*100/delta_total))
    prev_total=$total
    prev_idle=$idle

    mem_total=$(/system/bin/awk '/^MemTotal:/ {print int($2/1024)}' /proc/meminfo)
    mem_free=$(/system/bin/awk '/^MemAvailable:/ {print int($2/1024)}' /proc/meminfo)
    mem_used=$((mem_total-mem_free))

    gpu_raw=0
    [ -r "$GPU" ] && gpu_raw=$(/system/bin/cat "$GPU")
    gpu=$((gpu_raw*100/256))
    [ "$gpu" -gt 100 ] && gpu=100

    /system/bin/printf 'CPU %d%%  RAM %d MB usada / %d MB livre  GPU %d%%\n' \
        "$cpu" "$mem_used" "$mem_free" "$gpu" > "$METRICS"
done

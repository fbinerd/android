#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="${1:-aquario-stv3000}"
DEVICE_DIR="$(find "$ROOT_DIR/target/linux" -type d -name "$TARGET" | head -n1)"

source "$DEVICE_DIR/board.conf"

OUT_DIR="$ROOT_DIR/out/$TARGET"
PRODUCT_OUT="$ROOT_DIR/workspace/aosp9/out/target/product/stv3000"
VENDOR_IMG="$OUT_DIR/vendor.img"
VENDOR_OVERLAY="$DEVICE_DIR/vendor-overlay"
MALI_MODULE="$DEVICE_DIR/ramdisk-overlay/aquario-modules/mali.ko"
VENDOR_UEVENTD="$OUT_DIR/vendor-ueventd.rc"
VENDOR_SEPOLICY_CIL="$OUT_DIR/vendor-sepolicy-extcon.cil"
VENDOR_FILE_CONTEXTS="$OUT_DIR/vendor-file-contexts-extcon"
VENDOR_PRECOMPILED_SEPOLICY="$OUT_DIR/vendor-precompiled-sepolicy-extcon"
PLAT_SEPOLICY_CIL="$PRODUCT_OUT/obj/ETC/plat_sepolicy.cil_intermediates/plat_sepolicy.cil"
MAPPING_SEPOLICY_CIL="$PRODUCT_OUT/obj/ETC/28.0.cil_intermediates/28.0.cil"
PLAT_PUB_VERSIONED_CIL="$PRODUCT_OUT/obj/ETC/plat_pub_versioned.cil_intermediates/plat_pub_versioned.cil"
HOST_SECILC="$ROOT_DIR/workspace/aosp9/out/host/linux-x86/bin/secilc"

if [[ "$BASE_IMAGE" = /* ]]; then
    BASE="$BASE_IMAGE"
else
    BASE="$ROOT_DIR/$BASE_IMAGE"
fi

SYSTEM_BINDER="$PRODUCT_OUT/system/lib/libbinder.so"
for required in "$BASE" "$SYSTEM_BINDER" "$MALI_MODULE" "$VENDOR_OVERLAY" \
    "$PLAT_SEPOLICY_CIL" "$MAPPING_SEPOLICY_CIL" \
    "$PLAT_PUB_VERSIONED_CIL" "$HOST_SECILC"; do
    [[ -e "$required" ]] || { echo "[ERR] Artefato vendor ausente: $required" >&2; exit 1; }
done

mkdir -p "$OUT_DIR"
echo "-> Extraindo a vendor Aidan de 512 MiB da imagem-base..."
dd if="$BASE" of="$VENDOR_IMG" bs=1M skip=1494 count=512 status=none

DEBUGFS_COMMANDS="$(mktemp)"
trap 'unlink "$DEBUGFS_COMMANDS" 2>/dev/null || true' EXIT

replace_file() {
    local source="$1" destination="$2"
    printf '%s\n' \
        "rm $destination" \
        "write $source $destination" \
        "set_inode_field $destination mode 0100644" \
        "set_inode_field $destination uid 0" \
        "set_inode_field $destination gid 0" \
        >> "$DEBUGFS_COMMANDS"
}

echo "-> Importando correções comprovadas da vendor funcional..."
replace_file "$SYSTEM_BINDER" /lib/libbinder.so
replace_file "$MALI_MODULE" /lib/modules/mali.ko

# The legacy Amlogic policy labels two direct sysfs attributes through
# file_contexts.  restorecon then attempts an unsupported security.selinux
# xattr and emits EINVAL repeatedly during cold boot.  Label sysfs through
# genfscon instead and compile a matching precompiled policy.
debugfs -R "dump /etc/selinux/vendor_sepolicy.cil $VENDOR_SEPOLICY_CIL" \
    "$VENDOR_IMG" >/dev/null 2>&1
debugfs -R "dump /etc/selinux/vendor_file_contexts $VENDOR_FILE_CONTEXTS" \
    "$VENDOR_IMG" >/dev/null 2>&1
sed -i \
    -e '\|^/sys/devices/platform/vout/extcon/setmode/cable\.0/state[[:space:]]|d' \
    -e '\|^/sys/devices/platform/vout/extcon/setmode/state[[:space:]]|d' \
    "$VENDOR_FILE_CONTEXTS"

if ! grep -Fq \
    '(genfscon sysfs /devices/platform/vout/extcon/setmode/state ' \
    "$VENDOR_SEPOLICY_CIL"; then
    printf '%s\n' \
        '(genfscon sysfs /devices/platform/vout/extcon/setmode/state (u object_r sysfs_display ((s0) (s0))))' \
        '(genfscon sysfs /devices/platform/vout/extcon/setmode/cable.0/state (u object_r sysfs_display ((s0) (s0))))' \
        >> "$VENDOR_SEPOLICY_CIL"
fi

# This imported Amlogic policy predates Treble's current neverallow split and
# already contains legacy vendor/platform crossings.  -N permits rebuilding
# that same policy; the extcon change itself only adds labels, not allow rules.
"$HOST_SECILC" -N -m -M true -G -c 30 \
    "$PLAT_SEPOLICY_CIL" \
    "$MAPPING_SEPOLICY_CIL" \
    "$PLAT_PUB_VERSIONED_CIL" \
    "$VENDOR_SEPOLICY_CIL" \
    -o "$VENDOR_PRECOMPILED_SEPOLICY" -f /dev/null

replace_file "$VENDOR_SEPOLICY_CIL" /etc/selinux/vendor_sepolicy.cil
replace_file "$VENDOR_FILE_CONTEXTS" /etc/selinux/vendor_file_contexts
replace_file "$VENDOR_PRECOMPILED_SEPOLICY" /etc/selinux/precompiled_sepolicy

# A vendor-base uses the device-node form for a sysfs attribute. Android 9
# rejects it as malformed, so normalize it before applying the profile overlay.
debugfs -R "dump /ueventd.rc $VENDOR_UEVENTD" "$VENDOR_IMG" >/dev/null 2>&1
sed -i \
    's|^/sys/class/video/device_resolution[[:space:]]\+0666[[:space:]]\+system[[:space:]]\+system$|/sys/class/video device_resolution    0666   system     system|' \
    "$VENDOR_UEVENTD"
grep -qx '/sys/class/video device_resolution    0666   system     system' "$VENDOR_UEVENTD" || {
    echo "[ERR] Não foi possível corrigir device_resolution no ueventd da vendor" >&2
    exit 1
}
replace_file "$VENDOR_UEVENTD" /ueventd.rc

while IFS= read -r -d '' source; do
    relative="${source#"$VENDOR_OVERLAY"/}"
    replace_file "$source" "/$relative"
done < <(find "$VENDOR_OVERLAY" -type f -print0 | sort -z)

# Esta placa não possui Bluetooth. Do not advertise non-existent hardware to
# PackageManager or start the Bluetooth application after a factory reset.
printf '%s\n' \
    'rm /etc/permissions/android.hardware.bluetooth.xml' \
    'rm /etc/permissions/android.hardware.bluetooth_le.xml' \
    >> "$DEBUGFS_COMMANDS"

# These services have board-specific replacements in the boot ramdisk. The
# remaining vendor HAL rc files must stay intact and are the single source of
# truth for memtrack, power, lights, health, camera, OMX, thermal, USB and CEC.
for vendor_rc in \
    android.hardware.graphics.composer@2.2-service.rc \
    android.hardware.wifi@1.0-service.rc \
    hdmicecd.rc \
    systemcontrol.rc; do
    printf 'rm /etc/init/%s\n' "$vendor_rc" >> "$DEBUGFS_COMMANDS"
done

echo "-> Aplicando alterações da vendor em uma única transação debugfs..."
debugfs -w -f "$DEBUGFS_COMMANDS" "$VENDOR_IMG" >/dev/null

e2fsck -fy "$VENDOR_IMG" >/dev/null
e2fsck -fn "$VENDOR_IMG"

verify_file() {
    local expected="$1" path="$2" name="$3"
    local dump="$OUT_DIR/.vendor-verify-$name"
    debugfs -R "dump $path $dump" "$VENDOR_IMG" >/dev/null 2>&1
    cmp -s "$expected" "$dump" || { echo "[ERR] Vendor readback divergiu: $path" >&2; exit 1; }
    unlink "$dump"
}

verify_file "$SYSTEM_BINDER" /lib/libbinder.so binder
verify_file "$MALI_MODULE" /lib/modules/mali.ko mali
verify_file "$VENDOR_SEPOLICY_CIL" /etc/selinux/vendor_sepolicy.cil sepolicy-cil
verify_file "$VENDOR_FILE_CONTEXTS" /etc/selinux/vendor_file_contexts file-contexts
verify_file "$VENDOR_PRECOMPILED_SEPOLICY" /etc/selinux/precompiled_sepolicy precompiled-sepolicy
verify_file "$VENDOR_OVERLAY/lib/modules/ssv6051.ko" /lib/modules/ssv6051.ko ssv6051
verify_file "$VENDOR_OVERLAY/etc/remote.tab3" /etc/remote.tab3 remote
verify_file "$VENDOR_UEVENTD" /ueventd.rc ueventd
verify_file "$VENDOR_OVERLAY/etc/init/android.hardware.health@2.0-service.rc" \
    /etc/init/android.hardware.health@2.0-service.rc health

for removed_rc in \
    android.hardware.graphics.composer@2.2-service.rc \
    android.hardware.wifi@1.0-service.rc \
    hdmicecd.rc \
    systemcontrol.rc; do
    if debugfs -R "stat /etc/init/$removed_rc" "$VENDOR_IMG" 2>&1 | grep -q '^Inode:'; then
        echo "[ERR] rc conflitante ainda existe na vendor: $removed_rc" >&2
        exit 1
    fi
done

file "$MALI_MODULE" | grep -q 'ARM aarch64' || {
    echo "[ERR] mali.ko não é AArch64" >&2
    exit 1
}

sha256sum "$VENDOR_IMG" > "$OUT_DIR/vendor-SHA256SUMS"
echo "Vendor corrigida e validada: $VENDOR_IMG"

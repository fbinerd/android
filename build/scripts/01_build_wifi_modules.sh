#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET="${1:-aquario-stv3000}"
DEVICE_DIR="$(find "$ROOT_DIR/target/linux" -type d -name "$TARGET" | head -n1)"

source "$DEVICE_DIR/board.conf"

KERNEL_SRC="$FIRMWARE_LAB_DIR/$KERNEL_SOURCE_WORKDIR"
KERNEL_OUT="$FIRMWARE_LAB_DIR/$KERNEL_OUTPUT_WORKDIR"
WIFI_SRC="$FIRMWARE_LAB_DIR/$WIFI_SOURCE_WORKDIR"

CONTAINER_ROOT="/workspace/firmware-lab"
KERNEL_SRC_CONTAINER="$CONTAINER_ROOT/$KERNEL_SOURCE_WORKDIR"
KERNEL_OUT_CONTAINER="$CONTAINER_ROOT/$KERNEL_OUTPUT_WORKDIR"
WIFI_SRC_CONTAINER="$CONTAINER_ROOT/$WIFI_SOURCE_WORKDIR"
CROSS_CONTAINER="$CONTAINER_ROOT/infra/aidan/aosp9/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-"

RAMDISK_MODULES="$DEVICE_DIR/ramdisk-overlay/aquario-modules"
VENDOR_MODULES="$DEVICE_DIR/vendor-overlay/lib/modules"

[[ -d "$KERNEL_SRC" && -f "$KERNEL_OUT/.config" ]] || {
    echo "[ERR] Exact kernel source/output tree is missing" >&2
    exit 1
}
[[ -d "$WIFI_SRC/ssv6051" && -d "$WIFI_SRC/ssv_hwif_ctrl" ]] || {
    echo "[ERR] SV6051P source tree is missing" >&2
    exit 1
}
docker ps --format '{{.Names}}' | grep -qx android9-aquario || {
    echo "[ERR] Container android9-aquario is not running" >&2
    exit 1
}

MAC80211_SYMVERS="$KERNEL_OUT_CONTAINER/net/mac80211/Module.symvers"
SSV6051_SYMVERS="$WIFI_SRC_CONTAINER/ssv6051/Module.symvers"
SSV6X5X_SYMVERS="$WIFI_SRC_CONTAINER/ssv6x5x/Module.symvers"

echo "-> Rebuilding mac80211 and SV6051P modules against the active kernel..."
docker exec -i android9-aquario bash -lc "
set -euo pipefail
make -C '$KERNEL_SRC_CONTAINER' O='$KERNEL_OUT_CONTAINER' ARCH=arm64 CROSS_COMPILE='$CROSS_CONTAINER' M=net/mac80211 clean
make -C '$KERNEL_SRC_CONTAINER' O='$KERNEL_OUT_CONTAINER' ARCH=arm64 CROSS_COMPILE='$CROSS_CONTAINER' M=net/mac80211 -j${BUILD_JOBS:-16} modules

make -C '$KERNEL_SRC_CONTAINER' O='$KERNEL_OUT_CONTAINER' ARCH=arm64 CROSS_COMPILE='$CROSS_CONTAINER' M='$WIFI_SRC_CONTAINER/ssv6051' KBUILD_TOP='$WIFI_SRC_CONTAINER/ssv6051' clean
make -C '$KERNEL_SRC_CONTAINER' O='$KERNEL_OUT_CONTAINER' ARCH=arm64 CROSS_COMPILE='$CROSS_CONTAINER' M='$WIFI_SRC_CONTAINER/ssv6051' KBUILD_TOP='$WIFI_SRC_CONTAINER/ssv6051' KBUILD_EXTRA_SYMBOLS='$MAC80211_SYMVERS' -j${BUILD_JOBS:-16} modules

make -C '$KERNEL_SRC_CONTAINER' O='$KERNEL_OUT_CONTAINER' ARCH=arm64 CROSS_COMPILE='$CROSS_CONTAINER' M='$WIFI_SRC_CONTAINER/ssv6x5x' KBUILD_TOP='$WIFI_SRC_CONTAINER/ssv6x5x' clean
make -C '$KERNEL_SRC_CONTAINER' O='$KERNEL_OUT_CONTAINER' ARCH=arm64 CROSS_COMPILE='$CROSS_CONTAINER' M='$WIFI_SRC_CONTAINER/ssv6x5x' KBUILD_TOP='$WIFI_SRC_CONTAINER/ssv6x5x' KBUILD_EXTRA_SYMBOLS='$MAC80211_SYMVERS' -j${BUILD_JOBS:-16} modules

make -C '$KERNEL_SRC_CONTAINER' O='$KERNEL_OUT_CONTAINER' ARCH=arm64 CROSS_COMPILE='$CROSS_CONTAINER' M='$WIFI_SRC_CONTAINER/ssv_hwif_ctrl' KBUILD_TOP='$WIFI_SRC_CONTAINER/ssv_hwif_ctrl' clean
make -C '$KERNEL_SRC_CONTAINER' O='$KERNEL_OUT_CONTAINER' ARCH=arm64 CROSS_COMPILE='$CROSS_CONTAINER' M='$WIFI_SRC_CONTAINER/ssv_hwif_ctrl' KBUILD_TOP='$WIFI_SRC_CONTAINER/ssv_hwif_ctrl' KBUILD_EXTRA_SYMBOLS='$MAC80211_SYMVERS $SSV6051_SYMVERS $SSV6X5X_SYMVERS' -j${BUILD_JOBS:-16} modules

'${CROSS_CONTAINER}strip' --strip-unneeded '$KERNEL_OUT_CONTAINER/net/mac80211/mac80211.ko'
'${CROSS_CONTAINER}strip' --strip-unneeded '$WIFI_SRC_CONTAINER/ssv6051/ssv6051.ko'
'${CROSS_CONTAINER}strip' --strip-unneeded '$WIFI_SRC_CONTAINER/ssv6x5x/ssv6x5x.ko'
'${CROSS_CONTAINER}strip' --strip-unneeded '$WIFI_SRC_CONTAINER/ssv_hwif_ctrl/ssv_hwif_ctrl.ko'
"

declare -A MODULE_SOURCES=(
    [mac80211]="$KERNEL_OUT/net/mac80211/mac80211.ko"
    [ssv6051]="$WIFI_SRC/ssv6051/ssv6051.ko"
    [ssv6x5x]="$WIFI_SRC/ssv6x5x/ssv6x5x.ko"
    [ssv_hwif_ctrl]="$WIFI_SRC/ssv_hwif_ctrl/ssv_hwif_ctrl.ko"
)

mkdir -p "$RAMDISK_MODULES" "$VENDOR_MODULES"
for module in mac80211 ssv6051 ssv6x5x ssv_hwif_ctrl; do
    source_file="${MODULE_SOURCES[$module]}"
    [[ -s "$source_file" ]] || {
        echo "[ERR] Missing generated module: $source_file" >&2
        exit 1
    }
    file "$source_file" | grep -q 'ARM aarch64'
    install -m 0644 "$source_file" "$RAMDISK_MODULES/$module.ko"
    install -m 0644 "$source_file" "$VENDOR_MODULES/$module.ko"
done

sha256sum \
    "$RAMDISK_MODULES/mac80211.ko" \
    "$RAMDISK_MODULES/ssv6051.ko" \
    "$RAMDISK_MODULES/ssv6x5x.ko" \
    "$RAMDISK_MODULES/ssv_hwif_ctrl.ko" \
    > "$ROOT_DIR/out/$TARGET/wifi-modules-SHA256SUMS"

echo "Wi-Fi modules rebuilt and installed in ramdisk/vendor overlays."

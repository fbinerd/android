#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET="${1:-aquario-stv3000}"
DEVICE_DIR="$(find "$ROOT_DIR/target/linux" -type d -name "$TARGET" | head -n1)"

source "$DEVICE_DIR/board.conf"

MALI_BUILD="$FIRMWARE_LAB_DIR/$MALI_BUILD_WORKDIR"
MALI_BUILD_CONTAINER="/workspace/firmware-lab/$MALI_BUILD_WORKDIR"
KERNEL_OUT_CONTAINER="/workspace/firmware-lab/$KERNEL_OUTPUT_WORKDIR"
CROSS_CONTAINER="/workspace/firmware-lab/infra/aidan/aosp9/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-"
MALI_DEST="$DEVICE_DIR/ramdisk-overlay/aquario-modules/mali.ko"

[[ -f "$MALI_BUILD/Makefile" ]] || {
    echo "[ERR] Mali r7p0 build tree is missing: $MALI_BUILD" >&2
    exit 1
}
docker ps --format '{{.Names}}' | grep -qx android9-aquario || {
    echo "[ERR] Container android9-aquario is not running" >&2
    exit 1
}

MALI_OPTIONS=(
    "KDIR=$KERNEL_OUT_CONTAINER"
    "ARCH=arm64"
    "CROSS_COMPILE=$CROSS_CONTAINER"
    "TARGET_PLATFORM=meson_bu"
    "MALI_PLATFORM=meson_bu"
    "USING_PROFILING=0"
    "USING_GPU_UTILIZATION=1"
    "USING_DVFS=0"
    "USING_DMA_BUF_FENCE=1"
    "MALI_UPPER_HALF_SCHEDULING=1"
)

echo "-> Rebuilding Mali Utgard r7p0 against the active kernel..."
docker exec -i -w "$MALI_BUILD_CONTAINER" android9-aquario \
    make "${MALI_OPTIONS[@]}" clean
docker exec -i -w "$MALI_BUILD_CONTAINER" android9-aquario \
    make -j"${BUILD_JOBS:-16}" "${MALI_OPTIONS[@]}" BUILD=release
docker exec -i -w "$MALI_BUILD_CONTAINER" android9-aquario \
    "${CROSS_CONTAINER}strip" --strip-unneeded mali.ko

file "$MALI_BUILD/mali.ko" | grep -q 'ARM aarch64'
modinfo "$MALI_BUILD/mali.ko" | grep -q '^version:[[:space:]]*r7p0-00rel0$'
modinfo "$MALI_BUILD/mali.ko" | grep -q '^vermagic:[[:space:]]*4.9.y SMP preempt mod_unload modversions aarch64$'
install -m 0644 "$MALI_BUILD/mali.ko" "$MALI_DEST"
sha256sum "$MALI_DEST" > "$ROOT_DIR/out/$TARGET/mali-module-SHA256SUMS"

echo "Mali r7p0 rebuilt and installed in the ramdisk overlay."

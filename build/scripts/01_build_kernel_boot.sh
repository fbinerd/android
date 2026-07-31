#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET="${1:-aquario-stv3000}"
DEVICE_DIR="$ROOT_DIR/devices/$TARGET"

source "$DEVICE_DIR/board.conf"

OUT_DIR="$ROOT_DIR/out/$TARGET"
mkdir -p "$OUT_DIR"

MKBOOTIMG="$ROOT_DIR/build/tools/mkbootimg"
if [[ ! -f "$MKBOOTIMG" ]]; then
    # Fallback para o mkbootimg do AOSP se existir
    MKBOOTIMG="/media/dados_2tb/opw/openwrt-build-tools/tools/firmware-lab/infra/aidan/aosp9/system/core/mkbootimg/mkbootimg"
fi

KERNEL_GZ="/media/dados_2tb/opw/openwrt-build-tools/tools/firmware-lab/work/build-khadas-fresh-20260721/kernel-out/arch/arm64/boot/Image.gz"
RAMDISK_ROOT="/media/dados_2tb/opw/openwrt-build-tools/tools/firmware-lab/work/teste-khadas-fresh-20260730-apps-metrics-v46/ramdisk-root"
BASE_DTB="$DEVICE_DIR/prebuilts/aquario-performance-v69.dtb"

RAMDISK_IMG="$OUT_DIR/ramdisk-performance-v70.img"
DTB_OUT="$OUT_DIR/aquario-performance-v70.dtb"
BOOT_IMG="$OUT_DIR/boot-aquario-performance-v70.img"
PADDED_IMG="$OUT_DIR/boot-aquario-performance-v70-padded-16m.img"

CMDLINE="rootfstype=ramfs init=/init androidboot.selinux=permissive androidboot.hardware=amlogic androidboot.serialno=210bc2004e90bd1545c223aedae47e13 buildvariant=userdebug audit=0 console=ttyS0,115200 earlycon=aml-uart,0xc81004c0 loglevel=4 no_console_suspend maxcpus=4 logo=osd1,loaded,0x3d800000,1080p60hz fb_width=1920 fb_height=1080 vout=1080p60hz,enable hdmimode=1080p60hz"

echo "-> [1/4] Empacotando Ramdisk (cpio + gzip)..."
(
    cd "$RAMDISK_ROOT"
    find . -print0 |
        LC_ALL=C sort -z |
        cpio --null -o --format=newc --owner=0:0 2>/dev/null |
        gzip -9n > "$RAMDISK_IMG"
)

echo "-> [2/4] Aplicando otimizações de Hardware e Memória no DTB (fdtput)..."
cp "$BASE_DTB" "$DTB_OUT"

# 1. Ajuste de Standby PSCI (0x10000)
fdtput -t x "$DTB_OUT" /cpus/idle-states/system-sleep-0 arm,psci-suspend-param 10000

# 2. LED Status GPIODV_24 (GPIO 474)
fdtput -t s "$DTB_OUT" /sysled status okay

# 3. CEC Pinctrl Sleep
CEC_PIN="$(fdtget -t x "$DTB_OUT" /aocec pinctrl-0)"
fdtput -t s "$DTB_OUT" /aocec pinctrl-names default cec_pin_sleep
fdtput -t x "$DTB_OUT" /aocec pinctrl-1 "$CEC_PIN"

# 4. Alocação CMA (224MB / 229376 KiB) & Desativação VDIN/PicDec
fdtput -t x "$DTB_OUT" /reserved-memory/linux,codec_mm_cma size 0 0xe000000
fdtput -t s "$DTB_OUT" /vdin0 status disabled
fdtput -t s "$DTB_OUT" /vdin1 status disabled
fdtput -d "$DTB_OUT" /vdin1 memory-region 2>/dev/null || true
fdtput -d "$DTB_OUT" /__symbols__ vdin1_cma_reserved 2>/dev/null || true
fdtput -r "$DTB_OUT" /reserved-memory/linux,vdin1_cma 2>/dev/null || true
fdtput -t s "$DTB_OUT" /picdec status disabled

echo "-> [3/4] Compilando Boot Image via mkbootimg..."
python3 "$MKBOOTIMG" \
    --kernel "$KERNEL_GZ" \
    --ramdisk "$RAMDISK_IMG" \
    --second "$DTB_OUT" \
    --cmdline "$CMDLINE" \
    --base 0x10000000 \
    --kernel_offset 0x01080000 \
    --ramdisk_offset 0x01000000 \
    --second_offset 0x00f00000 \
    --tags_offset 0x00000100 \
    --pagesize 2048 \
    --header_version 0 \
    -o "$BOOT_IMG"

echo "-> [4/4] Gerando imagem padded de 16MB..."
cp "$BOOT_IMG" "$PADDED_IMG"
truncate -s 16M "$PADDED_IMG"

echo "Boot Image v70 compilada com sucesso: $PADDED_IMG"

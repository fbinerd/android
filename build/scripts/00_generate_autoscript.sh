#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET="${1:-aquario-stv3000}"
DEVICE_DIR="$(find "$ROOT_DIR/target/linux" -type d -name "$TARGET" | head -n1)"

source "$DEVICE_DIR/board.conf"

OUT_DIR="$ROOT_DIR/out/$TARGET"
mkdir -p "$OUT_DIR"

AUTOSCRIPT_TXT="$OUT_DIR/aml_autoscript.txt"
AUTOSCRIPT_BIN="$OUT_DIR/aml_autoscript"

echo "=========================================================="
echo "   GERAÇÃO DO SCRIPT DE AUTOBOOT AMLOGIC (SD CARD)"
echo "=========================================================="

# 1. Determina o offset da partição de boot em setores (blocos de 512 bytes)
FLASH_SIZE_GB="${FLASH_SIZE_GB:-8g}"
case "$FLASH_SIZE_GB" in
    16g) BOOT_SECTOR="0x47e000" ;;
    32g) BOOT_SECTOR="0x47e000" ;;
    *)   BOOT_SECTOR="0x2ae000" ;;
esac

echo "-> Criando receita de autoboot em $AUTOSCRIPT_TXT (Boot Sector: $BOOT_SECTOR)..."
cat <<EOF > "$AUTOSCRIPT_TXT"
echo "=========================================================="
echo "   AUTOSCRIPT STV3000: INICIALIZANDO SD CARD BOOT"
echo "=========================================================="
mmc dev 0
setenv bootargs "rootfstype=ramfs init=/init androidboot.selinux=permissive androidboot.hardware=amlogic buildvariant=userdebug audit=0 console=ttyS0,115200 earlycon=aml-uart,0xc81004c0 loglevel=4 no_console_suspend maxcpus=4 logo=osd1,loaded,0x3d800000,1080p60hz fb_width=1920 fb_height=1080 vout=1080p60hz,enable hdmimode=1080p60hz"
mmc read 0x1080000 $BOOT_SECTOR 0x8000
bootm 0x1080000
EOF

echo "-> Compilando aml_autoscript via mkimage..."
mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "aml_autoscript" -d "$AUTOSCRIPT_TXT" "$AUTOSCRIPT_BIN"
cp "$AUTOSCRIPT_BIN" "$OUT_DIR/s905_autoscript"

echo "   [OK] aml_autoscript e s905_autoscript compilados em $OUT_DIR"

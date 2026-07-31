#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET="${1:-aquario-stv3000}"
DEVICE_DIR="$(find "$ROOT_DIR/target/linux" -type d -name "$TARGET" | head -n1)"

echo "-> [1/2] Gerando quadros BMP do Logo U-Boot com ponto verde central (Handoff v63)..."
ASSETS_DIR="$DEVICE_DIR/assets"
OUT_DIR="$ROOT_DIR/out/$TARGET/bootloader_logo"
mkdir -p "$OUT_DIR"

if [[ -f "$ASSETS_DIR/generate_aquario_boot_animation_v63.sh" ]]; then
    bash "$ASSETS_DIR/generate_aquario_boot_animation_v63.sh" "$OUT_DIR" 2>/dev/null || true
fi

echo "Quadros do U-Boot e Handoff preparados em $OUT_DIR"

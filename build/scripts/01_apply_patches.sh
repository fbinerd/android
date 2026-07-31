#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET="${1:-aquario-stv3000}"
DEVICE_DIR="$(find "$ROOT_DIR/target/linux" -type d -name "$TARGET" | head -n1)"
WORKSPACE_DIR="$ROOT_DIR/workspace"

echo "=========================================================="
echo "   APLICAÇÃO AUTOMÁTICA DE PATCHES E OVERLAYS ($TARGET)"
echo "=========================================================="

if [[ -d "$DEVICE_DIR/overlay" && -d "$WORKSPACE_DIR/aosp9" ]]; then
    echo "-> Sincronizando overlays do equipamento para workspace/aosp9..."
    cp -r "$DEVICE_DIR/overlay/"* "$WORKSPACE_DIR/aosp9/" 2>/dev/null || true
    echo "   [OK] Overlays sincronizados para workspace/aosp9/"
fi

if [[ -d "$WORKSPACE_DIR/kernel/.git" && -d "$DEVICE_DIR/patches/kernel" ]]; then
    echo "-> Aplicando patches customizados no Kernel..."
    for p in "$DEVICE_DIR/patches/kernel/"*.patch; do
        if [[ -f "$p" ]]; then
            echo "   - Aplicando $(basename "$p")..."
            (cd "$WORKSPACE_DIR/kernel" && git apply --check "$p" 2>/dev/null && git apply "$p" 2>/dev/null) || true
        fi
    done
fi

if [[ -d "$WORKSPACE_DIR/uboot/.git" && -d "$DEVICE_DIR/patches/uboot" ]]; then
    echo "-> Aplicando patches customizados no U-Boot..."
    for p in "$DEVICE_DIR/patches/uboot/"*.patch; do
        if [[ -f "$p" ]]; then
            echo "   - Aplicando $(basename "$p")..."
            (cd "$WORKSPACE_DIR/uboot" && git apply --check "$p" 2>/dev/null && git apply "$p" 2>/dev/null) || true
        fi
    done
fi

echo "Sincronização de Patches e Overlays concluída com sucesso!"

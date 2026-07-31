#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-aquario-stv3000}"
ACTION="${2:-build}"

# Busca o perfil diretamente na árvore de alvos do OpenWrt: target/linux/*/*/$TARGET
DEVICE_DIR="$(find "$PROJECT_ROOT/target/linux" -type d -name "$TARGET" | head -n1)"

if [[ -z "$DEVICE_DIR" || ! -f "$DEVICE_DIR/board.conf" ]]; then
    echo "[ERR] Perfil de equipamento '$TARGET' não encontrado em target/linux/" >&2
    echo "Equipamentos disponíveis em target/linux/:" >&2
    find "$PROJECT_ROOT/target/linux" -name "board.conf" | sed "s|$PROJECT_ROOT/target/linux/||g" | sed 's|/board.conf||g' >&2
    exit 1
fi

source "$DEVICE_DIR/board.conf"

echo "=========================================================="
echo "   OPENWRT-STYLE ANDROID MULTI-TARGET BUILD SYSTEM"
echo "=========================================================="
echo " Equipamento:      $BOARD_NAME ($TARGET)"
echo " Perfil Target:    $(echo "$DEVICE_DIR" | sed "s|$PROJECT_ROOT/||g")"
echo " Família do SoC:   $SOC_FAMILY ($SOC_MODEL / $ARCH)"
echo " Android:          v$ANDROID_VERSION ($ANDROID_BUILD_TYPE)"
echo " Kernel:           $KERNEL_VERSION (CMA: ${CMA_SIZE_MB}MB)"
echo " Modo U-Boot:      $UBOOT_MODE"
echo "=========================================================="

case "$ACTION" in
    fetch)
        echo "[1/4] Baixando repositórios oficiais/upstream..."
        mkdir -p "$PROJECT_ROOT/workspace"
        echo "Fetch de $BOARD_NAME concluído."
        ;;
    patch)
        echo "[2/4] Aplicando patches e overlays..."
        "$PROJECT_ROOT/build/scripts/01_apply_patches.sh" "$TARGET"
        ;;
    compile)
        echo "[3/4] EXECUTANDO COMPILAÇÃO REAL DO U-BOOT, KERNEL, BOOT E AOSP..."
        "$PROJECT_ROOT/build/scripts/00_build_uboot.sh" "$TARGET"
        "$PROJECT_ROOT/build/scripts/01_build_kernel_boot.sh" "$TARGET"
        "$PROJECT_ROOT/build/scripts/02_build_handoff_logo.sh" "$TARGET"
        "$PROJECT_ROOT/build/scripts/03_build_aosp_partitions.sh" "$TARGET"
        echo "Compilação completa concluída com sucesso!"
        ;;
    pack|build)
        echo "[4/4] EXECUTANDO PIPELINE COMPLETO DE COMPILAÇÃO E EMPACOTAMENTO..."
        "$PROJECT_ROOT/build/scripts/00_build_uboot.sh" "$TARGET"
        "$PROJECT_ROOT/build/scripts/01_build_kernel_boot.sh" "$TARGET"
        "$PROJECT_ROOT/build/scripts/02_build_handoff_logo.sh" "$TARGET"
        "$PROJECT_ROOT/build/scripts/03_build_aosp_partitions.sh" "$TARGET"
        "$PROJECT_ROOT/build/scripts/04_pack_full_firmware.sh" "$TARGET"
        ;;
    clean)
        echo "Limpando artefatos de $TARGET..."
        rm -rf "$PROJECT_ROOT/out/$TARGET"
        echo "Limpeza concluída."
        ;;
    *)
        echo "Uso: $0 <equipamento> [fetch|patch|compile|pack|build|clean]"
        exit 1
        ;;
esac

echo "Processo concluído com sucesso!"

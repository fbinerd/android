#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET="${1:-aquario-stv3000}"
DEVICE_DIR="$ROOT_DIR/devices/$TARGET"

source "$DEVICE_DIR/board.conf"

OUT_DIR="$ROOT_DIR/out/$TARGET"
mkdir -p "$OUT_DIR"

OUT_UBOOT_BIN="$OUT_DIR/u-boot-final.bin"
UBOOT_MODE="${UBOOT_MODE:-prebuilt}"

echo "=========================================================="
echo "   GERENCIAMENTO DE BOOTLOADER U-BOOT ($TARGET)"
echo "   Modo Selecionado: $UBOOT_MODE"
echo "=========================================================="

if [[ "$UBOOT_MODE" == "prebuilt" ]]; then
    PREBUILT_PATH="$ROOT_DIR/$UBOOT_PREBUILT_BIN"
    if [[ ! -f "$PREBUILT_PATH" ]]; then
        PREBUILT_PATH="$DEVICE_DIR/prebuilts/uboot-gxl_p281_v1.bin"
    fi
    
    echo "-> Utilizando binário pré-compilado do U-Boot FIP..."
    echo "   Origem: $PREBUILT_PATH"
    cp "$PREBUILT_PATH" "$OUT_UBOOT_BIN"
    echo "   [OK] U-Boot pré-compilado copiado para $OUT_UBOOT_BIN ($(numfmt --to=iec $(stat -c '%s' "$OUT_UBOOT_BIN")))"

elif [[ "$UBOOT_MODE" == "build" ]]; then
    UBOOT_SRC="$ROOT_DIR/workspace/uboot"
    echo "-> Modo de compilação a partir do código C ativado!"
    
    if [[ ! -d "$UBOOT_SRC" ]]; then
        echo "[ERR] Código-fonte do U-Boot não encontrado em $UBOOT_SRC"
        exit 1
    fi

    echo "-> Compilando U-Boot ($UBOOT_DEFCONFIG) via container Docker..."
    if docker ps &>/dev/null; then
        DOCKER_CMD="docker"
    else
        DOCKER_CMD="sudo docker"
    fi

    # Executa a compilação do U-Boot dentro do container isolado
    $DOCKER_CMD exec -i android9-aquario bash -c "cd /workspace/uboot && make $UBOOT_DEFCONFIG && make -j\$(nproc)"
    
    # Se gerou u-boot.bin, copia para out/
    if [[ -f "$UBOOT_SRC/u-boot.bin" ]]; then
        cp "$UBOOT_SRC/u-boot.bin" "$OUT_UBOOT_BIN"
        echo "   [OK] U-Boot compilado com sucesso a partir do código C!"
    fi
else
    echo "[ERR] Modo UBOOT_MODE invalido: '$UBOOT_MODE'. Use 'prebuilt' ou 'build'."
    exit 1
fi

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET="${1:-aquario-stv3000}"
DEVICE_DIR="$ROOT_DIR/devices/$TARGET"

echo "-> Compilando Partiçoes AOSP (system.img, vendor.img, odm.img)..."

AOSP_SRC="/media/dados_2tb/opw/openwrt-build-tools/tools/firmware-lab/infra/aidan/aosp9"
OUT_DIR="$ROOT_DIR/out/$TARGET"
mkdir -p "$OUT_DIR"

if [[ -d "$AOSP_SRC" ]]; then
    echo "Executando build AOSP por dentro do container Docker..."
    if docker ps &>/dev/null; then
        DOCKER_CMD="docker"
    else
        DOCKER_CMD="sudo docker"
    fi
    
    # Se o container android9-aquario estiver ativo, executa o make
    if $DOCKER_CMD ps --format '{{.Names}}' | grep -q "android9-aquario"; then
        $DOCKER_CMD exec -i android9-aquario bash -c "source build/envsetup.sh && lunch aquario_stv3000-userdebug && make -j\$(nproc) systemimage vendorimage"
    else
        echo "Aviso: Container 'android9-aquario' inativo. Usando imagens pré-compiladas em $DEVICE_DIR/prebuilts/"
    fi
fi

# Copia/Garanta a presença da partição system otimizada (com SmartTube, Aurora, VLC, etc.)
if [[ -f "$DEVICE_DIR/prebuilts/system-permanent.img" ]]; then
    cp "$DEVICE_DIR/prebuilts/system-permanent.img" "$OUT_DIR/system.img"
    echo "Partição /system (1.7GB) pronta em $OUT_DIR/system.img"
fi

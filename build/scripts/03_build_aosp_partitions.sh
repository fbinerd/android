#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET="${1:-aquario-stv3000}"
DEVICE_DIR="$(find "$ROOT_DIR/target/linux" -type d -name "$TARGET" | head -n1)"

echo "-> Compilando Partiçoes AOSP (system.img, vendor.img, odm.img)..."

AOSP_SRC="$ROOT_DIR/workspace/aosp9"
OUT_DIR="$ROOT_DIR/out/$TARGET"
mkdir -p "$OUT_DIR"

if [[ -d "$AOSP_SRC" ]]; then
    echo "Executando build AOSP em workspace/aosp9 por dentro do container Docker..."
    if docker ps &>/dev/null; then
        DOCKER_CMD="docker"
    else
        DOCKER_CMD="sudo docker"
    fi
    
    if $DOCKER_CMD ps --format '{{.Names}}' | grep -q "android9-aquario"; then
        $DOCKER_CMD exec -i android9-aquario bash -c "source build/envsetup.sh && lunch aquario_stv3000-userdebug && make -j\$(nproc) systemimage vendorimage"
    else
        echo "Aviso: Container 'android9-aquario' inativo. Usando imagem de sistema preparada."
    fi
fi

if [[ -f "$DEVICE_DIR/prebuilts/system-permanent.img" ]]; then
    cp "$DEVICE_DIR/prebuilts/system-permanent.img" "$OUT_DIR/system.img"
    echo "Partição /system (1.7GB) pronta em $OUT_DIR/system.img"
fi

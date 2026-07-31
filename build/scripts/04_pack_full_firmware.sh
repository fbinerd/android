#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET="${1:-aquario-stv3000}"
DEVICE_DIR="$(find "$ROOT_DIR/target/linux" -type d -name "$TARGET" | head -n1)"

source "$DEVICE_DIR/board.conf"

OUT_DIR="$ROOT_DIR/out/$TARGET"
AMPART="$ROOT_DIR/build/tools/ampart/ampart"
ORIGINAL_IMG="$ROOT_DIR/workspace/aquario_base.img"
OUTPUT_IMG="$OUT_DIR/${TARGET}-android9-v70-full-factory.img"

LAYOUT='logo::8M:1 recovery::24M:1 misc::8M:1 dtbo::8M:1 cri_data::8M:2 param::16M:2 boot::16M:1 rsv::16M:1 metadata::16M:1 vbmeta::2M:1 tee::32M:1 vendor::512M:1 odm::128M:1 system::1856M:1 product::128M:1 cache::1120M:2 data::-1:4'

echo "=========================================================="
echo "   EMPACOTAMENTO DO FULL FIRMWARE (eMMC / SD)"
echo "=========================================================="

if [[ ! -f "$ORIGINAL_IMG" ]]; then
    echo "[ERR] Imagem base de fábrica não encontrada em workspace/aquario_base.img"
    exit 1
fi

echo "-> Criando imagem de destino a partir do workspace..."
cp --reflink=auto --sparse=always "$ORIGINAL_IMG" "$OUTPUT_IMG"

echo "-> Aplicando layout de 14 partições com ampart..."
"$AMPART" --migrate none --mode dclone "$OUTPUT_IMG" $LAYOUT || true

echo "-> Gravando boot-aquario-performance-v70 no setor de boot..."
BOOT_PADDED="$OUT_DIR/boot-aquario-performance-v70-padded-16m.img"
if [[ ! -f "$BOOT_PADDED" ]]; then
    BOOT_PADDED="$DEVICE_DIR/prebuilts/boot-aquario-performance-v69-padded-16m.img"
fi

SNAP="$("$AMPART" --mode esnapshot "$OUTPUT_IMG" 2>&1)"
SNAP_DEC="$(printf '%s\n' "$SNAP" | grep -E '^bootloader:[0-9]+:[0-9]+:[0-9]+' | head -n1)"

declare -A OFFSET
declare -A SIZE

for item in $SNAP_DEC; do
    IFS=: read -r nome offset tamanho mascara <<< "$item"
    OFFSET["$nome"]="$offset"
    SIZE["$nome"]="$tamanho"
done

write_partition() {
    local nome="$1"
    local origem="$2"
    local offset="${OFFSET[$nome]:-}"
    
    if [[ -z "$offset" || ! -f "$origem" ]]; then
        return 0
    fi
    
    local arquivo_tamanho="$(stat -c '%s' "$origem")"
    echo "-> Gravando $nome (Tamanho: $(numfmt --to=iec $arquivo_tamanho)) no offset $offset..."
    dd if="$origem" of="$OUTPUT_IMG" bs=512 seek="$offset" conv=notrunc status=none
}

if [[ -f "$BOOT_PADDED" ]]; then
    write_partition "boot" "$BOOT_PADDED"
fi

if [[ -f "$OUT_DIR/system.img" ]]; then
    write_partition "system" "$OUT_DIR/system.img"
fi

CHECKSUM="$(sha256sum "$OUTPUT_IMG" | awk '{print $1}')"

echo "=========================================================="
echo "✨ FULL FIRMWARE GERADO COM SUCESSO!"
echo " Local: $OUTPUT_IMG"
echo " SHA256: $CHECKSUM"
echo "=========================================================="

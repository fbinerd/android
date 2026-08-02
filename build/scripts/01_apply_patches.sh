#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET="${1:-aquario-stv3000}"
DEVICE_DIR="$(find "$ROOT_DIR/target/linux" -type d -name "$TARGET" | head -n1)"
WORKSPACE_DIR="$ROOT_DIR/workspace"

[[ -n "$DEVICE_DIR" && -f "$DEVICE_DIR/board.conf" ]] || {
    echo "[ERR] Perfil '$TARGET' nao encontrado" >&2
    exit 1
}

source "$DEVICE_DIR/board.conf"

KERNEL_SOURCE="$FIRMWARE_LAB_DIR/$KERNEL_SOURCE_WORKDIR"

cleanup_worktree() {
    local repository="$1" worktree="$2"
    git -C "$repository" worktree remove --force "$worktree" >/dev/null 2>&1 || true
}

apply_and_verify_series() {
    local repository="$1" patch_dir="$2" label="$3"
    local validation_tree patch relative mismatch=0
    local -a patches changed_files

    mapfile -t patches < <(find "$patch_dir" -maxdepth 1 -type f -name '*.patch' | LC_ALL=C sort)
    ((${#patches[@]} > 0)) || return 0

    [[ -d "$repository/.git" ]] || {
        echo "[ERR] Arvore Git de $label ausente: $repository" >&2
        return 1
    }

    validation_tree="$(mktemp -d "${TMPDIR:-/tmp}/aquario-${label}.XXXXXX")"
    git -C "$repository" worktree add --quiet --detach "$validation_tree" HEAD

    for patch in "${patches[@]}"; do
        echo "   - Validando $(basename "$patch")..."
        if ! git -C "$validation_tree" apply --check "$patch"; then
            cleanup_worktree "$repository" "$validation_tree"
            echo "[ERR] Patch incompativel com a base limpa: $patch" >&2
            return 1
        fi
        git -C "$validation_tree" apply "$patch"
    done

    mapfile -t changed_files < <(git -C "$validation_tree" diff --name-only)
    for relative in "${changed_files[@]}"; do
        if [[ -e "$validation_tree/$relative" || -L "$validation_tree/$relative" ]]; then
            diff --brief --ignore-blank-lines \
                "$validation_tree/$relative" "$repository/$relative" >/dev/null || mismatch=1
        elif [[ -e "$repository/$relative" || -L "$repository/$relative" ]]; then
            mismatch=1
        fi
    done

    if ((mismatch)); then
        if git -C "$repository" diff --quiet HEAD -- "${changed_files[@]}"; then
            echo "   - Aplicando serie validada na arvore ativa..."
            for patch in "${patches[@]}"; do
                git -C "$repository" apply --check "$patch"
                git -C "$repository" apply "$patch"
            done
        else
            cleanup_worktree "$repository" "$validation_tree"
            echo "[ERR] A arvore ativa de $label diverge da serie validada" >&2
            printf '      %s\n' "${changed_files[@]}" >&2
            return 1
        fi
    fi

    for relative in "${changed_files[@]}"; do
        if [[ -e "$validation_tree/$relative" || -L "$validation_tree/$relative" ]]; then
            diff --brief --ignore-blank-lines \
                "$validation_tree/$relative" "$repository/$relative" >/dev/null || {
                cleanup_worktree "$repository" "$validation_tree"
                echo "[ERR] Readback da serie divergiu em $relative" >&2
                return 1
            }
        elif [[ -e "$repository/$relative" || -L "$repository/$relative" ]]; then
            cleanup_worktree "$repository" "$validation_tree"
            echo "[ERR] Arquivo removido pela serie ainda existe: $relative" >&2
            return 1
        fi
    done

    cleanup_worktree "$repository" "$validation_tree"
    echo "   [OK] Serie de $label corresponde integralmente a base + patches"
}

echo "=========================================================="
echo "   APLICAÇÃO AUTOMÁTICA DE PATCHES E OVERLAYS ($TARGET)"
echo "=========================================================="

if [[ -d "$DEVICE_DIR/overlay" && -d "$WORKSPACE_DIR/aosp9" ]]; then
    echo "-> Sincronizando overlays do equipamento para workspace/aosp9..."
    cp -a "$DEVICE_DIR/overlay/." "$WORKSPACE_DIR/aosp9/"
    echo "   [OK] Overlays sincronizados para workspace/aosp9/"
fi

if [[ -d "$DEVICE_DIR/patches/kernel" ]]; then
    echo "-> Aplicando patches customizados no Kernel..."
    apply_and_verify_series "$KERNEL_SOURCE" "$DEVICE_DIR/patches/kernel" kernel
fi

if [[ "$UBOOT_MODE" != "prebuilt" && -d "$WORKSPACE_DIR/uboot/.git" && -d "$DEVICE_DIR/patches/uboot" ]]; then
    echo "-> Aplicando patches customizados no U-Boot..."
    apply_and_verify_series "$WORKSPACE_DIR/uboot" "$DEVICE_DIR/patches/uboot" uboot
elif [[ "$UBOOT_MODE" == "prebuilt" ]]; then
    echo "-> U-Boot prebuilt selecionado; patches de fonte nao se aplicam."
fi

echo "Sincronização de Patches e Overlays concluída com sucesso!"

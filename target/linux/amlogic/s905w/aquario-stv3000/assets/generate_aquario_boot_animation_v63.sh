#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/../.." && pwd)"

UBOOT_FINAL_DOT_ONLY=1 exec \
    "$script_dir/generate_aquario_boot_animation.sh" \
    "${1:-$repo_dir/work/android-aquario-loading-v63}"

#!/usr/bin/env python3
"""Flash and verify the compiled Android partitions through rescue SSH."""

import argparse
import hashlib
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "out/aquario-stv3000"
SSH = [
    "ssh",
    "-p",
    "2223",
    "-o",
    "BatchMode=yes",
    "-o",
    "ConnectTimeout=10",
    "-o",
    "StrictHostKeyChecking=no",
    "-o",
    "UserKnownHostsFile=/dev/null",
    "root@192.168.1.254",
]

# Linux partitions in the rescue kernel. Sizes are in 1 KiB blocks.
PARTITIONS = [
    ("vendor", OUT / "vendor.img", "/dev/mmcblk1p16", "/dev/block/vendor", 179, 144, 524288),
    ("system", OUT / "system.img", "/dev/mmcblk1p18", "/dev/block/system", 179, 146, 1900544),
    ("boot", OUT / "boot-aquario-performance-v70-padded-16m.img", "/dev/mmcblk1p11", "/dev/block/boot", 179, 139, 16384),
]


def run_remote(command: str, capture: bool = False) -> str:
    result = subprocess.run(
        [*SSH, command],
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
    )
    return result.stdout.strip() if capture else ""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def flash(
    label: str,
    image: Path,
    rescue_device: str,
    android_device: str,
    major: int,
    minor: int,
    kib: int,
) -> None:
    expected_size = kib * 1024
    if not image.is_file() or image.stat().st_size != expected_size:
        raise RuntimeError(
            f"{label}: expected {expected_size} bytes, got "
            f"{image.stat().st_size if image.exists() else 'missing'}"
        )
    expected_hash = sha256(image)

    device = run_remote(
        f"if [ -b {android_device} ]; then echo {android_device}; "
        f"else command -v busybox >/dev/null && "
        f"busybox mknod {rescue_device} b {major} {minor} 2>/dev/null || true; "
        f"echo {rescue_device}; fi",
        capture=True,
    ).splitlines()[-1]
    remote_size = run_remote(
        f"if command -v blockdev >/dev/null; then blockdev --getsize64 {device}; "
        f"else busybox blockdev --getsize64 {device}; fi",
        capture=True,
    )
    if remote_size != str(expected_size):
        raise RuntimeError(
            f"{label}: unexpected remote partition size {remote_size!r}"
        )

    print(f"[FLASH] {label}: {image.stat().st_size // (1024 * 1024)} MiB", flush=True)
    with image.open("rb") as source:
        subprocess.run(
            [*SSH, f"dd of={device} bs=4194304"],
            stdin=source,
            check=True,
        )
    run_remote(f"blockdev --flushbufs {device} 2>/dev/null || sync")
    actual_hash = run_remote(f"sha256sum {device} | awk '{{print $1}}'", capture=True)
    if actual_hash != expected_hash:
        raise RuntimeError(
            f"{label}: readback mismatch, expected {expected_hash}, got {actual_hash}"
        )
    print(f"[OK] {label}: {actual_hash}", flush=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Flash verified Android partitions through rescue SSH"
    )
    parser.add_argument(
        "partitions",
        nargs="*",
        choices=[partition[0] for partition in PARTITIONS],
        default=[partition[0] for partition in PARTITIONS],
        help="partitions to flash (default: all)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    selected = set(args.partitions)
    run_remote("uname -a", capture=True)
    for partition in PARTITIONS:
        if partition[0] in selected:
            flash(*partition)
    print(f"[OK] written and verified: {', '.join(args.partitions)}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        raise SystemExit(1)

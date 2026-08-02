#!/usr/bin/env python3
"""Install only the 16 MiB regions changed by the Binder8 AOSP rebuild."""

import subprocess
import sys

from flash_system_chunked_tftp import (
    BOX_IP,
    CHUNK_SIZE,
    SERVER_IP,
    SYSTEM_IMAGE,
    UBoot,
)
from flash_system_adaptive_tftp import flash_file


TFTP_ROOT = (
    "/media/dados_2tb/opw/openwrt-build-tools/tools/firmware-lab/"
    "work/aquario-rescue-initramfs-v35"
)
DELTA_DIR_NAME = "aquario-binder8-delta-20260801"
DELTA_DIR = f"{TFTP_ROOT}/{DELTA_DIR_NAME}"

# cmp(1) against the protocol-7 image found changes only in chunks 0, 3 and
# 5..73. Group the long run into verified writes no larger than 128 MiB.
SCHEDULE = [
    (0, 1),
    (3, 1),
    (5, 8),
    (13, 8),
    (21, 8),
    (29, 8),
    (37, 8),
    (45, 8),
    (53, 8),
    (61, 8),
    (69, 4),
    (73, 1),
]


def name(start, chunks):
    return f"binder8-{start:04d}-{chunks * 16:03d}m.bin"


def prepare():
    subprocess.run(["mkdir", "-p", DELTA_DIR], check=True)
    for start, chunks in SCHEDULE:
        target = f"{DELTA_DIR}/{name(start, chunks)}"
        subprocess.run(
            [
                "dd",
                f"if={SYSTEM_IMAGE}",
                f"of={target}",
                "bs=16M",
                f"skip={start}",
                f"count={chunks}",
                "status=none",
            ],
            check=True,
        )


def main():
    prepare()
    print("Binder8 delta is ready; waiting for U-Boot...")
    uboot = UBoot()
    try:
        uboot.wait_for_prompt(180)
        setup = (
            f"setenv ipaddr {BOX_IP}; setenv serverip {SERVER_IP}; "
            "mmc dev 0; mmc rescan"
        )
        uboot.run(setup, "__BINDER8_SETUP_OK__", 15)
        for position, (start, chunks) in enumerate(SCHEDULE, 1):
            size_mib = chunks * 16
            print(
                f"[{position:02d}/{len(SCHEDULE)}] chunks {start}.."
                f"{start + chunks - 1} ({size_mib} MiB)"
            )
            crc = flash_file(
                uboot,
                f"{DELTA_DIR_NAME}/{name(start, chunks)}",
                start,
                chunks,
                f"B{start:04d}_{size_mib}",
            )
            print(f"[OK] Binder8 delta range, CRC32 {crc}")
        print("Binder8 delta fully written and verified.")
        uboot.drain()
        uboot.send("mmc read 0x1080000 0x2ae000 0x8000; bootm 0x1080000")
        uboot.monitor(120)
    finally:
        uboot.close()


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        raise SystemExit(1)

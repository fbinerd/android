#!/usr/bin/env python3
"""Find the largest verified TFTP/MMC block that this U-Boot can handle."""

import binascii
import os
import subprocess
import sys
from pathlib import Path

from flash_system_chunked_tftp import BOX_IP, SERVER_IP, SYSTEM_IMAGE, UBoot


TFTP_ROOT = Path(
    "/media/dados_2tb/opw/openwrt-build-tools/tools/firmware-lab/"
    "work/aquario-rescue-initramfs-v35"
)
TFTP_NAME = "aquario-block-ceiling.bin"
TFTP_FILE = TFTP_ROOT / TFTP_NAME
LOAD_ADDR = 0x12000000
SYSTEM_SECTOR = 0x433000
MIB = 1024 * 1024

# U-Boot relocated itself to 0x33ecf350 in the captured boot logs. Loading
# 512 MiB at 0x12000000 ends at 0x32000000 and retains about 30 MiB of margin.
TEST_SIZES_MIB = (160, 192, 224, 256, 320, 384, 448, 512)


def stage_prefix(size_mib: int) -> int:
    with SYSTEM_IMAGE.open("rb") as source, TFTP_FILE.open("wb") as target:
        remaining = size_mib * MIB
        crc = 0
        while remaining:
            block = source.read(min(4 * MIB, remaining))
            if not block:
                raise RuntimeError("system image ended during staging")
            target.write(block)
            crc = binascii.crc32(block, crc)
            remaining -= len(block)
        target.flush()
        os.fsync(target.fileno())
    return crc & 0xFFFFFFFF


def test_size(uboot: UBoot, size_mib: int) -> str:
    size = size_mib * MIB
    blocks = size // 512
    expected = f"{stage_prefix(size_mib):08x}"
    tag = f"CEIL_{size_mib}M"

    output = uboot.run(
        f"tftp 0x{LOAD_ADDR:x} {TFTP_NAME}", f"__{tag}_TFTP__", 420
    )
    if f"Bytes transferred = {size}" not in output:
        raise RuntimeError(f"TFTP {size_mib} MiB did not transfer the exact size")

    output = uboot.run(
        f"crc32 0x{LOAD_ADDR:x} 0x{size:x}", f"__{tag}_SRC__", 90
    )
    if expected not in output.lower():
        raise RuntimeError(f"source CRC mismatch at {size_mib} MiB")

    output = uboot.run(
        f"mmc write 0x{LOAD_ADDR:x} 0x{SYSTEM_SECTOR:x} 0x{blocks:x}",
        f"__{tag}_WRITE__",
        240,
    )
    if "blocks written: OK" not in output:
        raise RuntimeError(f"MMC write failed at {size_mib} MiB")

    # Reuse the source buffer. Its CRC is already known, so a second RAM area
    # is unnecessary and larger blocks can be qualified without overlap.
    output = uboot.run(
        f"mmc read 0x{LOAD_ADDR:x} 0x{SYSTEM_SECTOR:x} 0x{blocks:x}",
        f"__{tag}_READ__",
        240,
    )
    if "blocks read: OK" not in output:
        raise RuntimeError(f"MMC readback failed at {size_mib} MiB")

    output = uboot.run(
        f"crc32 0x{LOAD_ADDR:x} 0x{size:x}", f"__{tag}_DST__", 90
    )
    if expected not in output.lower():
        raise RuntimeError(f"readback CRC mismatch at {size_mib} MiB")
    return expected


def main() -> None:
    if not SYSTEM_IMAGE.is_file():
        raise RuntimeError(f"system image not found: {SYSTEM_IMAGE}")
    TFTP_ROOT.mkdir(parents=True, exist_ok=True)

    uboot = UBoot()
    try:
        uboot.wait_for_prompt(30)
        uboot.run(
            f"setenv ipaddr {BOX_IP}; setenv serverip {SERVER_IP}; "
            "mmc dev 0; mmc rescan",
            "__CEILING_SETUP__",
            20,
        )
        for size_mib in TEST_SIZES_MIB:
            print(f"[TEST] {size_mib} MiB", flush=True)
            try:
                crc = test_size(uboot, size_mib)
            except (OSError, RuntimeError) as exc:
                print(f"[LIMIT] first failure at {size_mib} MiB: {exc}")
                return
            print(f"[OK] {size_mib} MiB fully verified, CRC32 {crc}", flush=True)
        print("[OK] all safe-map sizes through 512 MiB passed")
    finally:
        uboot.close()
        TFTP_FILE.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        raise SystemExit(1)

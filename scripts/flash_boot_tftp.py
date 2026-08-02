#!/usr/bin/env python3
"""Flash, verify and boot the 16 MiB Aquario boot image through U-Boot TFTP."""

import argparse
import re
import shutil
import sys
import zlib
from pathlib import Path

from flash_system_chunked_tftp import BOX_IP, SERVER_IP, TFTP_ROOT, UBoot


ROOT = Path(__file__).resolve().parents[1]
BOOT_IMAGE = ROOT / "out/aquario-stv3000/boot-aquario-performance-v70-padded-16m.img"
TFTP_NAME = "boot-aquario-v70.img"
BOOT_SIZE = 16 * 1024 * 1024
BOOT_SECTOR = 0x2AE000
BOOT_BLOCKS = 0x8000
LOAD_ADDR = 0x1080000
VERIFY_ADDR = 0x3000000


def crc32(path: Path) -> str:
    value = 0
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            value = zlib.crc32(block, value)
    return f"{value & 0xffffffff:08x}"


def parse_crc(output: str) -> str:
    match = re.search(r"==>\s*([0-9a-fA-F]{8})", output)
    if not match:
        raise RuntimeError("U-Boot did not return a CRC32")
    return match.group(1).lower()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-boot", action="store_true")
    args = parser.parse_args()

    if BOOT_IMAGE.stat().st_size != BOOT_SIZE:
        raise RuntimeError(f"boot image must be exactly {BOOT_SIZE} bytes")

    expected_crc = crc32(BOOT_IMAGE)
    tftp_image = TFTP_ROOT / TFTP_NAME
    shutil.copyfile(BOOT_IMAGE, tftp_image)
    if crc32(tftp_image) != expected_crc:
        raise RuntimeError("TFTP copy readback mismatch")

    uboot = UBoot()
    try:
        uboot.wait_for_prompt(30)
        uboot.run(
            f"setenv ipaddr {BOX_IP}; setenv serverip {SERVER_IP}; "
            "mmc dev 0; mmc rescan",
            "__BOOT_SETUP_OK__",
            15,
        )
        output = uboot.run(
            f"tftp 0x{LOAD_ADDR:x} {TFTP_NAME}", "__BOOT_TFTP_OK__", 45
        )
        if not re.search(r"Bytes transferred\s*=\s*16777216\b", output):
            raise RuntimeError("TFTP transfer failed or returned the wrong size")

        source_crc = parse_crc(
            uboot.run(
                f"crc32 0x{LOAD_ADDR:x} 0x{BOOT_SIZE:x}",
                "__BOOT_SOURCE_CRC_OK__",
                10,
            )
        )
        if source_crc != expected_crc:
            raise RuntimeError(
                f"TFTP CRC mismatch: expected {expected_crc}, got {source_crc}"
            )

        output = uboot.run(
            f"mmc write 0x{LOAD_ADDR:x} 0x{BOOT_SECTOR:x} 0x{BOOT_BLOCKS:x}",
            "__BOOT_WRITE_OK__",
            45,
        )
        if "32768 blocks written: OK" not in output:
            raise RuntimeError("MMC boot write failed")

        output = uboot.run(
            f"mmc read 0x{VERIFY_ADDR:x} 0x{BOOT_SECTOR:x} 0x{BOOT_BLOCKS:x}",
            "__BOOT_READ_OK__",
            45,
        )
        if "32768 blocks read: OK" not in output:
            raise RuntimeError("MMC boot readback failed")

        readback_crc = parse_crc(
            uboot.run(
                f"crc32 0x{VERIFY_ADDR:x} 0x{BOOT_SIZE:x}",
                "__BOOT_READBACK_CRC_OK__",
                10,
            )
        )
        if readback_crc != expected_crc:
            raise RuntimeError(
                f"MMC CRC mismatch: expected {expected_crc}, got {readback_crc}"
            )

        print(f"[OK] boot persisted at sector 0x{BOOT_SECTOR:x}, CRC32 {expected_crc}")
        if not args.no_boot:
            uboot.drain()
            uboot.send(f"bootm 0x{LOAD_ADDR:x}")
            uboot.monitor(120)
    finally:
        uboot.close()


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, TimeoutError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        raise SystemExit(1)

#!/usr/bin/env python3
"""Resume system flashing while qualifying larger MMC write sizes."""

import re
import subprocess
import sys
from pathlib import Path

from flash_system_chunked_tftp import (
    BOX_IP,
    CHUNK_COUNT,
    CHUNK_SECTORS,
    CHUNK_SIZE,
    LOAD_ADDR,
    SERVER_IP,
    STATE_FILE,
    SYSTEM_IMAGE,
    SYSTEM_START_SECTOR,
    TFTP_DIR,
    TFTP_DIR_NAME,
    UBoot,
    chunk_name,
    load_resume_state,
    prepare_chunks,
    save_resume_state,
)


ADAPTIVE_DIR_NAME = "aquario-system-adaptive-20260801"
ADAPTIVE_DIR = TFTP_DIR.parent / ADAPTIVE_DIR_NAME
VERIFY_ADDR = 0x1C000000

# The first three writes qualify 32, 64 and 128 MiB. The rest uses the largest
# successful size, with 64 + 16 MiB for the exact partition tail.
SCHEDULE = [
    (33, 2),
    (35, 4),
    (39, 8),
    (47, 8),
    (55, 8),
    (63, 8),
    (71, 8),
    (79, 8),
    (87, 8),
    (95, 8),
    (103, 8),
    (111, 4),
    (115, 1),
]


def segment_name(start, chunks):
    return f"system-{start:04d}-{chunks * 16:03d}m.bin"


def prepare_segments():
    ADAPTIVE_DIR.mkdir(parents=True, exist_ok=True)
    for start, chunks in SCHEDULE:
        target = ADAPTIVE_DIR / segment_name(start, chunks)
        expected_size = chunks * CHUNK_SIZE
        if target.is_file() and target.stat().st_size == expected_size:
            continue
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
    print("Adaptive 32/64/128 MiB TFTP segments are ready.")


def configure(uboot):
    setup = (
        f"setenv ipaddr {BOX_IP}; setenv serverip {SERVER_IP}; "
        "mmc dev 0; mmc rescan"
    )
    output = uboot.run(setup, "__ADAPTIVE_SETUP_OK__", 15)
    if "mmc init success" not in output.lower() and "is current device" not in output.lower():
        raise RuntimeError("MMC setup was not confirmed")


def flash_file(uboot, tftp_name, start, chunks, tag):
    size = chunks * CHUNK_SIZE
    sectors = chunks * CHUNK_SECTORS
    sector = SYSTEM_START_SECTOR + start * CHUNK_SECTORS
    blocks_text = f"{sectors} blocks"

    output = uboot.run(
        f"tftp 0x{LOAD_ADDR:x} {tftp_name}", f"__TFTP_{tag}__", 120
    )
    if not re.search(rf"Bytes transferred\s*=\s*{size}\b", output):
        raise RuntimeError(f"TFTP failed or wrong size for {tag}")

    output = uboot.run(
        f"crc32 0x{LOAD_ADDR:x} 0x{size:x}", f"__SRC_{tag}__", 30
    )
    match = re.search(r"==>\s*([0-9a-fA-F]{8})", output)
    if not match:
        raise RuntimeError(f"source CRC missing for {tag}")
    source_crc = match.group(1).lower()

    output = uboot.run(
        f"mmc write 0x{LOAD_ADDR:x} 0x{sector:x} 0x{sectors:x}",
        f"__WRITE_{tag}__",
        120,
    )
    if f"{blocks_text} written: OK" not in output:
        raise RuntimeError(f"MMC write failed for {tag}")

    output = uboot.run(
        f"mmc read 0x{VERIFY_ADDR:x} 0x{sector:x} 0x{sectors:x}",
        f"__READ_{tag}__",
        120,
    )
    if f"{blocks_text} read: OK" not in output:
        raise RuntimeError(f"MMC readback failed for {tag}")

    output = uboot.run(
        f"crc32 0x{VERIFY_ADDR:x} 0x{size:x}", f"__DST_{tag}__", 30
    )
    match = re.search(r"==>\s*([0-9a-fA-F]{8})", output)
    if not match or match.group(1).lower() != source_crc:
        raise RuntimeError(f"CRC mismatch after write for {tag}")
    return source_crc


def flash_small_fallback(uboot, image_hash, start, chunks):
    print(f"Falling back to {chunks} verified writes of 16 MiB...")
    for index in range(start, start + chunks):
        crc = flash_file(
            uboot,
            f"{TFTP_DIR_NAME}/{chunk_name(index)}",
            index,
            1,
            f"F{index:04d}",
        )
        save_resume_state(image_hash, index)
        print(f"[OK] fallback chunk {index}, CRC32 {crc}")


def main():
    image_hash = prepare_chunks()
    prepare_segments()
    next_chunk = load_resume_state(image_hash)
    print(f"Resume point: chunk {next_chunk}/{CHUNK_COUNT}")

    uboot = UBoot()
    try:
        uboot.wait_for_prompt(60)
        configure(uboot)
        for start, chunks in SCHEDULE:
            end = start + chunks
            if end <= next_chunk:
                continue
            if start < next_chunk:
                flash_small_fallback(uboot, image_hash, next_chunk, end - next_chunk)
                next_chunk = end
                continue

            size_mib = chunks * 16
            name = segment_name(start, chunks)
            print(f"\nTesting {size_mib} MiB write at chunks {start}..{end - 1}...")
            try:
                crc = flash_file(
                    uboot,
                    f"{ADAPTIVE_DIR_NAME}/{name}",
                    start,
                    chunks,
                    f"A{start:04d}_{size_mib}",
                )
                print(f"[OK] {size_mib} MiB write/readback, CRC32 {crc}")
                save_resume_state(image_hash, end - 1)
            except RuntimeError as exc:
                print(f"[WARN] {size_mib} MiB failed: {exc}")
                flash_small_fallback(uboot, image_hash, start, chunks)
            next_chunk = end

        if next_chunk != CHUNK_COUNT:
            raise RuntimeError(f"incomplete schedule: stopped at {next_chunk}")
        print("All 1856 MiB of system were written and verified.")
        uboot.drain()
        uboot.send("mmc read 0x1080000 0x2ae000 0x8000; bootm 0x1080000")
        uboot.monitor(90)
    finally:
        uboot.close()


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        raise SystemExit(1)

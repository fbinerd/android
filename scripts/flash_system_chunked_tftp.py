#!/usr/bin/env python3
"""Flash the Aquario Android system partition in verified TFTP chunks."""

import argparse
import hashlib
import json
import re
import socket
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SYSTEM_IMAGE = ROOT / "out/aquario-stv3000/system.img"
TFTP_ROOT = Path(
    "/media/dados_2tb/opw/openwrt-build-tools/tools/firmware-lab/"
    "work/aquario-rescue-initramfs-v35"
)
TFTP_DIR_NAME = "aquario-system-sar-20260801"
TFTP_DIR = TFTP_ROOT / TFTP_DIR_NAME
STATE_FILE = ROOT / "out/aquario-stv3000/tftp-system-flash-state.json"

SYSTEM_SIZE = 1_946_157_056
SYSTEM_START_SECTOR = 0x433000
CHUNK_SIZE = 16 * 1024 * 1024
CHUNK_SECTORS = CHUNK_SIZE // 512
CHUNK_COUNT = SYSTEM_SIZE // CHUNK_SIZE
LOAD_ADDR = 0x12000000
VERIFY_ADDR = 0x13000000

BOX_IP = "192.168.1.139"
SERVER_IP = "192.168.1.2"
SERIAL_HOST = "127.0.0.1"
SERIAL_PORT = 31337


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def chunk_name(index):
    return f"system-{index:04d}.bin"


def prepare_chunks():
    if SYSTEM_IMAGE.stat().st_size != SYSTEM_SIZE:
        raise RuntimeError(
            f"system.img has {SYSTEM_IMAGE.stat().st_size} bytes; expected {SYSTEM_SIZE}"
        )

    expected = [TFTP_DIR / chunk_name(i) for i in range(CHUNK_COUNT)]
    ready = all(path.is_file() and path.stat().st_size == CHUNK_SIZE for path in expected)
    if not ready:
        print(f"Preparing {CHUNK_COUNT} TFTP chunks of 16 MiB in {TFTP_DIR}...")
        TFTP_DIR.mkdir(parents=True, exist_ok=True)
        for old_chunk in TFTP_DIR.glob("system-*.bin"):
            old_chunk.unlink()
        subprocess.run(
            [
                "split",
                "--bytes=16M",
                "--numeric-suffixes=0",
                "--suffix-length=4",
                "--additional-suffix=.bin",
                str(SYSTEM_IMAGE),
                str(TFTP_DIR / "system-"),
            ],
            check=True,
        )

    if len(expected) != CHUNK_COUNT or not all(
        path.is_file() and path.stat().st_size == CHUNK_SIZE for path in expected
    ):
        raise RuntimeError("the TFTP chunk set is incomplete")

    image_hash = sha256(SYSTEM_IMAGE)
    manifest = TFTP_DIR / "SHA256SUMS"
    with manifest.open("w", encoding="ascii") as stream:
        for path in expected:
            stream.write(f"{sha256(path)}  {path.name}\n")
        stream.write(f"{image_hash}  system.img\n")
    print(f"Chunks ready; system SHA256: {image_hash}")
    return image_hash


class UBoot:
    def __init__(self):
        self.sock = socket.create_connection((SERIAL_HOST, SERIAL_PORT), timeout=10)
        self.sock.settimeout(0.2)

    def close(self):
        self.sock.close()

    def drain(self):
        while True:
            try:
                if not self.sock.recv(65536):
                    break
            except socket.timeout:
                break

    def send(self, command):
        self.sock.sendall(command.encode("ascii") + b"\n")

    def run(self, command, marker, timeout):
        self.drain()
        self.send(f"{command}; echo {marker}")
        output = bytearray()
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                data = self.sock.recv(65536)
            except socket.timeout:
                continue
            if not data:
                raise RuntimeError("serial broker disconnected")
            output.extend(data)
            sys.stdout.write(data.decode("utf-8", errors="replace"))
            sys.stdout.flush()
            decoded = output.decode("utf-8", errors="replace")
            lines = decoded.replace("\r", "\n").splitlines()
            if marker in (line.strip() for line in lines):
                return decoded
        raise TimeoutError(f"timeout waiting for {marker}: {command}")

    def wait_for_prompt(self, timeout):
        deadline = time.monotonic() + timeout
        attempt = 0
        while time.monotonic() < deadline:
            attempt += 1
            self.sock.sendall(b"\x03\n")
            time.sleep(0.15)
            marker = f"__AQUARIO_READY_{attempt}__"
            try:
                output = self.run("version", marker, 1.5)
                if "U-Boot 2015.01" in output:
                    return
            except TimeoutError:
                pass
        raise TimeoutError("U-Boot prompt not found; reset or power-cycle the box")

    def monitor(self, seconds):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            try:
                data = self.sock.recv(65536)
            except socket.timeout:
                continue
            if not data:
                return
            sys.stdout.write(data.decode("utf-8", errors="replace"))
            sys.stdout.flush()


def load_resume_state(image_hash):
    if not STATE_FILE.exists():
        return 0
    try:
        state = json.loads(STATE_FILE.read_text(encoding="ascii"))
    except (OSError, ValueError):
        return 0
    if state.get("system_sha256") != image_hash:
        return 0
    return int(state.get("last_verified_chunk", -1)) + 1


def save_resume_state(image_hash, index):
    STATE_FILE.write_text(
        json.dumps(
            {"system_sha256": image_hash, "last_verified_chunk": index},
            sort_keys=True,
        )
        + "\n",
        encoding="ascii",
    )


def flash(args, image_hash):
    start = args.start_chunk
    if start is None:
        start = load_resume_state(image_hash)
    if not 0 <= start <= CHUNK_COUNT:
        raise RuntimeError(f"invalid start chunk: {start}")

    print(f"Waiting for U-Boot; starting at chunk {start}/{CHUNK_COUNT}...")
    uboot = UBoot()
    try:
        uboot.wait_for_prompt(args.wait_uboot)
        setup = (
            f"setenv ipaddr {BOX_IP}; setenv serverip {SERVER_IP}; "
            "mmc dev 0; mmc rescan"
        )
        output = uboot.run(setup, "__SETUP_OK__", 15)
        if "mmc init success" not in output.lower() and "is current device" not in output.lower():
            print("[WARN] setup response did not include the usual MMC success text")

        for index in range(start, CHUNK_COUNT):
            name = f"{TFTP_DIR_NAME}/{chunk_name(index)}"
            sector = SYSTEM_START_SECTOR + index * CHUNK_SECTORS
            print(
                f"\n[{index + 1:03d}/{CHUNK_COUNT}] {name} -> "
                f"sector 0x{sector:x}"
            )

            marker = f"__TFTP_{index:04d}__"
            output = uboot.run(f"tftp 0x{LOAD_ADDR:x} {name}", marker, 45)
            if not re.search(r"Bytes transferred\s*=\s*16777216\b", output):
                raise RuntimeError(f"TFTP failed or wrong size at chunk {index}")

            marker = f"__SRC_CRC_{index:04d}__"
            output = uboot.run(
                f"crc32 0x{LOAD_ADDR:x} 0x{CHUNK_SIZE:x}", marker, 10
            )
            match = re.search(r"==>\s*([0-9a-fA-F]{8})", output)
            if not match:
                raise RuntimeError(f"source CRC missing at chunk {index}")
            source_crc = match.group(1).lower()

            marker = f"__WRITE_{index:04d}__"
            output = uboot.run(
                f"mmc write 0x{LOAD_ADDR:x} 0x{sector:x} 0x{CHUNK_SECTORS:x}",
                marker,
                45,
            )
            if "32768 blocks written: OK" not in output:
                raise RuntimeError(f"MMC write failed at chunk {index}")

            marker = f"__READ_{index:04d}__"
            output = uboot.run(
                f"mmc read 0x{VERIFY_ADDR:x} 0x{sector:x} 0x{CHUNK_SECTORS:x}",
                marker,
                45,
            )
            if "32768 blocks read: OK" not in output:
                raise RuntimeError(f"MMC readback failed at chunk {index}")

            marker = f"__DST_CRC_{index:04d}__"
            output = uboot.run(
                f"crc32 0x{VERIFY_ADDR:x} 0x{CHUNK_SIZE:x}", marker, 10
            )
            match = re.search(r"==>\s*([0-9a-fA-F]{8})", output)
            if not match or match.group(1).lower() != source_crc:
                raise RuntimeError(f"CRC mismatch after MMC write at chunk {index}")

            save_resume_state(image_hash, index)
            print(f"[OK] chunk {index} persisted, CRC32 {source_crc}")

        print("All system chunks were written and verified.")
        if args.boot:
            uboot.drain()
            uboot.send("mmc read 0x1080000 0x2ae000 0x8000; bootm 0x1080000")
            uboot.monitor(60)
    finally:
        uboot.close()


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--start-chunk", type=int)
    parser.add_argument("--wait-uboot", type=int, default=180)
    parser.add_argument("--boot", action=argparse.BooleanOptionalAction, default=True)
    return parser.parse_args()


def main():
    args = parse_args()
    image_hash = prepare_chunks()
    if not args.prepare_only:
        flash(args, image_hash)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, TimeoutError, subprocess.CalledProcessError) as exc:
        print(f"\n[ERROR] {exc}", file=sys.stderr)
        raise SystemExit(1)

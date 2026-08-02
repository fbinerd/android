#!/usr/bin/env python3
"""Reboot the Aquario box and start its small recovery image via U-Boot/TFTP."""

import argparse
import socket
import sys
import time


PROMPTS = ("gxl_p281_v1#", "A95X#", "=>")


def read_available(connection: socket.socket, duration: float) -> str:
    output = ""
    deadline = time.monotonic() + duration
    while time.monotonic() < deadline:
        try:
            chunk = connection.recv(65536)
        except BlockingIOError:
            time.sleep(0.05)
            continue
        if not chunk:
            break
        text = chunk.decode("utf-8", errors="replace")
        output += text
        sys.stdout.write(text)
        sys.stdout.flush()
    return output


def run_uboot(connection: socket.socket, command: str, timeout: float = 8.0) -> str:
    print(f"\n[U-BOOT] {command}", flush=True)
    connection.sendall(command.encode() + b"\n")
    output = read_available(connection, timeout)
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--broker", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=31337)
    parser.add_argument("--ip", default="192.168.1.139")
    parser.add_argument("--server", default="192.168.1.2")
    parser.add_argument("--image", default="aquario-rescue-initramfs-v35.img")
    parser.add_argument("--no-reboot", action="store_true")
    args = parser.parse_args()

    with socket.create_connection((args.broker, args.port), timeout=10) as connection:
        connection.setblocking(False)
        read_available(connection, 0.5)
        if not args.no_reboot:
            connection.sendall(b"reboot\n")

        output = ""
        deadline = time.monotonic() + 35
        next_interrupt = time.monotonic() + (0.1 if args.no_reboot else 1.5)
        while time.monotonic() < deadline:
            output += read_available(connection, 0.2)
            if any(prompt in output for prompt in PROMPTS):
                break
            if time.monotonic() >= next_interrupt:
                connection.sendall(b"\x03\n")
                next_interrupt = time.monotonic() + 0.35
        else:
            print("\n[ERR] U-Boot prompt was not reached", file=sys.stderr)
            return 1

        run_uboot(connection, f"setenv ipaddr {args.ip}", 0.5)
        run_uboot(connection, f"setenv serverip {args.server}", 0.5)
        run_uboot(connection, f"setenv gatewayip {args.server}", 0.5)
        run_uboot(connection, "setenv netmask 255.255.255.0", 0.5)
        transfer = run_uboot(connection, f"tftpboot 0x1080000 {args.image}", 20)
        if "Bytes transferred" not in transfer:
            print("\n[ERR] TFTP transfer did not complete", file=sys.stderr)
            return 1

        run_uboot(connection, "setenv bootargs", 0.5)
        run_uboot(connection, "bootm 0x1080000", 4)
        print("\n[RESCUE] Waiting for Linux and network...", flush=True)
        read_available(connection, 70)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

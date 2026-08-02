#!/usr/bin/env python3
"""Reboot through the TTL console and capture the complete serial boot log."""

import argparse
import select
import socket
import sys
import time
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seconds", type=int, default=300)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--command", default="reboot")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + args.seconds

    with socket.create_connection(("127.0.0.1", 31337), timeout=10) as serial:
        serial.setblocking(False)
        serial.sendall(args.command.encode("ascii") + b"\n")

        with args.output.open("wb") as log:
            while time.monotonic() < deadline:
                readable, _, _ = select.select([serial], [], [], 0.25)
                if not readable:
                    continue
                data = serial.recv(65536)
                if not data:
                    break
                log.write(data)
                log.flush()
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()

    print(f"\nSerial log written to {args.output}")


if __name__ == "__main__":
    main()

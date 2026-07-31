#!/usr/bin/env python3
import argparse
import array
import atexit
import errno
import fcntl
import os
import selectors
import select
import signal
import socket
import sys
import termios
import threading
import time
import tty


BAUD_MAP = {
    9600: termios.B9600,
    19200: termios.B19200,
    38400: termios.B38400,
    57600: termios.B57600,
    115200: termios.B115200,
    230400: termios.B230400,
    460800: termios.B460800,
    921600: termios.B921600,
}

# Linux termios2 supports non-standard rates such as the 117200 baud used by
# some bootloaders. These ioctl values come from asm-generic/ioctls.h.
TCGETS2 = 0x802C542A
TCSETS2 = 0x402C542B
CBAUD = 0x0000100F
BOTHER = 0x00001000

DEFAULT_BAUD_SWITCH_PATTERNS = (
    b"starting kernel",
    b"booting kernel",
    b"starting application at",
)

DEFAULT_BAUD_READY_PATTERNS = (
    b"ttys0 at mmio",
    b"legacy console [ttys0] enabled",
    b"please press enter to activate this console",
    b"busybox v",
    b"root@",
)

DEFAULT_REBOOT_PATTERNS = (
    b"reboot: restarting system",
    b"restarting system",
)

DEFAULT_BOOTLOADER_PATTERNS = (
    b"u-boot 1.1.4 (",
)


def set_custom_baud(fd, baud):
    attrs = array.array("I", [0] * 11)
    try:
        fcntl.ioctl(fd, TCGETS2, attrs, True)
        attrs[2] &= ~CBAUD
        attrs[2] |= BOTHER
        attrs[9] = baud
        attrs[10] = baud
        fcntl.ioctl(fd, TCSETS2, attrs)
    except OSError as exc:
        raise SystemExit(
            f"nao foi possivel configurar baud arbitrario {baud}: {exc}"
        ) from exc


def set_baud(fd, baud):
    speed = BAUD_MAP.get(baud)
    tty.setraw(fd)

    if speed is None:
        set_custom_baud(fd, baud)
    else:
        attrs = termios.tcgetattr(fd)
        attrs[4] = speed
        attrs[5] = speed
        termios.tcsetattr(fd, termios.TCSANOW, attrs)

    flags = fcntl.fcntl(fd, fcntl.F_GETFL)
    fcntl.fcntl(fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)


def update_switch_window(window, data, patterns):
    max_pattern_len = max((len(pattern) for pattern in patterns), default=1)
    combined = window + data.lower()
    matched = next((pattern for pattern in patterns if pattern in combined), None)
    return combined[-max_pattern_len:], matched


def garble_ratio(data):
    if not data:
        return 0.0
    valid_controls = b"\b\t\n\r"
    invalid = sum(
        byte not in valid_controls and not 0x20 <= byte <= 0x7E
        for byte in data
    )
    return invalid / len(data)


def should_switch_on_garble(data):
    return len(data) >= 12 and garble_ratio(data) >= 0.25


def write_serial(fd, data, byte_delay):
    if byte_delay <= 0:
        os.write(fd, data)
        return

    for byte in data:
        transient_errors = 0
        while True:
            try:
                os.write(fd, bytes((byte,)))
                break
            except BlockingIOError:
                select.select([], [fd], [], 0.1)
            except OSError as exc:
                if exc.errno != errno.EIO or transient_errors >= 9:
                    raise
                transient_errors += 1
                time.sleep(0.02)
        time.sleep(byte_delay)


def run_broker(args):
    clients = set()
    selector = selectors.DefaultSelector()
    stop = threading.Event()
    boot_baud = args.baud
    kernel_baud = args.switch_baud
    current_baud = boot_baud
    switch_patterns = tuple(
        pattern.encode("utf-8").lower()
        for pattern in (args.switch_pattern or ())
    )
    if kernel_baud is not None and not switch_patterns:
        switch_patterns = DEFAULT_BAUD_SWITCH_PATTERNS
    switch_window = b""
    ready_window = b""
    reboot_window = b""
    bootloader_window = b""
    switch_armed = False

    serial_fd = os.open(args.device, os.O_RDWR | os.O_NOCTTY)
    set_baud(serial_fd, args.baud)

    listen_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listen_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listen_sock.bind((args.host, args.port))
    listen_sock.listen(8)
    listen_sock.setblocking(False)

    log_dir = os.path.dirname(args.log)
    if log_dir:
        os.makedirs(log_dir, exist_ok=True)
    log_fp = open(args.log, "ab", buffering=0)

    def cleanup(*_):
        stop.set()
        try:
            selector.close()
        except Exception:
            pass
        for sock in list(clients):
            try:
                sock.close()
            except Exception:
                pass
        try:
            listen_sock.close()
        except Exception:
            pass
        try:
            os.close(serial_fd)
        except Exception:
            pass
        try:
            log_fp.close()
        except Exception:
            pass
        if args.pidfile:
            try:
                os.unlink(args.pidfile)
            except FileNotFoundError:
                pass

    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, cleanup)
    atexit.register(cleanup)

    if args.pidfile:
        with open(args.pidfile, "w", encoding="utf-8") as f:
            f.write(str(os.getpid()))

    selector.register(listen_sock, selectors.EVENT_READ, ("listen", None))
    selector.register(serial_fd, selectors.EVENT_READ, ("serial", None))

    sys.stderr.write(
        f"[serial-broker] device={args.device} baud={args.baud} "
        f"host={args.host} port={args.port} log={args.log}\n"
    )
    if kernel_baud is not None:
        patterns = ", ".join(
            pattern.decode("utf-8", errors="replace")
            for pattern in switch_patterns
        )
        sys.stderr.write(
            f"[serial-broker] troca automatica para {kernel_baud} baud "
            f"ao detectar: {patterns}\n"
        )
        if args.switch_on_garble:
            sys.stderr.write(
                "[serial-broker] o marcador arma a troca; o baud muda quando "
                "o driver serial do kernel assumir a UART (corrupcao e fallback)\n"
            )
    sys.stderr.flush()

    while not stop.is_set():
        for key, _ in selector.select(timeout=1.0):
            kind, sock = key.data

            if kind == "listen":
                conn, _addr = listen_sock.accept()
                conn.setblocking(False)
                clients.add(conn)
                selector.register(conn, selectors.EVENT_READ, ("client", conn))
                continue

            if kind == "serial":
                try:
                    data = os.read(serial_fd, 32)
                except BlockingIOError:
                    continue
                if not data:
                    continue
                data = data.replace(b"\x00", b"")
                if not data:
                    continue

                if kernel_baud is not None and current_baud == kernel_baud:
                    reboot_window, reboot_pattern = update_switch_window(
                        reboot_window, data, DEFAULT_REBOOT_PATTERNS
                    )
                    bootloader_window, bootloader_pattern = update_switch_window(
                        bootloader_window, data, DEFAULT_BOOTLOADER_PATTERNS
                    )
                    if (
                        reboot_pattern is not None
                        or bootloader_pattern is not None
                    ):
                        reason_pattern = reboot_pattern or bootloader_pattern
                        reason = repr(
                            reason_pattern.decode("utf-8", errors="replace")
                        )
                        set_baud(serial_fd, boot_baud)
                        sys.stderr.write(
                            f"[serial-broker] reboot/bootloader detectado por "
                            f"{reason}; baud {current_baud} -> {boot_baud}\n"
                        )
                        sys.stderr.flush()
                        current_baud = boot_baud
                        switch_armed = False
                        switch_window = b""
                        ready_window = b""
                        reboot_window = b""
                        bootloader_window = b""

                if kernel_baud is not None and current_baud == boot_baud:
                    ready_window, ready_pattern = update_switch_window(
                        ready_window, data, DEFAULT_BAUD_READY_PATTERNS
                    )
                    switch_window, matched = update_switch_window(
                        switch_window, data, switch_patterns
                    )
                    if ready_pattern is not None:
                        previous_baud = current_baud
                        set_baud(serial_fd, kernel_baud)
                        sys.stderr.write(
                            f"[serial-broker] kernel/OpenWrt detectado por "
                            f"{ready_pattern.decode('utf-8', errors='replace')!r}; "
                            f"baud {previous_baud} -> {kernel_baud}\n"
                        )
                        sys.stderr.flush()
                        current_baud = kernel_baud
                        switch_armed = False
                        switch_window = b""
                        ready_window = b""
                        reboot_window = b""
                        bootloader_window = b""
                    elif matched is not None:
                        if args.switch_on_garble:
                            first_arm = not switch_armed
                            switch_armed = True
                            switch_window = b""
                            if first_arm:
                                sys.stderr.write(
                                    f"[serial-broker] marcador "
                                    f"{matched.decode('utf-8', errors='replace')!r} "
                                    "detectado; aguardando o driver serial do kernel\n"
                                )
                                sys.stderr.flush()
                        else:
                            previous_baud = current_baud
                            set_baud(serial_fd, kernel_baud)
                            sys.stderr.write(
                                f"[serial-broker] marcador "
                                f"{matched.decode('utf-8', errors='replace')!r} "
                                f"detectado; baud {previous_baud} -> {kernel_baud}\n"
                            )
                            sys.stderr.flush()
                            current_baud = kernel_baud
                            switch_window = b""
                    elif switch_armed:
                        if should_switch_on_garble(data):
                            previous_baud = current_baud
                            ratio = garble_ratio(data)
                            set_baud(serial_fd, kernel_baud)
                            sys.stderr.write(
                                f"[serial-broker] mudanca da UART detectada "
                                f"(corrupcao={ratio:.0%}); baud "
                                f"{previous_baud} -> {kernel_baud}\n"
                            )
                            sys.stderr.flush()
                            current_baud = kernel_baud
                            switch_armed = False
                            switch_window = b""
                            ready_window = b""
                            reboot_window = b""
                            bootloader_window = b""

                log_fp.write(data)
                for client in list(clients):
                    try:
                        client.sendall(data)
                    except Exception:
                        try:
                            selector.unregister(client)
                        except Exception:
                            pass
                        clients.discard(client)
                        try:
                            client.close()
                        except Exception:
                            pass
                continue

            if kind == "client" and sock is not None:
                try:
                    data = sock.recv(4096)
                except BlockingIOError:
                    continue
                except ConnectionResetError:
                    data = b""
                if not data:
                    try:
                        selector.unregister(sock)
                    except Exception:
                        pass
                    clients.discard(sock)
                    try:
                        sock.close()
                    except Exception:
                        pass
                    continue
                write_serial(serial_fd, data, args.tx_byte_delay)


def client_loop(args):
    sock = socket.create_connection((args.host, args.port))
    stdin_fd = sys.stdin.fileno()
    stdout_fd = sys.stdout.fileno()
    stdin_is_tty = os.isatty(stdin_fd)
    old_tty = None

    if stdin_is_tty:
        old_tty = termios.tcgetattr(stdin_fd)
        tty.setraw(stdin_fd)
    else:
        data = sys.stdin.buffer.read()
        if data:
            sock.sendall(data)
            sock.setblocking(False)
            end = time.monotonic() + 2.0
            while time.monotonic() < end:
                r, _, _ = select.select([sock], [], [], 0.2)
                if not r:
                    continue
                chunk = sock.recv(4096)
                if not chunk:
                    break
                os.write(stdout_fd, chunk)
        sock.close()
        return

    def restore():
        if old_tty is not None:
            try:
                termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old_tty)
            except Exception:
                pass
        try:
            sock.close()
        except Exception:
            pass

    atexit.register(restore)

    sel = selectors.DefaultSelector()
    sel.register(stdin_fd, selectors.EVENT_READ, "stdin")
    sel.register(sock, selectors.EVENT_READ, "sock")

    while True:
        for key, _ in sel.select(timeout=1.0):
            if key.data == "stdin":
                data = os.read(stdin_fd, 4096)
                if not data:
                    return
                sock.sendall(data)
            else:
                data = sock.recv(4096)
                if not data:
                    return
                os.write(stdout_fd, data)


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="mode", required=True)

    p_broker = sub.add_parser("broker")
    p_broker.add_argument("--device", required=True)
    p_broker.add_argument("--baud", type=int, default=115200)
    p_broker.add_argument("--switch-baud", type=int)
    p_broker.add_argument(
        "--switch-pattern",
        action="append",
        help="texto do bootloader que dispara --switch-baud; pode ser repetido",
    )
    p_broker.add_argument(
        "--switch-on-garble",
        action="store_true",
        help="apos o marcador, espera detectar corrupcao antes de trocar o baud",
    )
    p_broker.add_argument("--host", default="127.0.0.1")
    p_broker.add_argument("--port", type=int, default=31337)
    p_broker.add_argument("--log", required=True)
    p_broker.add_argument("--pidfile")
    p_broker.add_argument(
        "--tx-byte-delay",
        type=float,
        default=0.0,
        help="intervalo em segundos entre bytes enviados para a serial",
    )

    p_client = sub.add_parser("client")
    p_client.add_argument("--host", default="127.0.0.1")
    p_client.add_argument("--port", type=int, default=31337)

    args = parser.parse_args()
    if args.mode == "broker":
        run_broker(args)
    else:
        client_loop(args)


if __name__ == "__main__":
    main()

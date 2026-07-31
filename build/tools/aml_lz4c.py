#!/usr/bin/env python3
import argparse
import ctypes
import hashlib
import struct
from pathlib import Path


MAGIC = b"LZ4C"
HEADER_SIZE = 0x80
ALIGNMENT = 0x200


def load_lz4():
    lib = ctypes.CDLL("liblz4.so.1")
    lib.LZ4_decompress_safe.argtypes = [
        ctypes.c_void_p,
        ctypes.c_void_p,
        ctypes.c_int,
        ctypes.c_int,
    ]
    lib.LZ4_decompress_safe.restype = ctypes.c_int
    lib.LZ4_compressBound.argtypes = [ctypes.c_int]
    lib.LZ4_compressBound.restype = ctypes.c_int
    lib.LZ4_compress_HC.argtypes = [
        ctypes.c_void_p,
        ctypes.c_void_p,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_int,
    ]
    lib.LZ4_compress_HC.restype = ctypes.c_int
    return lib


def parse_header(blob):
    if len(blob) < HEADER_SIZE or blob[:4] != MAGIC or blob[0x5C:0x60] != MAGIC:
        raise ValueError("not an Amlogic LZ4C image")
    header_size = struct.unpack_from("<H", blob, 6)[0]
    raw_size, compressed_size = struct.unpack_from("<II", blob, 8)
    if header_size != HEADER_SIZE:
        raise ValueError(f"unsupported header size: {header_size:#x}")
    if HEADER_SIZE + compressed_size > len(blob):
        raise ValueError("compressed payload extends past input")
    return raw_size, compressed_size


def unpack(source, output):
    blob = source.read_bytes()
    raw_size, compressed_size = parse_header(blob)
    compressed = blob[HEADER_SIZE:HEADER_SIZE + compressed_size]
    destination = ctypes.create_string_buffer(raw_size)
    source_buffer = ctypes.create_string_buffer(compressed)
    written = load_lz4().LZ4_decompress_safe(
        source_buffer, destination, compressed_size, raw_size
    )
    if written != raw_size:
        raise ValueError(f"LZ4 decompression returned {written}, expected {raw_size}")
    raw = destination.raw[:written]
    expected = blob[0x10:0x30]
    actual = hashlib.sha256(raw).digest()
    if actual != expected:
        raise ValueError("uncompressed payload SHA-256 mismatch")
    output.write_bytes(raw)
    print(f"unpacked={written} sha256={actual.hex()}")


def pack(source, template, output):
    raw = source.read_bytes()
    template_blob = template.read_bytes()
    parse_header(template_blob)
    lib = load_lz4()
    capacity = lib.LZ4_compressBound(len(raw))
    source_buffer = ctypes.create_string_buffer(raw)
    destination = ctypes.create_string_buffer(capacity)
    compressed_size = lib.LZ4_compress_HC(
        source_buffer, destination, len(raw), capacity, 12
    )
    if compressed_size <= 0:
        raise ValueError(f"LZ4 compression returned {compressed_size}")

    header = bytearray(template_blob[:HEADER_SIZE])
    struct.pack_into("<II", header, 8, len(raw), compressed_size)
    header[0x10:0x30] = hashlib.sha256(raw).digest()
    header[0x60:0x80] = hashlib.sha256(header[:0x60]).digest()
    blob = bytes(header) + destination.raw[:compressed_size]
    padded_size = (len(blob) + ALIGNMENT - 1) & ~(ALIGNMENT - 1)
    blob += bytes(padded_size - len(blob))
    output.write_bytes(blob)
    print(
        f"raw={len(raw)} compressed={compressed_size} padded={padded_size} "
        f"sha256={hashlib.sha256(blob).hexdigest()}"
    )


def main():
    parser = argparse.ArgumentParser(description="Pack and unpack Amlogic LZ4C BL33 images")
    subparsers = parser.add_subparsers(dest="command", required=True)

    unpack_parser = subparsers.add_parser("unpack")
    unpack_parser.add_argument("source", type=Path)
    unpack_parser.add_argument("output", type=Path)

    pack_parser = subparsers.add_parser("pack")
    pack_parser.add_argument("source", type=Path)
    pack_parser.add_argument("template", type=Path)
    pack_parser.add_argument("output", type=Path)

    args = parser.parse_args()
    if args.command == "unpack":
        unpack(args.source, args.output)
    else:
        pack(args.source, args.template, args.output)


if __name__ == "__main__":
    main()

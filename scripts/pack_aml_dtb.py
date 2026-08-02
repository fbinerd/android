import struct

def main():
    dtb_in = "/media/dados_2tb/android/target/linux/amlogic/s905w/aquario-stv3000/prebuilts/aquario-performance-v69.dtb"
    dtb_out = "/media/dados_2tb/android/out/aquario-stv3000/multi_dtb.img"
    
    with open(dtb_in, "rb") as f:
        dtb_data = f.read()
        
    variants = [b"gxl_p281_1g", b"gxl_p281_2g", b"gxl_p281_8g", b"gxl_p281_v1"]
    
    magic = b"AML_DTB\x00"
    version = 1
    count = len(variants)
    
    header = magic + struct.pack("<II", version, count)
    
    # 48 bytes header + count * 32 bytes entry table
    offset_start = 16 + count * 32
    
    entries = b""
    for i, var in enumerate(variants):
        name_buf = var.ljust(16, b"\x00")
        offset = offset_start
        size = len(dtb_data)
        entries += name_buf + struct.pack("<II", offset, size) + b"\x00" * 8
        
    multi_dtb = header + entries + dtb_data
    
    with open(dtb_out, "wb") as f:
        f.write(multi_dtb)
        
    print(f"✨ Multi-DTB universal Amlogic gerado em {dtb_out} ({count} variantes: {len(multi_dtb)} bytes)")

if __name__ == "__main__":
    main()

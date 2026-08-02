import struct

def main():
    mbr = bytearray(512)
    
    # Signature MBR 0xAA55
    mbr[510] = 0x55
    mbr[511] = 0xAA
    
    # Partição 1: FAT16 LBA (Type 0x0E)
    # Start Sector: 2048 (0x800), Size: 131072 sectors (64MB)
    part1 = struct.pack("<BBBBBBBBII",
        0x80,       # Status: Active / Bootable
        0x00, 0x01, 0x01, # CHS Start
        0x0E,       # Type: FAT16 LBA
        0x00, 0x00, 0x00, # CHS End
        2048,       # Start LBA Sector (1MB offset)
        131072      # Sector count (64MB)
    )
    
    # Partição 2: Linux Boot (Type 0x83)
    # Start Sector: 133120, Size: 32768 sectors (16MB)
    part2 = struct.pack("<BBBBBBBBII",
        0x00,       # Status: Inactive
        0x00, 0x00, 0x00, # CHS Start
        0x83,       # Type: Linux
        0x00, 0x00, 0x00, # CHS End
        133120,     # Start LBA Sector (65MB offset)
        32768       # Sector count (16MB)
    )
    
    mbr[0x1BE:0x1BE+16] = part1
    mbr[0x1CE:0x1CE+16] = part2
    
    out_file = "/media/dados_2tb/android/out/aquario-stv3000/sd_mbr.img"
    with open(out_file, "wb") as f:
        f.write(mbr)
        
    print(f"✨ MBR MPT FAT16 gerada em {out_file}")

if __name__ == "__main__":
    main()

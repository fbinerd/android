#!/usr/bin/env python3
import struct
import sys
import os
import time

def decode_prop(b):
    res = ""
    for i in range(0, len(b), 4):
        chunk = b[i:i+4]
        res += chunk[::-1].decode("utf-8", errors="ignore")
    return res.strip()

def encode_prop(s, length=16):
    s_padded = s.ljust(length, " ")
    res = b""
    for i in range(0, length, 4):
        chunk = s_padded[i:i+4]
        res += chunk[::-1].encode("utf-8")
    return res

def unpack_multi_dtb(file_path, out_dir):
    print(f"Descompactando multi-dtb: {file_path}")
    with open(file_path, "rb") as f:
        data = f.read()
        
    # Se o arquivo foi lido da partição eMMC com footer, podemos extrair os primeiros bytes AML_
    if data[:4] != b"AML_":
        print("Aviso: Primeiro bloco não começa com AML_. Procurando...")
        # Pode ser que estejamos lendo o bloco de partição inteiro (256K ou 512K)
        # Vamos verificar se a assinatura AML_ está no início.
        if len(data) >= 262144:
            print("Tentando extrair do primeiro bloco de 256KB...")
            data = data[:262144 - 16]
            if data[:4] != b"AML_":
                print("Erro: Não foi possível encontrar a assinatura AML_")
                return False
        else:
            print("Erro: Arquivo inválido")
            return False
        
    version, count = struct.unpack_from("<II", data, 4)
    print(f"Versão do cabeçalho: {version}")
    print(f"Quantidade de DTBs: {count}")
    
    if version == 1:
        prop_len = 4
    elif version == 2:
        prop_len = 16
    else:
        print(f"Erro: Versão {version} não suportada")
        return False
        
    os.makedirs(out_dir, exist_ok=True)
    entry_len = prop_len * 3 + 8
    
    for i in range(count):
        entry_offset = 12 + entry_len * i
        entry_data = data[entry_offset : entry_offset + entry_len]
        
        soc = decode_prop(entry_data[:prop_len])
        platform = decode_prop(entry_data[prop_len:prop_len*2])
        variant = decode_prop(entry_data[prop_len*2:prop_len*3])
        
        dtb_offset, dtb_size = struct.unpack_from("<II", entry_data, prop_len*3)
        
        print(f"DTB {i}: SOC='{soc}', Platform='{platform}', Variant='{variant}', Offset={hex(dtb_offset)}, Size={dtb_size} bytes")
        
        dtb_content = data[dtb_offset : dtb_offset + dtb_size]
        out_file = os.path.join(out_dir, f"dtb_{i}_{soc}_{platform}_{variant}.dtb")
        with open(out_file, "wb") as out_f:
            out_f.write(dtb_content)
        print(f"  [Salvo] -> {out_file}")
        
    return True

def pack_multi_dtb(dtb_list, out_file_path, version=2):
    print(f"Empacotando {len(dtb_list)} DTBs...")
    
    if version == 1:
        prop_len = 4
    elif version == 2:
        prop_len = 16
    else:
        print(f"Erro: Versão {version} inválida")
        return False
        
    header_magic = b"AML_"
    count = len(dtb_list)
    header = struct.pack("<4sII", header_magic, version, count)
    
    entry_len = prop_len * 3 + 8
    entries_area_size = entry_len * count
    first_dtb_offset = 12 + entries_area_size
    
    def align(val, alignment=2048):
        return ((val + alignment - 1) // alignment) * alignment
        
    first_dtb_offset = align(first_dtb_offset)
    current_offset = first_dtb_offset
    entries_binary = b""
    dtbs_binary = b""
    
    for item in dtb_list:
        with open(item['file'], "rb") as f:
            dtb_content = f.read()
            
        dtb_size = len(dtb_content)
        
        soc_bytes = encode_prop(item['soc'], prop_len)
        plat_bytes = encode_prop(item['platform'], prop_len)
        var_bytes = encode_prop(item['variant'], prop_len)
        
        entry = struct.pack(f"<{prop_len}s{prop_len}s{prop_len}sII", 
                            soc_bytes, plat_bytes, var_bytes, 
                            current_offset, dtb_size)
        entries_binary += entry
        
        dtbs_binary += dtb_content
        padding_len = align(dtb_size) - dtb_size
        dtbs_binary += b"\x00" * padding_len
        current_offset += dtb_size + padding_len
        
    padding_before_first_dtb = b"\x00" * (first_dtb_offset - len(header) - len(entries_binary))
    raw_dtb_data = header + entries_binary + padding_before_first_dtb + dtbs_binary
    
    # Agora criamos o bloco de partição de 256KB com footer e checksum
    partition_size = 262144
    if len(raw_dtb_data) > partition_size - 16:
        print(f"Erro: Dados do DTB ({len(raw_dtb_data)} bytes) excedem o limite da partição de 256KB")
        return False
        
    data_padded = raw_dtb_data.ljust(partition_size - 16, b"\x00")
    
    magic = 0x00447E41
    ver = 1
    timestamp = int(time.time())
    
    partition_bin = bytearray(data_padded + struct.pack("<III", magic, ver, timestamp))
    
    # Calcula checksum de 32 bits
    checksum = 0
    for i in range(65535):
        val, = struct.unpack_from("<I", partition_bin, i * 4)
        checksum = (checksum + val) & 0xFFFFFFFF
        
    partition_bin += struct.pack("<I", checksum)
    print(f"Calculado checksum da partição: {hex(checksum)}")
    
    # Criamos a imagem final contendo as duas cópias redundantes (512KB no total)
    final_output = bytes(partition_bin) + bytes(partition_bin)
    
    with open(out_file_path, "wb") as out_f:
        out_f.write(final_output)
        
    print(f"Imagem final de partição multi-dtb criada: {out_file_path} ({len(final_output)} bytes)")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso:")
        print("  unpack: manage_multi_dtb.py unpack <arquivo_multi_dtb> <diretorio_saida>")
        print("  pack:   manage_multi_dtb.py pack <diretorio_com_dtbs> <arquivo_saida>")
        sys.exit(1)
        
    mode = sys.argv[1]
    if mode == "unpack":
        if len(sys.argv) < 4:
            print("Uso: manage_multi_dtb.py unpack <arquivo_multi_dtb> <diretorio_saida>")
            sys.exit(1)
        unpack_multi_dtb(sys.argv[2], sys.argv[3])
    elif mode == "pack":
        if len(sys.argv) < 4:
            print("Uso: manage_multi_dtb.py pack <diretorio_com_dtbs> <arquivo_saida>")
            sys.exit(1)
        in_dir = sys.argv[2]
        out_file = sys.argv[3]
        dtb_files = [f for f in os.listdir(in_dir) if f.endswith(".dtb")]
        dtb_list = []
        for f in sorted(dtb_files):
            parts = f.replace(".dtb", "").split("_")
            if len(parts) >= 5:
                dtb_list.append({
                    'soc': parts[2],
                    'platform': parts[3],
                    'variant': parts[4],
                    'file': os.path.join(in_dir, f)
                })
        pack_multi_dtb(dtb_list, out_file)
    else:
        print(f"Modo {mode} desconhecido")

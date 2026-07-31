import socket
import time
import sys

def run_uboot_cmd(s, cmd):
    print(f"\n[U-BOOT CMD]: {cmd}")
    s.sendall(f"{cmd}\n".encode('utf-8'))
    time.sleep(1.5)
    buf = ""
    start = time.time()
    while time.time() - start < 3.0:
        try:
            chunk = s.recv(8192).decode('utf-8', errors='ignore')
            if chunk:
                buf += chunk
        except BlockingIOError:
            time.sleep(0.1)
    print(buf)
    return buf

def main():
    print("==========================================================")
    print("   INSPEÇÃO E TESTE DE BOOT MANUTENÇÃO U-BOOT (SD CARD)")
    print("==========================================================")
    
    try:
        s = socket.create_connection(("127.0.0.1", 31337), timeout=10)
        s.setblocking(False)
        
        # Garante prompt A95X#
        s.sendall(b"\x03\n")
        time.sleep(0.5)
        
        run_uboot_cmd(s, "mmc dev 0")
        run_uboot_cmd(s, "mmc info")
        run_uboot_cmd(s, "printenv bootcmd")
        run_uboot_cmd(s, "printenv bootargs")
        
        print("-> [TESTE 1] Tentando carregar a partição de Boot do SD card (Setor 0x2ae000)...")
        # 0x2ae000 (Setor boot) -> 0x1080000 em RAM (16MB / 32768 blocos)
        run_uboot_cmd(s, "mmc read 0x1080000 0x2ae000 0x8000")
        
        print("-> [TESTE 2] Executando bootm 0x1080000...")
        run_uboot_cmd(s, "bootm 0x1080000")
        
        # Monitora a saída do Kernel por 15 segundos
        start_k = time.time()
        while time.time() - start_k < 15.0:
            try:
                data = s.recv(8192)
                if data:
                    sys.stdout.write(data.decode('utf-8', errors='ignore'))
                    sys.stdout.flush()
            except BlockingIOError:
                time.sleep(0.1)
                
        s.close()
    except Exception as e:
        print("[ERR] Erro na comunicação U-Boot:", e)

if __name__ == "__main__":
    main()

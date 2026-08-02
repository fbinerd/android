import socket
import time
import sys

def main():
    print("==========================================================")
    print("   GRAVAÇÃO DE MULTI-DTB AMLOGIC VIA TFTP (192.168.1.2) & BOOT")
    print("==========================================================")
    
    try:
        s = socket.create_connection(("127.0.0.1", 31337), timeout=10)
        s.setblocking(False)
        
        def run_cmd(cmd, wait=2.0):
            print(f"\n[U-BOOT CMD]: {cmd}")
            s.sendall(f"{cmd}\n".encode('utf-8'))
            time.sleep(wait)
            buf = ""
            start = time.time()
            while time.time() - start < 4.0:
                try:
                    chunk = s.recv(8192).decode('utf-8', errors='ignore')
                    if chunk:
                        buf += chunk
                except BlockingIOError:
                    time.sleep(0.1)
            print(buf)
            return buf

        s.sendall(b"\x03\n")
        time.sleep(0.5)
        
        run_cmd("setenv ipaddr 192.168.1.139")
        run_cmd("setenv serverip 192.168.1.2")
        
        print("-> [1/4] Baixando multi_dtb.img do servidor TFTP 192.168.1.2 para 0x1000000...")
        run_cmd("tftp 0x1000000 multi_dtb.img")
        
        print("-> [2/4] Gravando Multi-DTB no armazenamento persistente via store dtb write...")
        run_cmd("store dtb write 0x1000000 0x40000")
        
        print("-> [3/4] Lendo imagem de boot v70 do Cartão SD (Offset 0x1a2000)...")
        run_cmd("mmc dev 0")
        run_cmd("mmc read 0x1080000 0x1a2000 0x8000")
        
        print("-> [4/4] Disparando bootm 0x1080000...")
        run_cmd("bootm 0x1080000")
        
        print("\n==========================================================")
        print("   MONITORANDO SUBIDA DO KERNEL LINUX E ANDROID 9 (v70)...")
        print("==========================================================")
        start_log = time.time()
        while time.time() - start_log < 30.0:
            try:
                data = s.recv(8192)
                if data:
                    sys.stdout.write(data.decode('utf-8', errors='ignore'))
                    sys.stdout.flush()
            except BlockingIOError:
                time.sleep(0.1)
                
        s.close()
    except Exception as e:
        print("[ERR] Erro:", e)

if __name__ == "__main__":
    main()

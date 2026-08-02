import socket
import time
import sys

def main():
    print("==========================================================")
    print("   TESTANDO CARREGAMENTO DO DTB EM 0x1000000 ANTES DO BOOTM")
    print("==========================================================")
    
    try:
        s = socket.create_connection(("127.0.0.1", 31337), timeout=10)
        s.setblocking(False)
        
        def run_cmd(cmd, wait=1.5):
            print(f"\n[U-BOOT CMD]: {cmd}")
            s.sendall(f"{cmd}\n".encode('utf-8'))
            time.sleep(wait)
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

        s.sendall(b"\x03\n")
        time.sleep(0.5)
        
        run_cmd("setenv ipaddr 192.168.1.139")
        run_cmd("setenv serverip 192.168.1.2")
        
        print("-> [1/4] Baixando _aml_dtb.img via TFTP para a RAM 0x1000000...")
        run_cmd("tftp 0x1000000 _aml_dtb.img")
        
        print("-> [2/4] Gravando DTB na eMMC (store dtb write 0x1000000)...")
        run_cmd("store dtb write 0x1000000 0x40000")
        
        print("-> [3/4] Lendo kernel do Cartão SD para 0x1080000...")
        run_cmd("mmc dev 0")
        run_cmd("mmc read 0x1080000 0x1a2000 0x8000")
        
        print("-> [4/4] Executando bootm 0x1080000...")
        s.sendall(b"bootm 0x1080000\n")
        
        print("\n==========================================================")
        print("   MONITORANDO LOGS DO BOOT DO KERNEL EM TEMPO REAL...")
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

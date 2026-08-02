import socket
import time
import sys

def main():
    print("==========================================================")
    print("   TESTANDO BOOT REAL DO SETOR EXATO DA SD CARD (0x1a2000)")
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
        run_cmd("mmc dev 0")
        
        print("-> Lendo partição de boot no setor exato 0x1a2000 (Setor 1712128)...")
        run_cmd("mmc read 0x1080000 0x1a2000 0x8000")
        
        print("-> Executando bootm 0x1080000...")
        run_cmd("bootm 0x1080000")
        
        print("\n==========================================================")
        print("   MONITORANDO SUBIDA DO KERNEL LINUX DA IMAGEM SD v70...")
        print("==========================================================")
        start_log = time.time()
        while time.time() - start_log < 25.0:
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

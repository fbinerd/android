import socket
import time
import sys

def main():
    print("==========================================================")
    print("   TESTANDO BOOT COM OFFSET REAL DO LAYOUT 32GB (0x47e000)")
    print("==========================================================")
    
    try:
        s = socket.create_connection(("127.0.0.1", 31337), timeout=10)
        s.setblocking(False)
        
        def run_cmd(cmd, wait=1.5):
            print(f"\n[U-BOOT]: {cmd}")
            s.sendall(f"{cmd}\n".encode('utf-8'))
            time.sleep(wait)
            try:
                buf = s.recv(8192).decode('utf-8', errors='ignore')
                print(buf)
                return buf
            except BlockingIOError:
                return ""

        s.sendall(b"\x03\n")
        time.sleep(0.5)
        
        # 1. Le do offset real da particao boot no layout 32GB: 0x8fc00000 / 512 = 0x47e000
        run_cmd("mmc dev 0")
        run_cmd("mmc read 0x1080000 0x47e000 0x8000")
        
        # 2. Executa bootm 0x1080000
        print("-> Executando bootm 0x1080000 com o offset correto do preset 32GB...")
        run_cmd("bootm 0x1080000")
        
        # Monitora a saída do Kernel
        start = time.time()
        while time.time() - start < 20.0:
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

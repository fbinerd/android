import socket
import time
import sys

def main():
    print("==========================================================")
    print("   TESTANDO BOOT DO KERNEL EM 0x1080800 (OFFSET DEPOIS DO CABEÇALHO ANDROID!)")
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
        
        run_cmd("mmc dev 0")
        run_cmd("mmc read 0x1080000 0x47e000 0x8000")
        
        # O cabeçalho Android! tem 2048 bytes (0x800 Hex). O Kernel Image.gz começa em 0x1080000 + 0x800 = 0x1080800!
        print("-> Executando booti 0x1080800 (Kernel descompactado/Image.gz no offset 0x800)...")
        run_cmd("booti 0x1080800")
        
        # Se booti 0x1080800 reclamar de DTB, tentamos indicar o DTB no offset
        run_cmd("bootm 0x1080000 0x1080000 0x1080000")
        
        start_log = time.time()
        while time.time() - start_log < 15.0:
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

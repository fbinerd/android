import socket
import time
import sys

def main():
    print("==========================================================")
    print("   REPARO DE DTB NO U-BOOT & AUTOBOOT SD CARD (TFTP: 192.168.1.2)")
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
        
        print("-> [1/3] Lendo Boot Image do SD Card no offset 0x1a2000...")
        run_cmd("mmc dev 0")
        run_cmd("mmc read 0x1080000 0x1a2000 0x8000")
        
        print("-> [2/3] Copiando DTB para 0x1000000 e gravando no DTB do U-Boot...")
        run_cmd("cp.b 0x1ea7000 0x1000000 0x40000")
        run_cmd("store dtb write 0x1000000 0x40000")
        
        print("-> [3/3] Disparando bootm 0x1080000...")
        run_cmd("bootm 0x1080000")
        
        print("\n==========================================================")
        print("   MONITORANDO INICIALIZAÇÃO COMPLETA DO ANDROID 9...")
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

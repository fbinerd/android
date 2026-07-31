import socket
import time
import sys

def main():
    print("==========================================================")
    print("   INSPEÇÃO DE COMANDOS DO U-BOOT (SD CARD BOOT)")
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
        
        run_cmd("help")
        run_cmd("mmc dev 0")
        run_cmd("mmc read 0x1080000 0x47e000 0x8000")
        
        # Testes de boot do Android Image
        run_cmd("booti 0x1080000")
        run_cmd("bootm 0x1080000")
        
        s.close()
    except Exception as e:
        print("[ERR] Erro:", e)

if __name__ == "__main__":
    main()

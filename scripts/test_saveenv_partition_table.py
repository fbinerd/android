import socket
import time
import sys

def main():
    print("==========================================================")
    print("   TESTANDO SAVEENV APÓS RESTAURAÇÃO DA TABELA EMMC")
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
        
        run_cmd("setenv bootcmd 'store dtb read 0x1000000; mmc dev 0; mmc read 0x1080000 0x1a2000 0x8000; bootm 0x1080000'")
        run_cmd("saveenv")
        run_cmd("printenv bootcmd")
        
        s.close()
    except Exception as e:
        print("[ERR] Erro:", e)

if __name__ == "__main__":
    main()

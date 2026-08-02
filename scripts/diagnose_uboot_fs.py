import socket
import time

def main():
    print("==========================================================")
    print("   DIAGNÓSTICO DE COMANDOS DE FILESYSTEM NO U-BOOT")
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
        run_cmd("fatls mmc 0")
        run_cmd("fatls mmc 0:1")
        run_cmd("fatls mmc 0:2")
        run_cmd("fatls mmc 0:boot_fat")
        run_cmd("ls mmc 0:1")
        run_cmd("fstype mmc 0:1")
        run_cmd("printenv recovery_from_sdcard")
        run_cmd("printenv bootcmd")
        
        s.close()
    except Exception as e:
        print("[ERR] Erro:", e)

if __name__ == "__main__":
    main()

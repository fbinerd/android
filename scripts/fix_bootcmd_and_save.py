import socket
import time
import sys

def main():
    print("==========================================================")
    print("   GRAVANDO BOOTCMD DEFINITIVO NA AMBIENTE U-BOOT DO SOC")
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
        
        run_cmd("setenv bootcmd 'mmc dev 0; mmc read 0x1080000 0x1a2000 0x8000; bootm 0x1080000'")
        run_cmd("saveenv")
        run_cmd("printenv bootcmd")
        
        print("\n-> Testando inicialização com o novo bootcmd...")
        run_cmd("run bootcmd")
        
        print("\n==========================================================")
        print("   MONITORANDO LOGS DO KERNEL ANDROID 9 (v70)...")
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

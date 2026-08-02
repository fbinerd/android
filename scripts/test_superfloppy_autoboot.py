import socket
import time
import sys

def main():
    print("==========================================================")
    print("   TESTANDO AUTOBOOT SUPERFLOPPY (SETOR 0) NO U-BOOT")
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
        
        print("-> [1/3] Baixando e gravando FAT superfloppy no setor 0 do SD...")
        run_cmd("tftp 0x1000000 sd_superfloppy.img", wait=6.0)
        run_cmd("mmc dev 0")
        run_cmd("mmc write 0x1000000 0 0x20000", wait=5.0)
        
        print("-> [2/3] Reiniciando MMC e testando fatls mmc 0...")
        run_cmd("mmc dev 0")
        run_cmd("fatls mmc 0")
        
        print("-> [3/3] Executando fatload mmc 0 0x1080000 aml_autoscript...")
        run_cmd("fatload mmc 0 0x1080000 aml_autoscript")
        run_cmd("autoscr 0x1080000")
        
        print("\n==========================================================")
        print("   MONITORANDO LOGS DO AUTOBOOT SD CARD...")
        print("==========================================================")
        start_log = time.time()
        while time.time() - start_log < 20.0:
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

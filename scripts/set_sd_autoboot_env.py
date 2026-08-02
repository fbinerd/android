import socket
import time
import sys

def main():
    print("==========================================================")
    print("   CONFIGURANDO AUTOBOOT DEFINITIVO NO SD CARD VIA U-BOOT")
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
        
        print("-> [1/3] Definindo bootcmd para boot direto do Cartão SD (setor 0x1a2000)...")
        run_cmd("setenv bootcmd 'mmc dev 0; mmc read 0x1080000 0x1a2000 0x8000; bootm 0x1080000'")
        
        print("-> [2/3] Salvando variáveis no ambiente do U-Boot (saveenv)...")
        run_cmd("saveenv")
        
        print("-> [3/3] Reiniciando placa (reset) para testar AUTOBOOT COLD REBOOT...")
        s.sendall(b"reset\n")
        
        print("\n==========================================================")
        print("   MONITORANDO BOOT AUTOMÁTICO COMPLETO DO KERNEL...")
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

import socket
import time
import sys

def main():
    print("==========================================================")
    print("   CONFIGURANDO AUTOBOOT DEFINITIVO NA EMMC E TESTANDO RESET")
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
        
        print("-> [1/4] Gravando DTB de compatibilidade na eMMC...")
        run_cmd("tftp 0x1000000 _aml_dtb.img")
        run_cmd("store dtb write 0x1000000 0x40000")
        
        print("-> [2/4] Definindo bootargs e bootcmd para autoboot direto do SD...")
        run_cmd("setenv bootcmd 'mmc dev 0; mmc read 0x1000000 0x8000 0x800; mmc read 0x1080000 0x1a2000 0x8000; bootm 0x1080000'")
        
        print("-> [3/4] Salvando variáveis de ambiente (saveenv)...")
        run_cmd("saveenv")
        
        print("-> [4/4] Enviando 'reset' para testar se liga sozinho sem parar no prompt...")
        s.sendall(b"reset\n")
        
        print("\n==========================================================")
        print("   MONITORANDO LOGS DO COLD BOOT AUTOMÁTICO...")
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

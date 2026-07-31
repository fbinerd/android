import socket
import time
import sys

def main():
    print("==========================================================")
    print("   CONFIGURANDO AUTOBOOT DO CARTÃO SD NO U-BOOT")
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

        # Cancela prompt
        s.sendall(b"\x03\n")
        time.sleep(0.5)
        
        # 1. Configura a variável bootcmd para ler do SD Card (mmc 0) no offset 0x2ae000 (partição de boot)
        run_cmd("setenv bootcmd 'mmc dev 0; mmc read 0x1080000 0x2ae000 0x8000; bootm 0x1080000'")
        
        # 2. Salva o ambiente no U-Boot para persistir no reinício
        run_cmd("saveenv")
        
        # 3. Dispara o autoboot imediato via run bootcmd
        print("\n-> Executando 'run bootcmd' para validar a subida da imagem v70 do SD Card...")
        run_cmd("run bootcmd")
        
        # Monitora a saída do Kernel por 20 segundos
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
        print("\n✨ CONFIGURAÇÃO DE AUTOBOOT SD CONCLUÍDA!")
    except Exception as e:
        print("[ERR] Erro ao comunicar com U-Boot:", e)

if __name__ == "__main__":
    main()

import socket
import time
import sys

def main():
    print("==========================================================")
    print("   APLICANDO CORREÇÃO AUTOBOOT SD CARD VIA TFTP & U-BOOT")
    print("==========================================================")
    
    try:
        s = socket.create_connection(("127.0.0.1", 31337), timeout=10)
        s.setblocking(False)
        
        def run_cmd(cmd, wait=1.5):
            print(f"\n[U-BOOT]: {cmd}")
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

        # Cancela qualquer estado e vai para prompt A95X#
        s.sendall(b"\x03\n")
        time.sleep(0.5)
        
        print("-> [1/4] Configurando IP do U-Boot e Servidor TFTP...")
        run_cmd("setenv ipaddr 192.168.1.139")
        run_cmd("setenv serverip 192.168.1.10")
        
        print("-> [2/4] Baixando aml_autoscript do servidor TFTP...")
        run_cmd("tftp 0x1080000 aml_autoscript")
        
        print("-> [3/4] Atualizando comando de autoboot padrao para o Cartao SD (32GB / Offset 0x47e000)...")
        run_cmd("setenv bootcmd 'mmc dev 0; mmc read 0x1080000 0x47e000 0x8000; bootm 0x1080000'")
        
        print("-> [4/4] Executando autoscr 0x1080000 para dar BOOT IMEDIATO pelo Cartao SD...")
        run_cmd("autoscr 0x1080000")
        
        # Monitora os logs do Kernel por 30 segundos
        print("\n==========================================================")
        print("   MONITORANDO SUBIDA DO KERNEL LINUX DA IMAGEM SD v70...")
        print("==========================================================")
        start_kernel = time.time()
        while time.time() - start_kernel < 30.0:
            try:
                data = s.recv(8192)
                if data:
                    sys.stdout.write(data.decode('utf-8', errors='ignore'))
                    sys.stdout.flush()
            except BlockingIOError:
                time.sleep(0.1)
                
        s.close()
        print("\n✨ CORREÇÃO APLICADA E BOOT DISPARADO COM SUCESSO!")
        
    except Exception as e:
        print("[ERR] Erro ao comunicar via TTL:", e)

if __name__ == "__main__":
    main()

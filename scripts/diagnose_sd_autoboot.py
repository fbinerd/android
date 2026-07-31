import socket
import time
import sys

def main():
    print("==========================================================")
    print("   DIAGNÓSTICO DE AUTOBOOT DA TV BOX (SERIAL TTL)")
    print("==========================================================")
    
    try:
        s = socket.create_connection(("127.0.0.1", 31337), timeout=10)
        s.setblocking(False)
        
        # Envia Enter para obter prompt atual
        s.sendall(b"\n")
        time.sleep(1.0)
        
        # Lê a saída atual do console
        buffer = ""
        start = time.time()
        while time.time() - start < 5.0:
            try:
                data = s.recv(8192)
                if data:
                    chunk = data.decode("utf-8", errors="ignore")
                    buffer += chunk
            except BlockingIOError:
                time.sleep(0.1)
                
        print("\n--- [SAÍDA DO CONSOLE SERIAL CURRENT STATE] ---")
        print(buffer if buffer.strip() else "[Sem dados novos na serial - Enviando reboot para capturar boot sequence]")
        
        # Dispara reboot ou consulta uboot env se estiver no u-boot
        print("\n-> [1/2] Enviando sinal de reboot no console...")
        s.sendall(b"\x03reboot\n")
        
        # Monitora a saída durante o boot inicial (15 segundos)
        print("-> [2/2] Capturando logs de boot do U-Boot e inicialização...")
        start_log = time.time()
        boot_log = ""
        while time.time() - start_log < 15.0:
            try:
                data = s.recv(8192)
                if data:
                    chunk = data.decode("utf-8", errors="ignore")
                    boot_log += chunk
                    sys.stdout.write(chunk)
                    sys.stdout.flush()
            except BlockingIOError:
                time.sleep(0.1)
                
        s.close()
        
    except Exception as e:
        print("[ERR] Erro ao conectar no broker TTL:", e)

if __name__ == "__main__":
    main()

import socket
import time
import sys

def main():
    print("==========================================================")
    print("   CAPTURANDO LOG DE BOOT EM TEMPO REAL DA SERIAL TTL")
    print("==========================================================")
    
    try:
        s = socket.create_connection(("127.0.0.1", 31337), timeout=10)
        s.setblocking(False)
        
        # Envia ENTER / reset para ver o prompt ou logs atuais
        s.sendall(b"\n")
        
        buf = ""
        start = time.time()
        while time.time() - start < 15.0:
            try:
                data = s.recv(8192)
                if data:
                    chunk = data.decode('utf-8', errors='ignore')
                    buf += chunk
                    sys.stdout.write(chunk)
                    sys.stdout.flush()
            except BlockingIOError:
                time.sleep(0.1)
                
        print("\n==========================================================")
        print("   RESUMO DA CAPTURA:")
        print("==========================================================")
        s.close()
    except Exception as e:
        print("[ERR] Erro na conexão serial:", e)

if __name__ == "__main__":
    main()

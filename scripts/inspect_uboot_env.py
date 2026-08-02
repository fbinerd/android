import socket
import time
import sys

def main():
    print("==========================================================")
    print("   INSPEÇÃO COMPLETA DAS VARIÁVEIS DE AMBIENTE DO U-BOOT")
    print("==========================================================")
    
    try:
        s = socket.create_connection(("127.0.0.1", 31337), timeout=10)
        s.setblocking(False)
        
        s.sendall(b"\x03\n")
        time.sleep(0.5)
        
        s.sendall(b"printenv\n")
        time.sleep(3.0)
        
        buf = ""
        start = time.time()
        while time.time() - start < 5.0:
            try:
                data = s.recv(8192)
                if data:
                    chunk = data.decode('utf-8', errors='ignore')
                    buf += chunk
            except BlockingIOError:
                time.sleep(0.1)
                
        print(buf)
        s.close()
    except Exception as e:
        print("[ERR] Erro:", e)

if __name__ == "__main__":
    main()

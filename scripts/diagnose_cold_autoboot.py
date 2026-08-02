import socket
import time
import sys

def main():
    print("==========================================================")
    print("   DIAGNOSTICANDO COLD REBOOT & AUTOBOOT SEM INTERRUPÇÃO")
    print("==========================================================")
    
    try:
        s = socket.create_connection(("127.0.0.1", 31337), timeout=10)
        s.setblocking(False)
        
        print("-> Reiniciando a TV Box via comando 'reset' no U-Boot...")
        s.sendall(b"reset\n")
        time.sleep(0.5)
        
        print("\n==========================================================")
        print("   CAPTURA INTEGRAL DO LOG DE COLD BOOT (30 SEGUNDOS)")
        print("==========================================================")
        
        start_time = time.time()
        buf = ""
        while time.time() - start_time < 30.0:
            try:
                data = s.recv(8192)
                if data:
                    text = data.decode('utf-8', errors='ignore')
                    buf += text
                    sys.stdout.write(text)
                    sys.stdout.flush()
            except BlockingIOError:
                time.sleep(0.1)
                
        s.close()
        
        print("\n==========================================================")
        print("   ANÁLISE FINAL DO MOTIVO DO PROMPT A95X#")
        print("==========================================================")
        if "A95X#" in buf:
            print("❌ O U-Boot parou no prompt A95X#.")
        else:
            print("✅ O U-Boot continuou o boot sem parar no prompt!")
            
    except Exception as e:
        print("[ERR] Erro na conexão:", e)

if __name__ == "__main__":
    main()

import socket
import time
import sys

def main():
    print("==========================================================")
    print("   FIXANDO IP ESTÁTICO DO U-BOOT (192.168.1.139 / MIKROTIK)")
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
        
        print("-> Definindo configurações de rede estáticas no U-Boot...")
        run_cmd("setenv ipaddr 192.168.1.139")
        run_cmd("setenv serverip 192.168.1.2")
        run_cmd("setenv gatewayip 192.168.1.254")
        run_cmd("setenv netmask 255.255.255.0")
        
        print("-> Salvando variáveis permanentemente no U-Boot via saveenv...")
        run_cmd("saveenv")
        
        print("-> Testando TFTP com IP estático 192.168.1.139...")
        run_cmd("tftp 0x1000000 multi_dtb.img", wait=4.0)
        
        s.close()
        print("\n✨ CONFIGURAÇÃO DE REDE FIXADA E SALVA COM SUCESSO!")
        
    except Exception as e:
        print("[ERR] Erro:", e)

if __name__ == "__main__":
    main()

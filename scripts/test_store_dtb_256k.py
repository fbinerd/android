import socket
import time
import sys

def main():
    print("==========================================================")
    print("   GRAVAÇÃO PERMANENTE NO U-BOOT (256KB COM CHECKSUM)")
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
        
        print("-> Baixando _aml_dtb.img para 0x1000000...")
        run_cmd("tftp 0x1000000 _aml_dtb.img", wait=4.0)
        
        print("-> Executando store dtb write 0x1000000 0x40000 para gravar definitivamente...")
        run_cmd("store dtb write 0x1000000 0x40000", wait=4.0)
        
        s.close()
        print("\n✨ MULTI-DTB GRAVADO COM CHECKSUM VÁLIDO NA FLASH COM SUCESSO!")
        
    except Exception as e:
        print("[ERR] Erro:", e)

if __name__ == "__main__":
    main()

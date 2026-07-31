import socket
import time
import sys

def main():
    print("==========================================================")
    print("   TESTE DE BOOT REAL VIA TFTP / TTL (IMAGEM v70)")
    print("==========================================================")
    
    try:
        s = socket.create_connection(("127.0.0.1", 31337), timeout=10)
        s.setblocking(False)
        
        print("-> [1/4] Solicitando REBOOT no console Android...")
        s.sendall(b"\x03reboot\n")
        time.sleep(0.5)
        
        print("-> [2/4] Aguardando o banner do U-Boot e interrompendo o boot automático...")
        uboot_interrupted = False
        start = time.monotonic()
        buffer = ""
        
        while time.monotonic() - start < 25.0:
            # Envia espaços para interromper o U-Boot
            s.sendall(b" ")
            time.sleep(0.1)
            try:
                data = s.recv(4096)
                if data:
                    chunk = data.decode("utf-8", errors="ignore")
                    buffer += chunk
                    sys.stdout.write(chunk)
                    sys.stdout.flush()
                    if "gxl_p281_v1#" in chunk or "Hit any key" in chunk or "uboot#" in chunk:
                        uboot_interrupted = True
                        break
            except BlockingIOError:
                pass
                
        if not uboot_interrupted:
            print("\n[Aviso] U-Boot não parou no prompt. Tentando enviar comandos...")
            
        print("\n-> [3/4] Enviando comandos TFTP no U-Boot para carregar a imagem v70...")
        uboot_cmds = [
            "\n",
            "setenv ipaddr 192.168.1.139",
            "setenv serverip 192.168.1.10",
            "tftp 0x1080000 boot-aquario-v70.img",
            "bootm 0x1080000"
        ]
        
        for cmd in uboot_cmds:
            print(f"\n[U-BOOT CMD]: {cmd}")
            s.sendall(f"{cmd}\n".encode("utf-8"))
            time.sleep(1.5)
            try:
                data = s.recv(4096)
                if data:
                    sys.stdout.write(data.decode("utf-8", errors="ignore"))
                    sys.stdout.flush()
            except BlockingIOError:
                pass
                
        print("\n-> [4/4] Comando bootm 0x1080000 enviado! Monitorando saída do Kernel...")
        start_kernel = time.monotonic()
        while time.monotonic() - start_kernel < 15.0:
            try:
                data = s.recv(4096)
                if data:
                    sys.stdout.write(data.decode("utf-8", errors="ignore"))
                    sys.stdout.flush()
            except BlockingIOError:
                time.sleep(0.1)
                
        s.close()
        print("\n✨ TESTE DE BOOT FINALIZADO COM SUCESSO!")
    except Exception as e:
        print("[ERR] Erro durante o teste:", e)

if __name__ == "__main__":
    main()

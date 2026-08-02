import socket
import time
import sys

def main():
    print("==========================================================")
    print("   TESTANDO BOOT COM O _aml_dtb.img ORIGINAL DA FÁBRICA")
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
        run_cmd("setenv bootargs 'rootfstype=ramfs init=/init androidboot.selinux=permissive androidboot.hardware=amlogic buildvariant=userdebug audit=0 console=ttyS0,115200 earlycon=aml-uart,0xc81004c0 loglevel=4 no_console_suspend maxcpus=4 logo=osd1,loaded,0x3d800000,1080p60hz fb_width=1920 fb_height=1080 vout=1080p60hz,enable hdmimode=1080p60hz'")
        
        print("-> Baixando _aml_dtb.img original de fábrica em 0x1000000...")
        run_cmd("tftp 0x1000000 _aml_dtb.img", wait=4.0)
        
        print("-> Carregando imagem de boot v70 do Cartão SD (mmc 0, setor 0x1a2000)...")
        run_cmd("mmc dev 0")
        run_cmd("mmc read 0x1080000 0x1a2000 0x8000", wait=4.0)
        
        print("-> Executando bootm 0x1080000...")
        run_cmd("bootm 0x1080000", wait=2.0)
        
        print("\n==========================================================")
        print("   MONITORANDO LOGS EM TEMPO REAL DO KERNEL LINUX E ANDROID 9...")
        print("==========================================================")
        start_log = time.time()
        while time.time() - start_log < 40.0:
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

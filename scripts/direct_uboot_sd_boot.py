import socket
import time
import sys

def main():
    print("==========================================================")
    print("   BOOT DIRETO DA IMAGEM SD 32GB (OFFSET 0x47e000)")
    print("==========================================================")
    
    try:
        s = socket.create_connection(("127.0.0.1", 31337), timeout=10)
        s.setblocking(False)
        
        def run_cmd(cmd, wait=1.0):
            print(f"\n[U-BOOT]: {cmd}")
            s.sendall(f"{cmd}\n".encode('utf-8'))
            time.sleep(wait)
            buf = ""
            start = time.time()
            while time.time() - start < 2.0:
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
        
        run_cmd("setenv bootargs 'rootfstype=ramfs init=/init androidboot.selinux=permissive androidboot.hardware=amlogic buildvariant=userdebug audit=0 console=ttyS0,115200 earlycon=aml-uart,0xc81004c0 loglevel=4 no_console_suspend maxcpus=4 logo=osd1,loaded,0x3d800000,1080p60hz fb_width=1920 fb_height=1080 vout=1080p60hz,enable hdmimode=1080p60hz'")
        run_cmd("mmc dev 0")
        run_cmd("mmc read 0x1080000 0x47e000 0x8000")
        run_cmd("bootm 0x1080000")
        
        print("\n==========================================================")
        print("   MONITORANDO INICIALIZAÇÃO DO KERNEL LINUX v70...")
        print("==========================================================")
        start_k = time.time()
        while time.time() - start_k < 20.0:
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

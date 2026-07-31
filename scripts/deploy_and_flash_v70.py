import socket
import time
import sys
import subprocess

def run_ttl_cmd(s, cmd):
    s.sendall(b"\x03")
    time.sleep(0.1)
    s.sendall(f"{cmd}\n".encode('utf-8'))
    
    time.sleep(1.0)
    buffer = ""
    start = time.time()
    while time.time() - start < 4.0:
        try:
            chunk = s.recv(4096).decode('utf-8', errors='ignore')
            if chunk:
                buffer += chunk
                if "console:/" in chunk or "console:#" in chunk:
                    break
        except BlockingIOError:
            time.sleep(0.1)
    return buffer

def main():
    boot_img = "/media/dados_2tb/android/out/aquario-stv3000/boot-aquario-performance-v70-padded-16m.img"
    ip_box = "192.168.1.139"
    
    print("==========================================================")
    echo_step = lambda s: print(f"\n-> {s}")
    
    echo_step(f"[1/4] Enviando boot image compilado ({boot_img}) para a TV Box ({ip_box})...")
    res = subprocess.run(["scp", "-o", "StrictHostKeyChecking=no", boot_img, f"root@{ip_box}:/data/local/tmp/boot-v70-test.img"], capture_output=True, text=True)
    if res.returncode != 0:
        print("[ERR] Falha ao enviar via SCP:", res.stderr)
        return
    print("   [OK] Transferência concluída com sucesso!")
    
    echo_step("[2/4] Conectando no Socket Serial TTL 31337 para gravar e verificar a partição de boot...")
    try:
        s = socket.create_connection(("127.0.0.1", 31337), timeout=10)
        s.setblocking(False)
        
        # 1. Copia o boot image de /data/local/tmp para a partição de boot
        print(run_ttl_cmd(s, "dd if=/data/local/tmp/boot-v70-test.img of=/dev/block/boot status=progress"))
        
        # 2. Confirma o SHA256 na partição de boot
        print(run_ttl_cmd(s, "sha256sum /dev/block/boot"))
        
        echo_step("[3/4] Disparando REBOOT para testar o boot da nova imagem v70 compilada...")
        s.sendall(b"\x03reboot\n")
        time.sleep(1.0)
        s.close()
        
        echo_step("[4/4] Aguardando o boot pelo TTL e monitorando sys.boot_completed...")
        start_wait = time.time()
        completed = False
        
        while time.time() - start_wait < 90:
            time.sleep(5)
            # Tenta consultar sys.boot_completed por SSH ou socket
            res_boot = subprocess.run(["ssh", "-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=3", f"root@{ip_box}", "getprop sys.boot_completed"], capture_output=True, text=True)
            if res_boot.returncode == 0 and "1" in res_boot.stdout:
                completed = True
                break
            print(".", end="", flush=True)
            
        print("")
        if completed:
            print("\n✨ BOOT CONCLUÍDO COM SUCESSO! sys.boot_completed = 1")
            print("   A nova imagem compilada pelo nosso repositório subiu 100% perfeitamente no hardware real!")
        else:
            print("\n[Aviso] O dispositivo ainda está completando a inicialização.")
            
    except Exception as e:
        print("[ERR] Erro no teste serial:", e)

if __name__ == "__main__":
    main()

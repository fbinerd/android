import socket
import time
import sys
import os
import threading

def http_server():
    import http.server
    import socketserver
    os.chdir("/media/dados_2tb/android/out/aquario-stv3000")
    handler = http.server.SimpleHTTPRequestHandler
    with socketserver.TCPServer(("0.0.0.0", 8080), handler) as httpd:
        httpd.serve_forever()

def main():
    print("==========================================================")
    print("   GRAVAÇÃO DIRETA NO HARDWARE (BOOT PARTITION v70)")
    print("==========================================================")
    
    # Inicia servidor HTTP local em segundo plano na porta 8080
    t = threading.Thread(target=http_server, daemon=True)
    t.start()
    time.sleep(1.0)
    print("-> Servidor HTTP local ativo em http://192.168.1.10:8080/")
    
    try:
        s = socket.create_connection(("127.0.0.1", 31337), timeout=10)
        s.setblocking(False)
        
        def send_cmd(cmd, wait=1.5):
            print(f"\n[TTL RUN]: {cmd}")
            s.sendall(f"{cmd}\n".encode('utf-8'))
            time.sleep(wait)
            try:
                buf = s.recv(8192).decode('utf-8', errors='ignore')
                print(buf)
                return buf
            except BlockingIOError:
                return ""

        print("-> [1/4] Acordando o Android pelo console serial TTL...")
        s.sendall(b"\x03\n\ninput keyevent 26\n")
        time.sleep(1.0)
        
        print("-> [2/4] Elevando privilégios para ROOT e configurando rede eth0...")
        send_cmd("su")
        send_cmd("ifconfig eth0 192.168.1.139 netmask 255.255.255.0 up")
        send_cmd("ip route add default via 192.168.1.1 dev eth0 2>/dev/null || true")
        
        print("-> [3/4] Baixando e Gravando boot-aquario-performance-v70-padded-16m.img diretamente em /dev/block/boot...")
        send_cmd("curl -s http://192.168.1.10:8080/boot-aquario-performance-v70-padded-16m.img -o /data/local/tmp/boot_v70.img || wget http://192.168.1.10:8080/boot-aquario-performance-v70-padded-16m.img -O /data/local/tmp/boot_v70.img", wait=5.0)
        
        send_cmd("ls -lh /data/local/tmp/boot_v70.img")
        send_cmd("dd if=/data/local/tmp/boot_v70.img of=/dev/block/boot status=progress conv=fsync", wait=4.0)
        send_cmd("sha256sum /dev/block/boot /data/local/tmp/boot_v70.img")
        
        print("-> [4/4] Disparando REBOOT para testar o boot da partição gravada...")
        send_cmd("reboot", wait=1.0)
        s.close()
        
        print("\n✨ COMANDO DE GRAVAÇÃO E REBOOT ENVIADO COM SUCESSO!")
        
    except Exception as e:
        print("[ERR] Falha ao comunicar via TTL:", e)

if __name__ == "__main__":
    main()

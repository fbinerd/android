import socket
import time
import sys

def main():
    try:
        s = socket.create_connection(("127.0.0.1", 31337), timeout=5)
        s.setblocking(False)
        
        s.sendall(b"\n")
        time.sleep(0.5)
        
        buf = ""
        start = time.time()
        while time.time() - start < 3.0:
            try:
                data = s.recv(8192)
                if data:
                    chunk = data.decode('utf-8', errors='ignore')
                    buf += chunk
            except BlockingIOError:
                time.sleep(0.1)
        print("LOG SERIAL ATUAL:")
        print(buf)
        s.close()
    except Exception as e:
        print("[ERR] Erro:", e)

if __name__ == "__main__":
    main()

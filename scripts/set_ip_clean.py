import socket
import time

def main():
    s = socket.create_connection(('127.0.0.1', 31337))
    cmd = "ifconfig eth0 192.168.1.139 netmask 255.255.255.0 broadcast 192.168.1.255 up\n"
    s.sendall(b"\n")
    time.sleep(0.5)
    for ch in cmd:
        s.sendall(ch.encode('utf-8'))
        time.sleep(0.01)
    time.sleep(1.0)
    print(s.recv(4096).decode('utf-8', errors='ignore'))
    s.close()

if __name__ == "__main__":
    main()

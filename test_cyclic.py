from pwn import *
import os

# start server
os.system("src/vault_server &")
time.sleep(1)

# send pattern
payload = b"AUTH " + cyclic(800)
s = remote("127.0.0.1", 9999)
s.recv(1024)
s.send(payload)
s.close()

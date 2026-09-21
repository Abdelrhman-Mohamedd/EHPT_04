# Lab 04 Manual: Remote Buffer Overflow Prep

## Mission Briefing
You have discovered a legacy VaultTech Authentication Server running in the background of your system on **port 9999**. Your objective is to exploit a stack-based buffer overflow in this service, gain a reverse shell as the service account, and read the secret flag.

## Target Details
- **Location:** `127.0.0.1:9999`
- **Protocol:** The server expects the command `AUTH <password>`
- **Flag Location:** `/etc/lab04_flag` (Owned by `lab04:lab04 600`)
- **Protection:** The service runs under the `lab04` user. The flag is completely locked down. You must successfully execute shellcode to spawn a reverse shell as `lab04` to read it. ASLR is disabled and the stack is executable.

## Objective & Methodology
Unlike previous labs, there is no `print_flag` shortcut. You must perform a complete buffer overflow exploit following these rigorous steps to earn all three flags:

1. **Fuzzing (Flag 1):** Create a script to send incrementing amounts of data to `AUTH ` until the service crashes. When the service crashes, it will write your first intermediate flag to a system log file. *Hint: Check `/tmp/vault_crash.log`.*
2. **Finding the Offset (Flag 2):** Generate a cyclic pattern (e.g., using `pwntools` or `metasploit`), send it to the crashed service, and inspect the crash log (`/tmp/vault_crash.log`). The server has been instrumented to print the exact Instruction Pointer (RIP) it crashed on! Feed that value into `msf-pattern_offset` to find the exact byte offset.
   - *Challenge:* To prove you control `RIP`, use `objdump` to find the address of a hidden `debug_offset()` function in the binary. Overwrite `RIP` with this address. If successful, the server will drop your second flag in `/tmp/vault_offset.log`!
3. **Bad Characters:** The authentication parser explicitly filters or breaks on certain "bad characters". You must send byte arrays (from `\x01` to `\xff`) to the buffer and inspect memory to identify which characters truncate or mangle your payload.
4. **JMP RAX:** In 64-bit binaries, memory addresses contain null bytes (`\x00`). If you try to jump to `RSP` (placing shellcode *after* the return address), `strcpy` will truncate your payload at the return address's null bytes! Instead, `strcpy` conveniently returns a pointer to the destination buffer in the `RAX` register. Find a "Jump RAX" gadget to redirect execution to the *start* of your buffer.
5. **Shellcode:** Use `msfvenom` to generate an encoded reverse shell payload, avoiding your discovered bad characters.
6. **Exploit (Flag 3):** Combine a NOP sled, your shellcode, padding, and the JMP RAX address into a final exploit script. Start a `netcat` listener, and fire the payload to catch a reverse shell as the `lab04` user to read `/etc/lab04_flag`!

## Tools
- `gdb` (with `gef` or `pwndbg` if you choose to install them)
- `python3` (for exploit scripting)
- `msfvenom` (for shellcode generation)
- `nc` (Netcat for connecting to the service and catching shells)

---

## Helpful Hints

If you are stuck or aren't familiar with Python socket programming, use these hints to guide your research:

> **Hint 1: Python Socket Skeleton**
> You do not need to be a Python master. If you are struggling to communicate with the server, start with this skeleton script and just modify the `payload` variable:
> ```python
> import socket
> 
> target_ip = "127.0.0.1"
> target_port = 9999
> 
> # Modify this!
> payload = b"AUTH " + b"A" * 600
> 
> s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
> s.settimeout(2)
> s.connect((target_ip, target_port))
> s.recv(1024)
> s.send(payload)
> 
> # Try to receive the response. If it's empty, the server crashed!
> response = s.recv(1024)
> if not response:
>     print("The server crashed!")
> 
> s.close()
> ```

> **Hint 2: Finding the Exact Offset**
> Don't try to guess the exact padding length manually. Look into Metasploit's `msf-pattern_create` and `msf-pattern_offset` tools. They are designed specifically for this task!

> **Hint 3: Missing Bad Characters**
> If your reverse shell isn't working, your payload is probably getting truncated. The `strcpy` function always breaks on Null Bytes (`\x00`), and network services often break on Newlines (`\x0a`) and Carriage Returns (`\x0d`). I might have also added one more arbitrary symbol to the filter... generate a byte array from `\x01` to `\xff` to see exactly where your payload gets cut off!

> **Hint 4: Finding the Gadget**
> You need to tell the CPU to jump to your buffer. Since `strcpy` leaves the buffer address in the `RAX` register, look into the `objdump -d /srv/labs/lab04/bin/vault_server` command. Can you pipe that output into `grep` to search for a `call` or `jmp` instruction targeting `%rax`?

> **Hint 5: Architecture Matters**
> Remember, this is a 64-bit Linux server, not a 32-bit Windows machine! Make sure your `msfvenom` payload and your registers (`RIP`/`RSP` instead of `EIP`/`ESP`) reflect the 64-bit Linux architecture!

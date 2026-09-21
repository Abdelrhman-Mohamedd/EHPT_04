# Lab 04 Manual: Remote Buffer Overflow Prep

## Mission Briefing
You have discovered a legacy VaultTech Authentication Server running in the background of your system on **port 9999**. Your objective is to exploit a stack-based buffer overflow in this service, gain a reverse shell as the service account, and read the secret flag.

## Target Details
- **Location:** `127.0.0.1:9999`
- **Protocol:** The server expects the command `AUTH <password>`
- **Flag Location:** `/etc/lab04_flag` (Owned by `lab04:lab04 600`)
- **Protection:** The service runs under the `lab04` user. The flag is completely locked down. You must successfully execute shellcode to spawn a reverse shell as `lab04` to read it. ASLR is disabled and the stack is executable.

## Objective & Methodology
Unlike previous labs, there is no `print_flag` shortcut. You must perform a complete buffer overflow exploit following these rigorous steps:

1. **Fuzzing:** Create a script to send incrementing amounts of data to `AUTH ` until the service crashes.
2. **Finding the Offset:** Generate a cyclic pattern (e.g., using `pwntools` or `metasploit`), send it to the crashed service, and inspect the core dump (or attach `gdb` to the running service) to find the exact byte offset that overwrites the Instruction Pointer (RIP).
3. **Bad Characters:** The authentication parser explicitly filters or breaks on certain "bad characters". You must send byte arrays (from `\x01` to `\xff`) to the buffer and inspect memory to identify which characters truncate or mangle your payload.
4. **JMP RSP:** Find a "Jump RSP" gadget in the binary to redirect execution to your shellcode on the stack.
5. **Shellcode:** Use `msfvenom` to generate an encoded reverse shell payload, avoiding your discovered bad characters.
6. **Exploit:** Combine the padding, JMP RSP address, NOP sled, and shellcode into a final exploit script, start a `netcat` listener, and fire the payload.

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
> You need to tell the CPU to jump to the stack. Look into the `objdump -d /srv/labs/lab04/bin/vault_server` command. Can you pipe that output into `grep` to search for a `jmp` instruction?

> **Hint 5: Architecture Matters**
> Remember, this is a 64-bit Linux server, not a 32-bit Windows machine! Make sure your `msfvenom` payload and your registers (`RIP`/`RSP` instead of `EIP`/`ESP`) reflect the 64-bit Linux architecture!

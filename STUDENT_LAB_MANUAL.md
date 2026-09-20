# Lab 04 Manual: Basic Buffer Overflow

## Mission Briefing
You have gained access to a legacy authentication system used by VaultTech. Your goal is to exploit a stack-based buffer overflow vulnerability in this system to elevate your privileges and retrieve the secret flag.

## Target Details
- **Location:** `/srv/labs/lab04/bin/vuln`
- **Flag Location:** `/etc/lab04_flag`
- **Protection:** The flag is owned by `root:lab04` with `640` permissions. You are logged in as `student`. The vulnerable binary has the SGID bit set, so if you successfully hijack its execution flow, it will run with `lab04` group privileges, allowing you to read the flag.

## Objective
The binary contains a hidden function `print_flag()` that reads and displays the flag. You need to craft a payload that overflows the input buffer and overwrites the saved return address on the stack, replacing it with the address of the `print_flag()` function (a technique known as "ret2win").

## Tools
You can use `gdb`, `objdump`, `python3`, or any other standard tools available on the VM to analyze the binary and craft your exploit.

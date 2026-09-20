# Lab 04: OSCP-style Buffer Overflow Prep

This repository contains the complete source code, deployment scripts, and instructor tools for **Lab 04**.

## Lab Theme: Remote Buffer Overflow

Lab 04 is a highly focused binary exploitation lab designed to teach the rigorous methodology required for OSCP-style buffer overflows. The lab mimics a remote Windows buffer overflow, but is built for a 64-bit Linux environment to simplify deployment while teaching identical concepts.

Students will attack a custom VaultTech authentication daemon running on port 9999.

## Methodology Covered
To solve this lab, students must successfully perform:
1. **Fuzzing:** Writing a Python fuzzer to crash the service.
2. **Offset Discovery:** Using cyclic patterns to find the exact RIP offset.
3. **Bad Character Analysis:** Systematically discovering which characters the custom `filter_bad_chars()` function breaks on (e.g., `\x00`, `\x0a`, `\x0d`, `\x2b`).
4. **Gadget Hunting:** Locating the embedded `JMP RSP` gadget to execute stack payloads.
5. **Shellcode Generation:** Using `msfvenom` to create an encoded reverse shell.
6. **Local Privilege Escalation:** Catching the reverse shell, which will execute as the `lab04` service account, allowing access to the protected flag.

## Appliance Hardening & Anti-Tampering Model

1. **Instructor-Prepared Template**: The instructor runs `prepare_template_vm.sh` once. This locks down the VM and hides all setup files in `/opt/lab04-setup/`.
2. **Automated GUI First-Boot Setup**: The student logs in and the environment is provisioned.
3. **Systemd Service**: The vulnerable target (`vault_server`) runs continuously in the background via `systemctl` under the unprivileged `lab04` user.
4. **Flag Protection**: The flag at `/etc/lab04_flag` is strictly owned by `lab04:lab04 600`. The student must get a reverse shell to read it.
5. **ASLR Disabled**: For this preparatory lab, ASLR is disabled system-wide during setup to ensure consistent memory addresses, and the binary is compiled with an executable stack.

## Quick Start (Instructor Setup)

```bash
# 1. Clone repository
git clone https://github.com/Abdelrhman-Mohamedd/EHPT_04.git
cd EHPT_04

# 2. Prepare the Template VM (Run Once)
sudo ./prepare_template_vm.sh

# 3. Export VM and distribute to students
```

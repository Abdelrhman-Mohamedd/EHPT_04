# Lab 04: Basic Buffer Overflow (Ethical Hacking Lab)

This repository contains the complete source code, setup scripts, and instructor verification tools for **Lab 04**.

## Lab Theme: Buffer Overflow & Memory Corruption

Lab 04 targets fundamental memory corruption vulnerabilities:
- **Stack-based Buffer Overflow** (using vulnerable functions like `gets()`)
- **Control Flow Hijacking** (Overwriting the Instruction Pointer / Return Address)
- **Privilege Escalation** via setuid/setgid binaries

## Appliance Hardening & Anti-Tampering Model

To ensure a realistic and secure lab environment:

1. **Instructor-Prepared Template**: The instructor runs `prepare_template_vm.sh` once. This locks down the VM and hides all setup files in `/opt/lab04-setup/`.
2. **Automated GUI First-Boot Setup**: The student logs in, enters their Student ID, and the environment is provisioned with a unique flag.
3. **SetGID Binary Privilege**: The vulnerable program (`/srv/labs/lab04/bin/vuln`) is owned by `root:lab04` and has the SGID bit set (`2755`). The flag at `/etc/lab04_flag` is only readable by the `lab04` group (`640`). The student must exploit the binary to gain `lab04` privileges and read the flag.
4. **Cryptographic Flag Binding**: The flag is dynamically generated based on `sha256(STUDENT_ID + VULN_TYPE + SECRET_SALT)`.
5. **ASLR Disabled**: For this basic lab, ASLR is disabled system-wide during setup to ensure consistent memory addresses.

## Quick Start (Instructor Setup)

```bash
# 1. Clone repository
git clone https://github.com/Abdelrhman-Mohamedd/EHPT_04.git
cd EHPT_04

# 2. Prepare the Template VM (Run Once)
sudo ./prepare_template_vm.sh

# 3. Export VM and distribute to students
```

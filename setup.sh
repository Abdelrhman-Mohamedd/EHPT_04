#!/usr/bin/env bash
# ==============================================================================
# Lab 04 Deployment Script: OSCP-style Buffer Overflow Prep
# ==============================================================================
set -e

if [ "$EUID" -ne 0 ]; then
  echo "[-] Run as root: sudo ./setup.sh <STUDENT_ID> [--production]"; exit 1
fi

STUDENT_ID="${1:-abdelrhman_h_2026}"
IS_PRODUCTION=0
for arg in "$@"; do [ "$arg" == "--production" ] && IS_PRODUCTION=1; done

SALT_FILE="/etc/lab04.conf"
SECRET_SALT=$([ -f "$SALT_FILE" ] && cat "$SALT_FILE" || echo "${2:-EHPT04_SECRET_SALT_2026}")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ "$SCRIPT_DIR" == "/srv/labs/lab04" ] && echo "[-] Do not run from /srv/labs/lab04" && exit 1

echo "==[🔒] Lab 04 — Personalizing for: ${STUDENT_ID} =="

FLAG_CRASH=$(echo -n "${STUDENT_ID}_CRASH_${SECRET_SALT}" | sha256sum | cut -c1-32)
FLAG_OFFSET=$(echo -n "${STUDENT_ID}_OFFSET_${SECRET_SALT}" | sha256sum | cut -c1-32)
FLAG_BOF=$(echo -n  "${STUDENT_ID}_BOF_${SECRET_SALT}"  | sha256sum | cut -c1-32)

echo "[+] Step 1: System user 'lab04' (Service Account)..."
# Using a system account with a home directory for the daemon
id -u lab04 >/dev/null 2>&1 || useradd --system --create-home --shell=/usr/sbin/nologin lab04

echo "[+] Step 2: Directory structure..."
mkdir -p /srv/labs/lab04/bin

echo "[+] Step 3: Compiling Vault Server (no flags in binary — anti-cheat)..."
cd "${SCRIPT_DIR}/src"
make clean
make CFLAGS="-g -O0 -fno-stack-protector -z execstack -no-pie"
cp vault_server /srv/labs/lab04/bin/
chown lab04:lab04 /srv/labs/lab04/bin/vault_server
chmod 755 /srv/labs/lab04/bin/vault_server
cd "${SCRIPT_DIR}"

echo "[+] Step 4: Injecting flags (Strict permissions — lab04 only)..."
# Flag 3: Final flag (reverse shell required)
echo "FLAG{${FLAG_BOF}}" > /etc/lab04_flag
chown lab04:lab04 /etc/lab04_flag
chmod 600 /etc/lab04_flag

# Flag 1: Crash flag (read at runtime by the binary's signal handler)
echo "FLAG{${FLAG_CRASH}}" > /etc/lab04_flag_crash
chown lab04:lab04 /etc/lab04_flag_crash
chmod 600 /etc/lab04_flag_crash

# Flag 2: Offset flag (read at runtime by the binary's debug_offset function)
echo "FLAG{${FLAG_OFFSET}}" > /etc/lab04_flag_offset
chown lab04:lab04 /etc/lab04_flag_offset
chmod 600 /etc/lab04_flag_offset

echo "[+] Step 5: Systemd Service Configuration..."
cat << EOF > /etc/systemd/system/lab04-vault.service
[Unit]
Description=VaultTech Legacy Auth Server (Lab 04)
After=network.target

[Service]
Type=simple
User=lab04
Group=lab04
WorkingDirectory=/srv/labs/lab04/bin
ExecStart=/srv/labs/lab04/bin/vault_server
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable lab04-vault
systemctl restart lab04-vault

echo "[+] Step 6: System Config (ASLR & dmesg)..."
echo 0 > /proc/sys/kernel/randomize_va_space || true
echo "kernel.randomize_va_space = 0" > /etc/sysctl.d/99-disable-aslr.conf || true
sysctl -w kernel.dmesg_restrict=0 || true
echo "kernel.dmesg_restrict = 0" >> /etc/sysctl.d/99-disable-aslr.conf || true

echo "[+] Step 7: Hostname & banner..."
HOSTNAME_TARGET="lab04-${STUDENT_ID//_/-}"
command -v hostnamectl >/dev/null 2>&1 && hostnamectl set-hostname "${HOSTNAME_TARGET}" 2>/dev/null || echo "${HOSTNAME_TARGET}" > /etc/hostname
cat << EOF > /etc/motd
==============================================================================
  VaultTech Ethical Hacking Black-Box Appliance (Lab 04)
  Student ID  : ${STUDENT_ID}
  Target      : Remote Service on 127.0.0.1:9999
  Methodology : Fuzz -> Offset -> Bad Chars -> JMP RAX -> Shellcode
==============================================================================
EOF
cp /etc/motd /etc/issue

if [ "$IS_PRODUCTION" -eq 1 ]; then
    echo "[+] Step 8: Production purge..."
    rm -f "${SCRIPT_DIR}/setup.sh" "${SCRIPT_DIR}/generate_student_flags.py"
    rm -rf "${SCRIPT_DIR}/.git"
    rm -rf "${SCRIPT_DIR}/src"
fi

echo "==[🎉] Lab 04 ready for ${STUDENT_ID} =="

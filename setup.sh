#!/usr/bin/env bash
# ==============================================================================
# Lab 04 Deployment & Personalization Script
# Vulnerability: Buffer Overflow (Classic Ret2Win)
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

# Flag derivation
FLAG_BOF=$(echo -n  "${STUDENT_ID}_BOF_${SECRET_SALT}"  | sha256sum | cut -c1-32)

echo "[+] Step 1: System user 'lab04'..."
id -u lab04 >/dev/null 2>&1 || useradd --system --no-create-home --shell=/usr/sbin/nologin lab04

echo "[+] Step 2: Directory structure..."
mkdir -p /srv/labs/lab04/bin

echo "[+] Step 3: Compiling vulnerable program..."
cd "${SCRIPT_DIR}/src"
make clean
make
cp vuln /srv/labs/lab04/bin/
cd "${SCRIPT_DIR}"

echo "[+] Step 4: Injecting flags..."
echo "FLAG{${FLAG_BOF}}" > /etc/lab04_flag
chown root:lab04 /etc/lab04_flag
chmod 640 /etc/lab04_flag

echo "[+] Step 5: Build metadata..."
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
MACHINE_HASH="N/A"
[ -f /etc/machine-id ] && MACHINE_HASH=$(sha256sum /etc/machine-id | cut -c1-32)

cat << EOF > /srv/labs/lab04/.buildinfo
STUDENT_ID=${STUDENT_ID}
BUILD_TIMESTAMP=${BUILD_TIME}
MACHINE_HASH=${MACHINE_HASH}
FLAG_BOF=FLAG{${FLAG_BOF}}
EOF

echo "[+] Step 6: Permissions & SGID..."
chown root:lab04 /srv/labs/lab04/.buildinfo
chmod 700 /srv/labs/lab04/.buildinfo

# Set SGID on the binary so it runs as the group lab04, allowing it to read /etc/lab04_flag
chown root:lab04 /srv/labs/lab04/bin/vuln
chmod 2755 /srv/labs/lab04/bin/vuln

echo "[+] Step 7: System Config (ASLR disabled)..."
echo 0 > /proc/sys/kernel/randomize_va_space || true
# Ensure it persists on reboot
echo "kernel.randomize_va_space = 0" > /etc/sysctl.d/99-disable-aslr.conf || true

echo "[+] Step 8: Hostname & banner..."
HOSTNAME_TARGET="lab04-${STUDENT_ID//_/-}"
command -v hostnamectl >/dev/null 2>&1 && hostnamectl set-hostname "${HOSTNAME_TARGET}" 2>/dev/null || echo "${HOSTNAME_TARGET}" > /etc/hostname
cat << EOF > /etc/motd
==============================================================================
  VaultTech Ethical Hacking Black-Box Appliance (Lab 04)
  Student ID  : ${STUDENT_ID}    |    Build: ${BUILD_TIME}
  Target      : /srv/labs/lab04/bin/vuln
==============================================================================
EOF
cp /etc/motd /etc/issue

if [ "$IS_PRODUCTION" -eq 1 ]; then
    echo "[+] Step 9: Production purge..."
    rm -f "${SCRIPT_DIR}/setup.sh" "${SCRIPT_DIR}/generate_student_flags.py"
    rm -rf "${SCRIPT_DIR}/.git"
    rm -rf "${SCRIPT_DIR}/src"
fi

echo "==[🎉] Lab 04 ready for ${STUDENT_ID} =="

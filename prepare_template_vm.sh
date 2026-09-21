#!/usr/bin/env bash
# ==============================================================================
# prepare_template_vm.sh — Instructor-Run Golden Template Preparation Script
# Run this ONCE on the base Rocky Linux VM (as root) to lock it down before
# distributing to students. Students will NOT need root or sudo for anything
# except the single whitelisted setup.sh call via first_boot_setup.sh.
#
# Usage: sudo ./prepare_template_vm.sh [SECRET_SALT]
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "[-] Please run as root: sudo ./prepare_template_vm.sh [SECRET_SALT]"
    exit 1
fi

STUDENT_USER="student"
SECRET_SALT="${1:-EHPT04_SECRET_SALT_2026}"

# EHPT_04 repo goes to /opt/lab04-setup/ (root:root 700 — invisible to student)
EHPT_DIR="/opt/lab04-setup"

echo "=============================================================================="
echo "[*] Preparing Lab 04 Black-Box Template VM"
echo "    Theme: Basic Buffer Overflow"
echo "=============================================================================="

# ---- 1. Create student user 'student' ----
echo "[+] Step 1: Creating student user '${STUDENT_USER}' (no sudo, locked password)..."
if ! id -u "$STUDENT_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$STUDENT_USER"
    echo "    Created user ${STUDENT_USER}"
fi

# Ensure student is NOT in any admin/sudo groups
gpasswd -d "$STUDENT_USER" wheel 2>/dev/null || true
gpasswd -d "$STUDENT_USER" sudo  2>/dev/null || true

# Set a simple known password (instructor changes before distributing)
echo "${STUDENT_USER}:labpassword" | chpasswd
echo "    Password set to: labpassword  (change this before distributing!)"

# ---- Hide 'cyberlabs' instructor account from GDM login screen ----
echo "[+] Step 1b: Hiding 'cyberlabs' from GDM login screen..."
mkdir -p /var/lib/AccountsService/users/
cat > /var/lib/AccountsService/users/cyberlabs << 'ACCT'
[User]
SystemAccount=true
ACCT
chmod 644 /var/lib/AccountsService/users/cyberlabs
echo "    cyberlabs is now hidden from the GDM login screen (account still usable)."

# ---- 1c. Copy UI settings from Instructor ----
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    echo "[+] Step 1c: Copying Desktop and UI settings from instructor (${SUDO_USER}) to student..."
    if [ -d "/home/${SUDO_USER}/Desktop" ]; then
        cp -r "/home/${SUDO_USER}/Desktop" "/home/${STUDENT_USER}/"
    fi
    if [ -d "/home/${SUDO_USER}/.config/dconf" ]; then
        mkdir -p "/home/${STUDENT_USER}/.config"
        cp -r "/home/${SUDO_USER}/.config/dconf" "/home/${STUDENT_USER}/.config/"
    fi
    if [ -d "/home/${SUDO_USER}/.local/share/backgrounds" ]; then
        mkdir -p "/home/${STUDENT_USER}/.local/share"
        cp -r "/home/${SUDO_USER}/.local/share/backgrounds" "/home/${STUDENT_USER}/.local/share/"
    fi
    chown -R "${STUDENT_USER}:${STUDENT_USER}" "/home/${STUDENT_USER}/Desktop" "/home/${STUDENT_USER}/.config" "/home/${STUDENT_USER}/.local" 2>/dev/null || true
    echo "    Copied Desktop and dconf settings."
fi

# ---- 2. Install Dependencies (GUI & Exploitation Tools) ----
echo "[+] Step 2: Installing dependencies (zenity, gcc, gdb, nc, pwntools)..."
dnf install -y zenity gcc make gdb binutils python3 python3-pip nmap-ncat curl >/dev/null 2>&1 && echo "    Dependencies installed successfully." || echo "    [!] Dependency install failed — check DNF."
pip3 install pwntools >/dev/null 2>&1 || echo "    [!] pwntools install failed."

echo "[+] Step 2b: Installing Metasploit Framework (for msfvenom)..."
curl -s https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > /tmp/msfinstall
chmod 755 /tmp/msfinstall
/tmp/msfinstall >/dev/null 2>&1 && echo "    Metasploit installed successfully." || echo "    [!] Metasploit installation failed."
rm -f /tmp/msfinstall

# Create symlinks for pattern tools which aren't always symlinked by default
ln -sf /opt/metasploit-framework/bin/msf-pattern_create /usr/local/bin/msf-pattern_create || true
ln -sf /opt/metasploit-framework/bin/msf-pattern_offset /usr/local/bin/msf-pattern_offset || true

# ---- 3. Write the secret salt to /etc/lab04.conf (root:root 600 — student CANNOT read) ----
echo "[+] Step 3: Storing secret salt in /etc/lab04.conf (root-only)..."
echo "${SECRET_SALT}" > /etc/lab04.conf
chown root:root /etc/lab04.conf
chmod 600 /etc/lab04.conf
echo "    Salt stored at /etc/lab04.conf  (mode: 600 — student access: DENIED)"

# ---- 4. Clone EHPT_04 repo to /opt/lab04-setup/ (outside student home, root-only) ----
echo "[+] Step 4: Deploying EHPT_04 repo to ${EHPT_DIR} (root-only, invisible to student)..."
if [ ! -d "${EHPT_DIR}/.git" ]; then
    git clone https://github.com/Abdelrhman-Mohamedd/EHPT_04.git "$EHPT_DIR"
else
    git -C "$EHPT_DIR" pull
fi

# Root owns everything — student cannot list, read, or enter this directory
chown -R root:root "$EHPT_DIR"
chmod 700 "$EHPT_DIR"
find "$EHPT_DIR" -type d -exec chmod 700 {} \;
find "$EHPT_DIR" -type f -exec chmod 600 {} \;
chmod 500 "${EHPT_DIR}/setup.sh"
echo "    ${EHPT_DIR}  mode=700 (root:root) — student cannot ls, read, or enter"
echo "    setup.sh     mode=500 (root:root) — executable only by root via sudo"

# ---- 5. Install the first-boot wizard (ONLY file student can see — contains NO salt) ----
echo "[+] Step 5: Installing first_boot_setup.sh wizard (salt-free)..."
cp "${EHPT_DIR}/first_boot_setup.sh" "/home/${STUDENT_USER}/first_boot_setup.sh"
chown root:root "/home/${STUDENT_USER}/first_boot_setup.sh"
chmod 755 "/home/${STUDENT_USER}/first_boot_setup.sh"
echo "    Installed at /home/${STUDENT_USER}/first_boot_setup.sh"
echo "    This file contains NO salt — student learns nothing from reading it."

# Trigger via GNOME autostart .desktop entry
AUTOSTART_DIR="/home/${STUDENT_USER}/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
cat > "${AUTOSTART_DIR}/lab04-setup.desktop" << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=Lab 04 First Boot Setup
Exec=bash /home/student/first_boot_setup.sh
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=3
DESKTOP
chown -R "${STUDENT_USER}:${STUDENT_USER}" "/home/${STUDENT_USER}/.config"
echo "    GNOME autostart entry created — runs after desktop loads, not on login shell."

# ---- Suppress GNOME Initial Setup dialog ----
echo "[+] Step 5b: Suppressing GNOME Initial Setup welcome dialog..."
touch "/home/${STUDENT_USER}/.config/gnome-initial-setup-done"
chown "${STUDENT_USER}:${STUDENT_USER}" "/home/${STUDENT_USER}/.config/gnome-initial-setup-done"
echo "    'Welcome to Rocky Linux' dialog will NOT appear on first login."

# ---- 6. Configure Narrowly Scoped sudoers Rule ----
echo "[+] Step 6: Configuring restricted sudoers rule..."
cat << EOF > /etc/sudoers.d/lab04-setup
# Lab 04 Restricted sudo: student may ONLY run setup.sh as root
# setup.sh lives in /opt/lab04-setup/ (root:root 500) — student cannot read or modify it.
student ALL=(root) NOPASSWD: /opt/lab04-setup/setup.sh *
EOF
chmod 440 /etc/sudoers.d/lab04-setup
visudo -c -f /etc/sudoers.d/lab04-setup && echo "    Sudoers rule OK at /etc/sudoers.d/lab04-setup" || echo "[!] sudoers syntax error!"

# ---- 7. Harden SSH & Disable SELinux ----
echo "[+] Step 7: Hardening SSH and Disabling SELinux..."
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl reload sshd 2>/dev/null || true
echo "    Root SSH login disabled."

if command -v setenforce >/dev/null 2>&1; then
    setenforce 0 2>/dev/null || true
    sed -i 's/^SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config 2>/dev/null || true
    echo "    SELinux has been disabled (required for buffer overflow & reverse shell)."
fi

# ---- 8. Set appliance-mode login banner ----
echo "[+] Step 8: Setting pre-login banner..."
cat << 'BANNER' > /etc/issue.net
╔═══════════════════════════════════════════════════════════════════╗
║       VaultTech Ethical Hacking Lab 04 — Black-Box Appliance      ║
║     Unauthorized access is strictly prohibited.                    ║
╚═══════════════════════════════════════════════════════════════════╝
Login as: student / labpassword (change before distributing)
BANNER

# ---- 9. Lock root password ----
echo "[+] Step 9: Locking root password..."
passwd -l root
echo "    Root account locked. Only sudo via sudoers rule is possible."

# ---- 9b. Configure firewall for network isolation ----
echo "[+] Step 9b: Configuring firewall — blocking internet egress..."
if command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port=80/tcp 2>/dev/null || true

    # Clear previous direct rules
    firewall-cmd --permanent --direct --remove-all-rules 2>/dev/null || true

    # Allow outbound to private subnets (RFC1918) and loopback, block everything else
    firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 -m state --state ESTABLISHED,RELATED -j ACCEPT
    firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 1 -d 127.0.0.0/8 -j ACCEPT
    firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 2 -d 10.0.0.0/8 -j ACCEPT
    firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 3 -d 172.16.0.0/12 -j ACCEPT
    firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 4 -d 192.168.0.0/16 -j ACCEPT
    firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 99 -j REJECT

    firewall-cmd --reload 2>/dev/null || true
    echo "    Firewall: port 80/tcp inbound OPEN"
    echo "    Firewall: ALL outbound internet traffic BLOCKED (RFC1918 allowed)"
fi

# ---- 9c. Configure DNS Blackhole ----
echo "[+] Step 9c: Configuring DNS Blackhole (Defense in Depth)..."
# Remove existing resolver and point to nowhere
rm -f /etc/resolv.conf
echo "nameserver 127.0.0.1" > /etc/resolv.conf
# Lock the file so NetworkManager/DHCP cannot overwrite it
chattr +i /etc/resolv.conf 2>/dev/null || true
echo "    DNS locked to 127.0.0.1. External name resolution is BLOCKED."


# ---- Summary ----
echo "=============================================================================="
echo "[✅] Template VM Preparation Complete!"
echo ""
echo "     Student User    : ${STUDENT_USER} / labpassword"
echo "     EHPT_04 Repo    : /opt/lab04-setup/  (root:root 700 — student cannot see)"
echo "     Secret Salt     : /etc/lab04.conf    (root:root 600 — student cannot read)"
echo "     Student Sudo    : ONLY /opt/lab04-setup/setup.sh (nothing else)"
echo "     First-Boot UI   : /home/student/first_boot_setup.sh (contains NO salt)"
echo "     Root Login      : LOCKED"
echo ""
echo "     Before distribution:"
echo "       1. Change student password:  passwd ${STUDENT_USER}"
echo "       2. Export the VM to .OVA or .qcow2 and hand out one copy per student."
echo "=============================================================================="

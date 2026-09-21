#!/usr/bin/env bash
echo "[+] Unlocking Firewall and DNS..."
chattr -i /etc/resolv.conf 2>/dev/null || true
echo "nameserver 8.8.8.8" > /etc/resolv.conf
firewall-cmd --permanent --direct --remove-all-rules >/dev/null 2>&1 || true
firewall-cmd --reload >/dev/null 2>&1 || true

echo "[+] Downloading and installing Metasploit Framework..."
curl -s https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > /tmp/msfinstall
chmod 755 /tmp/msfinstall
/tmp/msfinstall

echo "[+] Creating symlinks..."
ln -sf /opt/metasploit-framework/bin/msf-pattern_create /usr/bin/msf-pattern_create
ln -sf /opt/metasploit-framework/bin/msf-pattern_offset /usr/bin/msf-pattern_offset

echo "[+] Re-locking Firewall and DNS..."
firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 -m state --state ESTABLISHED,RELATED -j ACCEPT >/dev/null 2>&1 || true
firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 1 -d 127.0.0.0/8 -j ACCEPT >/dev/null 2>&1 || true
firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 2 -d 10.0.0.0/8 -j ACCEPT >/dev/null 2>&1 || true
firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 3 -d 172.16.0.0/12 -j ACCEPT >/dev/null 2>&1 || true
firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 4 -d 192.168.0.0/16 -j ACCEPT >/dev/null 2>&1 || true
firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 99 -j REJECT >/dev/null 2>&1 || true
firewall-cmd --reload >/dev/null 2>&1 || true

echo "nameserver 127.0.0.1" > /etc/resolv.conf
chattr +i /etc/resolv.conf

echo "[✅] Done! Metasploit is installed and the VM is securely isolated again."

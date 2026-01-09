#!/bin/bash
set -euo pipefail

LOG=/var/log/user-data-wireguard.log
exec > >(tee -a "$LOG") 2>&1

# Terraform template vars
WG_ADDRESS="${wg_address}"
WG_PORT="${wg_port}"

echo "[1/7] Install packages"
if command -v dnf >/dev/null 2>&1; then
  dnf -y update
  dnf -y install wireguard-tools iproute iptables
elif command -v yum >/dev/null 2>&1; then
  yum -y update
  yum -y install wireguard-tools iproute iptables
else
  echo "Unsupported package manager"; exit 1
fi

echo "[2/7] Enable IPv4 forwarding"
cat >/etc/sysctl.d/99-wireguard.conf <<'EOF'
net.ipv4.ip_forward=1
EOF
sysctl --system

echo "[3/7] Generate WireGuard keys if not exist"
install -d -m 700 /etc/wireguard
if [ ! -f /etc/wireguard/privatekey ]; then
  umask 077
  wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
fi
chmod 600 /etc/wireguard/privatekey
chmod 644 /etc/wireguard/publickey

AWS_PRIV_KEY="$(cat /etc/wireguard/privatekey)"

echo "[4/7] Create wg0.conf skeleton (peer/allowedips will be filled later)"
cat >/etc/wireguard/wg0.conf <<EOF
[Interface]
Address = $WG_ADDRESS
ListenPort = $WG_PORT
PrivateKey = $AWS_PRIV_KEY

# === Peer section will be managed later (On-Prem side is 협업 범위) ===
# [Peer]
# PublicKey = <ONPREM_PUBLIC_KEY>
# AllowedIPs = <ONPREM_CIDR>, <ONPREM_TUNNEL_IP>/32
# PersistentKeepalive = 25
EOF
chmod 600 /etc/wireguard/wg0.conf

echo "[5/7] Basic forward allow (wg0 <-> eth0)"
iptables -C FORWARD -i wg0 -o eth0 -j ACCEPT 2>/dev/null || iptables -A FORWARD -i wg0 -o eth0 -j ACCEPT
iptables -C FORWARD -i eth0 -o wg0 -j ACCEPT 2>/dev/null || iptables -A FORWARD -i eth0 -o wg0 -j ACCEPT

echo "[6/7] Enable & start wg-quick"
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

echo "[7/7] Show AWS WG PublicKey"
cat /etc/wireguard/publickey
echo "Done."

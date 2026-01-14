#!/bin/bash
set -euo pipefail

LOG=/var/log/user-data-wireguard.log
exec > >(tee -a "$LOG") 2>&1

WG_ADDRESS="${wg_address}"
WG_PORT="${wg_port}"

echo "[1/8] Install packages (Amazon Linux 2)"
yum -y update
yum -y install wireguard-tools iproute iptables-services

echo "[2/8] Enable IPv4 forwarding (persistent)"
cat >/etc/sysctl.d/99-wireguard.conf <<'EOF'
net.ipv4.ip_forward = 1
EOF
sysctl --system

echo "[3/8] Generate WireGuard keys if not exist"
install -d -m 700 /etc/wireguard
if [ ! -f /etc/wireguard/privatekey ]; then
  umask 077
  wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
fi
chmod 600 /etc/wireguard/privatekey
chmod 644 /etc/wireguard/publickey

AWS_PRIV_KEY="$(cat /etc/wireguard/privatekey)"

echo "[4/8] Create wg0.conf"
cat >/etc/wireguard/wg0.conf <<EOF
[Interface]
Address = $WG_ADDRESS
ListenPort = $WG_PORT
PrivateKey = $AWS_PRIV_KEY

# Peer configuration is managed separately (On-Prem)
EOF
chmod 600 /etc/wireguard/wg0.conf

echo "[5/8] Configure iptables (SNAT + Forward)"
iptables -t nat -C POSTROUTING -o wg0 -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE

iptables -C FORWARD -i eth0 -o wg0 -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i eth0 -o wg0 -j ACCEPT

iptables -C FORWARD -i wg0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i wg0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "[6/8] Persist iptables rules (AL2)"
service iptables save
systemctl enable iptables

echo "[7/8] Enable & start WireGuard"
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

echo "[8/8] Show WireGuard public key"
cat /etc/wireguard/publickey
echo "WireGuard setup completed."
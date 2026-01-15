#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "[INFO] WireGuard gateway bootstrap start (Amazon Linux 2)"

# -----------------------------
# 0) 기본 패키지 업데이트/설치
# -----------------------------
yum update -y
yum install -y \
  yum-utils \
  iptables-services \
  jq \
  curl

# -----------------------------
# 1) IP Forwarding (runtime + persistent)
# -----------------------------
echo "[INFO] Enable IPv4 forwarding"
sysctl -w net.ipv4.ip_forward=1

cat >/etc/sysctl.d/99-wireguard.conf <<EOF
net.ipv4.ip_forward = 1
EOF

sysctl --system

# -----------------------------
# 2) WireGuard 설치
#   - AL2: amazon-linux-extras 사용 가능
# -----------------------------
echo "[INFO] Install WireGuard"
if ! command -v wg >/dev/null 2>&1; then
  amazon-linux-extras enable epel
  yum clean metadata
  yum install -y epel-release
  yum install -y wireguard-tools
fi

mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

# -----------------------------
# 3) wg0.conf 생성/배치
#   - 아래 템플릿 변수들은 네 기존 userdata 템플릿 변수명에 맞춰 유지/치환
# -----------------------------
echo "[INFO] Write /etc/wireguard/wg0.conf"

cat >/etc/wireguard/wg0.conf <<EOF
[Interface]
Address = ${wg_address}
PrivateKey = ${wg_private_key}
ListenPort = 51820

# (선택) 필요하면 MTU, DNS 등 추가 가능
# MTU = 1420

[Peer]
PublicKey = ${onprem_peer_public_key}
Endpoint = ${onprem_peer_endpoint}
AllowedIPs = ${onprem_allowed_ips}
PersistentKeepalive = 25
EOF

chmod 600 /etc/wireguard/wg0.conf

# -----------------------------
# 4) iptables 설정 (NAT + Forward)
#   - 중복 방지를 위해 -C 체크 후 없을 때만 추가
#   - MASQUERADE는 VPC CIDR(10.100.0.0/16)만 대상으로 제한 권장
# -----------------------------
echo "[INFO] Configure iptables"

VPC_CIDR="$${vpc_cidr:-10.100.0.0/16}"

# NAT
iptables -t nat -C POSTROUTING -s "${VPC_CIDR}" -o wg0 -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s "${VPC_CIDR}" -o wg0 -j MASQUERADE

# Forward rules
iptables -C FORWARD -i eth0 -o wg0 -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i eth0 -o wg0 -j ACCEPT

iptables -C FORWARD -i wg0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i wg0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# 규칙 저장 + 서비스 활성화
mkdir -p /etc/sysconfig
iptables-save > /etc/sysconfig/iptables

systemctl enable iptables
systemctl restart iptables

# -----------------------------
# 5) WireGuard 서비스 기동
# -----------------------------
echo "[INFO] Enable & start wg-quick@wg0"
systemctl daemon-reload
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

# -----------------------------
# 6) 상태 출력(디버깅용)
# -----------------------------
echo "[INFO] wg-quick@wg0 status"
systemctl --no-pager status wg-quick@wg0 || true

echo "[INFO] wg show"
wg show || true

echo "[INFO] iptables -S"
iptables -S || true

echo "[INFO] iptables -t nat -S"
iptables -t nat -S || true

echo "[INFO] WireGuard gateway bootstrap completed"

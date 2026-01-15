variable "name_prefix" { type = string }
variable "env"         { type = string }
variable "tags"        { type = map(string) }

variable "vpc_id" { type = string }

variable "vpc_cidr" {
  description = "VPC CIDR (used in userdata template)"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for VPN EC2s (2 subnets in different AZ recommended)"
  type        = list(string)
}

variable "private_route_table_id" {
  description = "Route table id used by private subnets (EKS nodes) where onprem route will be added/replaced"
  type        = string
}

variable "onprem_cidr" {
  description = "On-prem CIDR to route via WireGuard gateway"
  type        = string
}

variable "admin_cidrs" {
  description = "SSH management CIDRs"
  type        = list(string)
}

variable "wireguard_port" {
  type    = number
  default = 51820
}

variable "wireguard_allowed_cidrs" {
  description = "Allowed CIDRs for WireGuard UDP inbound (typically on-prem public IP/32 or NAT egress CIDR)"
  type        = list(string)
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ami_id" {
  description = "AMI for VPN instances (AL2023/AL2/Rocky etc). If empty, latest Amazon Linux 2023 will be used."
  type        = string
  default     = ""
}

variable "wg_addresses" {
  description = "WG tunnel interface addresses for [active, standby]. Example: [\"10.200.0.1/24\", \"10.200.0.2/24\"]"
  type        = list(string)
  default     = ["10.200.0.1/24", "10.200.0.2/24"]
}

variable "wg_private_key" {
  description = "WireGuard private key for the gateway (active/standby 동일 키 사용 전제)"
  type        = string
  sensitive   = true
}

variable "onprem_peer_public_key" {
  description = "WireGuard public key of on-prem peer"
  type        = string
  sensitive   = true
}

variable "onprem_peer_endpoint" {
  description = "On-prem peer endpoint in host:port format (e.g. 1.2.3.4:51820)"
  type        = string
}

variable "onprem_allowed_ips" {
  description = "AllowedIPs to route to on-prem via WG (e.g. [\"192.168.1.0/24\"])"
  type        = list(string)
}
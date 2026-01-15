variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "default"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "env" {
  description = "Environment (dev/stage/prod)"
  type        = string
}

variable "tags" {
  description = "Additional tags merged into base tags"
  type        = map(string)
  default     = {}
}

# Admin / SSH
variable "admin_cidr_blocks" {
  description = "Allowed CIDRs for admin/ssh access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "extra_admin_cidrs" {
  description = "Extra allowed CIDRs for admin/ssh access"
  type        = list(string)
  default     = []
}

# Hybrid (On-Prem / WireGuard)
variable "onprem_cidr" {
  description = "On-Prem CIDR (PostgreSQL subnet)"
  type        = string
  default     = "192.168.1.0/24"
}

variable "wireguard_allowed_cidrs" {
  description = "CIDRs routed via WireGuard from AWS"
  type        = list(string)
  default     = ["192.168.1.0/24"]
}

variable "wg_addresses" {
  description = "WireGuard tunnel addresses assigned to AWS gateways (wg0)"
  type        = list(string)
  default     = ["10.200.0.1/24", "10.200.0.2/24"]
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

# Route53 / ExternalDNS (IRSA)
variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID for rockyvicky.com"
  type        = string
}

variable "externaldns_domain" {
  description = "Domain filter used by ExternalDNS"
  type        = string
  default     = "rockyvicky.com"
}

variable "externaldns_txt_owner_id" {
  description = "txtOwnerId for ExternalDNS ownership (e.g. rockyvicky-dev)"
  type        = string
  default     = "rockyvicky-dev"
}

# ACM (선구축 참조)
variable "acm_certificate_arn" {
  description = "ACM certificate ARN (ap-northeast-2). Pre-created and referenced."
  type        = string
  default     = ""
}

# AWS Load Balancer Controller (IRSA + Helm)
variable "alb_controller_chart_version" {
  description = "Helm chart version for aws-load-balancer-controller (chart version, not appVersion)"
  type        = string
  default     = "1.17.1"
}

# Valkey (ElastiCache)
variable "valkey_node_type" {
  description = "Valkey node instance type"
  type        = string
  default     = "cache.t4g.small"
}

variable "valkey_num_node_groups" {
  type        = number
}

variable "valkey_replicas_per_node_group" { 
  type        = number 
}

variable "valkey_num_cache_clusters" {
  description = "Number of cache clusters (primary+replicas). For replication group."
  type        = number
  default     = 2
}

variable "valkey_engine_version" {
  description = "Valkey engine version"
  type        = string
  default     = "7"
}

variable "valkey_port" {
  description = "Valkey port"
  type        = number
  default     = 6379
}

# --- EKS/Network 공통 ---
variable "eks_cluster_name" {
  type        = string
  description = "EKS cluster name (must match actual cluster name for subnet tagging)"
  default     = ""
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR"
  default     = "10.100.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public subnet CIDRs (2 AZ)"
  default     = ["10.100.0.0/24", "10.100.1.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private subnet CIDRs (2 AZ)"
  default     = ["10.100.10.0/24", "10.100.11.0/24"]
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Whether to create NAT Gateway for private subnets"
  default     = true
}

variable "eks_cluster_version" {
  type        = string
  description = "EKS version"
  default     = "1.29"
}

variable "eks_node_groups" {
  type        = any
  description = "Node group map definition"
  default     = {}
}

# --- Route53/ACM (정리본 기준) ---
variable "domain_name" {
  type        = string
  description = "Apex domain"
  default     = "rockyvicky.com"
}

variable "txt_owner_id" {
  type        = string
  description = "ExternalDNS txtOwnerId"
  default     = "rockyvicky-dev"
}

variable "externaldns_policy" {
  type        = string
  description = "ExternalDNS policy"
  default     = "upsert-only"
}

variable "create_certificate" {
  type        = bool
  description = "true=create ACM cert, false=reference existing"
  default     = false
}

variable "existing_certificate_arn" {
  type        = string
  description = "Existing ACM certificate ARN (ap-northeast-2)"
  default     = ""
}

# --- wg_failover ---
variable "wg_failover_log_retention_days" {
  type        = number
  description = "CloudWatch log retention days for WG failover Lambda"
  default     = 7
}

variable "wg_failover_datapoints_to_alarm" {
  type        = number
  description = "CloudWatch alarm datapoints_to_alarm for WG failover"
  default     = 2
}

variable "wg_private_key" {
  description = "WireGuard private key for the gateway (active/standby 동일 키 사용 전제)"
  type        = string
  sensitive   = true
}

# frontend (S3 + CloudFront)

variable "frontend_bucket_name" {
  description = "S3 bucket name for static frontend (already exists or to be created)"
  type        = string
}

variable "cloudfront_acm_arn" {
  description = "ACM certificate ARN in us-east-1 for CloudFront"
  type        = string
}
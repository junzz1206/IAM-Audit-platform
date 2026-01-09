variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile name"
  default     = "changhun"
}

variable "project_name" {
  type        = string
  description = "Project name used for naming/tagging"
  default     = "soldesk-rockyvickyeasyfeezy"
}

variable "env" {
  type        = string
  description = "Environment name"
  default     = "dev"
}

variable "admin_cidr_blocks" {
  type        = list(string)
  default     = []
  description = "EKS API Public Access 허용 CIDR 목록. 비워두면 자동 공인IP/32 적용"
}

variable "onprem_cidr" {
  type        = string
  description = "On-Prem CIDR"
}

variable "wireguard_allowed_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach WireGuard UDP port"
}

variable "wg_addresses" {
  type        = list(string)
  description = "WG tunnel addresses for [active, standby]"
}

variable "extra_admin_cidrs" {
  type    = list(string)
  default = []
}

variable "valkey_engine_version" { 
  type = string 
  default = "8.2" 
}

variable "valkey_node_type" { 
  type = string 
  default = "cache.t4g.micro" 
}

variable "valkey_num_node_groups" { 
  type = number 
  default = 2 
}

variable "valkey_replicas_per_node_group" { 
  type = number 
  default = 2 
}

variable "valkey_parameter_group_name" { 
  type = string 
  default = "default.valkey8.cluster.on" 
}

variable "valkey_snapshot_retention_days" { 
  type = number 
  default = 1 
}

variable "valkey_auto_minor_version_upgrade" { 
  type = bool 
  default = true 
}





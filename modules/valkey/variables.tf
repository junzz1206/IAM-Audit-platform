variable "name_prefix" {
  type = string
}

variable "env" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

# 인바운드 허용 소스: EKS 워커 SG(또는 최소 클러스터 SG)
variable "eks_worker_sg_id" {
  type = string
}

variable "port" {
  type    = number
  default = 6379
}

variable "engine_version" {
  type    = string
  default = "8.2"
}

variable "node_type" {
  type    = string
  default = "cache.t4g.micro"
}

# cluster mode enabled => shard 기반
variable "num_node_groups" {
  type    = number
  default = 1
}

variable "replicas_per_node_group" {
  type    = number
  default = 1
}

variable "parameter_group_name" {
  type    = string
  default = "default.valkey8.cluster.on"
}

variable "snapshot_retention_days" {
  type    = number
  default = 1
}

variable "auto_minor_version_upgrade" {
  type    = bool
  default = true
}

variable "transit_encryption_mode" {
  type    = string
  default = "required" # TLS only
}
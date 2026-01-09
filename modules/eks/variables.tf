variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "eks_version" {
  type    = string
  default = "1.29"
}

variable "admin_cidr_blocks" {
  type        = list(string)
  description = "EKS API Public Access CIDR"
}

variable "tags" {
  type    = map(string)
  default = {}
}

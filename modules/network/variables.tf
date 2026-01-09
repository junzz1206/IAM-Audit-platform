variable "project_name" {
  type        = string
  description = "Project name"
}

variable "env" {
  type        = string
  description = "Environment name"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
}

variable "public_subnets" {
  type = list(object({
    cidr      = string
    az_suffix = string
  }))
  description = "Public subnet definitions"
}

variable "private_subnets" {
  type = list(object({
    cidr      = string
    az_suffix = string
  }))
  description = "Private subnet definitions"
}

variable "tags" {
  type        = map(string)
  description = "Common tags"
  default     = {}
}

variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "eks_cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "tags" {
  type    = map(string)
  default = {}
}

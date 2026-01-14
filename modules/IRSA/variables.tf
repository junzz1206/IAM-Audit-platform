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

variable "create_oidc_provider" {
  description = "If true, create aws_iam_openid_connect_provider. If false, lookup existing provider."
  type        = bool
  default     = true
}

variable "alb_service_account" {
  description = "ServiceAccount for AWS Load Balancer Controller"
  type = object({
    namespace = string
    name      = string
  })
  default = {
    namespace = "kube-system"
    name      = "aws-load-balancer-controller"
  }
}

variable "cluster_autoscaler_service_account" {
  description = "ServiceAccount for Cluster Autoscaler"
  type = object({
    namespace = string
    name      = string
  })
  default = {
    namespace = "kube-system"
    name      = "cluster-autoscaler"
  }
}

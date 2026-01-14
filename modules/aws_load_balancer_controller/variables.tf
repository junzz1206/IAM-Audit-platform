variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where EKS is deployed"
}

variable "cluster_oidc_provider_arn" {
  type        = string
  description = "IAM OIDC provider ARN for the EKS cluster"
}

variable "cluster_oidc_issuer_url" {
  type        = string
  description = "OIDC issuer URL for the EKS cluster (starts with https://...)"
}

variable "service_account_namespace" {
  type        = string
  default     = "kube-system"
  description = "Namespace of aws-load-balancer-controller ServiceAccount"
}

variable "service_account_name" {
  type        = string
  default     = "aws-load-balancer-controller"
  description = "Name of aws-load-balancer-controller ServiceAccount"
}

variable "helm_chart_version" {
  type        = string
  default     = "1.8.2"
  description = "Helm chart version for aws-load-balancer-controller (set per your standard)"
}

variable "iam_policy_scope_to_vpc" {
  type        = bool
  default     = true
  description = "If true, scope down some EC2 SG rule permissions to this VPC"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Common tags"
}

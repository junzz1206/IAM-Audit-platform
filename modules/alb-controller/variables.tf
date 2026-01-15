variable "project_name" {
  type        = string
  description = "프로젝트 이름(리소스 네이밍용)"
}

variable "env" {
  type        = string
  description = "환경(dev/prod 등)"
}

variable "region" {
  type        = string
  description = "AWS Region (예: ap-northeast-2)"
}

variable "tags" {
  type        = map(string)
  description = "공통 태그"
  default     = {}
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC Provider ARN"
}

variable "oidc_issuer_url" {
  type        = string
  description = "EKS OIDC issuer URL (https://...)"
}

variable "namespace" {
  type        = string
  description = "ServiceAccount/Helm namespace"
  default     = "kube-system"
}

variable "service_account_name" {
  type        = string
  description = "ServiceAccount name"
  default     = "aws-load-balancer-controller"
}

variable "helm_repository" {
  type        = string
  description = "Helm repository URL"
  default     = "https://aws.github.io/eks-charts"
}

variable "helm_chart" {
  type        = string
  description = "Helm chart name"
  default     = "aws-load-balancer-controller"
}

variable "helm_chart_version" {
  type        = string
  description = "Helm chart version (고정 권장)"
  default     = "1.17.1"
}

variable "replica_count" {
  type        = number
  description = "컨트롤러 replica 수"
  default     = 2
}

variable "iam_policy_file" {
  type        = string
  description = "모듈 기준 IAM policy json 상대경로"
  default     = "policy/iam_policy.json"
}

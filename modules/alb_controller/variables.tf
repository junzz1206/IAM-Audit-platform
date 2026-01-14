variable "project_name" {
  type        = string
  description = "프로젝트 이름(태그/리소스 네이밍용)"
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
  description = "EKS Cluster Name"
}

variable "vpc_id" {
  type        = string
  description = "EKS가 붙은 VPC ID"
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC Provider ARN"
}

variable "oidc_issuer_url" {
  type        = string
  description = "EKS OIDC Issuer URL (예: https://oidc.eks.ap-northeast-2.amazonaws.com/id/XXXX)"
}

variable "namespace" {
  type        = string
  description = "ALB Controller가 설치될 네임스페이스"
  default     = "kube-system"
}

variable "service_account_name" {
  type        = string
  description = "ALB Controller ServiceAccount 이름"
  default     = "aws-load-balancer-controller"
}

variable "helm_repo_url" {
  type        = string
  description = "EKS Charts Repo"
  default     = "https://aws.github.io/eks-charts"
}

variable "helm_chart_name" {
  type        = string
  description = "ALB Controller Helm chart name"
  default     = "aws-load-balancer-controller"
}

variable "helm_chart_version" {
  type        = string
  description = "차트 버전(고정 권장). 비워두면 최신으로 설치될 수 있어 재현성이 떨어짐"
  default     = ""
}

variable "replica_count" {
  type        = number
  description = "컨트롤러 replica 수"
  default     = 2
}

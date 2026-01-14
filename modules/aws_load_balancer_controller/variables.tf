variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (권한 조건 스코핑에 사용 가능)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC issuer URL (예: https://oidc.eks.ap-northeast-2.amazonaws.com/id/XXXX)"
  type        = string
}

variable "namespace" {
  description = "Namespace to install controller"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "ServiceAccount name for controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "helm_release_name" {
  description = "Helm release name"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "helm_chart_version" {
  description = "Helm chart version (고정 권장, 예: 1.7.x 등)"
  type        = string
  default     = null
}

variable "iam_policy_json_path" {
  description = "AWS Load Balancer Controller IAM policy JSON file path (repo에 같이 커밋 권장)"
  type        = string
  default     = null
}

variable "load_balancer_name" {
  description = "Ingress에 alb.ingress.kubernetes.io/load-balancer-name으로 고정할 ALB name(선택)"
  type        = string
  default     = null
}

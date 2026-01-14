variable "domain_name" {
  type        = string
  description = "예: rockyvicky.com"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "create_public_zone" {
  type        = bool
  description = "새 계정에서 hosted zone 없으면 true로 생성"
  default     = true
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "EKS OIDC Provider ARN"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "EKS OIDC issuer URL (without https:// if you normalize it in code)"
  type        = string
}

variable "externaldns_namespace" {
  description = "Namespace to install external-dns"
  type        = string
  default     = "kube-system"
}

variable "externaldns_service_account_name" {
  description = "ServiceAccount name for external-dns"
  type        = string
  default     = "external-dns"
}

variable "helm_chart_version" {
  description = "external-dns helm chart version"
  type        = string
  default     = null
}

variable "policy" {
  description = "external-dns policy: sync or upsert-only"
  type        = string
  default     = "upsert-only"
}

variable "txt_owner_id" {
  description = "TXT registry owner id (prevent record ownership conflicts)"
  type        = string
}

# (선택) domain filter를 변수로 받을 거면 추가 권장
variable "domain_filter" {
  description = "Limit external-dns to manage only this domain"
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Existing Route53 public hosted zone id. If set, module will use it instead of lookup by name."
  type        = string
  default     = null
}


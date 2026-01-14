variable "cluster_name" { type = string }
variable "region"       { type = string }
variable "vpc_id"       { type = string }

variable "oidc_provider_arn" { type = string }
variable "oidc_issuer_url"   { type = string }

variable "hosted_zone_id" { type = string }
variable "domain_filter"  { type = string } # "rockyvicky.com"

variable "namespace" {
  type    = string
  default = "kube-system"
}

variable "service_account_name" {
  type    = string
  default = "external-dns"
}

variable "txt_owner_id" { type = string } # 예: "rockyvicky-dev"
variable "policy" {
  type    = string
  default = "upsert-only" # or "sync"
}

variable "chart_version" {
  type    = string
  default = "1.14.5" # 필요 시 조정
}

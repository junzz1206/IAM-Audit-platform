variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC Provider ARN"
}

variable "oidc_issuer_url" {
  type        = string
  description = "EKS OIDC issuer URL (https://...)"
}

variable "hosted_zone_id" {
  type        = string
  description = "Route53 Hosted Zone ID"
}

variable "domain" {
  type        = string
  description = "ExternalDNS domain filter (e.g. rockyvicky.com)"
}

variable "txt_owner_id" {
  type        = string
  description = "ExternalDNS txtOwnerId"
}

variable "policy" {
  type        = string
  description = "ExternalDNS policy (upsert-only or sync)"
  default     = "upsert-only"
}

variable "helm_chart_version" {
  type        = string
  description = "external-dns helm chart version"
  default     = "1.14.4"
}

variable "tags" {
  type        = map(string)
  description = "Tags"
  default     = {}
}

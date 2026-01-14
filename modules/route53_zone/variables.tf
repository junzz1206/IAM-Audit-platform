variable "domain_name" {
  description = "예: rockyvicky.com"
  type        = string
}

variable "create_hosted_zone" {
  description = "빈 계정 bootstrap이면 true, 이미 콘솔에 있으면 false로 조회만"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}

# ExternalDNS 최소권한 정책 만들지 여부
variable "create_externaldns_policy" {
  description = "ExternalDNS용 IAM Policy를 Terraform에서 생성할지"
  type        = bool
  default     = true
}

variable "externaldns_policy_name" {
  description = "ExternalDNS IAM Policy name"
  type        = string
  default     = null
}

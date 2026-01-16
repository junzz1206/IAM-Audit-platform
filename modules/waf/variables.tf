variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "name" {
  type        = string
  default     = ""
  description = "Optional WebACL name. If empty, <project>-<env>-waf"
}

variable "description" {
  type        = string
  default     = "WAFv2 Web ACL for ALB - Regional"
  description = "Web ACL description"
}

variable "tags" {
  type    = map(string)
  default = {}
}

# 운영모드: 처음엔 COUNT로 튜닝 -> 이후 BLOCK로 전환
# - true  => override_action { count {} }
# - false => override_action { none {} } (관리형 룰 기본 액션 적용)
variable "count_mode" {
  type        = bool
  default     = true
  description = "If true, managed rule groups run in COUNT mode initially."
}

# (선택) ALB에 WebACL 연결
variable "associate_to_alb" {
  type        = bool
  default     = true
  description = "If true, associate Web ACL to ALB ARN"
}

variable "alb_arn" {
  type        = string
  default     = ""
  description = "ALB ARN (required if associate_to_alb=true)"
}

# (선택) 로깅
variable "enable_logging" {
  type        = bool
  default     = false
  description = "Enable WAF logging configuration"
}

variable "log_destination_arns" {
  type        = list(string)
  default     = []
  description = "Log destination ARNs (e.g., Kinesis Firehose ARN). Required if enable_logging=true"
}

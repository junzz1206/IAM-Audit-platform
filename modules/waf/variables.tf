variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "name" {
  type        = string
  default     = ""
  description = "Optional WebACL name. If empty, auto = <project>-<env>-waf"
}

variable "description" {
  type    = string
  default = "WAF for ALB (AWS Managed Rules)"
}

variable "enable_logging" {
  type        = bool
  default     = false
  description = "Enable WAF logging (requires log_destination_arns)"
}

variable "log_destination_arns" {
  type        = list(string)
  default     = []
  description = "WAF log destination ARNs (Kinesis Data Firehose recommended)"
}

variable "tags" {
  type    = map(string)
  default = {}
}

# 운영모드 결정: 처음엔 COUNT(=override_action.count)로 튜닝하고 나중에 BLOCK로 바꾸는 게 안전
# - count_mode=true  => override_action { count {} }
# - count_mode=false => override_action { none {} }  (관리형 룰의 기본 액션 적용)
variable "count_mode" {
  type        = bool
  default     = true
  description = "If true, managed rule groups run in COUNT mode initially."
}
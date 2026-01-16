variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
  default     = ""
}

variable "eks_version" {
  type        = string
  description = "EKS version (e.g. 1.29)"
  default     = "1.29"
}

variable "endpoint_public_access" {
  type    = bool
  default = true
}

variable "endpoint_private_access" {
  type    = bool
  default = true
}

variable "admin_cidr_blocks" {
  type        = list(string)
  description = "CIDRs allowed to access EKS public endpoint (when enabled)"
  default     = ["0.0.0.0/0"]
}

# Managed Node Groups (기본: ng-iam / ng-ui)
variable "node_groups" {
  description = "Managed node groups configuration"
  type = map(object({
    desired_size   = number
    min_size       = number
    max_size       = number
    instance_types = list(string)
    labels         = map(string)
  }))
  default = {
    "ng-iam" = {
      desired_size   = 2
      min_size       = 2
      max_size       = 3
      instance_types = ["t3.medium"]
      labels         = { "role" = "iam" }
    }
    "ng-ui" = {
      desired_size   = 2
      min_size       = 2
      max_size       = 3
      instance_types = ["t3.medium"]
      labels         = { "role" = "ui" }
    }
  }
}

# Node SG를 “정석”으로 뽑고 싶으면 true (기존 콘솔 환경과 불일치 시 plan에서 바뀔 수 있음)
variable "create_node_security_group" {
  type        = bool
  description = "Create dedicated node security group and attach via launch template"
  default     = false
}

# validation은 변수 값이 “말이 안 되는 상태”로 들어오는 걸 미리 막는 안전장치
variable "create_oidc_provider" {
  type    = bool
  default = true
}

variable "existing_oidc_provider_arn" {
  type    = string
  default = ""

  validation {
    condition = (
      var.create_oidc_provider
      || (length(trimspace(var.existing_oidc_provider_arn)) > 0)
    )
    error_message = "create_oidc_provider=false 이면 existing_oidc_provider_arn 을 반드시 입력해야 합니다."
  }

  validation {
    condition = (
      var.create_oidc_provider
      || can(regex("^arn:aws:iam::[0-9]{12}:oidc-provider/.+", var.existing_oidc_provider_arn))
    )
    error_message = "existing_oidc_provider_arn 형식이 IAM OIDC Provider ARN이 아닙니다. 예: arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks...."
  }
}

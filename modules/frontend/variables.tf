variable "name_prefix" {
  description = "Prefix for naming (e.g. project-env)"
  type        = string
}

variable "domain_name" {
  description = "Root domain for frontend (e.g. rockyvicky.com)"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID for domain_name"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name for static frontend (must be globally unique)"
  type        = string
}

variable "cloudfront_acm_arn" {
  description = "ACM cert ARN in us-east-1 for CloudFront"
  type        = string
}

variable "distribution_comment" {
  description = "CloudFront distribution comment/name shown in console"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
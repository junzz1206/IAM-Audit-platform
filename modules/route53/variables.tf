variable "domain_name" {
  type        = string
  description = "Hosted Zone domain name (e.g., rockyvicky.com)"
}

variable "private_zone" {
  type        = bool
  default     = false
  description = "Whether to lookup private hosted zone"
}
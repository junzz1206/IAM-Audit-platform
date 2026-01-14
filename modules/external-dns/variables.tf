variable "project_name" { type = string }
variable "env"          { type = string }

variable "cluster_name" { type = string }

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID for rockyvicky.com"
  type        = string
}

variable "domain" {
  type    = string
  default = "rockyvicky.com"
}

variable "tags" {
  type = map(string)
}
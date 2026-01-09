variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "namespaces" {
  type = list(string)
}

variable "extra_labels" {
  type    = map(string)
  default = {}
}

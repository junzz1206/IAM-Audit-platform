variable "name_prefix" { type = string }
variable "env"         { type = string }
variable "tags"        { type = map(string) }

variable "active_instance_id" { type = string }

variable "eip_allocation_id" { type = string }
variable "route_table_id"    { type = string }
variable "dest_cidr"         { type = string }

variable "standby_eni_id" { type = string }

variable "alarm_period" {
  type    = number
  default = 60
}

variable "alarm_evaluation_periods" {
  type    = number
  default = 2
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "alarm_datapoints_to_alarm" {
  type    = number
  default = 2
}
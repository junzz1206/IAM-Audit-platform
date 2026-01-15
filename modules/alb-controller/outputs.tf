output "alb_controller_role_arn" {
  value = aws_iam_role.this.arn
}

output "alb_controller_service_account" {
  value = "${var.namespace}/${var.service_account_name}"
}

output "alb_controller_policy_arn" {
  value = aws_iam_policy.this.arn
}

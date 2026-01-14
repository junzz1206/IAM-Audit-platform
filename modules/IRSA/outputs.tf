output "oidc_issuer_url" {
  value = local.oidc_issuer_url
}

output "oidc_provider_arn" {
  value = local.oidc_provider_arn
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}

output "cluster_autoscaler_role_arn" {
  value = aws_iam_role.cluster_autoscaler.arn
}

output "alb_service_account" {
  value = var.alb_service_account
}

output "cluster_autoscaler_service_account" {
  value = var.cluster_autoscaler_service_account
}

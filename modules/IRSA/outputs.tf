output "oidc_issuer_url" {
  value = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}

output "cluster_autoscaler_role_arn" {
  value = aws_iam_role.cluster_autoscaler.arn
}

output "alb_service_account" {
  value = {
    namespace = "kube-system"
    name      = "aws-load-balancer-controller"
  }
}

output "cluster_autoscaler_service_account" {
  value = {
    namespace = "kube-system"
    name      = "cluster-autoscaler"
  }
}

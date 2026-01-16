output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  value = var.create_oidc_provider ? aws_iam_openid_connect_provider.this[0].arn : var.existing_oidc_provider_arn
}

output "oidc_issuer_url" {
  value = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# Node SG 출력: create_node_security_group=false면 cluster SG로 대체
output "node_security_group_id" {
  value = var.create_node_security_group ? aws_security_group.node[0].id : aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_group_role_arns" {
  value = {
    "node_role" = aws_iam_role.eks_node.arn
  }
}
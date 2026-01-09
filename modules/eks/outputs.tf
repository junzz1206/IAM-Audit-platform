output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_security_group_id" {
  value = aws_eks_node_group.this.resources[0].autoscaling_groups[0].resources[0].instances[0].security_groups[0]
}
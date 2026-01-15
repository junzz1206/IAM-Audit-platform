output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_route_table_id" {
  value = module.network.private_route_table_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "eks_oidc_issuer_url" {
  value = module.eks.oidc_issuer_url
}

output "node_group_role_arns" {
  value = module.eks.node_group_role_arns
}

# WireGuard
output "wireguard_active_instance_id" {
  value = module.wireguard.active_instance_id
}

output "wireguard_standby_instance_id" {
  value = module.wireguard.standby_instance_id
}

output "wireguard_active_eni_id" {
  value = module.wireguard.active_eni_id
}

output "wireguard_standby_eni_id" {
  value = module.wireguard.standby_eni_id
}

# WG failover automation (if module implemented)
output "wg_failover_alarm_name" {
  value = module.wg_failover.alarm_name
}

output "wg_failover_lambda_name" {
  value = module.wg_failover.lambda_name
}

# Valkey
output "valkey_configuration_endpoint" {
  value = module.valkey.configuration_endpoint
}

output "valkey_reader_endpoint" {
  value = module.valkey.reader_endpoint
}

# WAF
output "waf_web_acl_arn" {
  value = module.waf.web_acl_arn
}

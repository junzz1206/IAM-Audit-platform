output "detected_public_ip" {
  value = local.detected_public_ip
}

output "effective_admin_cidrs" {
  value = local.effective_admin_cidrs
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_endpoint" {
  value = module.eks.cluster_endpoint
}

output "alb_controller_role_arn" {
  value = module.irsa.alb_controller_role_arn
}

output "cluster_autoscaler_role_arn" {
  value = module.irsa.cluster_autoscaler_role_arn
}

output "oidc_provider_arn" {
  value = module.irsa.oidc_provider_arn
}

output "wg_eip_public_ip" {
  value = module.wireguard_ha.eip_public_ip 
}

output "wg_eip_allocation_id" {
  value = module.wireguard_ha.eip_allocation_id
}

output "wg_active_eni_id" {
  value = module.wireguard_ha.active_eni_id
}

output "wg_standby_eni_id" {
  value = module.wireguard_ha.standby_eni_id
}

output "private_route_table_id" {
  value = module.network.private_route_table_id
}

output "wg_failover_alarm_name" { 
  value = module.wg_failover.alarm_name 
}

output "wg_failover_lambda" { 
  value = module.wg_failover.lambda_name 
}
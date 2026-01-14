output "hosted_zone_id" {
  value = local.hosted_zone_id
}

output "name_servers" {
  value = local.name_servers
}

output "externaldns_policy_arn" {
  value       = try(aws_iam_policy.externaldns[0].arn, null)
  description = "create_externaldns_policy=true 일 때만 생성됨"
}

output "hosted_zone_id" {
  value = local.hz_id
}

output "externaldns_irsa_role_arn" {
  value = aws_iam_role.externaldns_irsa.arn
}

output "externaldns_policy_arn" {
  value = aws_iam_policy.externaldns.arn
}
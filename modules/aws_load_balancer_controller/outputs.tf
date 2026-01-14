output "irsa_role_arn" {
  value = aws_iam_role.lbc_irsa.arn
}

output "iam_policy_arn" {
  value = aws_iam_policy.lbc.arn
}

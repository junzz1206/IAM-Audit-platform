output "certificate_arn" {
  value = aws_acm_certificate.this.arn
}

output "validation_status" {
  value = aws_acm_certificate_validation.this.id
}

output "san_list" {
  value = aws_acm_certificate.this.subject_alternative_names
}
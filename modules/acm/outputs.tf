locals {
  certificate_arn = var.create_certificate ? aws_acm_certificate.this[0].arn : (
    var.existing_certificate_arn != "" ? var.existing_certificate_arn : data.aws_acm_certificate.existing[0].arn
  )

  san_list = var.create_certificate ? aws_acm_certificate.this[0].subject_alternative_names : []
}

output "certificate_arn" {
  value = local.certificate_arn
}

output "san_list" {
  value = local.san_list
}

output "validation_status" {
  value = var.create_certificate ? aws_acm_certificate_validation.this[0].id : "SKIPPED(reference_mode)"
}

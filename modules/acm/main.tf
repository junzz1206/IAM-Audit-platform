locals {
  sans = distinct(
    concat(
      var.create_wildcard ? ["*.${var.domain_name}"] : [],
      var.additional_sans
    )
  )

  name_tag = var.certificate_name != "" ? var.certificate_name : "acm-${var.domain_name}"
}

############################################
# A) Reference mode (create_certificate=false)
############################################
data "aws_acm_certificate" "existing" {
  count       = var.create_certificate || var.existing_certificate_arn != "" ? 0 : 1
  domain      = var.domain_name
  statuses    = ["ISSUED"]
  most_recent = true
}

############################################
# B) Create mode (create_certificate=true)
############################################
resource "aws_acm_certificate" "this" {
  count = var.create_certificate ? 1 : 0

  domain_name               = var.domain_name
  validation_method         = "DNS"
  subject_alternative_names = local.sans

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = local.name_tag
  })
}

# ACM DNS validation records (only when creating)
resource "aws_route53_record" "validation" {
  for_each = var.create_certificate ? {
    for dvo in aws_acm_certificate.this[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

# Wait until certificate is validated (only when creating)
resource "aws_acm_certificate_validation" "this" {
  count = var.create_certificate ? 1 : 0

  certificate_arn = aws_acm_certificate.this[0].arn

  validation_record_fqdns = [
    for r in aws_route53_record.validation : r.fqdn
  ]

  lifecycle {
    precondition {
      condition     = var.hosted_zone_id != ""
      error_message = "hosted_zone_id must be set when create_certificate=true."
    }
  }
}
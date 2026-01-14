locals {
  # 기본 전략: 1장으로 apex + wildcard
  # - domain_name: rockyvicky.com
  # - SAN: *.rockyvicky.com (+ 필요시 추가 SAN)
  sans = distinct(
    concat(
      var.create_wildcard ? ["*.${var.domain_name}"] : [],
      var.additional_sans
    )
  )

  name_tag = var.certificate_name != "" ? var.certificate_name : "acm-${var.domain_name}"
}

resource "aws_acm_certificate" "this" {
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

# ACM이 요구하는 DNS 검증 레코드들을 Route53에 자동 생성
resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

# 검증 완료까지 Terraform이 기다리게 함 (ALB 붙이기 전에 필수)
resource "aws_acm_certificate_validation" "this" {
  certificate_arn = aws_acm_certificate.this.arn

  validation_record_fqdns = [
    for r in aws_route53_record.validation : r.fqdn
  ]
}
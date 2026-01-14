locals {
  zone_name = "${trim(var.domain_name, ".")}."
}

# (A) 빈 계정이면 Hosted Zone 생성
resource "aws_route53_zone" "this" {
  count = var.create_hosted_zone ? 1 : 0

  name = trim(var.domain_name, ".")
  tags = var.tags
}

# (B) 이미 Hosted Zone이 있으면 조회만
data "aws_route53_zone" "this" {
  count        = var.create_hosted_zone ? 0 : 1
  name         = local.zone_name
  private_zone = false
}

locals {
  hosted_zone_id = var.create_hosted_zone ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.this[0].zone_id
  name_servers   = var.create_hosted_zone ? aws_route53_zone.this[0].name_servers : data.aws_route53_zone.this[0].name_servers
}

# ------------------------------------------------------------
# ExternalDNS 최소권한 IAM Policy (Hosted Zone ID로 스코핑)
# - ExternalDNS는 보통 ListHostedZonesByName, ListResourceRecordSets, ChangeResourceRecordSets 권한이 필요
# - 특히 ChangeResourceRecordSets는 zone ARN 단위로 제한 가능
# ------------------------------------------------------------
data "aws_iam_policy_document" "externaldns" {
  count = var.create_externaldns_policy ? 1 : 0

  statement {
    sid     = "ListZones"
    effect  = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "ChangeRecordsInSpecificZone"
    effect  = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets"
    ]
    resources = [
      "arn:aws:route53:::hostedzone/${local.hosted_zone_id}"
    ]
  }
}

resource "aws_iam_policy" "externaldns" {
  count  = var.create_externaldns_policy ? 1 : 0
  name   = coalesce(var.externaldns_policy_name, "externaldns-${trim(var.domain_name, ".")}")
  policy = data.aws_iam_policy_document.externaldns[0].json
}

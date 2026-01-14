locals {
  # OIDC issuer hostpath: oidc.eks.ap-northeast-2.amazonaws.com/id/XXXX
  oidc_issuer_hostpath = replace(var.cluster_oidc_issuer_url, "https://", "")

  sa_sub = "system:serviceaccount:${var.externaldns_namespace}:${var.externaldns_service_account_name}"

  # Hosted Zone ID 결정 로직
  hz_id = var.create_hosted_zone ? aws_route53_zone.public[0].zone_id : var.hosted_zone_id
}

# (선택) Public Hosted Zone 생성
resource "aws_route53_zone" "public" {
  count = var.create_hosted_zone ? 1 : 0

  name = var.domain_name

  comment = "Public Hosted Zone for ${var.domain_name}"
  tags    = var.tags
}

data "aws_caller_identity" "current" {}

#############################################
# ExternalDNS IRSA Role (AssumeRoleWithWebIdentity)
#############################################
resource "aws_iam_role" "externaldns_irsa" {
  name = "${var.cluster_name}-externaldns"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.cluster_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer_hostpath}:sub" = local.sa_sub
            "${local.oidc_issuer_hostpath}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

#############################################
# ExternalDNS 최소권한 Policy (Hosted Zone 1개로 제한)
#############################################
resource "aws_iam_policy" "externaldns" {
  name = "${var.cluster_name}-ExternalDNS-Route53-${local.hz_id}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Hosted Zone / 레코드 조회는 전체 허용(읽기)
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource",
          "route53:GetHostedZone"
        ]
        Resource = "*"
      },

      # 레코드 변경은 특정 Hosted Zone으로만 제한(쓰기)
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/${local.hz_id}"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "externaldns_attach" {
  role       = aws_iam_role.externaldns_irsa.name
  policy_arn = aws_iam_policy.externaldns.arn
}

#############################################
# Helm: ExternalDNS 설치 (bitnami/external-dns)
#############################################
resource "helm_release" "externaldns" {
  name       = "external-dns"
  namespace  = var.externaldns_namespace

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = var.helm_chart_version

  # SA (IRSA)
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = var.externaldns_service_account_name
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.externaldns_irsa.arn
  }

  # Provider: AWS Route53
  set {
    name  = "provider"
    value = "aws"
  }

  # 안전장치 3종: domainFilter / txt registry / owner id
  set {
    name  = "domainFilters[0]"
    value = var.domain_name
  }
  set {
    name  = "registry"
    value = "txt"
  }
  set {
    name  = "txtOwnerId"
    value = var.txt_owner_id
  }

  # 운영 정책
  set {
    name  = "policy"
    value = var.policy
  }

  # TXT 레코드 prefix(선택) - 충돌 방지에 도움
  set {
    name  = "txtPrefix"
    value = "_externaldns"
  }

  # (중요) 대상 zone을 명시적으로 제한: zoneIdFilters
  # bitnami chart는 extraArgs로 전달 가능
  set {
    name  = "extraArgs[0]"
    value = "--zone-id-filter=${local.hz_id}"
  }

  # (중요) Ingress 기반만 보면 보통 이게 기본인데, 명시해두면 덜 헷갈림
  set {
    name  = "sources[0]"
    value = "ingress"
  }
}
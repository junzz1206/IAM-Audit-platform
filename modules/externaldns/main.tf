resource "aws_iam_role" "externaldns" {
  name = "${var.cluster_name}-externaldns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Federated = var.oidc_provider_arn },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(var.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}",
          "${replace(var.oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# Hosted Zone 제한(중요): rockyvicky.com Hosted Zone만 조작 가능하게
resource "aws_iam_policy" "externaldns" {
  name        = "${var.cluster_name}-externaldns-policy"
  description = "ExternalDNS access limited to hosted zone ${var.hosted_zone_id}"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # zone 조회 권한(일반적으로 필요)
      {
        Effect = "Allow",
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ],
        Resource = "*"
      },

      # 변경 권한은 Hosted Zone에만 제한
      {
        Effect = "Allow",
        Action = [
          "route53:ChangeResourceRecordSets"
        ],
        Resource = "arn:aws:route53:::hostedzone/${replace(var.hosted_zone_id, "/hostedzone/", "")}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "externaldns_attach" {
  role       = aws_iam_role.externaldns.name
  policy_arn = aws_iam_policy.externaldns.arn
}

resource "kubernetes_service_account" "externaldns" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.externaldns.arn
    }
  }
}

resource "helm_release" "externaldns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.chart_version
  namespace  = var.namespace

  values = [
    yamlencode({
      provider = "aws"
      registry = "txt"
      txtOwnerId = var.txt_owner_id

      domainFilters = [var.domain_filter]
      policy        = var.policy

      sources = ["ingress"]
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.externaldns.metadata[0].name
      }

      env = [
        { name = "AWS_REGION", value = var.region }
      ]

      extraArgs = [
        "--aws-zone-type=public",
        "--interval=1m"
      ]
    })
  ]
}

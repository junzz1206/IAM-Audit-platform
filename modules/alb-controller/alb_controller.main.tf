locals {
  oidc_issuer_hostpath = replace(var.oidc_issuer_url, "https://", "")

  role_name   = "${var.project_name}-${var.env}-alb-controller-role"
  policy_name = "${var.project_name}-${var.env}-alb-controller-policy"
}

############################################
# 1) IAM Policy (파일 기반)
############################################
resource "aws_iam_policy" "this" {
  name   = local.policy_name
  policy = file("${path.module}/${var.iam_policy_file}")

  tags = var.tags
}

############################################
# 2) IAM Role (IRSA)
############################################
resource "aws_iam_role" "this" {
  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer_hostpath}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            "${local.oidc_issuer_hostpath}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

############################################
# 3) Kubernetes ServiceAccount
############################################
resource "kubernetes_service_account_v1" "this" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    }

    labels = {
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
    }
  }
}

############################################
# 4) Helm Release (AWS Load Balancer Controller)
############################################
resource "helm_release" "this" {
  name       = "aws-load-balancer-controller"
  namespace  = var.namespace
  repository = var.helm_repository
  chart      = var.helm_chart
  version = var.helm_chart_version != "" ? var.helm_chart_version : null

  set = [
  { name = "clusterName",            value = var.cluster_name },
  { name = "region",                 value = var.region },
  { name = "vpcId",                  value = var.vpc_id },
  { name = "serviceAccount.create",  value = "false" },
  { name = "serviceAccount.name",    value = var.service_account_name },
  { name = "replicaCount",           value = tostring(var.replica_count) },
  ]

  depends_on = [
    kubernetes_service_account_v1.this,
    aws_iam_role_policy_attachment.attach
  ]
}

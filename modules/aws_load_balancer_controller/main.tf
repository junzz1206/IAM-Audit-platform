terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
  }
}

locals {
  # IRSA trust policy에서 쓰는 issuer host/path (https:// 제거)
  oidc_issuer = replace(var.oidc_provider_url, "https://", "")

  # 공식 가이드는 iam_policy.json을 내려받아 policy 생성하는 것을 권장함. :contentReference[oaicite:1]{index=1}
  # Terraform에서는 repo에 iam_policy.json을 함께 두고 file()로 읽는 방식이 가장 재현성 좋음.
  iam_policy_doc = var.iam_policy_json_path != null ? file(var.iam_policy_json_path) : null
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.cluster_name}-alb-controller-irsa"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# 1) 정책은 'iam_policy.json'을 repo에 포함시키는 걸 권장
#   - 설치 가이드도 동일하게 iam_policy.json을 기반으로 policy 생성 :contentReference[oaicite:2]{index=2}
resource "aws_iam_policy" "this" {
  count  = local.iam_policy_doc == null ? 0 : 1
  name   = "${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  policy = local.iam_policy_doc
}

resource "aws_iam_role_policy_attachment" "attach" {
  count      = local.iam_policy_doc == null ? 0 : 1
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this[0].arn
}

# ServiceAccount 생성(이미 helm에서 create=false로 쓰기 때문에 여기서 직접 생성)
resource "kubernetes_service_account_v1" "this" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
    }
  }
}

resource "helm_release" "this" {
  name       = var.helm_release_name
  namespace  = var.namespace
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  
  version    = var.helm_chart_version

  set = [
    {
      name  = "clusterName"
      value = var.cluster_name
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = var.service_account_name
    },
    {
      name  = "region"
      value = var.region
    }
  ]

  depends_on = [
    kubernetes_service_account_v1.this,
    aws_iam_role_policy_attachment.attach
  ]
}
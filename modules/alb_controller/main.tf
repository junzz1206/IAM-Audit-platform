locals {
  # OIDC issuer URL에서 https:// 제거 (조건 key에 쓰임)
  oidc_issuer_hostpath = replace(var.oidc_issuer_url, "https://", "")

  role_name   = "${var.project_name}-${var.env}-alb-controller-role"
  policy_name = "${var.project_name}-${var.env}-alb-controller-policy"
}

############################################
# 1) IAM Policy (ALB Controller 권한)
############################################
# AWS Load Balancer Controller 권한은 매우 길어서 파일로 분리하는 게 유지보수에 유리함.
# (새 채팅방에서 정책 최신본으로 교체/검증하기도 쉬움)
resource "aws_iam_policy" "this" {
  name   = local.policy_name
  policy = file("${path.module}/iam_policy.json")

  tags = var.tags
}

############################################
# 2) IRSA Role (AssumeRoleWithWebIdentity)
############################################
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    # 가장 흔한 실수 포인트:
    # sub 조건은 반드시 "system:serviceaccount:<ns>:<sa>" 형태여야 함
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_hostpath}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

############################################
# 3) ServiceAccount (IRSA annotation)
############################################
resource "kubernetes_service_account" "this" {
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
# 4) Helm install (AWS Load Balancer Controller)
############################################
resource "helm_release" "this" {
  name             = "aws-load-balancer-controller"
  repository       = var.helm_repo_url
  chart            = var.helm_chart_name
  namespace        = var.namespace
  create_namespace = true

  # 버전을 비워두면 최신으로 갈 수 있어서 재현성이 떨어짐.
  # dev.tfvars에서 버전 고정 추천.
  dynamic "version" {
    for_each = var.helm_chart_version == "" ? [] : [var.helm_chart_version]
    content {
      version = var.helm_chart_version
    }
  }

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  # IRSA로 SA를 우리가 만들기 때문에 chart에서는 SA 생성 끔
  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = var.service_account_name
  }

  set {
    name  = "replicaCount"
    value = tostring(var.replica_count)
  }

  depends_on = [
    kubernetes_service_account.this,
    aws_iam_role_policy_attachment.attach
  ]
}

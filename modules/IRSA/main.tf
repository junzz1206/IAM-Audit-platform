# Read EKS OIDC issuer
data "aws_eks_cluster" "this" {
  name = var.eks_cluster_name
}

locals {
  oidc_issuer_url  = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  oidc_issuer_host = replace(local.oidc_issuer_url, "https://", "")

  common_tags = merge(var.tags, {
    Env       = var.env
    ManagedBy = "Terraform"
  })
}

# If we create OIDC provider: need thumbprint
data "tls_certificate" "oidc" {
  count = var.create_oidc_provider ? 1 : 0
  url   = local.oidc_issuer_url
}

# ✅ (선택) OIDC provider 생성
resource "aws_iam_openid_connect_provider" "eks" {
  count = var.create_oidc_provider ? 1 : 0

  url = local.oidc_issuer_url

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    data.tls_certificate.oidc[0].certificates[0].sha1_fingerprint
  ]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.env}-eks-oidc"
  })
}

# ✅ (선택) 기존 OIDC provider 참조
data "aws_iam_openid_connect_provider" "eks" {
  count = var.create_oidc_provider ? 0 : 1
  url   = local.oidc_issuer_url
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.eks[0].arn : data.aws_iam_openid_connect_provider.eks[0].arn
}

# ----------------------------
# IRSA: AWS Load Balancer Controller
# ----------------------------
data "aws_iam_policy_document" "alb_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:${var.alb_service_account.namespace}:${var.alb_service_account.name}"]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.project_name}-${var.env}-irsa-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_assume_role.json
  tags               = local.common_tags
}

# ALB Controller IAM Policy (AWS 권장 정책 기반) - 기존 그대로 유지
data "aws_iam_policy_document" "alb_controller" {
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcPeeringConnections",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:ModifySecurityGroupRules",
      "ec2:UpdateSecurityGroupRuleDescriptionsIngress"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:SetWebAcl",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "alb_controller" {
  name   = "${var.project_name}-${var.env}-policy-alb-controller"
  policy = data.aws_iam_policy_document.alb_controller.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# ----------------------------
# IRSA: Cluster Autoscaler
# ----------------------------
data "aws_iam_policy_document" "ca_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:${var.cluster_autoscaler_service_account.namespace}:${var.cluster_autoscaler_service_account.name}"]
    }
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  name               = "${var.project_name}-${var.env}-irsa-cluster-autoscaler"
  assume_role_policy = data.aws_iam_policy_document.ca_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs",
      "eks:DescribeNodegroup"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name   = "${var.project_name}-${var.env}-policy-cluster-autoscaler"
  policy = data.aws_iam_policy_document.cluster_autoscaler.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ca_attach" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

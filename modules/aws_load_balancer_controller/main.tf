locals {
  oidc_issuer_hostpath = replace(var.cluster_oidc_issuer_url, "https://", "")

  sa_sub = "system:serviceaccount:${var.service_account_namespace}:${var.service_account_name}"

  # LBC 공식 설치 가이드의 기본 iam_policy.json(v2.17.0) 기반으로 Terraform에 내장
  # (Gov/China 리전은 별도 json이 있으니 그 경우 분기 필요)  ※ 우리는 ap-northeast-2라 일반 정책 기준
  # 출처: kubernetes-sigs 공식 설치 가이드에서 iam_policy.json 사용 안내 :contentReference[oaicite:2]{index=2}
  lbc_iam_policy = {
    Version   = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = [
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
            "elasticloadbalancing:DescribeTags",
            "elasticloadbalancing:DescribeTrustStores",
            "elasticloadbalancing:DescribeListenerAttributes",
            "elasticloadbalancing:DescribeCapacityReservation",
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
            "shield:DeleteProtection",
            "shield:DescribeSubscription",
            "shield:ListProtections"
          ]
          Resource = "*"
        },

        {
          Effect = "Allow"
          Action = [
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:RevokeSecurityGroupIngress"
          ]
          Resource = "*"

          # 스코프다운(선택): 특정 VPC에서만 SG 인그레스/리보크 허용
          # (안전하게 “우리 VPC에서 만든 SG”만 만지게 하려는 용도)
          # VPC 조건은 LBC 문서에 예시가 있음 :contentReference[oaicite:3]{index=3}
          Condition = var.iam_policy_scope_to_vpc ? {
            ArnEquals = {
              "ec2:Vpc" = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:vpc/${var.vpc_id}"
            }
          } : null
        },

        {
          Effect = "Allow"
          Action = [
            "ec2:CreateSecurityGroup",
            "ec2:CreateTags",
            "ec2:DeleteTags",
            "ec2:DeleteSecurityGroup"
          ]
          Resource = "*"
        },

        {
          Effect = "Allow"
          Action = [
            "ec2:AuthorizeSecurityGroupEgress",
            "ec2:RevokeSecurityGroupEgress"
          ]
          Resource = "*"
        },

        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:CreateLoadBalancer",
            "elasticloadbalancing:CreateTargetGroup",
            "elasticloadbalancing:CreateListener",
            "elasticloadbalancing:DeleteListener",
            "elasticloadbalancing:CreateRule",
            "elasticloadbalancing:DeleteRule",
            "elasticloadbalancing:ModifyLoadBalancerAttributes",
            "elasticloadbalancing:SetIpAddressType",
            "elasticloadbalancing:SetSecurityGroups",
            "elasticloadbalancing:SetSubnets",
            "elasticloadbalancing:DeleteLoadBalancer",
            "elasticloadbalancing:ModifyTargetGroup",
            "elasticloadbalancing:ModifyTargetGroupAttributes",
            "elasticloadbalancing:DeleteTargetGroup",
            "elasticloadbalancing:RegisterTargets",
            "elasticloadbalancing:DeregisterTargets",
            "elasticloadbalancing:ModifyListener",
            "elasticloadbalancing:AddListenerCertificates",
            "elasticloadbalancing:RemoveListenerCertificates",
            "elasticloadbalancing:ModifyRule",
            "elasticloadbalancing:SetWebAcl",
            "elasticloadbalancing:ModifyListenerAttributes",
            "elasticloadbalancing:ModifyCapacityReservation"
          ]
          Resource = "*"
        },

        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:AddTags",
            "elasticloadbalancing:RemoveTags"
          ]
          Resource = [
            "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
          ]
        }
      ],
      []
    )
  }
}

data "aws_caller_identity" "current" {}

# IRSA Role (Trust Policy)
resource "aws_iam_role" "lbc_irsa" {
  name = "${var.cluster_name}-aws-load-balancer-controller"

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

# IAM Policy for LBC
resource "aws_iam_policy" "lbc" {
  name   = "${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  policy = jsonencode(local.lbc_iam_policy)
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "lbc_attach" {
  role       = aws_iam_role.lbc_irsa.name
  policy_arn = aws_iam_policy.lbc.arn
}

# Helm install: aws-load-balancer-controller
# (Helm repo는 EKS charts 사용)
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = var.service_account_namespace
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.helm_chart_version

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

  # IRSA 사용: SA는 이미 존재한다고 가정(혹은 별도로 만들고 annotation만)
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = var.service_account_name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lbc_irsa.arn
  }

  # 운영 편의상 replicas 2 (너희도 2/2로 운용했음)
  set {
    name  = "replicaCount"
    value = "2"
  }
}

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.helm_chart_version

  values = [yamlencode({
    provider = "aws"

    serviceAccount = {
      create = false
      name   = "external-dns"
    }

    domainFilters = [var.domain]

    policy     = var.policy
    registry   = "txt"
    txtOwnerId = var.txt_owner_id

    sources = ["ingress"]

    logLevel = "info"
  })]

  depends_on = [
    kubernetes_service_account_v1.external_dns
  ]
}
resource "helm_release" "external_dns" {
  name       = "external-dns"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.14.4"

  values = [yamlencode({
    provider = "aws"

    serviceAccount = {
      create = false
      name   = "external-dns"
    }

    domainFilters = [
      var.domain
    ]

    policy = "upsert-only"

    registry = "txt"
    txtOwnerId = "${var.project_name}-${var.env}"

    sources = [
      "ingress"
    ]

    aws = {
      zoneType = "public"
    }

    logLevel = "info"
  })]

  depends_on = [
    kubernetes_service_account.external_dns
  ]
}
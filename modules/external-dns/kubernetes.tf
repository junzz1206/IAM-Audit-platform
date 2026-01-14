resource "kubernetes_service_account" "external_dns" {
  metadata {
    name      = "external-dns"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
    }
  }
}
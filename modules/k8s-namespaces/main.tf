resource "kubernetes_namespace_v1" "this" {
  for_each = toset(var.namespaces)

  metadata {
    name = each.value

    labels = merge(var.extra_labels, {
      project = var.project_name
      env     = var.env
      owner   = "CloudInfra"
      purpose = each.value
    })
  }
}

resource "kubernetes_namespace" "example" {
  metadata {
    name = lower(random_string.random.result)
  }
}

resource "random_string" "random" {
  length  = 8
  upper   = false
  special = false
  numeric = false
}

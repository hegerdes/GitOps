resource "kubernetes_namespace" "example" {
  metadata {
    name = random_string.random.result
  }
}

resource "random_string" "random" {
  length  = 8
  special = false
}

resource "kubernetes_namespace" "example" {
  metadata {
    name = "my-first-namespace"
  }
}

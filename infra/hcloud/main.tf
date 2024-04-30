# resource "kubernetes_namespace" "example" {
#   metadata {
#     name = "my-first-namespace"
#   }
# }


resource "hcloud_network" "my_k8s_network" {
  name     = "demo"
  ip_range = "10.0.0.0/16"
}

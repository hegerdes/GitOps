resource "hcloud_network" "demo" {
  name     = "demo"
  ip_range = "10.10.0.0/16"
}

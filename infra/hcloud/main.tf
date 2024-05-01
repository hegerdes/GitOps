resource "hcloud_placement_group" "demo" {
  name = random_string.random.result
  type = "spread"
  labels = {
    key = "demo"
  }
}
resource "random_string" "random" {
  length  = 8
  special = false
}

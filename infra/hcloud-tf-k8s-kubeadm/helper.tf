# Helper: tf destroy -target hcloud_server.worker_pool_arm64 -target hcloud_server.worker_pool_amd64 -target hcloud_server.control_plane_pool
# ################# SSH-Key #################
resource "hcloud_ssh_key" "default" {
  for_each   = toset(local.ssh_keys)
  name       = sha256(each.key)
  public_key = each.key
}

# ################# Firewall #################
resource "hcloud_firewall" "dynamic" {
  for_each = {
    for index, rule in var.firewall_rules :
    rule.name => rule
  }

  name = each.value.name
  labels = {
    managedby = "terraform"
  }
  apply_to {
    label_selector = each.value.label_selector
  }
  dynamic "rule" {
    for_each = contains(["tcp", "udp", "icmp", "gre", "esp"], lower(each.value.protocol)) ? [1] : []
    content {
      direction       = each.value.direction
      protocol        = each.value.protocol
      port            = each.value.ports
      source_ips      = each.value.source_ips
      destination_ips = each.value.destination_ips
    }
  }
}

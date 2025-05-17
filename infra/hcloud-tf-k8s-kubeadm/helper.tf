# Helper: tf destroy -target hcloud_server.worker_pool_arm64 -target hcloud_server.worker_pool_amd64 -target hcloud_server.control_plane_pool
# ################# SSH-Key #################
resource "tls_private_key" "dummy" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# Create a new SSH key
resource "hcloud_ssh_key" "dummy" {
  name       = "dummy-key"
  public_key = tls_private_key.dummy.public_key_openssh
}
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

  dynamic "apply_to" {
    for_each = each.value.label_selectors
    content {
      label_selector = apply_to.value
    }
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

################### DATA #################
data "azurerm_key_vault" "hegerdes" {
  name                = "hegerdes"
  resource_group_name = "default"
}

data "azurerm_key_vault_secret" "hcloud_token" {
  name         = "hcloud-k8s-token"
  key_vault_id = data.azurerm_key_vault.hegerdes.id
}

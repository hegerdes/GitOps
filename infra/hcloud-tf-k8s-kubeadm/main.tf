# ################# LOCALS #################
locals {
  ssh_keys = flatten([for pool in var.node_pools : [for key in pool.ssh_key_paths : file(key)]])
  default_tags = {
    task = "k8s",
  }

  loadbalancers = { for index, lb in var.loadbancers : lb.name => merge(lb, {
    tags       = local.default_tags
    private_ip = cidrhost("10.0.0.0/24", index + 8)
  }) }

  node_pools = { for index, pool in var.node_pools :
    pool.name => merge(
      pool, {
        user_data = templatefile(pool.cloud_init_path, {
          ssh_key      = [for key in pool.ssh_key_paths : file(key)]
          network_role = "client"
          nat_enabled  = !var.per_instance_ipv4
        })
        tags                 = merge(pool.tags, local.default_tags)
        ssh_keys             = [for key in hcloud_ssh_key.default : key.name]
        network_name         = hcloud_network.k8s_network.name
        location             = var.location
        public_ipv4          = var.per_instance_ipv4
        private_ip_addresses = try([for i in range(pool.size) : cidrhost("10.0.${index + 1}.0/24", i + 8)], [])
      }
    )
  }
}

# ################# Network #################
resource "hcloud_network" "k8s_network" {
  name     = var.vnet_name
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "my_subnets" {
  type         = "cloud"
  network_id   = hcloud_network.k8s_network.id
  network_zone = "eu-central"
  ip_range     = "10.0.${count.index}.0/24"
  count        = length(var.node_pools) + 1
}

resource "hcloud_network_route" "my_routes" {
  for_each = {
    for index, route in var.vnet_routes :
    route.name => route
  }
  network_id  = hcloud_network.k8s_network.id
  destination = each.value.destination
  gateway     = each.value.gateway
}

# ################# Server #################
module "node_pools" {
  source   = "hegerdes/hetzner-node-pool/hcloud"
  version  = "~>1"
  for_each = local.node_pools
  # for_each = {}

  name          = each.value.name
  size          = each.value.size
  image         = each.value.image
  location      = each.value.location
  instance_type = each.value.instance
  ssh_keys      = each.value.ssh_keys
  vm_names      = each.value.vm_names
  public_ipv4   = each.value.public_ipv4

  tags                 = each.value.tags
  user_data            = each.value.user_data
  network_name         = each.value.network_name
  private_ip_addresses = each.value.private_ip_addresses
  snapshot_image       = strcontains(each.value.image, "k8s")

  depends_on = [hcloud_network.k8s_network]
}

# ################# LB #################
module "loadbalancers" {
  source   = "hegerdes/hetzner-loadbalancer/hcloud"
  version  = "~>0.1"
  for_each = local.loadbalancers
  # for_each = {}

  location   = var.location
  network_id = hcloud_network.k8s_network.id
  name       = each.value.name
  services   = try(each.value.services, [])
  targets    = try(each.value.targets, [])
  tags       = each.value.tags
  private_ip = each.value.private_ip
}

# Create manager VM
resource "hcloud_server" "manager_nodes" {
  count       = var.manager_vm_create ? 1 : 0
  name        = "manager-node"
  image       = "debian-12"
  server_type = "cax11"
  location    = var.location
  user_data = templatefile("../data/cloud-init-default.yml", {
    ssh_key      = local.ssh_keys
    network_role = "gateway"
    nat_enabled  = !var.per_instance_ipv4
  })
  labels = {
    managedby = "terraform"
    task      = "manager"
    manager   = "true"
  }
  ssh_keys = [for key in hcloud_ssh_key.default : key.id]
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
  network {
    network_id = hcloud_network.k8s_network.id
    ip         = "10.0.0.2"
  }
  lifecycle {
    ignore_changes = [
      ssh_keys,
      user_data
    ]
  }
}

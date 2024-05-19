# ################# LOCALS #################
locals {
  controlplane_internel_lb_ip    = "10.0.0.10"
  controlplane_internal_endpoint = "${local.cluster_name}-cp-internal"
  controlplane_public_endpoint   = var.controlplane_endpoint
  cluster_name                   = var.cluster_name
  ssh_keys                       = flatten([for pool in var.node_pools : [for key in pool.ssh_key_paths : file(key)]])
  subnets                        = [for index in range(length(var.node_pools) + 1) : "10.0.${index}.0/24"]

  cloudflare_dns = var.dns_record.create && var.dns_record.provider == "cloudflare" ? { a = module.loadbalancer.lb_ipv4, aaaa = module.loadbalancer.lb_ipv6 } : {}
  aws_route53    = var.dns_record.create && var.dns_record.provider == "aws" ? { a = module.loadbalancer.lb_ipv4, aaaa = module.loadbalancer.lb_ipv6 } : {}

  certSANs = distinct(concat([
    local.controlplane_internel_lb_ip,
    local.controlplane_internal_endpoint,
    local.controlplane_internal_endpoint,
    local.controlplane_public_endpoint,
    module.loadbalancer.lb_ipv6,
    module.loadbalancer.lb_ipv4
  ]))

  node_pools = { for index, pool in var.node_pools :
    pool.name => merge(
      pool, {
        user_data            = data.talos_machine_configuration.this[pool.name].machine_configuration
        tags                 = merge(pool.tags, local.default_tags)
        ssh_keys             = [for key in hcloud_ssh_key.default : key.name]
        network_name         = hcloud_network.k8s_network.name
        location             = pool.location != "null" ? pool.location : var.location
        private_ip_addresses = try([for i in range(pool.size) : cidrhost("10.0.${index + 1}.0/24", i + 8)], [])
      }
    )
  }
  default_tags = {
    task      = "k8s",
    managedby = "terraform"
  }
}

# ################# Talos #################
resource "talos_machine_secrets" "this" {}

# create the worker/controlplane config and apply patch
data "talos_machine_configuration" "this" {
  for_each = { for index, pool in var.node_pools : pool.name => pool }

  cluster_name     = local.cluster_name
  cluster_endpoint = "https://${local.controlplane_internal_endpoint}:6443"
  machine_type     = each.value.tags.role
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  docs             = false
  config_patches = [
    templatefile("${path.module}/${each.value.talos_conf_patch}", {
      certSANs                       = local.certSANs,
      subnets                        = local.subnets,
      controlplane_endpoint_internal = local.controlplane_internal_endpoint,
      controlplane_internal_ip       = local.controlplane_internel_lb_ip
      extraArgsApiServer             = var.api_server_extra_args
    })
  ]
}

# create the talos client config
data "talos_client_configuration" "this" {
  cluster_name         = local.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints = [
    module.loadbalancer.lb_ipv4
  ]
}

# kubeconfig
data "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for pool in module.node_groups : pool.ips[0]][0]
  timeouts = {
    read = "1h"
  }
}

# bootstrap the cluster
resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration

  endpoint = [for pool in module.node_groups : pool.ips[0]][0]
  node     = [for pool in module.node_groups : pool.ips[0]][0]
}

# ################# Server #################
module "node_groups" {
  source  = "hegerdes/hetzner-node-pool/hcloud"
  version = "~>0.2"

  for_each = local.node_pools
  # for_each = {}

  name           = each.value.name
  size           = each.value.size
  image          = each.value.image
  location       = each.value.location
  instance_type  = each.value.instance
  ssh_keys       = each.value.ssh_keys
  snapshot_image = true

  tags                 = each.value.tags
  user_data            = each.value.user_data
  network_name         = each.value.network_name
  private_ip_addresses = each.value.private_ip_addresses

  depends_on = [hcloud_network.k8s_network, hcloud_network_subnet.subnets]
}

# ################# SSH-Key #################
resource "hcloud_ssh_key" "default" {
  for_each   = toset(local.ssh_keys)
  name       = sha256(each.key)
  public_key = each.key
}

# ################# Network #################
resource "hcloud_network" "k8s_network" {
  name     = "k8s-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "subnets" {
  for_each     = toset(local.subnets)
  type         = "cloud"
  ip_range     = each.key
  network_zone = "eu-central"
  network_id   = hcloud_network.k8s_network.id
}

# ################# LB #################
module "loadbalancer" {
  source  = "hegerdes/hetzner-loadbalancer/hcloud"
  version = "~>0.1"

  network_id = hcloud_network.k8s_network.id
  name       = "controlplane"
  location   = var.location
  private_ip = local.controlplane_internel_lb_ip
  tags = merge(local.default_tags, {
    task      = "lb"
    k8s       = "cp-lb"
    lb        = "true"
    k8s-cp-lb = "true"
  })

  targets = [{
    name   = "controlplanes"
    type   = "label_selector"
    target = "k8s_control_plane"
  }]

  services = [{
    name        = "controlplane"
    protocol    = "tcp"
    source_port = 6443
    target_port = 6443
  }]

  depends_on = [hcloud_network.k8s_network, hcloud_network_subnet.subnets]
}

# ################# DNS #################

# Cloudflare
resource "cloudflare_record" "api_server" {
  for_each = local.cloudflare_dns
  zone_id  = var.dns_record.zone
  name     = var.controlplane_endpoint
  value    = each.value
  type     = upper(each.key)
  comment  = "Managed by terraform"
}

# AWS Route53
resource "aws_route53_record" "api_server" {
  for_each = local.aws_route53
  zone_id  = var.dns_record.zone
  name     = var.controlplane_endpoint
  type     = upper(each.key)
  records  = [each.value]
}

# ################# LOCALS #################
locals {
  cp_internel_lb_ip    = "10.0.0.10"
  cp_internal_endpoint = "${local.cluster_name}-cp-internal"
  cp_public_endpoint   = var.controlplane_endpoint
  node_pool_ips        = flatten([for index, pool in module.node_groups : pool.vm_ips])
  cluster_name         = var.cluster_name
  subnets              = [for index in range(length(var.node_pools) + 1) : "10.0.${index}.0/24"]
  ssh_keys             = flatten([for pool in var.node_pools : [for key in pool.ssh_key_paths : file(key)]])

  # DNS
  dns_records    = { a = module.loadbalancer.lb_ipv4, aaaa = module.loadbalancer.lb_ipv6 }
  cloudflare_dns = var.dns_record.create && var.dns_record.provider == "cloudflare" ? local.dns_records : {}
  aws_route53    = var.dns_record.create && var.dns_record.provider == "aws" ? local.dns_records : {}

  # CertSANs
  certSANsAll = flatten([local.certSANs, [module.loadbalancer.lb_ipv6, module.loadbalancer.lb_ipv4]])
  certSANs = distinct(concat([
    local.cp_internel_lb_ip,
    local.cp_internal_endpoint,
    local.cp_public_endpoint,
  ]))

  # IP map configs
  talos_apply_use_pvt_ip = true
  raw_server_list        = flatten([for pool in module.node_groups : [for vm in pool.vms_raw : vm]])
  vm_pvt_ip_map          = { for vm in local.raw_server_list : (vm.network[*].ip)[0] => vm }
  private_ips            = flatten([for pool in local.node_pools : [for ip in pool.private_ip_addresses : ip]])

  # Node Pools
  node_pools = { for index, pool in var.node_pools :
    pool.name => merge(
      pool, {
        user_data            = data.talos_machine_configuration.this[pool.name].machine_configuration
        tags                 = merge(pool.tags, local.default_tags, { pool = pool.name })
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

# Ensures that current machine configuration is afer servers are created
resource "talos_machine_configuration_apply" "this" {
  for_each                    = toset(local.private_ips)
  endpoint                    = local.cp_public_endpoint
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[local.vm_pvt_ip_map[each.key].labels.pool].machine_configuration

  node = local.talos_apply_use_pvt_ip ? each.key : local.vm_pvt_ip_map[each.key].ipv4_address
  # node       = local.vm_pvt_ip_map[each.key].ipv4_address
  depends_on = [module.node_groups]
}

# create the worker/controlplane config and apply patches
data "talos_machine_configuration" "this" {
  for_each = { for index, pool in var.node_pools : pool.name => pool }

  cluster_name       = local.cluster_name
  cluster_endpoint   = "https://${local.cp_internal_endpoint}:6443"
  machine_type       = each.value.tags.role
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.cluster_version
  talos_version      = var.talos_version
  docs               = false
  config_patches = [for patch in each.value.machine_patches :
    templatefile("${path.module}/${patch}", {
      machineCertSANs                = local.certSANs,
      apiServerCertSANs              = local.certSANsAll,
      subnets                        = local.subnets,
      controlplane_endpoint_internal = local.cp_internal_endpoint,
      controlplane_internal_ip       = local.cp_internel_lb_ip
      extraArgsApiServer             = var.api_server_extra_args
      nodeLabels                     = { pool = each.value.name }
      nodeRole                       = each.value.tags.role
    })
  ]
}

# create the talos client config
data "talos_client_configuration" "this" {
  cluster_name         = local.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = compact([for x in local.node_pool_ips : can(regex("::", x)) ? "" : x])
  nodes                = compact([for x in local.node_pool_ips : can(regex("::", x)) ? "" : x])
}

# create kubeconfig
# resource "talos_cluster_kubeconfig" "this" {
data "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for pool in module.node_groups : pool.vm_ips[0]][0]
  timeouts = {
    read = "8h"
  }
}

# bootstrap the cluster
resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration

  endpoint = [for pool in module.node_groups : pool.vm_ips[0]][0]
  node     = [for pool in module.node_groups : pool.vm_ips[0]][0]
}

# ################# Server #################
module "node_groups" {
  source  = "hegerdes/hetzner-node-pool/hcloud"
  version = "~>1"

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
  for_each   = { for x in distinct(local.ssh_keys) : sha1(x) => x }
  name       = sha1(each.value)
  public_key = each.value
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
  private_ip = local.cp_internel_lb_ip
  tags = merge(local.default_tags, {
    task      = "lb"
    k8s       = "cp-lb"
    lb        = "true"
    k8s-cp-lb = "true"
  })

  targets = [{
    name   = "controlplanes"
    type   = "label_selector"
    target = "k8s"
  }]

  services = [
    {
      name        = "controlplane"
      protocol    = "tcp"
      source_port = 6443
      target_port = 6443
    },
    {
      name        = "talos"
      protocol    = "tcp"
      source_port = 50000
      target_port = 50000
  }]

  depends_on = [hcloud_network.k8s_network, hcloud_network_subnet.subnets]
}

# ############### FIREWALL ##############
resource "hcloud_firewall" "block" {
  name = "block-all"
  apply_to {
    label_selector = "k8s"
  }
  apply_to {
    label_selector = "hcloud/node-group"
  }
}

resource "hcloud_firewall" "talos" {
  name = "talos"

  apply_to {
    label_selector = "k8s"
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "50000-50001"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

# ################# DNS #################

# Cloudflare
resource "cloudflare_record" "api_server" {
  for_each = local.cloudflare_dns
  zone_id  = var.dns_record.zone
  name     = var.controlplane_endpoint
  content  = each.value
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

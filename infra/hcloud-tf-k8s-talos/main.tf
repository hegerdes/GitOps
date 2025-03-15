# ################# LOCALS #################
locals {
  cp_internel_lb_ip    = "10.0.0.10"
  cp_internal_endpoint = var.controlplane_endpoint
  cp_public_endpoint   = var.controlplane_endpoint
  cluster_name         = var.cluster_name
  ipv6_enabled         = true
  subnets              = [for index in range(length(var.node_pools) + 1) : "10.0.${index}.0/24"]
  ssh_keys             = flatten([for pool in var.node_pools : [for key in pool.ssh_key_paths : file(key)]])
  # node_pool_ips        = flatten([for index, pool in module.node_pools : pool.vm_ips])

  # DNS
  dns_records    = { a = module.loadbalancer.lb_ipv4, aaaa = module.loadbalancer.lb_ipv6 }
  cloudflare_dns = var.dns_record.create && var.dns_record.provider == "cloudflare" ? local.dns_records : {}
  aws_route53    = var.dns_record.create && var.dns_record.provider == "aws" ? local.dns_records : {}

  default_tags = {
    task      = "k8s",
    managedby = "terraform"
  }

  # CertSANs
  certSANsAll = flatten([local.certSANs, [module.loadbalancer.lb_ipv6, module.loadbalancer.lb_ipv4]])
  certSANs = distinct(concat([
    local.cp_internel_lb_ip,
    local.cp_internal_endpoint,
    local.cp_public_endpoint,
  ]))

  # IP map configs
  talos_apply_use_pvt_ip = true
  raw_server_list        = flatten([for pool in module.node_pools : [for vm in pool.vms_raw : vm]])
  vm_pvt_ip_map          = { for vm in local.raw_server_list : (vm.network[*].ip)[0] => vm }
  private_ips            = flatten([for pool in local.node_pools : [for ip in pool.private_ip_addresses : ip]])
  private_ips_map        = { for vm in local.raw_server_list : vm.name => (vm.network[*].ip)[0] }
  private_cp_ips         = [for ip, vm in local.vm_pvt_ip_map : ip if contains(keys(vm.labels), "k8s_control_plane")]

  # Talos endpoints
  talos_endpoint   = local.talos_apply_use_pvt_ip ? local.cp_public_endpoint : null
  talos_cp_node_ip = local.talos_apply_use_pvt_ip ? try(local.private_cp_ips[0], "") : try([for pool in module.node_pools : pool.vm_ips[0]][0], "")

  # Node Pools
  node_pools = { for index, pool in var.node_pools :
    pool.name => merge(
      pool, {
        user_data            = data.talos_machine_configuration.this[pool.name].machine_configuration
        tags                 = merge(pool.tags, local.default_tags, { pool = pool.name })
        ssh_keys             = concat([for key in hcloud_ssh_key.default : key.name], [hcloud_ssh_key.dummy.id])
        network_name         = hcloud_network.k8s_network.name
        location             = pool.location != "null" ? pool.location : var.location
        private_ip_addresses = try([for i in range(pool.size) : cidrhost("10.0.${index + 1}.0/24", i + 8)], [])
      }
    )
  }

  # Autoscaler
  autoscale_node_conf = compact([for k, v in data.talos_machine_configuration.this : v.machine_type == "worker" ? v.machine_configuration : null])[0]
  cluster-config = base64encode(jsonencode(
    {
      imagesForArch = {
        arm64 = "name=${try(compact([for k, v in local.node_pools : strcontains(v.image, "arm64") ? v.image : null])[0], "")}"
        amd64 = "name=${try(compact([for k, v in local.node_pools : strcontains(v.image, "amd64") ? v.image : null])[0], "")}"
      },
      nodeConfigs = {
        cas-arm-small = {
          cloudInit = jsonencode(yamldecode(local.autoscale_node_conf)),
          labels = {
            "node.kubernetes.io/role" = "autoscaler-node"
          }
        }
        cas-amd-small = {
          cloudInit = jsonencode(yamldecode(local.autoscale_node_conf)),
          labels = {
            "node.kubernetes.io/role" = "autoscaler-node"
          }
        }
      }
    }
  ))
}

# ################# Talos #################
resource "talos_machine_secrets" "this" {}

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
      apiServerCertSANs              = local.certSANs,
      subnets                        = local.subnets,
      controlplane_endpoint_internal = local.cp_internal_endpoint,
      controlplane_internal_ip       = local.cp_internel_lb_ip
      ipv6_enabled                   = local.ipv6_enabled
      extraArgsApiServer             = var.api_server_extra_args
      nodeRole                       = each.value.tags.role
      nodeLabels = {
        "pool"              = each.value.name,
        "openebs.io/engine" = "mayastor"
      }
    })
  ]
}

# create the talos client config
data "talos_client_configuration" "this" {
  cluster_name         = local.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [var.controlplane_endpoint]
  nodes                = local.private_ips
}

# create kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  client_configuration         = talos_machine_secrets.this.client_configuration
  certificate_renewal_duration = "2h"
  endpoint                     = local.talos_endpoint
  node                         = local.talos_cp_node_ip

  depends_on = [
    talos_machine_bootstrap.this
  ]
}

# bootstrap the cluster
resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = local.talos_endpoint
  node                 = local.talos_cp_node_ip
}

# Ensures that current machine configuration is afer servers are created
resource "talos_machine_configuration_apply" "this" {
  for_each                    = toset(local.private_ips)
  endpoint                    = local.cp_public_endpoint
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[local.vm_pvt_ip_map[each.key].labels.pool].machine_configuration

  node       = local.talos_apply_use_pvt_ip ? each.key : local.vm_pvt_ip_map[each.key].ipv4_address
  depends_on = [module.node_pools]
}

# ################# Server #################
module "node_pools" {
  source  = "hegerdes/hetzner-node-pool/hcloud"
  version = "~>1"

  for_each = local.node_pools

  name           = each.value.name
  size           = each.value.size
  image          = each.value.image
  location       = each.value.location
  instance_type  = each.value.instance
  ssh_keys       = each.value.ssh_keys
  snapshot_image = true
  # public_ipv4    = false

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

# RSA key of size 4096 bits
resource "tls_private_key" "dummy" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create a new SSH key
resource "hcloud_ssh_key" "dummy" {
  name       = "dummy-key"
  public_key = tls_private_key.dummy.public_key_openssh
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
resource "cloudflare_dns_record" "api_server" {
  for_each = local.cloudflare_dns
  zone_id  = var.dns_record.zone
  name     = var.controlplane_endpoint
  content  = each.value
  type     = upper(each.key)
  ttl      = try(each.value.ttl, 3600)
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

# ################# Export Autoscale Conf #################

data "azurerm_key_vault" "hegerdes" {
  name                = "hegerdes"
  resource_group_name = "default"
}

resource "azurerm_key_vault_secret" "k8s-hetzner-custer-autoscale-conf" {
  name         = "k8s-hetzner-custer-autoscale-conf"
  value        = local.cluster-config
  key_vault_id = data.azurerm_key_vault.hegerdes.id
}

# import {
#   to = azurerm_key_vault_secret.k8s-hetzner-custer-autoscale-conf
#   id = "https://hegerdes.vault.azure.net/secrets/k8s-hetzner-custer-autoscale-conf/aeef5ae9ad1a4eeba182300aff937dcb"
# }

# ################# Output #################
resource "local_sensitive_file" "machineconf" {
  for_each = data.talos_machine_configuration.this
  content  = each.value.machine_configuration
  filename = "out/machine_configuration-${each.key}.yaml"
}
resource "local_sensitive_file" "talosclientconf" {
  content  = data.talos_client_configuration.this.talos_config
  filename = "out/talosconfig.yaml"
}

resource "local_sensitive_file" "kubeconf" {
  content  = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "out/kubeconfig.yaml"
}

output "certSANs" {
  value = local.certSANsAll
}
output "vm_pool_ips" {
  value = { for index, pool in module.node_pools : pool.name => pool.vm_ips }
}
output "vm_pool_names" {
  value = { for index, pool in module.node_pools : pool.name => pool.vm_names }
}
output "vm_pool_pvt_ips" {
  value = local.private_ips_map
}
output "vm_pool_public_ips" {
  value = merge(local.pool_cp_public_ips, local.pool_worker_public_ips)
}
output "lb_endpoint" {
  value = local.cp_public_endpoint
}

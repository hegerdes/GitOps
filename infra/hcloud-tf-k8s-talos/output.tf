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
  filename = "out/kubeconfig.yaml"
  content = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = local.cluster_name
      cluster = {
        server                     = "https://${local.cp_public_endpoint}:6443"
        certificate-authority-data = talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate
      }
    }]
    users = [{
      name = "admin@${local.cluster_name}"
      user = {
        client-certificate-data = talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate
        client-key-data         = talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key
      }
    }]
    contexts = [{
      name = "admin@${local.cluster_name}"
      context = {
        cluster   = local.cluster_name
        namespace = "default"
        user      = "admin@${local.cluster_name}"
      }
    }]
    current-context = "admin@${local.cluster_name}"
  })
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

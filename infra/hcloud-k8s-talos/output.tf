# ################# Output #################
resource "local_sensitive_file" "machineconf" {
  for_each = data.talos_machine_configuration.this
  content  = each.value.machine_configuration
  filename = "out/machine_configuration-${md5(each.value.machine_configuration)}.yaml"
}
resource "local_sensitive_file" "talosclientconf" {
  content  = data.talos_client_configuration.this.talos_config
  filename = "out/client_configuration.yaml"
}
resource "local_sensitive_file" "kubeconf" {
  content = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = local.cluster_name
      cluster = {
        server                     = "https://${local.controlplane_public_endpoint}:6443"
        certificate-authority-data = data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate
      }
    }]
    users = [{
      name = "admin@${local.cluster_name}"
      user = {
        client-certificate-data = data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate
        client-key-data         = data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key
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
  # content  = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "out/kubeconf.yaml"
}

output "vm_pool_ips" {
  value = { for index, pool in module.node_groups : index => pool.ips }
}
output "vm_pool_names" {
  value = { for index, pool in module.node_groups : index => pool.names }
}

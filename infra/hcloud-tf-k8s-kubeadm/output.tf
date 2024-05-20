# ################# Output #################
output "vm_pool_ips" {
  value = { for index, pool in module.node_groups : index => pool.ips }
}
output "vm_pool_names" {
  value = { for index, pool in module.node_groups : index => pool.names }
}
output "manager_nodes_ips" {
  value = concat(hcloud_server.manager_nodes[*].ipv4_address, hcloud_server.manager_nodes[*].ipv6_address)
}

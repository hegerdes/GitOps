# ################# Output #################
output "vm_pool_ips" {
  value = { for index, pool in module.node_pools : pool.name => pool.vm_ips }

}
output "vm_pool_names" {
  value = { for index, pool in module.node_pools : pool.name => pool.vm_names }

}
output "manager_node_ips" {
  value = concat(hcloud_server.manager_nodes[*].ipv4_address, hcloud_server.manager_nodes[*].ipv6_address)
}

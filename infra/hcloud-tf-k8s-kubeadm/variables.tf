variable "location" {
  type        = string
  default     = "fsn1"
  description = "Location of the ressources."
  validation {
    condition     = contains(["fsn1", "nbg1", "hel1", "ash", "hil"], lower(var.location))
    error_message = "Unsupported location type."
  }
}

variable "node_pools" {
  type = list(object({
    name            = string
    instance        = string
    tags            = any
    image           = string
    location        = optional(string, "fsn1")
    size            = optional(number, 1)
    cloud_init_path = optional(string, "data/cloud-init.yml")
    ssh_key_paths   = optional(list(string), ["~/.ssh/id_rsa.pub"])
    vm_names        = optional(list(string), [])
    ipv4_enabled    = optional(bool, true)
    ipv6_enabled    = optional(bool, true)
  }))
  default     = []
  description = "List of node pools configurations."
}
variable "loadbancers" {
  type = list(object({
    name = string
    services = list(object({
      name           = string
      protocol       = string
      proxy_protocol = optional(bool, false)
      source_port    = optional(number, 80)
      target_port    = optional(number, 80)
    }))
    targets = list(object({
      name   = string
      type   = string
      target = string
    }))
  }))
  default     = []
  description = "List of loadbalancers."
}

variable "vnet_name" {
  type        = string
  default     = "k8s-network"
  description = "Name of the hcloud vnet."
}

variable "manager_vm_create" {
  type        = bool
  default     = "true"
  description = "Create a manager nodes that is not part of the k8s cluster."
}

variable "vnet_routes" {
  type = list(object({
    name        = string
    gateway     = string
    destination = string
  }))
  default = []
  # default = [
  #   {
  #     "name": "nat-gateway",
  #     "gateway": "10.0.0.2",
  #     "destination": "0.0.0.0/0"
  #   }
  # ]
}
variable "firewall_rules" {
  type = list(object({
    name            = string
    direction       = optional(string, "")
    protocol        = optional(string, "")
    source_ips      = optional(list(string), ["0.0.0.0/0", "::/0"])
    destination_ips = optional(list(string), [])
    ports           = optional(string)
    label_selectors = list(string)
  }))
  default = []
}

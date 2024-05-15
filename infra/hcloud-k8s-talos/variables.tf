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
    cloud_init_path = optional(string, "")
    ssh_key_paths   = optional(list(string), ["~/.ssh/id_rsa.pub"])
    vm_names        = optional(list(string), [])
  }))
  default     = []
  description = "List of node pools configurations."
}

variable "vnet_name" {
  type        = string
  default     = "k8s-network"
  description = "Name of the hcloud vnet."
}

variable "talos_conf_patch" {
  type        = string
  default     = "data/controlplanepatch.yaml.tmpl"
  description = "Path to the talos template with placeholders for Endpoints."
}

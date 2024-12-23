variable "cluster_name" {
  type        = string
  default     = "talos-hcloud"
  description = "Name of the cluster."
}
variable "cluster_version" {
  type        = string
  default     = "v1.32.0"
  description = "Version of the cluster."
}
variable "talos_version" {
  type        = string
  default     = "v1.9.0"
  description = "Talos Version of the cluster."
}
variable "controlplane_endpoint" {
  type        = string
  default     = "k8s.example.com"
  description = "Domain name of the controlplane."
}
variable "node_pools" {
  type = list(object({
    name            = string
    instance        = string
    tags            = any
    image           = string
    size            = optional(number, 1)
    location        = optional(string, "null")
    machine_patches = optional(list(string), ["data/controlplanepatch.yaml.tmpl"])
    ssh_key_paths   = optional(list(string), ["~/.ssh/id_rsa.pub"])
    vm_names        = optional(list(string), [])
  }))
  default = [{
    name     = "talos-controlplane"
    instance = "cx21"
    image    = "my-talos-image"
    tags = {
      k8s_control_plane = "true"
      k8s               = "controlplane"
      role              = "controlplane"
    }
  }]
  description = "List of node pools configurations."

  validation {
    condition     = length(var.node_pools) > 0
    error_message = "At least one node pool is required."
  }

  validation {
    condition     = alltrue([for pool in var.node_pools : pool.size > 0])
    error_message = "Each node pool must have a non-empty size and image."
  }
}
variable "location" {
  type        = string
  default     = "nbg1"
  description = "Default location of the resources."
  validation {
    condition     = contains(["fsn1", "nbg1", "hel1", "ash", "hil"], lower(var.location))
    error_message = "Unsupported location."
  }
}
variable "api_server_extra_args" {
  type        = any
  default     = {}
  description = "Extra args for the controlplane. Key value pairs."
}
variable "dns_record" {
  type = object({
    create   = bool
    zone     = string
    provider = string
    token    = string
  })
  sensitive   = true
  default     = { create = false, zone = "", provider = "", token = "xxx" }
  description = "DNS record for the controlplane. Provider can be cloudflare, aws, azure"
}
variable "argo_values_path" {
  type        = string
  default     = "data/helm-values-argocd-raw.yml"
  description = "Path to the argo values file."
}
variable "cilium_values_path" {
  type        = string
  default     = "data/helm-values-cilium-raw.yml"
  description = "Path to the argo values file."
}

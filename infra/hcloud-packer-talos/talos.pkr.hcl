# NOTE: Based on https://www.talos.dev/v1.5/talos-guides/install/cloud-platforms/hetzner/

packer {
  required_version  = ">=1.12.0"
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = ">= 1.6.0"
    }
  }
}

######################## INPUT ########################
variable "talos_version" {
  type    = string
  default = "v1.9.5"
}
variable "talos_extensions" {
  type    = list(string)
  # default = []
  default = ["siderolabs/crun", "siderolabs/gvisor", "siderolabs/wasmedge"]
}
variable "talos_kernel_args" {
  type    = list(string)
  default = []
  # default = ["security=apparmor"]
}

######################## LOCALS ########################
locals {
  talos_download_factory   = "https://factory.talos.dev/image"
  talos_extensions_postfix = length(var.talos_extensions) > 0 ? "-${join("-", local.talos_extensions)}" : ""
  talos_extensions         = [for ext in var.talos_extensions : replace(ext, "siderolabs/", "")]

  talos_customization_id  = jsondecode(data.http.customizations_id.body)["id"]
  talos_download_base_url = join("/", [local.talos_download_factory, local.talos_customization_id])

  setups = { for arch in ["amd64", "arm64"] :
    arch => {
      image = "${local.talos_download_base_url}/${var.talos_version}/hcloud-${arch}.raw.xz"
      name  = "talos-${var.talos_version}-${arch}${local.talos_extensions_postfix}"
      arch  = "${arch}"

      tags = {
        type            = "infra",
        os              = "talos",
        arch            = "${arch}"
        name            = "talos-${var.talos_version}-${arch}${local.talos_extensions_postfix}"
        version         = "${var.talos_version}",
        origin          = "talos-factory"
        image_id_part_1 = length(var.talos_extensions) > 0 ? substr(local.talos_customization_id, 0, 32) : "default"
        image_id_part_2 = length(var.talos_extensions) > 0 ? substr(local.talos_customization_id, 32, 32) : "default"
        extensions      = length(var.talos_extensions) > 0 ? "${join("-", local.talos_extensions)}" : "none"
      }
    }
  }
}

source "hcloud" "talos_amd64" {
  rescue               = "linux64"
  image                = "debian-12"
  location             = "fsn1"
  server_type          = "cx22"
  ssh_username         = "root"
  snapshot_name        = local.setups.amd64.name
  snapshot_labels      = local.setups.amd64.tags
}

source "hcloud" "talos_arm64" {
  image                = "debian-12"
  location             = "fsn1"
  rescue               = "linux64"
  server_type          = "cax11"
  ssh_username         = "root"
  snapshot_name        = local.setups.arm64.name
  snapshot_labels      = local.setups.arm64.tags
}

build {
  name    = "talos_build"
  sources = ["source.hcloud.talos_amd64", "source.hcloud.talos_arm64"]
  provisioner "shell" {
    inline = [
      "export TALOS_IMAGE=${source.name == "talos_amd64" ? local.setups.amd64.image : local.setups.arm64.image}",
      "echo \"Downloading from $TALOS_IMAGE\"",
      "curl --fail -sL -o /tmp/talos.raw.xz $TALOS_IMAGE",
      "echo \"Download done\nWriting to /dev/sda\"",
      "xz -d -c /tmp/talos.raw.xz | dd of=/dev/sda && sync",
    ]
  }
}

######################## DATA ########################
data "http" "customizations_id" {
  url = "https://factory.talos.dev/schematics"
  method = "POST"
  request_body = jsonencode({
    customization = {
      systemExtensions = {
        officialExtensions = var.talos_extensions
      }
      extraKernelArgs = var.talos_kernel_args
    }
  })
  request_headers = {
    Accept = "application/json"
  }
}

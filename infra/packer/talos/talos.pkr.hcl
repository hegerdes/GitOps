# talos.pkr.hcl
# NOTE: Based on https://www.talos.dev/v1.5/talos-guides/install/cloud-platforms/hetzner/

# packer.pkr.hcl
packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = ">= 1.3.0"
    }
  }
}

variable "talos_version" {
  type    = string
  default = "v1.7.2"
}
variable "talos_download_base_url" {
  // Special images on https://factory.talos.dev/
  type = string
  // default = "https://github.com/siderolabs/talos/releases/download"
  default = "https://factory.talos.dev/image/4c88839d5043b0db26041959bfdc2111f7d4684a255ebeabbfd8c161ac33328d"
}
variable "talos_extentions" {
  type    = list(string)
  // default = []
  default = ["gvisor", "wasmedge"]
}

locals {
  extentions_postfix = length(var.talos_extentions) > 0 ? "-${join("-", var.talos_extentions)}" : ""
  setups = { for arch in ["amd64", "arm64"] : arch => {
    image = "${var.talos_download_base_url}/${var.talos_version}/hcloud-${arch}.raw.xz"
    name  = "talos-${var.talos_version}-${arch}${local.extentions_postfix}"
    arch  = "${arch}"

    tags = {
      type       = "infra",
      os         = "talos",
      arch       = "${arch}"
      name       = "talos-${var.talos_version}-${arch}${local.extentions_postfix}"
      version    = "${var.talos_version}",
      extentions = length(var.talos_extentions) > 0 ? "${join("-", var.talos_extentions)}" : "none"
    }
  } }
}

source "hcloud" "talos_amd64" {
  rescue          = "linux64"
  image           = "debian-12"
  location        = "fsn1"
  server_type     = "cx11"
  ssh_username    = "root"
  snapshot_name   = local.setups.amd64.name
  snapshot_labels = local.setups.amd64.tags
}

source "hcloud" "talos_arm64" {
  image           = "debian-12"
  location        = "fsn1"
  rescue          = "linux64"
  server_type     = "cax11"
  ssh_username    = "root"
  snapshot_name   = local.setups.arm64.name
  snapshot_labels = local.setups.arm64.tags
}

build {
  name    = "talos_build"
  sources = ["source.hcloud.talos_amd64", "source.hcloud.talos_arm64"]
  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y wget",
      "wget -O /tmp/talos.raw.xz ${source.name == "talos_amd64" ? local.setups.amd64.image : local.setups.arm64.image}",
      "xz -d -c /tmp/talos.raw.xz | dd of=/dev/sda && sync",
    ]
  }
}

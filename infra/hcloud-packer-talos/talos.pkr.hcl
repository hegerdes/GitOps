# talos.pkr.hcl
# NOTE: Based on https://www.talos.dev/v1.5/talos-guides/install/cloud-platforms/hetzner/

packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = ">= 1.4.0"
    }
  }
}

variable "talos_version" {
  type    = string
  default = "v1.7.3"
}
variable "talos_extentions" {
  type = list(string)
  default = []
  // default = ["siderolabs/gvisor", "siderolabs/wasmedge"]
}

locals {
  talos_download_github  = "https://github.com/siderolabs/talos/releases/download"
  talos_download_factory = "https://factory.talos.dev/image"

  talos_extentions_postfix = length(var.talos_extentions) > 0 ? "-${join("-", local.talos_extentions)}" : ""
  talos_extentions         = [for s in var.talos_extentions : replace(s, "siderolabs/", "")]

  talos_custominazion_id  = jsondecode(data.http.customizations_id.body)["id"]
  talos_download_base_url = length(var.talos_extentions) > 0 ? join("/", [local.talos_download_factory, local.talos_custominazion_id]) : local.talos_download_github

  setups = { for arch in ["amd64", "arm64"] : arch => {
    image = "${local.talos_download_base_url}/${var.talos_version}/hcloud-${arch}.raw.xz"
    name  = "talos-${var.talos_version}-${arch}${local.talos_extentions_postfix}"
    arch  = "${arch}"

    tags = {
      type       = "infra",
      os         = "talos",
      arch       = "${arch}"
      name       = "talos-${var.talos_version}-${arch}${local.talos_extentions_postfix}"
      version    = "${var.talos_version}",
      origin     = length(var.talos_extentions) > 0 ? "talos-factory" : "github"
      image_id_part_1     = length(var.talos_extentions) > 0 ? substr(local.talos_custominazion_id, 0, 32) : "default"
      image_id_part_2     = length(var.talos_extentions) > 0 ? substr(local.talos_custominazion_id, 32, 32) : "default"
      extentions = length(var.talos_extentions) > 0 ? "${join("-", local.talos_extentions)}" : "none"
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
      "apt-get -qq update",
      "apt-get -qq install -y wget",
      "echo \"Downloading from ${source.name == "talos_amd64" ? local.setups.amd64.image : local.setups.arm64.image}\"",
      "wget --quiet -O /tmp/talos.raw.xz ${source.name == "talos_amd64" ? local.setups.amd64.image : local.setups.arm64.image}",
      "echo \"Download done\nWriting to /dev/sda\"",
      "xz -d -c /tmp/talos.raw.xz | dd of=/dev/sda && sync",
    ]
  }
}

######################## DATA ########################
// Packer can only do get requests. So we use a lambda to do the post for the customizations_id
data "http" "customizations_id" {
  url = data.null.talos_download_url.output
  request_headers = {
    Accept = "application/json"
  }
}
// Packer does not allow locals in data blocks so we use null data. Dirty but hashicorp... way of things
data "null" "talos_download_url" {
  input =    "https://gecopek4tnjqowdbygnxe7ngve0kchwk.lambda-url.eu-central-1.on.aws/?payload=${data.null.talos_custominazion_id.output}&encoding=base64&target=https://factory.talos.dev/schematics"
}
// Encode the extention list ty yaml and base64 encde
data "null" "talos_custominazion_id" {
  input = replace(base64encode(yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = var.talos_extentions
      }
    }
  })),"=", "")
}

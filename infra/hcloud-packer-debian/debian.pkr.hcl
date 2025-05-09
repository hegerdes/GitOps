# hcloud.pkr.hcl
packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = ">= 1.6.0"
    }
  }
}

variable "base_image" {
  type    = string
  default = "debian-12"
}
variable "output_name" {
  type    = string
  default = "debian-12-k8s"
}
variable "k8s_version" {
  type    = string
  default = "1.33.0"
}
variable "user_data_path" {
  type    = string
  default = "cloud-init.yml"
}

locals {
  output_name = "${var.output_name}-v${var.k8s_version}"
}

source "hcloud" "k8s-amd64" {
  image         = var.base_image
  location      = "fsn1"
  server_type   = "cx22"
  ssh_keys      = []
  user_data     = file(var.user_data_path)
  ssh_username  = "root"
  snapshot_name = "${local.output_name}-amd64"
  snapshot_labels = {
    type    = "infra",
    base    = var.base_image,
    version = "${var.k8s_version}",
    name    = "${local.output_name}-amd64"
    arch    = "amd64"
  }
}
source "hcloud" "k8s-arm64" {
  image         = var.base_image
  location      = "fsn1"
  server_type   = "cax11"
  ssh_keys      = []
  user_data     = file(var.user_data_path)
  ssh_username  = "root"
  snapshot_name = "${local.output_name}-arm64"
  snapshot_labels = {
    type    = "infra",
    base    = var.base_image,
    version = "${var.k8s_version}",
    name    = "${local.output_name}-arm64"
    arch    = "arm64"
  }
}
build {
  sources = ["source.hcloud.k8s-amd64", "source.hcloud.k8s-arm64"]
  # sources = ["source.hcloud.k8s-arm64"]

  provisioner "shell" {
    expect_disconnect = true
    env = {
      k8s_version = "${var.k8s_version}"
    }
    scripts = [
      "ansible-setup.sh",
    ]
  }
  provisioner "shell" {
    pause_before = "30s"
    max_retries = 1
    env = {
      k8s_version = "${var.k8s_version}"
    }
    scripts = [
      "ansible-setup.sh",
    ]
  }
}

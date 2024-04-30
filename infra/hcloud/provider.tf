terraform {
  required_version = ">=1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.29.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.45.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
  }
}

provider "kubernetes" {}

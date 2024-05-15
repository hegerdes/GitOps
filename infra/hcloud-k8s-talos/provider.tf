terraform {
  required_version = ">= 1.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.47.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.13.1"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.102.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.11.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

provider "azurerm" {
  use_oidc = true
  features {}
}

provider "helm" {
  kubernetes {
    host = "https://${local.controlplane_public_endpoint}:6443"

    client_certificate     = base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
  }
}

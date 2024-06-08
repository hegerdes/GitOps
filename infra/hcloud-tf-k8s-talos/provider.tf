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
      version = "2.13.2"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.102.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.50.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.33.0"
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

provider "cloudflare" {
  api_token = var.dns_record.token
}

provider "helm" {
  kubernetes {
    # host = "https://${local.controlplane_public_endpoint}:6443"
    host = "https://${module.loadbalancer.lb_ipv4}:6443"

    client_certificate     = base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
  }
}

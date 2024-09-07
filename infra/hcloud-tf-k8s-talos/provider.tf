terraform {
  required_version = ">= 1.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~>1.48"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~>0.5"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~>2.15"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.32"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.66"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~>4.41"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~>2.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~>0.12"
    }
    null = {
      source  = "hashicorp/null"
      version = "~>3.2"
    }
  }
}

provider "azurerm" {
  use_oidc        = true
  subscription_id = "777ba5ef-85e2-4cfd-8162-1da84acac4a6"
  features {}
}

provider "cloudflare" {
  api_token = var.dns_record.token
}

provider "kubernetes" {
  # host = "https://${local.controlplane_public_endpoint}:6443"
  host = "https://${module.loadbalancer.lb_ipv4}:6443"

  client_certificate     = base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(data.talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
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

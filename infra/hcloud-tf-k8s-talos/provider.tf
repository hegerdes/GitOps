terraform {
  required_version = ">= 1.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~>1.48"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~>0.6"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~>2.16"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.8"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.74"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~>4.45"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0"
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

provider "aws" {
  region = "eu-central-1"
}

provider "helm" {
  kubernetes {
    # host = "https://${local.cp_public_endpoint}:6443"

    # client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    # client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
    # cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
    config_path = local_sensitive_file.kubeconf.filename
  }
}

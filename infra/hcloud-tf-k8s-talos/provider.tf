terraform {
  required_version = ">= 1.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~>1.49"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~>0.7"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~>2.17"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.20"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.88"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~>5.1"
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
    # host                   = yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw).clusters[0].cluster.server
    # cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)

    # client_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    # client_key         = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
    config_path = local_sensitive_file.kubeconf.filename
  }
}

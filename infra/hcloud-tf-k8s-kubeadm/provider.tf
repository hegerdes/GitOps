terraform {
  required_version = ">= 1.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~>1.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.8"
    }
    local = {
      source  = "hashicorp/local"
      version = "~>2.5"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.62"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.2"
    }
  }
}


provider "azurerm" {
  use_oidc        = true
  subscription_id = "777ba5ef-85e2-4cfd-8162-1da84acac4a6"
  features {}
}

provider "hcloud" {
  token = data.azurerm_key_vault_secret.hcloud_token.value
}

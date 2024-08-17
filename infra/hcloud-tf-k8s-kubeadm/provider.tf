terraform {
  required_version = ">= 1.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~>1.48"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~>2.5"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.116"
    }
  }
}

provider "azurerm" {
  use_oidc = true
  features {}
}

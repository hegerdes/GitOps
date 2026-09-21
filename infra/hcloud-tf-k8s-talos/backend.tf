terraform {
  backend "azurerm" {
    container_name       = "tf-states"
    key                  = "hetzner-talos.tfstate"
    resource_group_name  = "default"
    storage_account_name = "hegerdesdevblobs"
    use_oidc             = true
  }
}

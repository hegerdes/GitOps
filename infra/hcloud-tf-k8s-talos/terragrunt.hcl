remote_state {
  backend = "azurerm"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    resource_group_name  = "default"
    storage_account_name = "hegerdesdevblobs"
    container_name       = "tf-states"
    key                  = get_env("TF_VAR_backend", "hetzner-talos.tfstate")
    use_oidc             = true
  }
}

terraform {
  extra_arguments "common_vars" {
    commands = ["init"]
    arguments = [
      "-reconfigure"
    ]
  }
}
// terraform {
//   extra_arguments "common_vars" {
//     commands = ["plan", "apply"]

//     arguments = [
//       "-var-file=../../common.tfvars",
//       "-var-file=../region.tfvars"
//     ]
//   }
// }

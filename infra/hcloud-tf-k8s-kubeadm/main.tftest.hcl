# infra.tftest.hcl

variables {
  bucket_prefix = "test"
}

run "local" {
  command = plan

  assert {
    condition     = can(yamldecode(local.cloud_init_user_data))
    error_message = "Unable to render cloud-init config"
  }

  // Snapshot
  assert {
    condition     = can(yamldecode(local.cloud_init_user_data))
    error_message = "Unable to render cloud-init config"
  }
}

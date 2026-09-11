mock_provider "cloudflare" {
  override_during = plan

  mock_resource "cloudflare_r2_bucket" {
    defaults = { id = "synthetic-state-bucket" }
  }
}

variables {
  cloudflare_account_id = "11111111111111111111111111111111"
}

run "two_private_destination_state_buckets" {
  command = plan

  assert {
    condition = length(output.state_buckets) == 2 && toset([
      for bucket in values(output.state_buckets) : bucket.name
      ]) == toset([
      "ritual-investing-terraform-state-prod", "ritual-investing-terraform-state-staging"
    ])
    error_message = "Bootstrap must create only the two named destination state buckets."
  }
  assert {
    condition = alltrue([
      for bucket in values(cloudflare_r2_bucket.state) :
      bucket.account_id == var.cloudflare_account_id && bucket.jurisdiction == "default" && bucket.storage_class == "Standard"
    ])
    error_message = "State buckets must use the explicit destination and reviewed storage settings."
  }
}

run "reject_source_account" {
  command = plan
  variables { cloudflare_account_id = "5cc3bc33ca089258d20b6e80e67e5333" }
  expect_failures = [var.cloudflare_account_id]
}

run "reject_missing_account" {
  command = plan
  variables { cloudflare_account_id = "" }
  expect_failures = [var.cloudflare_account_id]
}

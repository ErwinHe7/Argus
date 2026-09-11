locals {
  state_buckets = {
    prod    = "ritual-investing-terraform-state-prod"
    staging = "ritual-investing-terraform-state-staging"
  }
}

# These are empty, private backend buckets. Public access, domains and objects
# are not Terraform resources in this provisioning phase.
resource "cloudflare_r2_bucket" "state" {
  for_each = local.state_buckets

  account_id    = var.cloudflare_account_id
  name          = each.value
  jurisdiction  = "default"
  storage_class = "Standard"

  lifecycle {
    prevent_destroy = true
  }
}

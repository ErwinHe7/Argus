# Catalog settings are proposed until profiles/leoinvestment.json records administrator verification.
# The shared CLI reads the same catalog and refuses unverified settings before remote planning.
locals {
  catalog = jsondecode(file("${path.module}/catalog.json"))
}

module "account_resources" {
  source = "../../modules/account-resources"

  cloudflare_account_id = var.cloudflare_account_id
  environment           = "staging"
  catalog               = local.catalog
}

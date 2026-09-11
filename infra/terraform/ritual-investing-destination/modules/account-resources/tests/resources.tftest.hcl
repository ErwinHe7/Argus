# These tests use the actual environment roots and a provider mock only.
# Hosted deployment history, R2 privacy and queue integrations require the CLI checks.
mock_provider "cloudflare" {
  override_during = plan

  mock_resource "cloudflare_worker" {
    defaults = { id = "synthetic-worker-id" }
  }
  mock_resource "cloudflare_pages_project" {
    defaults = { id = "synthetic-pages-id" }
  }
  mock_resource "cloudflare_r2_bucket" {
    defaults = { id = "synthetic-bucket-id" }
  }
  mock_resource "cloudflare_workers_kv_namespace" {
    defaults = { id = "22222222222222222222222222222222" }
  }
  mock_resource "cloudflare_queue" {
    defaults = {
      id                    = "synthetic-queue-id"
      queue_id              = "synthetic-queue-id"
      consumers_total_count = 0
      producers_total_count = 0
    }
  }
  mock_resource "cloudflare_turnstile_widget" {
    defaults = {
      id      = "synthetic-sitekey"
      sitekey = "synthetic-sitekey"
      secret  = "synthetic-widget-secret-must-not-be-output"
    }
  }
}

variables {
  cloudflare_account_id = "11111111111111111111111111111111"
}

run "production_root_catalog" {
  command = plan
  module { source = "../../environments/prod" }

  assert {
    condition     = sum([for resources in values(output.resource_identifiers) : length(resources)]) == 13
    error_message = "The production root must create the 13 inventoried account resources."
  }
  assert {
    condition = toset([for worker in values(output.resource_identifiers.workers) : worker.name]) == toset([
      "ritual-investing-api", "ritual-investing-demo", "ritual-investing-member", "ritual-investing-site"
    ]) && length(output.resource_identifiers.pages) == 0
    error_message = "Production must use the observed Worker identities without inventing Pages projects."
  }
  assert {
    condition = alltrue([
      for worker in values(module.account_resources.provisioning_contract.workers) :
      worker.account_id == var.cloudflare_account_id && !worker.subdomain_enabled && !worker.previews_enabled && length(worker.tail_consumers) == 0
    ])
    error_message = "Every production Worker must use the explicit destination and disable URLs and tail integrations."
  }
  assert {
    condition = alltrue([
      for queue in values(module.account_resources.provisioning_contract.queues) :
      queue.account_id == var.cloudflare_account_id && queue.delivery_paused && queue.consumers_total_count == 0 && queue.producers_total_count == 0
    ])
    error_message = "Production queues must be paused with no integrations in the mock plan."
  }
  assert {
    condition = alltrue([
      for widget in values(module.account_resources.provisioning_contract.turnstile) :
      widget.account_id == var.cloudflare_account_id && widget.clearance_level == "no_clearance"
    ]) && !strcontains(jsonencode(output.resource_identifiers), "synthetic-widget-secret-must-not-be-output")
    error_message = "Widgets must grant no clearance and outputs must never expose their generated secrets."
  }
}

run "staging_root_catalog" {
  command = plan
  module { source = "../../environments/staging" }

  assert {
    condition     = sum([for resources in values(output.resource_identifiers) : length(resources)]) == 15
    error_message = "The staging root must create the 15 inventoried account resources."
  }
  assert {
    condition = toset([for worker in values(output.resource_identifiers.workers) : worker.name]) == toset([
      "ritual-investing-api-beta", "ritual-investing-demo-beta", "ritual-investing-member-preview", "ritual-investing-site-beta"
      ]) && toset([for page in values(output.resource_identifiers.pages) : page.name]) == toset([
      "ritual-investing-site-staging", "ritual-investing-demo-staging"
    ])
    error_message = "Staging must retain its observed Workers and two staging-only Pages shells."
  }
  assert {
    condition = alltrue([
      for worker in values(module.account_resources.provisioning_contract.workers) :
      worker.account_id == var.cloudflare_account_id && !worker.subdomain_enabled && !worker.previews_enabled && length(worker.tail_consumers) == 0
      ]) && alltrue([
      for page in values(module.account_resources.provisioning_contract.pages) :
      page.account_id == var.cloudflare_account_id && page.source_absent
    ])
    error_message = "Staging must disable Worker URLs and leave Pages unconnected without build or runtime configuration."
  }
  assert {
    condition = alltrue([
      for queue in values(module.account_resources.provisioning_contract.queues) :
      queue.account_id == var.cloudflare_account_id && queue.delivery_paused && queue.consumers_total_count == 0 && queue.producers_total_count == 0
      ]) && alltrue([
      for widget in values(module.account_resources.provisioning_contract.turnstile) :
      widget.account_id == var.cloudflare_account_id && widget.clearance_level == "no_clearance"
    ])
    error_message = "Staging queues must be paused and its unused widgets must not grant clearance."
  }
  assert {
    condition = toset([for bucket in values(output.resource_identifiers.r2_buckets) : bucket.name]) == toset([
      "ritual-beta-deletion-deny", "ritual-beta-media-public", "ritual-beta-media-quarantine", "ritual-beta-privacy-exports"
      ]) && alltrue([
      for bucket in values(module.account_resources.provisioning_contract.r2_buckets) : bucket.account_id == var.cloudflare_account_id
      ]) && alltrue([
      for namespace in values(module.account_resources.provisioning_contract.kv_namespaces) : namespace.account_id == var.cloudflare_account_id
    ]) && !strcontains(jsonencode(output.resource_identifiers), "synthetic-widget-secret-must-not-be-output")
    error_message = "Storage must use the destination inventory/account and outputs must omit widget secrets."
  }
}

run "reject_personal_account_at_root" {
  command = plan
  module { source = "../../environments/staging" }
  variables { cloudflare_account_id = "5cc3bc33ca089258d20b6e80e67e5333" }
  expect_failures = [var.cloudflare_account_id]
}

run "reject_missing_account_at_root" {
  command = plan
  module { source = "../../environments/prod" }
  variables { cloudflare_account_id = "" }
  expect_failures = [var.cloudflare_account_id]
}

run "reject_personal_account_at_module" {
  command = plan
  variables {
    cloudflare_account_id = "5cc3bc33ca089258d20b6e80e67e5333"
    environment           = "prod"
    catalog               = jsondecode(file("../../environments/prod/catalog.json"))
  }
  expect_failures = [var.cloudflare_account_id]
}

run "reject_missing_account_at_module" {
  command = plan
  variables {
    cloudflare_account_id = ""
    environment           = "prod"
    catalog               = jsondecode(file("../../environments/prod/catalog.json"))
  }
  expect_failures = [var.cloudflare_account_id]
}

run "reject_catalog_for_another_environment" {
  command = plan
  variables {
    environment = "prod"
    catalog     = jsondecode(file("../../environments/staging/catalog.json"))
  }
  expect_failures = [var.catalog]
}

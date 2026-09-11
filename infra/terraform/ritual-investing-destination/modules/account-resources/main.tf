# Identity only: this resource uploads no Worker code or versions.
resource "cloudflare_worker" "identities" {
  for_each = var.catalog.workers

  account_id = var.cloudflare_account_id
  name       = each.value.name
  logpush    = false
  subdomain = {
    enabled          = false
    previews_enabled = false
  }
  tail_consumers = []

  lifecycle {
    prevent_destroy = true
  }
}

# Empty project shells: no source, build, deployment or custom-domain configuration.
resource "cloudflare_pages_project" "shells" {
  for_each = var.catalog.pages

  account_id        = var.cloudflare_account_id
  name              = each.value.name
  production_branch = each.value.production_branch

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_workers_kv_namespace" "empty" {
  for_each = var.catalog.kv_namespaces

  account_id = var.cloudflare_account_id
  title      = each.value.title

  lifecycle {
    prevent_destroy = true
  }
}

# New R2 buckets are private. No public-access, domain, CORS or object resources
# are owned here; the CLI independently verifies public access before/after apply.
resource "cloudflare_r2_bucket" "private" {
  for_each = var.catalog.r2_buckets

  account_id    = var.cloudflare_account_id
  name          = each.value.name
  jurisdiction  = each.value.jurisdiction
  location      = each.value.location
  storage_class = each.value.storage_class

  lifecycle {
    prevent_destroy = true
  }
}

# Producer/consumer integration and DLQ associations belong to a later runtime release.
resource "cloudflare_queue" "paused" {
  for_each = var.catalog.queues

  account_id = var.cloudflare_account_id
  queue_name = each.value.queue_name
  settings = {
    delivery_paused          = true
    delivery_delay           = each.value.delivery_delay
    message_retention_period = each.value.message_retention_period
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Creation generates a new sensitive secret in Terraform state. It is never output.
resource "cloudflare_turnstile_widget" "unused" {
  for_each = var.catalog.turnstile

  account_id      = var.cloudflare_account_id
  name            = each.value.name
  domains         = each.value.domains
  mode            = each.value.mode
  region          = each.value.region
  clearance_level = "no_clearance"
  bot_fight_mode  = false
  ephemeral_id    = false
  offlabel        = false

  lifecycle {
    prevent_destroy = true
  }
}

variable "cloudflare_account_id" {
  description = "Explicit LeoInvestment account ID verified by the provisioning CLI; there is no source-account fallback."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_account_id)) && var.cloudflare_account_id != "5cc3bc33ca089258d20b6e80e67e5333"
    error_message = "Supply a verified 32-character lowercase destination account ID; the personal source account is forbidden."
  }
}

variable "environment" {
  description = "The fixed environment selected by a destination root."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "Only the staging and prod destination catalogs are supported."
  }
}

variable "catalog" {
  description = "Nonsecret environment-owned resource catalog; inactive boundaries are fixed in this module."
  type = object({
    schema_version = number
    environment    = string
    workers = map(object({
      name = string
    }))
    pages = map(object({
      name              = string
      production_branch = string
    }))
    kv_namespaces = map(object({
      title = string
    }))
    r2_buckets = map(object({
      name          = string
      jurisdiction  = string
      location      = optional(string)
      storage_class = string
    }))
    queues = map(object({
      queue_name               = string
      delivery_delay           = optional(number)
      message_retention_period = optional(number)
    }))
    turnstile = map(object({
      name    = string
      domains = list(string)
      mode    = string
      region  = string
    }))
  })
  nullable = false

  validation {
    condition     = var.catalog.schema_version == 1 && var.catalog.environment == var.environment
    error_message = "The catalog must use schema version 1 and match the explicitly selected destination environment."
  }

  validation {
    condition = alltrue([
      for widget in values(var.catalog.turnstile) : length(widget.domains) > 0 && alltrue([
        for domain in widget.domains : length(trimspace(domain)) > 0 && !strcontains(domain, "*")
      ])
    ])
    error_message = "Unused Turnstile widgets require an explicit, nonempty domain allowlist without wildcards."
  }
}

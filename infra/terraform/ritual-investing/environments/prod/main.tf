variable "enable_brownfield_imports" {
  description = "Enables only the configuration-driven imports declared in imports.tf."
  type        = bool
  default     = false
}

variable "enable_remote_changes" {
  description = "Explicit operator authorization for a remote apply after every readiness proof is recorded."
  type        = bool
  default     = false
}

variable "adoption_phase" {
  description = "Manual adoption phase. The default deliberately prevents every plan and apply."
  type        = string
  default     = "disabled"

  validation {
    condition     = contains(["disabled", "inventory-import-plan", "ready"], var.adoption_phase)
    error_message = "Adoption phase must be disabled, inventory-import-plan, or ready."
  }
}

variable "adoption_evidence" {
  description = "Sanitized digests and inventory exclusions recorded outside Terraform; never put secrets in this value."
  type = object({
    live_inventory_sha256            = string
    backend_lock_proof_sha256        = string
    provider_lock_sha256             = string
    import_only_plan_sha256          = string
    no_op_plan_sha256                = string
    readiness_receipt_sha256         = string
    has_secret_environment_variables = bool
    has_functions_or_worker          = bool
    has_bindings                     = bool
    has_unknown_settings             = bool
  })
  default  = null
  nullable = true

  validation {
    condition = var.adoption_evidence == null ? true : alltrue([
      for digest in [
        var.adoption_evidence.live_inventory_sha256,
        var.adoption_evidence.backend_lock_proof_sha256,
        var.adoption_evidence.provider_lock_sha256,
      ] : can(regex("^[a-f0-9]{64}$", digest))
      ]) && alltrue([
      for digest in [
        var.adoption_evidence.import_only_plan_sha256,
        var.adoption_evidence.no_op_plan_sha256,
        var.adoption_evidence.readiness_receipt_sha256,
      ] : digest == "" || can(regex("^[a-f0-9]{64}$", digest))
    ])
    error_message = "Inventory, backend-lock, and provider-lock digests must be lowercase SHA-256 values; later adoption digests must be empty or lowercase SHA-256 values."
  }
}

variable "brownfield_import_inventory" {
  description = "Exact nonsecret provider import identifiers from the live prod inventory."
  type = object({
    landing_pages_project_import_id = string
    landing_pages_domain_name       = string
    landing_dns_record_import_id    = string
    demo_pages_project_import_id    = string
    demo_pages_domain_name          = string
    demo_dns_record_import_id       = string
  })
  default  = null
  nullable = true

  validation {
    condition = var.brownfield_import_inventory == null ? true : (
      alltrue([
        for value in [
          var.brownfield_import_inventory.landing_pages_project_import_id,
          var.brownfield_import_inventory.landing_pages_domain_name,
          var.brownfield_import_inventory.landing_dns_record_import_id,
          var.brownfield_import_inventory.demo_pages_project_import_id,
          var.brownfield_import_inventory.demo_pages_domain_name,
          var.brownfield_import_inventory.demo_dns_record_import_id,
        ] : length(trimspace(value)) > 0
      ])
    )
    error_message = "Prod import inventory must provide every nonempty Cloudflare import identity."
  }
}

variable "demo_pages_project_name" {
  description = "Existing prod Demo Pages project declared for import."
  type        = string
  default     = "ritual-investing-demo"

  validation {
    condition     = var.demo_pages_project_name == "ritual-investing-demo"
    error_message = "The prod Demo project name is fixed by the live-resource contract."
  }
}

variable "demo_pages_domain" {
  description = "Existing prod Demo custom domain declared for import."
  type        = string
  default     = "demo.just-build-this.app"

  validation {
    condition     = var.demo_pages_domain == "demo.just-build-this.app"
    error_message = "The prod Demo domain is fixed by the live-resource contract."
  }
}

locals {
  base_adoption_evidence_valid = try(
    can(regex("^[a-f0-9]{64}$", var.adoption_evidence.live_inventory_sha256)) &&
    can(regex("^[a-f0-9]{64}$", var.adoption_evidence.backend_lock_proof_sha256)) &&
    can(regex("^[a-f0-9]{64}$", var.adoption_evidence.provider_lock_sha256)) &&
    !var.adoption_evidence.has_secret_environment_variables &&
    !var.adoption_evidence.has_functions_or_worker &&
    !var.adoption_evidence.has_bindings &&
    !var.adoption_evidence.has_unknown_settings,
    false,
  )
  final_adoption_evidence_valid = local.base_adoption_evidence_valid && try(
    can(regex("^[a-f0-9]{64}$", var.adoption_evidence.import_only_plan_sha256)) &&
    can(regex("^[a-f0-9]{64}$", var.adoption_evidence.no_op_plan_sha256)) &&
    can(regex("^[a-f0-9]{64}$", var.adoption_evidence.readiness_receipt_sha256)),
    false,
  )
  import_inventory_valid = try(
    var.brownfield_import_inventory.landing_pages_domain_name == var.pages_domain &&
    var.brownfield_import_inventory.demo_pages_domain_name == var.demo_pages_domain,
    false,
  )
}

output "remote_change_gate" {
  value = "ritual-prod-remote-change-gate-v1"

  precondition {
    condition = (
      var.adoption_phase == "inventory-import-plan" ? (
        var.enable_brownfield_imports && !var.enable_remote_changes &&
        local.base_adoption_evidence_valid && local.import_inventory_valid
        ) : var.adoption_phase == "ready" ? (
        var.enable_brownfield_imports && var.enable_remote_changes &&
        local.final_adoption_evidence_valid && local.import_inventory_valid
      ) : false
    )
    error_message = "Prod adoption is disabled. Inventory/import planning requires exact safe inventory and backend proof with applies disabled; apply additionally requires recorded import-only, no-op, and readiness receipt digests."
  }
}

module "pages_environment" {
  source = "../../modules/pages-environment"

  environment           = var.environment
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = var.cloudflare_zone_id
  pages_project_name    = var.pages_project_name
  pages_domain          = var.pages_domain
  production_branch     = var.production_branch
  pages_root_dir        = "ritual-investing-site"
  pages_destination_dir = "public"
}

resource "cloudflare_pages_project" "demo" {
  account_id        = var.cloudflare_account_id
  name              = var.demo_pages_project_name
  production_branch = var.production_branch

  build_config = {
    build_caching   = false
    destination_dir = "public"
    root_dir        = "ritual-investing-site"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_pages_domain" "demo" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.demo.name
  name         = var.demo_pages_domain

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_dns_record" "demo" {
  zone_id = var.cloudflare_zone_id
  name    = var.demo_pages_domain
  type    = "CNAME"
  content = cloudflare_pages_project.demo.subdomain
  ttl     = 1
  proxied = true

  lifecycle {
    prevent_destroy = true
  }
}

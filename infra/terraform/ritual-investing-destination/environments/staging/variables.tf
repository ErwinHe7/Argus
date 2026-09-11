variable "cloudflare_account_id" {
  description = "Explicit LeoInvestment account ID verified by the provisioning CLI; there is no source-account fallback."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.cloudflare_account_id)) && var.cloudflare_account_id != "5cc3bc33ca089258d20b6e80e67e5333"
    error_message = "Supply a verified 32-character lowercase destination account ID; the personal source account is forbidden."
  }
}

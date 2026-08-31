variable "environment" {
  description = "Fixed canonical environment for this root."
  type        = string
  default     = "staging"

  validation {
    condition     = var.environment == "staging"
    error_message = "This root accepts only the staging environment."
  }
}

variable "cloudflare_account_id" {
  description = "Nonsecret Cloudflare account identifier."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Nonsecret Cloudflare zone identifier."
  type        = string
}

variable "pages_project_name" {
  description = "Staging Cloudflare Pages project name."
  type        = string

  validation {
    condition     = can(regex("staging", lower(var.pages_project_name))) && !can(regex("prod(uction)?", lower(var.pages_project_name)))
    error_message = "Staging Pages project name must contain staging and must not target prod."
  }
}

variable "pages_domain" {
  description = "Staging Cloudflare Pages custom domain."
  type        = string

  validation {
    condition     = can(regex("staging", lower(var.pages_domain))) && !can(regex("prod(uction)?", lower(var.pages_domain)))
    error_message = "Staging Pages domain must contain staging and must not target prod."
  }
}

variable "production_branch" {
  description = "Cloudflare Pages production branch metadata."
  type        = string
  default     = "main"
}

variable "github_owner" {
  description = "GitHub organization or user owner."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name."
  type        = string
}

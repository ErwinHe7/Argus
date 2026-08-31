variable "environment" {
  description = "Fixed canonical environment for this root."
  type        = string
  default     = "prod"

  validation {
    condition     = var.environment == "prod"
    error_message = "This root accepts only the prod environment."
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
  description = "Prod Cloudflare Pages project name."
  type        = string

  validation {
    condition     = !can(regex("staging", lower(var.pages_project_name)))
    error_message = "Prod Pages project name must not target staging."
  }
}

variable "pages_domain" {
  description = "Prod Cloudflare Pages custom domain."
  type        = string

  validation {
    condition     = !can(regex("staging", lower(var.pages_domain)))
    error_message = "Prod Pages domain must not target staging."
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

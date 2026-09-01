variable "environment" {
  description = "Canonical hosted environment name."
  type        = string

  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "Environment must be exactly staging or prod."
  }
}

variable "cloudflare_account_id" {
  description = "Nonsecret Cloudflare account identifier."
  type        = string

  validation {
    condition     = length(trimspace(var.cloudflare_account_id)) > 0
    error_message = "Cloudflare account ID must not be empty."
  }
}

variable "cloudflare_zone_id" {
  description = "Nonsecret Cloudflare zone identifier for the custom domain."
  type        = string

  validation {
    condition     = length(trimspace(var.cloudflare_zone_id)) > 0
    error_message = "Cloudflare zone ID must not be empty."
  }
}

variable "pages_project_name" {
  description = "Cloudflare Pages project owned by this environment."
  type        = string

  validation {
    condition     = length(trimspace(var.pages_project_name)) > 0
    error_message = "Pages project name must not be empty; resource preconditions reject the opposite environment."
  }
}

variable "pages_domain" {
  description = "Custom Pages domain owned by this environment."
  type        = string

  validation {
    condition     = length(trimspace(var.pages_domain)) > 0
    error_message = "Pages domain must not be empty; resource preconditions reject the opposite environment."
  }
}

variable "production_branch" {
  description = "Pages production branch metadata; content publishing remains external."
  type        = string
}

variable "pages_root_dir" {
  description = "Repository-relative Pages build root metadata."
  type        = string
}

variable "pages_destination_dir" {
  description = "Pages build destination metadata."
  type        = string
}

terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    github = {
      source = "integrations/github"
    }
  }
}

locals {
  github_environment_variables = {
    RITUAL_ENVIRONMENT   = var.environment
    RITUAL_PAGES_DOMAIN  = var.pages_domain
    RITUAL_PAGES_PROJECT = var.pages_project_name
  }
}

resource "cloudflare_pages_project" "this" {
  account_id        = var.cloudflare_account_id
  name              = var.pages_project_name
  production_branch = var.production_branch

  build_config = {
    build_caching   = false
    destination_dir = var.pages_destination_dir
    root_dir        = var.pages_root_dir
  }

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = var.environment != "staging" || (can(regex("staging", lower(var.pages_project_name))) && !can(regex("prod(uction)?", lower(var.pages_project_name))))
      error_message = "The staging root must target a staging Pages project, never the opposite environment."
    }

    precondition {
      condition     = var.environment != "prod" || !can(regex("staging", lower(var.pages_project_name)))
      error_message = "The prod root cannot target a staging Pages project from the opposite environment."
    }
  }
}

resource "cloudflare_pages_domain" "this" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.this.name
  name         = var.pages_domain

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = var.environment != "staging" || (can(regex("staging", lower(var.pages_domain))) && !can(regex("prod(uction)?", lower(var.pages_domain))))
      error_message = "The staging root must target a staging Pages domain, never the opposite environment."
    }

    precondition {
      condition     = var.environment != "prod" || !can(regex("staging", lower(var.pages_domain)))
      error_message = "The prod root cannot target a staging Pages domain from the opposite environment."
    }
  }
}

resource "cloudflare_dns_record" "pages" {
  zone_id = var.cloudflare_zone_id
  name    = var.pages_domain
  type    = "CNAME"
  content = cloudflare_pages_project.this.subdomain
  ttl     = 1
  proxied = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "github_repository_environment" "this" {
  repository  = var.github_repository
  environment = var.environment

  lifecycle {
    prevent_destroy = true
  }
}

resource "github_actions_environment_variable" "control_plane" {
  for_each = local.github_environment_variables

  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = each.key
  value         = each.value

  lifecycle {
    prevent_destroy = true
  }
}

terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
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

terraform {
  required_version = "~> 1.15.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.24.0"
    }
  }
}

# Authentication comes exclusively from the runtime environment.
provider "cloudflare" {}

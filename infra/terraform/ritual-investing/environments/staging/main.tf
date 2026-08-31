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
  github_repository     = var.github_repository
}

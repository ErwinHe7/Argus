output "pages_project_name" {
  description = "Managed Cloudflare Pages project name."
  value       = cloudflare_pages_project.this.name
}

output "pages_domain" {
  description = "Managed Cloudflare Pages custom domain."
  value       = cloudflare_pages_domain.this.name
}

output "dns_record_id" {
  description = "Managed Cloudflare DNS record identifier."
  value       = cloudflare_dns_record.pages.id
}

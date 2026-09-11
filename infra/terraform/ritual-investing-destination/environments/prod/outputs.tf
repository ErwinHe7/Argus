output "resource_identifiers" {
  description = "Destination resource IDs/names and public Turnstile sitekeys only; no widget secrets or integration settings."
  value       = module.account_resources.resource_identifiers
}

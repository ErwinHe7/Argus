# Provider-specific Cloudflare identifiers are exact, opaque inventory inputs.
import {
  for_each = var.enable_brownfield_imports ? { landing = { id = try(var.brownfield_import_inventory.landing_pages_project_import_id, "") } } : {}

  to = module.pages_environment.cloudflare_pages_project.this
  id = each.value.id
}

import {
  for_each = var.enable_brownfield_imports ? { landing = { id = try(var.brownfield_import_inventory.landing_pages_domain_import_id, "") } } : {}

  to = module.pages_environment.cloudflare_pages_domain.this
  id = each.value.id
}

import {
  for_each = var.enable_brownfield_imports ? { landing = { id = try(var.brownfield_import_inventory.landing_dns_record_import_id, "") } } : {}

  to = module.pages_environment.cloudflare_dns_record.pages
  id = each.value.id
}

import {
  for_each = var.enable_brownfield_imports ? { demo = { id = try(var.brownfield_import_inventory.demo_pages_project_import_id, "") } } : {}

  to = cloudflare_pages_project.demo
  id = each.value.id
}

import {
  for_each = var.enable_brownfield_imports ? { demo = { id = try(var.brownfield_import_inventory.demo_pages_domain_import_id, "") } } : {}

  to = cloudflare_pages_domain.demo
  id = each.value.id
}

import {
  for_each = var.enable_brownfield_imports ? { demo = { id = try(var.brownfield_import_inventory.demo_dns_record_import_id, "") } } : {}

  to = cloudflare_dns_record.demo
  id = each.value.id
}

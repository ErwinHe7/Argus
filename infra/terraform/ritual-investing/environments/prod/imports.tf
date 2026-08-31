# Provider-specific Cloudflare identifiers are opaque inventory inputs. The
# current Cloudflare Pages domain importer uses the domain name itself.
import {
  for_each = var.enable_brownfield_imports ? { landing = { id = try(var.brownfield_import_inventory.landing_pages_project_import_id, "") } } : {}

  to = module.pages_environment.cloudflare_pages_project.this
  id = each.value.id
}

import {
  for_each = var.enable_brownfield_imports ? { landing = { name = try(var.brownfield_import_inventory.landing_pages_domain_name, "") } } : {}

  to = module.pages_environment.cloudflare_pages_domain.this
  id = each.value.name
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
  for_each = var.enable_brownfield_imports ? { demo = { name = try(var.brownfield_import_inventory.demo_pages_domain_name, "") } } : {}

  to = cloudflare_pages_domain.demo
  id = each.value.name
}

import {
  for_each = var.enable_brownfield_imports ? { demo = { id = try(var.brownfield_import_inventory.demo_dns_record_import_id, "") } } : {}

  to = cloudflare_dns_record.demo
  id = each.value.id
}

# integrations/github v6 imports environments as <repository>:<environment>.
import {
  for_each = var.enable_brownfield_imports ? { environment = "${var.github_repository}:${var.environment}" } : {}

  to = module.pages_environment.github_repository_environment.this
  id = each.value
}

import {
  for_each = var.enable_brownfield_imports ? try(var.brownfield_import_inventory.github_environment_variable_import_ids, {}) : {}

  to = module.pages_environment.github_actions_environment_variable.control_plane[each.key]
  id = each.value
}

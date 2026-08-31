# Imports remain inert until an operator supplies the exact sanitized live
# inventory and explicitly selects the manual inventory/import-plan phase.
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

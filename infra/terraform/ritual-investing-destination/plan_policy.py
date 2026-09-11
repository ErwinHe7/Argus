"""Saved-plan provisioning policy for the reviewed Cloudflare 5.24.0 schema.

Computed-only fields are never required known on create. Excluded hosted surfaces
still need independent API verification before apply.
"""
import json
import re

PROVIDER = "registry.terraform.io/cloudflare/cloudflare"
FIELDS = {
    "cloudflare_worker": ({"account_id", "logpush", "name", "observability", "subdomain", "tags", "tail_consumers"},
                         {"created_on", "deployed_on", "id", "references", "updated_on"}),
    "cloudflare_pages_project": ({"account_id", "build_config", "deployment_configs", "name", "production_branch", "source"},
                                {"canonical_deployment", "created_on", "domains", "framework", "framework_version", "id", "latest_deployment", "preview_script_name", "production_script_name", "subdomain", "uses_functions"}),
    "cloudflare_workers_kv_namespace": ({"account_id", "title"}, {"id", "supports_url_encoding"}),
    "cloudflare_r2_bucket": ({"account_id", "jurisdiction", "location", "name", "storage_class"}, {"creation_date", "id"}),
    "cloudflare_queue": ({"account_id", "queue_name", "settings"}, {"consumers", "consumers_total_count", "created_on", "id", "modified_on", "producers", "producers_total_count", "queue_id"}),
    "cloudflare_turnstile_widget": ({"account_id", "bot_fight_mode", "clearance_level", "domains", "ephemeral_id", "mode", "name", "offlabel", "region"},
                                   {"created_on", "deployed_via", "id", "last_modified_via", "modified_on", "secret", "sitekey"}),
}
GROUPS = {"workers": ("cloudflare_worker", "identities"), "pages": ("cloudflare_pages_project", "shells"),
          "kv_namespaces": ("cloudflare_workers_kv_namespace", "empty"), "r2_buckets": ("cloudflare_r2_bucket", "private"),
          "queues": ("cloudflare_queue", "paused"), "turnstile": ("cloudflare_turnstile_widget", "unused")}


class PolicyError(Exception):
    pass


def require(condition):
    if not condition:
        raise PolicyError("Saved plan is outside the destination provisioning policy.")


def unknown(value):
    if isinstance(value, dict):
        return any(unknown(item) for item in value.values())
    if isinstance(value, list):
        return any(unknown(item) for item in value)
    return value is not False and value is not None


def known(after, uncertain, key, expected):
    require(isinstance(after, dict) and isinstance(uncertain, dict))
    require(key in after and not unknown(uncertain.get(key)) and after[key] == expected)
    # bool and number equality must not make enabled=0 equivalent to false.
    if isinstance(expected, bool):
        require(after[key] is expected)


def expected_resources(target, catalog):
    if target == "bootstrap":
        return {f'cloudflare_r2_bucket.state["{target}"]': ("cloudflare_r2_bucket", {
            "name": f"ritual-investing-terraform-state-{target}", "jurisdiction": "default", "storage_class": "Standard", "location": None})
                for target in ("prod", "staging")}
    require(target in ("staging", "prod") and isinstance(catalog, dict))
    require(catalog.get("schema_version") == 1 and catalog.get("environment") == target)
    require(set(catalog) == {"schema_version", "environment", *GROUPS})
    result = {}
    for group, (kind, name) in GROUPS.items():
        require(isinstance(catalog[group], dict))
        for key, values in catalog[group].items():
            require(isinstance(key, str) and re.fullmatch(r"[a-z0-9_]+", key) and isinstance(values, dict))
            result[f'module.account_resources.{kind}.{name}["{key}"]'] = (kind, values)
    require(len(result) == (15 if target == "staging" else 13))
    return result


def configuration_resources(plan, expected):
    config = plan.get("configuration")
    require(isinstance(config, dict) and isinstance(config.get("provider_config"), dict))
    providers = config["provider_config"]
    require(set(providers) == {"cloudflare"})
    require(providers["cloudflare"].get("full_name") == PROVIDER)
    # API origins and credentials cannot be configured through provider arguments.
    require(not providers["cloudflare"].get("expressions"))
    found = {}

    def visit(module, prefix=""):
        require(isinstance(module, dict))
        for resource in module.get("resources", []):
            require(isinstance(resource, dict) and resource.get("mode") == "managed")
            require(not resource.get("provisioners") and not resource.get("connection"))
            require(resource.get("provider_config_key") == "cloudflare")
            kind = resource.get("type")
            require(kind in FIELDS)
            address = prefix + resource.get("address", "")
            require(address not in found)
            expressions = resource.get("expressions")
            require(isinstance(expressions, dict) and set(expressions) <= FIELDS[kind][0])
            if kind == "cloudflare_pages_project":
                require(not ({"source", "build_config", "deployment_configs"} & set(expressions)))
            if kind == "cloudflare_worker":
                require(not ({"observability", "tags"} & set(expressions)))
            found[address] = expressions
        for name, call in module.get("module_calls", {}).items():
            require(name == "account_resources" and not prefix and call.get("source") == "../../modules/account-resources")
            visit(call.get("module"), "module.account_resources.")

    visit(config.get("root_module"))
    require(set(found) == {address.split("[")[0] for address in expected})
    return found


def safe_values(kind, after, uncertain, values, account):
    require(isinstance(after, dict) and isinstance(uncertain, dict))
    require(set(after) | set(uncertain) <= FIELDS[kind][0] | FIELDS[kind][1])
    known(after, uncertain, "account_id", account)
    if kind in ("cloudflare_worker", "cloudflare_pages_project", "cloudflare_r2_bucket", "cloudflare_turnstile_widget"):
        known(after, uncertain, "name", values["name"])
    if kind == "cloudflare_worker":
        known(after, uncertain, "logpush", False)
        known(after, uncertain, "tail_consumers", [])
        known(after, uncertain, "tags", [])
        subdomain, sub_unknown = after.get("subdomain"), uncertain.get("subdomain", {})
        known(subdomain, sub_unknown, "enabled", False)
        known(subdomain, sub_unknown, "previews_enabled", False)
        require(set(subdomain) | set(sub_unknown) <= {"enabled", "previews_enabled", "url", "preview_url_suffix"})
        observability, obs_unknown = after.get("observability"), uncertain.get("observability", {})
        known(observability, obs_unknown, "enabled", False)
        require(set(observability) | set(obs_unknown) <= {"enabled", "head_sampling_rate", "logs", "traces"})
        traces, trace_unknown = observability.get("traces"), obs_unknown.get("traces", {})
        known(traces, trace_unknown, "enabled", False)
        require(set(traces) | set(trace_unknown) <= {"enabled", "head_sampling_rate", "persist", "destinations", "propagation_policy"})
        # Unknown nested logs/traces defaults are inert because enabled is known false.
    elif kind == "cloudflare_pages_project":
        known(after, uncertain, "production_branch", values["production_branch"])
        known(after, uncertain, "source", None)
        # Omission in configuration is mandatory (checked above). Read-back may
        # contain provider-computed build/deployment defaults even on creation.
    elif kind == "cloudflare_workers_kv_namespace":
        known(after, uncertain, "title", values["title"])
    elif kind == "cloudflare_r2_bucket":
        for field in ("jurisdiction", "storage_class"):
            known(after, uncertain, field, values[field])
        if values.get("location") is not None:
            known(after, uncertain, "location", values["location"])
    elif kind == "cloudflare_queue":
        known(after, uncertain, "queue_name", values["queue_name"])
        settings, settings_unknown = after.get("settings"), uncertain.get("settings", {})
        known(settings, settings_unknown, "delivery_paused", True)
        require(set(settings) | set(settings_unknown) <= {"delivery_paused", "delivery_delay", "message_retention_period"})
        for field in ("delivery_delay", "message_retention_period"):
            if values[field] is not None:
                queue_value(field, values[field])
                known(settings, settings_unknown, field, values[field])
    elif kind == "cloudflare_turnstile_widget":
        for field in ("domains", "mode", "region"):
            known(after, uncertain, field, values[field])
        known(after, uncertain, "clearance_level", "no_clearance")
        for field in ("bot_fight_mode", "ephemeral_id", "offlabel"):
            known(after, uncertain, field, False)


def queue_value(field, value):
    lower, upper = (0, 86400) if field == "delivery_delay" else (60, 1209600)
    require(type(value) in (int, float) and lower <= value <= upper and value == int(value))


def resource_values(module):
    """Flatten Terraform's JSON values representation without hiding child modules."""
    require(isinstance(module, dict))
    result = {}
    for resource in module.get("resources", []):
        require(isinstance(resource, dict) and isinstance(resource.get("address"), str))
        require(resource["address"] not in result)
        result[resource["address"]] = resource
    for child in module.get("child_modules", []):
        nested = resource_values(child)
        require(not set(result) & set(nested))
        result.update(nested)
    return result


def owned_resources(state, expected, account):
    """Validate raw state ownership, returning address -> provider attributes."""
    if state is None:
        return {}
    from state_backend import _validate_state
    _validate_state(state)
    result = {}
    for resource in state["resources"]:
        require(resource.get("mode") == "managed" and resource.get("provider") == 'provider["' + PROVIDER + '"]')
        for instance in resource["instances"]:
            prefix = resource.get("module", "")
            address = (prefix + "." if prefix else "") + resource["type"] + "." + resource["name"]
            if "index_key" in instance:
                address += "[" + json.dumps(instance["index_key"], separators=(",", ":")) + "]"
            require(address in expected and address not in result)
            kind, catalog = expected[address]
            attrs = instance["attributes"]
            name = "title" if kind == "cloudflare_workers_kv_namespace" else "queue_name" if kind == "cloudflare_queue" else "name"
            require(attrs.get("account_id") == account and attrs.get(name) == catalog[name])
            require(isinstance(attrs.get("id"), str) and bool(attrs["id"]))
            result[address] = attrs
    return result


def inactive_values(kind, after, uncertain):
    """Critical computed fields must be known on existing resources."""
    if kind == "cloudflare_worker":
        known(after, uncertain, "deployed_on", None)
        references = after.get("references")
        require(isinstance(references, dict) and not unknown(uncertain.get("references")))
        require(set(references) == {"workers", "domains", "dispatch_namespace_outbounds", "durable_objects", "queues"})
        require(all(value == [] for value in references.values()))
    elif kind == "cloudflare_pages_project":
        for field in ("canonical_deployment", "latest_deployment"):
            known(after, uncertain, field, None)
    elif kind == "cloudflare_queue":
        for field in ("consumers", "producers"):
            known(after, uncertain, field, [])
            known(after, uncertain, field + "_total_count", 0)
            require(type(after[field + "_total_count"]) is int)
        for field in ("delivery_delay", "message_retention_period"):
            settings = after["settings"]
            require(not unknown(uncertain.get("settings", {}).get(field)))
            queue_value(field, settings.get(field))


def inspect_outputs(plan, target, expected):
    """Only derived nonsecret identifiers may reconcile without resource changes."""
    name = "state_buckets" if target == "bootstrap" else "resource_identifiers"
    planned_outputs = plan.get("planned_values", {}).get("outputs", {})
    require(isinstance(planned_outputs, dict) and set(planned_outputs) <= {name})
    require(all(output.get("sensitive") is False for output in planned_outputs.values()))
    outputs = plan.get("output_changes", {})
    require(isinstance(outputs, dict) and set(outputs) <= {name})
    for output in outputs.values():
        require(output.get("actions") in (["create"], ["update"], ["no-op"]))
        require(output.get("after_sensitive") is False)
        after, uncertain = output.get("after"), output.get("after_unknown", {})
        # Output type/unknown details differ across TF phases. Validate every
        # known leaf against the corresponding resource, never against free text.
        shape = {}
        resources = {resource["address"]: resource["change"]["after"] for resource in plan["resource_changes"]}
        for address, (kind, values) in expected.items():
            key = address.split('["')[1][:-2]
            if target == "bootstrap":
                shape[key] = {"id": resources[address].get("id"), "account_id": resources[address]["account_id"], "name": values["name"]}
            else:
                group = next(group for group, pair in GROUPS.items() if pair[0] == kind)
                field = "sitekey" if kind == "cloudflare_turnstile_widget" else "id"
                label = "title" if kind == "cloudflare_workers_kv_namespace" else "name"
                shape.setdefault(group, {})[key] = {field: resources[address].get("queue_id" if kind == "cloudflare_queue" else field), label: values.get(label, values.get("queue_name"))}
        def inspect(value, template, unknowns):
            require(isinstance(value, dict) and isinstance(unknowns, dict))
            require(set(value) | set(unknowns) <= set(template))
            require(set(value) | {key for key, item in unknowns.items() if unknown(item)} == set(template))
            for key, expected_value in template.items():
                if isinstance(expected_value, dict):
                    inspect(value.get(key, {}), expected_value, unknowns.get(key, {}))
                elif expected_value is None:
                    require(key not in value and unknowns.get(key) is True)
                else:
                    require(value.get(key) == expected_value and not unknown(unknowns.get(key)))
        inspect(after, shape, uncertain)
    return any(output["actions"] != ["no-op"] for output in outputs.values())


def safe_queue_update(before, after, uncertain, values):
    """Allow provider-computed update metadata; configured activation stays known."""
    inactive_values("cloudflare_queue", before, {})
    known(before["settings"], {}, "delivery_paused", True)
    require(set(before) == set(after) | set(uncertain))
    for field in ("account_id", "queue_name", "id", "queue_id"):
        require(isinstance(before.get(field), str) and bool(before[field]))
        known(after, uncertain, field, before[field])
    for field, empty in (("consumers", []), ("producers", []),
                         ("consumers_total_count", 0), ("producers_total_count", 0)):
        if uncertain.get(field) is True:
            require(field not in after)
        else:
            known(after, uncertain, field, empty)
            if empty == 0:
                require(type(after[field]) is int)
    settings, settings_unknown = after["settings"], uncertain.get("settings", {})
    fields = {"delivery_delay", "delivery_paused", "message_retention_period"}
    require(set(before["settings"]) == fields and set(settings) | set(settings_unknown) == fields)
    for field in ("delivery_delay", "message_retention_period"):
        if unknown(settings_unknown.get(field)):
            require(values[field] is None and settings_unknown[field] is True and field not in settings)
        else:
            queue_value(field, settings.get(field))


def inspect_plan(plan, account, target, catalog=None, *, initialized=False):
    """Return only allowlisted action counts; never serialize plan values."""
    try:
        require(isinstance(plan, dict) and plan.get("format_version") == "1.2")
        require(re.fullmatch(r"1\.15\.\d+", plan.get("terraform_version", "")))
        require(plan.get("complete") is True and plan.get("errored") is False)
        expected = expected_resources(target, catalog)
        configuration_resources(plan, expected)
        changes = plan.get("resource_changes")
        require(isinstance(changes, list))
        seen = set()
        counts = {"create": 0, "no-op": 0, "update": 0, "delete": 0}
        for resource in changes:
            require(isinstance(resource, dict))
            address = resource.get("address")
            require(address in expected and address not in seen)
            seen.add(address)
            kind, values = expected[address]
            require(resource.get("type") == kind and resource.get("mode") == "managed" and resource.get("provider_name") == PROVIDER)
            require(not resource.get("previous_address"))
            change = resource.get("change")
            require(isinstance(change, dict) and not change.get("importing"))
            actions = change.get("actions")
            require(actions in (["create"], ["no-op"], ["update"]))
            require(actions != ["update"] or initialized and kind == "cloudflare_queue" and target != "bootstrap")
            require(not change.get("replace_paths"))
            require(change.get("before") is None if actions == ["create"] else isinstance(change.get("before"), dict))
            safe_values(kind, change.get("after"), change.get("after_unknown", {}), values, account)
            if actions != ["create"]:
                before, after = change["before"], change["after"]
                if actions == ["no-op"]:
                    inactive_values(kind, after, change.get("after_unknown", {}))
                    require(before == after)
                else:
                    safe_queue_update(before, after, change.get("after_unknown", {}), values)
            counts[actions[0]] += 1
        require(seen == set(expected))
        planned = resource_values(plan.get("planned_values", {}).get("root_module"))
        require(set(planned) == set(expected))
        for resource in changes:
            item = planned[resource["address"]]
            require(item.get("type") == resource["type"] and item.get("mode") == "managed" and item.get("provider_name") == PROVIDER)
            require(item.get("values") == resource["change"]["after"])
        for drift in plan.get("resource_drift", []):
            require(drift.get("address") in expected and drift.get("change", {}).get("actions") == ["no-op"])
            require(drift.get("mode") == "managed" and drift.get("provider_name") == PROVIDER and drift.get("type") == expected[drift["address"]][0])
            require(drift["change"].get("before") == drift["change"].get("after"))
        inspect_outputs(plan, target, expected)
        require(not plan.get("deferred_changes"))
        require(all(check.get("status") == "pass" for check in plan.get("checks", [])))
        return counts
    except (KeyError, TypeError, ValueError, AttributeError):
        raise PolicyError("Saved plan is incomplete or outside the destination provisioning policy.") from None

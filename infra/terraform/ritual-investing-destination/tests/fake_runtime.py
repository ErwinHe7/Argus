"""Process-level Terraform and HTTP fixtures for real CLI recovery tests only."""
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.parse

ACCOUNT = "1" * 32
SECRET = "synthetic-private-widget-secret-never-print"


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value))


def storage():
    return Path(os.environ["FAKE_REMOTE"])


def backend(root):
    path = root / "fake-backend.json"
    return json.loads(path.read_text()) if path.exists() else None


def state_path(root):
    value = backend(root)
    return storage() / value["bucket"] / value["key"] if value else root / "terraform.tfstate"


def load(path):
    return json.loads(path.read_text()) if path.exists() else None


def flatten(state):
    result = {}
    if state:
        for resource in state["resources"]:
            for instance in resource["instances"]:
                prefix = resource.get("module", "")
                address = (prefix + "." if prefix else "") + resource["type"] + "." + resource["name"] + "[" + json.dumps(instance["index_key"]) + "]"
                result[address] = instance["attributes"]
    return result


def materialize(resource):
    attrs = copy.deepcopy(resource["change"]["after"])
    def fill(value, uncertain):
        for key, item in uncertain.items():
            if item is True:
                value.setdefault(key, None)
            elif isinstance(item, dict):
                value.setdefault(key, {})
                fill(value[key], item)
    fill(attrs, resource["change"]["after_unknown"])
    identifier = hashlib.sha256(resource["address"].encode()).hexdigest()[:32]
    attrs["id"] = identifier
    kind = resource["type"]
    if kind == "cloudflare_worker":
        attrs["references"] = {key: [] for key in ("workers", "domains", "dispatch_namespace_outbounds", "durable_objects", "queues")}
        attrs["deployed_on"] = None
    elif kind == "cloudflare_pages_project":
        attrs.update(subdomain=attrs["name"] + "-fixture.pages.dev", domains=[attrs["name"] + "-fixture.pages.dev"], canonical_deployment=None, latest_deployment=None)
    elif kind == "cloudflare_queue":
        attrs.update(queue_id=identifier, producers=[], consumers=[], producers_total_count=0, consumers_total_count=0)
        previous = (resource["change"].get("before") or {}).get("settings", {})
        for field, default in (("delivery_delay", 0), ("message_retention_period", 345600)):
            if attrs["settings"].get(field) is None:
                attrs["settings"][field] = previous.get(field, default)
    elif kind == "cloudflare_turnstile_widget":
        attrs.update(sitekey=identifier, secret=SECRET)
    return attrs


def plan_for(root):
    target = root.name if root.name in ("prod", "staging") else "bootstrap"
    feature = Path(os.environ["FAKE_FEATURE"])
    plan = load(feature / "tests/fixtures" / ("provider-5.24-" + ("staging" if target != "bootstrap" else target) + "-create.json"))
    existing = load(state_path(root))
    owned = flatten(existing)
    catalog = load(root / "catalog.json")
    values_by_address = {}
    for resource in plan["resource_changes"]:
        address = resource["address"]
        before = owned.get(address)
        if before:
            after = copy.deepcopy(before)
            if resource["type"] == "cloudflare_queue":
                for key in ("delivery_delay", "message_retention_period"):
                    selected = catalog["queues"][resource["index"]][key]
                    if selected is not None:
                        after["settings"][key] = selected
            resource["change"].update(actions=["no-op" if before == after else "update"], before=before, after=after, after_unknown={})
            if resource["change"]["actions"] == ["update"]:
                uncertain = resource["change"]["after_unknown"]
                # Observed Cloudflare 5.24 update shape: computed metadata and
                # omitted optional settings are unknown until the update returns.
                for field in ("consumers", "producers", "consumers_total_count", "producers_total_count", "created_on", "modified_on"):
                    after.pop(field, None)
                    uncertain[field] = True
                uncertain["settings"] = {}
                for field in ("delivery_delay", "message_retention_period"):
                    if catalog["queues"][resource["index"]][field] is None:
                        after["settings"].pop(field, None)
                        uncertain["settings"][field] = True
        elif catalog and resource["type"] == "cloudflare_queue":
            for key in ("delivery_delay", "message_retention_period"):
                selected = catalog["queues"][resource["index"]][key]
                if selected is not None:
                    resource["change"]["after"]["settings"][key] = selected
                    resource["change"]["after_unknown"]["settings"].pop(key, None)
        values_by_address[address] = resource["change"]["after"]
    def update_values(module):
        for resource in module.get("resources", []):
            resource["values"] = values_by_address[resource["address"]]
        for child in module.get("child_modules", []):
            update_values(child)
    update_values(plan["planned_values"]["root_module"])
    name = "state_buckets" if target == "bootstrap" else "resource_identifiers"
    output, uncertain = {}, {}
    groups = {"cloudflare_worker": "workers", "cloudflare_pages_project": "pages", "cloudflare_queue": "queues", "cloudflare_workers_kv_namespace": "kv_namespaces", "cloudflare_r2_bucket": "r2_buckets", "cloudflare_turnstile_widget": "turnstile"}
    for resource in plan["resource_changes"]:
        attrs, kind, key = resource["change"]["after"], resource["type"], resource["index"]
        known = resource["change"]["actions"] != ["create"]
        if target == "bootstrap":
            item, unknown = {"name": attrs["name"], "account_id": ACCOUNT}, {}
            destination, unknown_destination = output, uncertain
        else:
            label = "title" if kind == "cloudflare_workers_kv_namespace" else "name"
            item, unknown = {label: attrs.get(label, attrs.get("queue_name"))}, {}
            destination = output.setdefault(groups[kind], {})
            unknown_destination = uncertain.setdefault(groups[kind], {})
        field = "sitekey" if kind == "cloudflare_turnstile_widget" else "id"
        if known:
            item[field] = attrs.get("queue_id") if kind == "cloudflare_queue" else attrs[field]
        else:
            unknown[field] = True
        destination[key], unknown_destination[key] = item, unknown
    prior = existing.get("outputs", {}).get(name, {}).get("value") if existing else None
    changing = any(r["change"]["actions"] != ["no-op"] for r in plan["resource_changes"])
    actions = ["create"] if prior is None else ["no-op"] if prior == output and not changing else ["update"]
    plan["output_changes"] = {name: {"actions": actions, "before": prior, "after": output, "after_unknown": uncertain, "after_sensitive": False}}
    return plan


def terraform():
    root, args = Path.cwd(), sys.argv[1:]
    with open(os.environ["FAKE_CALLS"], "a") as log:
        log.write(json.dumps({"terraform": args, "cwd": str(root)}) + "\n")
    print(SECRET) if args[0] not in ("show", "version") else None
    if args[0] == "version":
        print(json.dumps({"terraform_version": "1.15.0"}))
    elif args[0] == "init":
        config = next((arg.split("=", 1)[1] for arg in args if arg.startswith("-backend-config=")), None)
        if config:
            value = load(root / config)
            if "-migrate-state" in args:
                write(storage() / value["bucket"] / value["key"], load(root / "terraform.tfstate"))
            write(root / "fake-backend.json", value)
        elif "-reconfigure" in args and (root / "fake-backend.json").exists():
            (root / "fake-backend.json").unlink()
    elif args[0] == "show":
        print(Path(args[-1]).read_text())
    elif args[0] == "plan":
        value = backend(root)
        if value and value["key"].startswith("locking-check/"):
            lock = storage() / value["bucket"] / (value["key"] + ".tflock")
            if lock.exists():
                print("Error acquiring the state lock " + load(lock)["ID"])
                return 1
            if "-input=true" in args:
                write(lock, {"ID": "fixture-lock", "Path": value["bucket"] + "/" + value["key"]})
                input()
                lock.unlink()
            return 0
        plan = plan_for(root)
        if os.environ.get("FAKE_POST_DRIFT") and (storage() / "applied").exists():
            return 2
        destination = next(arg[5:] for arg in args if arg.startswith("-out="))
        write(Path(destination), plan)
        return 2 if any(r["change"]["actions"] != ["no-op"] for r in plan["resource_changes"]) or any(o["actions"] != ["no-op"] for o in plan["output_changes"].values()) else 0
    elif args[0] == "apply":
        plan = load(Path(args[-1]))
        prior = load(state_path(root))
        resources = []
        for index, resource in enumerate(plan["resource_changes"]):
            if os.environ.get("FAKE_PARTIAL") and index:
                continue
            attrs = materialize(resource)
            address = resource["address"]
            value = {"mode": "managed", "type": resource["type"], "name": resource["name"], "provider": 'provider["registry.terraform.io/cloudflare/cloudflare"]',
                     "instances": [{"index_key": resource["index"], "schema_version": 0, "attributes": attrs}]}
            if address.startswith("module."):
                value["module"] = "module.account_resources"
            resources.append(value)
        state = {"version": 4, "terraform_version": "1.15.0", "lineage": prior["lineage"] if prior else "fixture-" + root.name,
                 "serial": prior["serial"] + 1 if prior else 1, "resources": resources, "outputs": {}}
        path = state_path(root)
        write(path, state)
        # Derive completed outputs from the same state/configuration.
        completed = plan_for(root)
        state["outputs"] = {key: {"value": output["after"], "sensitive": False} for key, output in completed["output_changes"].items()}
        write(path, state)
        write(storage() / "applied", True)
        if os.environ.get("FAKE_EMERGENCY"):
            write(root / "errored.tfstate", state)
            return 1
        return 1 if os.environ.get("FAKE_PARTIAL") else 0
    else:
        return 99
    return 0


def request(opener, req, *args, **kwargs):
    class Response(io.BytesIO):
        status = 200
    parsed = urllib.parse.urlsplit(req.full_url)
    with open(os.environ["FAKE_CALLS"], "a") as log:
        log.write(json.dumps({"http": req.full_url, "method": req.method}) + "\n")
    if parsed.netloc == ACCOUNT + ".r2.cloudflarestorage.com":
        path = storage() / parsed.path.lstrip("/")
        if path.exists():
            return Response(path.read_bytes())
        body = b"<Error><Code>NoSuchKey</Code></Error>"
        if os.environ.get("FAKE_S3_DENIED"):
            raise urllib.error.HTTPError(req.full_url, 403, "denied", {}, io.BytesIO(body))
        raise urllib.error.HTTPError(req.full_url, 404, "absent", {}, io.BytesIO(body))
    assert parsed.netloc == "api.cloudflare.com"
    assert req.method == "GET"
    resources = {}
    local = Path(os.environ["FAKE_PRIVATE_HOME"]) / ".local/state/ritual-investing-destination/accounts" / ACCOUNT / "work/terraform.tfstate"
    for path in [local, *storage().rglob("terraform.tfstate")]:
        resources.update(flatten(load(path)))
    values = list(resources.values())
    suffix = parsed.path.removeprefix("/client/v4/accounts/" + ACCOUNT)
    if suffix == "":
        result = {"id": ACCOUNT, "name": "LeoInvestment"}
    elif suffix == "/r2/buckets":
        return Response(json.dumps({"success": True, "result": {"buckets": [{"name": value["name"]} for value in values if "storage_class" in value]}, "result_info": {"cursor": None}}).encode())
    elif suffix.startswith("/r2/buckets/"):
        name = suffix.split("/")[3]
        result = next(value for value in values if value.get("name") == name)
        if suffix.endswith("/domains/managed"):
            result = {"enabled": bool(os.environ.get("FAKE_PUBLIC"))}
        elif suffix.endswith("/domains/custom"):
            result = {"domains": []}
    else:
        result = []
        if parsed.path == "/client/v4/zones":
            result = []
        else:
            paths = {"/workers/workers": "subdomain", "/pages/projects": "production_branch", "/storage/kv/namespaces": "title", "/queues": "queue_name", "/challenges/widgets": "sitekey"}
            matched = False
            for prefix, field in paths.items():
                if suffix == prefix or suffix.startswith(prefix + "/"):
                    matched = True
                    selected = [value for value in values if field in value and (prefix != "/workers/workers" or "logpush" in value)]
                    if suffix == prefix:
                        result = selected
                    elif suffix.endswith(("/versions", "/deployments")):
                        result = [{"id": "activated"}] if os.environ.get("FAKE_ACTIVATED") else []
                    else:
                        identifier = suffix[len(prefix) + 1:]
                        result = next(value for value in selected if identifier in (value.get("id"), value.get("name"), value.get("sitekey"), value.get("queue_id")))
                    break
            assert matched or parsed.path == "/client/v4/zones", parsed.path
    params = urllib.parse.parse_qs(parsed.query)
    info = None
    if isinstance(result, list):
        page, per_page = int(params.get("page", [1])[0]), int(params.get("per_page", [100])[0])
        total = len(result)
        result = result[(page - 1) * per_page:page * per_page]
        info = {"page": page, "per_page": per_page, "count": len(result), "total_count": total}
    return Response(json.dumps({"success": True, "result": result, "result_info": info}).encode())

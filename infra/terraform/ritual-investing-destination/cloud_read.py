"""Read-only destination API transport. Payloads stay in private artifact files."""
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.parse
import urllib.request
import uuid

from state_backend import BackendSpec, _NoRedirect, _no_duplicates, private_write


class CloudError(Exception):
    """Never contains provider payloads, credentials, or caller-controlled text."""


class OutsideScope(CloudError):
    """Independent API evidence shows activation outside provisioning."""


def require(condition):
    if not condition:
        raise CloudError("Destination resource evidence is incomplete or does not match owned state.")


def inactive(condition):
    if not condition:
        raise OutsideScope("Destination resource activation is outside provisioning scope.")


class CloudRead:
    ORIGIN = "https://api.cloudflare.com/client/v4"

    def __init__(self, account, directory):
        BackendSpec(account, "bootstrap")
        self.account = account
        self.directory = Path(directory) / "api"
        self.verified_zones = set()
        self.token = os.environ.get("CLOUDFLARE_API_TOKEN", "")
        if not re.fullmatch(r"[A-Za-z0-9_-]+", self.token):
            raise CloudError("A destination API token is required.")

    def get(self, path, *, headers=None):
        # The caller may select only account-scoped read paths. No redirects,
        # environment proxies, credentials in URLs, or configurable API origin.
        account_path = (path == f"/accounts/{self.account}" or path.startswith(f"/accounts/{self.account}/"))
        zone_list = bool(re.fullmatch(r"/zones\?account.id=" + self.account + r"&page=[0-9]+&per_page=50", path))
        zone_routes = any(path == f"/zones/{zone}/workers/routes" for zone in self.verified_zones)
        if (not (account_path or zone_list or zone_routes) or
                not re.fullmatch(r"/[A-Za-z0-9_./%-]+(?:\?[A-Za-z0-9_=&%.-]+)?", path) or
                ".." in path or "%" in path.split("?")[0]):
            raise CloudError("Destination API path is invalid.")
        request_headers = {"Authorization": "Bearer " + self.token, "Accept": "application/json"}
        if headers:
            if set(headers) != {"cf-r2-jurisdiction"} or headers["cf-r2-jurisdiction"] not in ("default", "eu", "fedramp"):
                raise CloudError("Destination API headers are invalid.")
            request_headers.update(headers)
        request = urllib.request.Request(self.ORIGIN + path, headers=request_headers, method="GET")
        destination = self.directory / (uuid.uuid4().hex + ".json")
        try:
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), _NoRedirect())
            with opener.open(request, timeout=30) as response:
                data = response.read(8 * 1024 * 1024 + 1)
                private_write(destination, data)
                if response.status != 200 or len(data) > 8 * 1024 * 1024:
                    raise CloudError("Destination API response is incomplete.")
            value = json.loads(data, object_pairs_hook=_no_duplicates)
            if (not isinstance(value, dict) or value.get("success") is not True or
                    value.get("errors") not in (None, []) or "result" not in value):
                raise CloudError("Destination API read failed.")
            return value
        except urllib.error.HTTPError as error:
            with error:
                private_write(destination, error.read(8 * 1024 * 1024))
            raise CloudError("Destination API read failed; absence is unproven.") from None
        except (OSError, ValueError, TypeError, urllib.error.URLError):
            raise CloudError("Destination API transport or response failed.") from None

    def verify_account(self):
        result = self.get(f"/accounts/{self.account}")["result"]
        if not isinstance(result, dict) or result.get("id") != self.account or result.get("name") != "LeoInvestment":
            raise CloudError("Destination account identity does not match the verified profile.")
        return True

    def buckets(self):
        """Exhaust cursor pagination; permission failures never mean absence.

        Cloudflare List Buckets returns result.buckets and result_info.cursor.
        A full page without an explicit terminal cursor is ambiguous.
        """
        names, cursors, cursor = set(), set(), None
        for _ in range(1000):
            query = {"per_page": 1000}
            if cursor:
                query["cursor"] = cursor
            value = self.get(f"/accounts/{self.account}/r2/buckets?" + urllib.parse.urlencode(query))
            result, info = value["result"], value.get("result_info")
            if not isinstance(result, dict) or not isinstance(result.get("buckets"), list) or not isinstance(info, dict):
                raise CloudError("Destination bucket inventory is incomplete.")
            page = result["buckets"]
            for bucket in page:
                if (not isinstance(bucket, dict) or not isinstance(bucket.get("name"), str) or
                        not bucket["name"] or bucket["name"] in names):
                    raise CloudError("Destination bucket inventory is ambiguous.")
                names.add(bucket["name"])
            cursor = info.get("cursor")
            if cursor in (None, ""):
                if "cursor" not in info and len(page) >= 1000:
                    raise CloudError("Destination bucket pagination is incomplete.")
                return names
            if not isinstance(cursor, str) or not cursor or cursor in cursors or not page:
                raise CloudError("Destination bucket pagination is ambiguous.")
            cursors.add(cursor)
        raise CloudError("Destination bucket pagination exceeded its bound.")

    def require_bootstrap_absent(self):
        expected = {f"ritual-investing-terraform-state-{target}" for target in ("prod", "staging")}
        if self.buckets() & expected:
            raise CloudError("Existing destination state buckets require an explicit recovery or adoption decision.")
        return True

    def pages(self, path, *, page_size=100, query=None):
        """Return a complete stable inventory, never inferring absence from truncation."""
        result, total = [], None
        for page in range(1, 1001):
            params = {**(query or {}), "page": page, "per_page": page_size}
            value = self.get(path + "?" + urllib.parse.urlencode(params))
            items, info = value["result"], value.get("result_info")
            require(isinstance(items, list) and isinstance(info, dict))
            require(all(type(info.get(key)) is int for key in ("page", "per_page", "count", "total_count")))
            require(info["page"] == page and info["per_page"] == page_size and info["count"] == len(items))
            require(0 <= len(items) <= page_size and info["total_count"] >= 0)
            if total is None:
                total = info["total_count"]
            require(total == info["total_count"] and len(result) + len(items) <= total)
            pages = max(1, (total + page_size - 1) // page_size)
            require("total_pages" not in info or type(info["total_pages"]) is int and info["total_pages"] in ({0, 1} if total == 0 else {pages}))
            result.extend(items)
            if len(result) == total:
                require(page == pages)
                return result
            require(len(items) == page_size)
        raise CloudError("Destination pagination exceeded its bound.")

    def private_bucket(self, name, jurisdiction="default"):
        require(isinstance(name, str) and bool(re.fullmatch(r"[a-z0-9-]+", name)))
        path = f"/accounts/{self.account}/r2/buckets/{name}"
        headers = {"cf-r2-jurisdiction": jurisdiction}
        bucket = self.get(path, headers=headers)["result"]
        require(isinstance(bucket, dict) and bucket.get("name") == name)
        require(bucket.get("account_id", self.account) == self.account)
        require(bucket.get("jurisdiction", "default") == jurisdiction)
        managed = self.get(path + "/domains/managed", headers=headers)["result"]
        custom = self.get(path + "/domains/custom", headers=headers)["result"]
        require(isinstance(managed, dict) and isinstance(custom, dict))
        require("enabled" in managed and isinstance(custom.get("domains"), list))
        inactive(managed["enabled"] is False and custom["domains"] == [])
        return bucket

    def verify_buckets(self, spec):
        require(spec.account == self.account)
        names = {f"ritual-investing-terraform-state-{target}" for target in ("prod", "staging")}
        require(names <= self.buckets())
        for name in sorted(names):
            self.private_bucket(name)
        return True

    def verify_routes(self, workers):
        zones = self.pages("/zones", page_size=50, query={"account.id": self.account})
        verified = set()
        for zone in zones:
            require(isinstance(zone, dict) and zone.get("account", {}).get("id") == self.account)
            identifier = zone.get("id")
            require(isinstance(identifier, str) and bool(re.fullmatch(r"[0-9a-f]{32}", identifier)) and identifier not in verified)
            verified.add(identifier)
        self.verified_zones = verified
        for zone in sorted(verified):
            routes = self.get(f"/zones/{zone}/workers/routes")["result"]
            require(isinstance(routes, list))  # This endpoint is explicitly unpaginated.
            for route in routes:
                require(isinstance(route, dict) and "script" in route)
                inactive(route["script"] not in workers)

    def verify_resources(self, expected, owned, *, creating=(), require_all=False):
        """Cross-check catalog identity and unused surfaces against complete APIs.

        Only an explicit expected create permits absence. Present resources require
        state ownership; matching names alone never authorize adoption.
        """
        paths = {"cloudflare_worker": ("workers/workers", "name", "id"),
                 "cloudflare_pages_project": ("pages/projects", "name", "id"),
                 "cloudflare_workers_kv_namespace": ("storage/kv/namespaces", "title", "id"),
                 "cloudflare_queue": ("queues", "queue_name", "queue_id"),
                 "cloudflare_turnstile_widget": ("challenges/widgets", "name", "sitekey")}
        inventories = {}
        kinds = {kind for kind, _ in expected.values()}
        for kind in kinds:
            if kind == "cloudflare_r2_bucket":
                inventories[kind] = {name: {"name": name} for name in self.buckets()}
                continue
            suffix, name_field, _ = paths[kind]
            items = self.pages(f"/accounts/{self.account}/{suffix}")
            names, identifiers = {}, set()
            expected_names = {values[name_field] for resource_kind, values in expected.values() if resource_kind == kind}
            id_field = paths[kind][2]
            for item in items:
                require(isinstance(item, dict) and isinstance(item.get(name_field), str))
                identifier = item.get(id_field)
                require(isinstance(identifier, str) and identifier and identifier not in identifiers)
                identifiers.add(identifier)
                if item[name_field] in expected_names:
                    require(item[name_field] not in names)
                    names[item[name_field]] = item
            inventories[kind] = names
        workers = {values["name"] for kind, values in expected.values() if kind == "cloudflare_worker"}
        if workers:
            self.verify_routes(workers)
        for address, (kind, values) in expected.items():
            name_field = "title" if kind == "cloudflare_workers_kv_namespace" else "queue_name" if kind == "cloudflare_queue" else "name"
            name = values[name_field]
            item = inventories[kind].get(name)
            if item is None:
                require(not require_all and address in creating)
                continue
            require(address in owned)
            state = owned[address]
            if kind == "cloudflare_r2_bucket":
                self.private_bucket(name, values["jurisdiction"])
                continue
            suffix, _, id_field = paths[kind]
            identifier = item.get(id_field)
            require(isinstance(identifier, str) and bool(re.fullmatch(r"[A-Za-z0-9_-]+", identifier)))
            require(identifier == state.get(id_field, state.get("id")))
            selector = name if kind == "cloudflare_pages_project" else identifier
            require(isinstance(selector, str) and bool(re.fullmatch(r"[A-Za-z0-9_-]+", selector)))
            path = f"/accounts/{self.account}/{suffix}/{selector}"
            resource = self.get(path)["result"]
            require(isinstance(resource, dict) and resource.get(name_field) == name and resource.get(id_field) == identifier)
            require(resource.get("account_id", self.account) == self.account)
            if kind == "cloudflare_worker":
                subdomain = resource.get("subdomain")
                require(isinstance(subdomain, dict) and all(key in subdomain for key in ("enabled", "previews_enabled")))
                inactive(subdomain["enabled"] is False and subdomain["previews_enabled"] is False and resource.get("deployed_on") is None)
                require(isinstance(resource.get("tail_consumers"), list))
                references = resource.get("references")
                require(isinstance(references, dict) and set(references) == {"workers", "domains", "dispatch_namespace_outbounds", "durable_objects", "queues"})
                require(all(isinstance(value, list) for value in references.values()))
                inactive(resource["tail_consumers"] == [] and all(value == [] for value in references.values()))
                inactive(self.pages(path + "/versions") == [])
            elif kind == "cloudflare_pages_project":
                inactive(all(resource.get(field) is None for field in ("source", "canonical_deployment", "latest_deployment")))
                subdomain, domains = resource.get("subdomain"), resource.get("domains")
                require(isinstance(subdomain, str) and bool(re.fullmatch(r"[a-z0-9-]+\.pages\.dev", subdomain)))
                require(isinstance(domains, list))
                inactive(domains in ([], [subdomain]))
                inactive(self.pages(path + "/deployments") == [])
            elif kind == "cloudflare_queue":
                settings = resource.get("settings")
                require(isinstance(settings, dict) and "delivery_paused" in settings)
                inactive(settings["delivery_paused"] is True)
                for field in ("consumers", "producers"):
                    require(isinstance(resource.get(field), list) and type(resource.get(field + "_total_count")) is int)
                    inactive(resource[field] == [] and resource[field + "_total_count"] == 0)
        return True

"""One reviewed apex cutover. Credentials stay in process memory; receipts omit bodies."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import sys
import time
import urllib.error
import urllib.request

ACCOUNT = "5cc3bc33ca089258d20b6e80e67e5333"
ZONE = "84e6285e3d2a72d9fd9b4676346b96ed"
HOST = "leoinvesting.com"
PREVIOUS_WORKER = "ritual-investing-member"
WORKER = "leo-domain-proxy"
UPSTREAM = "https://leo.axio7.workers.dev"
EXPECTED_REF = "refs/heads/codex/leo-models-publication-20260910"
API = "https://api.cloudflare.com/client/v4"
MAX_RESPONSE = 4 * 1024 * 1024
HERE = Path(__file__).resolve().parent


class Failure(Exception):
    """Stable operator-facing error; never include remote bodies or credentials."""


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def require(condition, reason):
    if not condition:
        raise Failure(reason)


def digest(value):
    return hashlib.sha256(value).hexdigest()


def request_bytes(url, *, method="GET", headers=None, data=None):
    opener = urllib.request.build_opener(NoRedirect())
    request = urllib.request.Request(url, headers={"User-Agent": "LeoDomainPublication/1.0", **(headers or {})},
                                     data=data, method=method)
    try:
        response = opener.open(request, timeout=30)
    except urllib.error.HTTPError as error:
        response = error
    except Exception:
        raise Failure("network_request_failed") from None
    with response:
        body = response.read(MAX_RESPONSE + 1)
        require(len(body) <= MAX_RESPONSE, "response_size_limit")
        return response.status, response.headers, body


class Cloudflare:
    def __init__(self, token):
        self.token = token

    def call(self, method, path, payload=None, content_type="application/json", allow_missing=False):
        # There are exactly three permitted write endpoints and two attachment targets.
        writes = {
            ("PUT", f"/accounts/{ACCOUNT}/workers/scripts/{WORKER}"),
            ("POST", f"/accounts/{ACCOUNT}/workers/scripts/{WORKER}/subdomain"),
            ("PUT", f"/accounts/{ACCOUNT}/workers/domains"),
        }
        require(path.startswith("/") and not path.startswith("//") and ".." not in path,
                "invalid_api_path")
        require(method == "GET" or (method, path) in writes, "write_endpoint_not_allowed")
        if method == "PUT" and path.endswith("/workers/domains"):
            require(isinstance(payload, dict) and set(payload) == {"hostname", "service", "zone_id", "zone_name"}
                    and payload["hostname"] == HOST and payload["zone_id"] == ZONE
                    and payload["zone_name"] == HOST
                    and payload["service"] in {WORKER, PREVIOUS_WORKER}, "domain_write_not_allowed")
        if method == "POST":
            require(payload == {"enabled": False, "previews_enabled": False}, "subdomain_write_not_allowed")
        data = payload if isinstance(payload, bytes) else (json.dumps(payload).encode() if payload is not None else None)
        headers = {"Authorization": "Bearer " + self.token, "Accept": "application/json"}
        if data is not None:
            headers["Content-Type"] = content_type
        status, _, raw = request_bytes(API + path, method=method, headers=headers, data=data)
        if status == 404 and allow_missing:
            return None
        try:
            body = json.loads(raw)
        except (ValueError, UnicodeError):
            raise Failure(f"cloudflare_http_{status}_invalid_json") from None
        codes = [str(entry.get("code")) for entry in body.get("errors", []) or []
                 if isinstance(entry, dict) and isinstance(entry.get("code"), int)]
        if status not in range(200, 300) or body.get("success") is not True:
            suffix = "_permission_or_token_access" if status in (401, 403) else ""
            raise Failure(f"cloudflare_http_{status}{suffix}_codes_{'-'.join(codes) or 'none'}")
        return body


def domain_inventory(cloud):
    body = cloud.call("GET", f"/accounts/{ACCOUNT}/workers/domains")
    entries = body.get("result")
    require(isinstance(entries, list), "invalid_domain_inventory")
    total = (body.get("result_info") or {}).get("total_count", len(entries))
    require(total == len(entries), "incomplete_domain_inventory")
    keys = ("id", "hostname", "service", "environment", "zone_id", "zone_name")
    return sorted([{key: entry.get(key) for key in keys} for entry in entries], key=lambda x: x["hostname"])


def apex(entries):
    matches = [item for item in entries if item["hostname"] == HOST]
    require(len(matches) == 1, "expected_one_existing_apex_attachment")
    item = matches[0]
    require(item["zone_id"] == ZONE and item["zone_name"] == HOST, "unexpected_domain_zone")
    return item


def others(entries):
    return [entry for entry in entries if entry["hostname"] != HOST]


def deployment(cloud, worker):
    body = cloud.call("GET", f"/accounts/{ACCOUNT}/workers/scripts/{worker}/deployments")
    entries = (body.get("result") or {}).get("deployments")
    require(isinstance(entries, list) and len(entries) > 0, "missing_worker_deployment")
    current = entries[0]
    require(current.get("versions"), "missing_worker_versions")
    return {key: current.get(key) for key in ("id", "created_on", "versions")}


def dns_records():
    result = {}
    for kind in ("NS", "MX"):
        status, _, raw = request_bytes(
            f"https://cloudflare-dns.com/dns-query?name={HOST}&type={kind}",
            headers={"Accept": "application/dns-json"})
        require(status == 200, "dns_read_failed")
        body = json.loads(raw)
        require(body.get("Status") == 0 and body.get("Answer"), "dns_answers_unavailable")
        result[kind] = sorted(str(entry["data"]) for entry in body["Answer"])
    return result


def verify_site(origin, release, proxy=False):
    checks = []
    for path, expected in release["assets"].items():
        status, headers, raw = request_bytes(origin + path)
        require(status == 200 and expected["content_type"] in headers.get("content-type", "")
                and digest(raw) == expected["sha256"], "asset_identity_mismatch")
        if proxy:
            require(headers.get("x-leo-domain-proxy") == "v1", "proxy_header_missing")
        checks.append({"path": path, "status": status, "sha256": digest(raw)})
    for path in ("/", "/original/", "/app/", "/pricing", "/strategy-auth/callback"):
        status, headers, raw = request_bytes(origin + path)
        require(status == 200 and "text/html" in headers.get("content-type", ""), "page_verification_failed")
        if path == "/":
            require(b"Astra's Pick" in raw and b"research-desk/desk.js" in raw, "homepage_identity_mismatch")
        checks.append({"path": path, "status": status})
    for path, expected_schema in (
        ("/app/research-desk/data/event-radar.json", "astra-event-radar.v1"),
        ("/app/research-desk/data/shortlist-feed/current.json", "astra-shortlist-publication.v1"),
    ):
        status, headers, raw = request_bytes(origin + path)
        require(status == 200 and "application/json" in headers.get("content-type", ""), "feed_verification_failed")
        body = json.loads(raw)
        require(body.get("schemaVersion") == expected_schema, "feed_schema_mismatch")
        checks.append({"path": path, "status": status, "schemaVersion": expected_schema})
    return checks


def www_redirect():
    status, headers, _ = request_bytes("https://www.leoinvesting.com/domain-publication-check?source=www")
    require(status in (301, 308) and headers.get("location") ==
            "https://leoinvesting.com/domain-publication-check?source=www", "www_redirect_changed")
    return {"status": status, "location": headers.get("location")}


def multipart(script, config, sha):
    require(len(script) <= 64 * 1024, "proxy_source_too_large")
    metadata = {"main_module": "index.mjs", "compatibility_date": config["compatibility_date"],
                "bindings": [], "observability": config["observability"],
                "annotations": {"workers/tag": digest(script), "workers/message": "Leo domain publication " + sha}}
    boundary = "leo-" + secrets.token_hex(24)
    parts = []
    for name, content_type, content in (
        ("metadata", "application/json", json.dumps(metadata).encode()),
        ("index.mjs", "application/javascript+module", script),
    ):
        parts.append((f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\""
                      + (f"; filename=\"{name}\"" if name != "metadata" else "")
                      + f"\r\nContent-Type: {content_type}\r\n\r\n").encode() + content + b"\r\n")
    return b"".join(parts) + f"--{boundary}--\r\n".encode(), "multipart/form-data; boundary=" + boundary


def attachment(worker):
    return {"hostname": HOST, "service": worker, "zone_id": ZONE, "zone_name": HOST}


def run(cloud, receipt, save, sleep=time.sleep):
    release = json.loads((HERE / "release.json").read_text())
    config = json.loads((HERE / "wrangler.jsonc").read_text())
    require(release["upstream_origin"] == UPSTREAM and config["account_id"] == ACCOUNT
            and config["name"] == WORKER and config["workers_dev"] is False
            and config["preview_urls"] is False
            and config["routes"] == [{"pattern": HOST, "custom_domain": True}], "unexpected_release_configuration")
    receipt["phase"] = "verify_token_and_ownership"
    save()
    token_result = cloud.call("GET", "/user/tokens/verify").get("result") or {}
    require(token_result.get("status") == "active", "cloudflare_token_not_active")
    zones = cloud.call("GET", "/zones?name=" + HOST).get("result")
    require(isinstance(zones, list) and len(zones) == 1 and zones[0].get("id") == ZONE
            and (zones[0].get("account") or {}).get("id") == ACCOUNT and zones[0].get("status") == "active",
            "owning_zone_not_accessible_or_active")
    before = domain_inventory(cloud)
    require(apex(before)["service"] == PREVIOUS_WORKER, "existing_apex_target_changed")
    receipt["before"] = {"domains": before, "legacyDeployment": deployment(cloud, PREVIOUS_WORKER),
                         "dns": dns_records(), "www": www_redirect()}
    receipt["upstreamChecks"] = verify_site(UPSTREAM, release)
    existing = cloud.call("GET", f"/accounts/{ACCOUNT}/workers/scripts/{WORKER}/settings", allow_missing=True)
    require(existing is None, "proxy_worker_already_exists_review_before_replacement")
    receipt["state"] = "preflight_passed"
    receipt["phase"] = "create_fixed_origin_proxy"
    save()
    source = (HERE / "index.mjs").read_bytes()
    body, content_type = multipart(source, config, receipt["sourceSha"])
    cloud.call("PUT", f"/accounts/{ACCOUNT}/workers/scripts/{WORKER}", body, content_type)
    receipt["proxySourceSha256"] = digest(source)
    receipt["proxyDeployment"] = deployment(cloud, WORKER)
    cloud.call("POST", f"/accounts/{ACCOUNT}/workers/scripts/{WORKER}/subdomain",
               {"enabled": False, "previews_enabled": False})
    receipt["state"] = "proxy_uploaded_domain_unchanged"
    save()
    require(domain_inventory(cloud) == before, "domain_inventory_changed_during_preflight")
    # A timeout can mean the write succeeded. Record intent first; reconcile in finally.
    receipt["attachmentAttempted"] = True
    receipt["phase"] = "attach_apex_and_verify"
    save()
    try:
        cloud.call("PUT", f"/accounts/{ACCOUNT}/workers/domains", attachment(WORKER))
        after = domain_inventory(cloud)
        require(apex(after)["service"] == WORKER and others(after) == others(before), "attachment_verification_failed")
        checks = None
        for attempt in range(8):
            try:
                checks = verify_site("https://" + HOST, release, proxy=True)
                break
            except Failure:
                if attempt == 7:
                    raise
                sleep(10)
        require(dns_records() == receipt["before"]["dns"], "dns_or_mail_changed")
        require(www_redirect() == receipt["before"]["www"], "www_changed")
        require(deployment(cloud, PREVIOUS_WORKER) == receipt["before"]["legacyDeployment"], "legacy_worker_changed")
        receipt.update({"state": "published", "phase": "verified", "afterDomains": after,
                        "publicChecks": checks, "rollback": "not_needed"})
        save()
    except Exception:
        # Restore only our own attachment; never overwrite a concurrent operator change.
        receipt["phase"] = "reconcile_and_restore_apex"
        receipt["rollback"] = "checking_current_mapping"
        save()
        observed = apex(domain_inventory(cloud))["service"]
        if observed == WORKER:
            cloud.call("PUT", f"/accounts/{ACCOUNT}/workers/domains", attachment(PREVIOUS_WORKER))
            require(apex(domain_inventory(cloud))["service"] == PREVIOUS_WORKER, "rollback_verification_failed")
            receipt["rollback"] = "previous_apex_restored"
        elif observed == PREVIOUS_WORKER:
            receipt["rollback"] = "already_on_previous_apex"
        else:
            receipt["rollback"] = "operator_changed_target_manual_review_required"
        receipt["state"] = "publication_failed"
        save()
        raise


def main():
    require(os.environ.get("GITHUB_REPOSITORY") == "ErwinHe7/Argus"
            and os.environ.get("GITHUB_REF") == EXPECTED_REF
            and os.environ.get("CLOUDFLARE_ACCOUNT_ID") == ACCOUNT, "unexpected_execution_target")
    sha = os.environ.get("GITHUB_SHA", "")
    require(re.fullmatch(r"[a-f0-9]{40}", sha), "invalid_source_revision")
    token = os.environ.get("CLOUDFLARE_API_TOKEN", "")
    require(bool(token), "cloudflare_secret_missing")
    receipt_path = Path(os.environ["RUNNER_TEMP"]) / "leo-domain-receipt.json"
    receipt = {"schemaVersion": "leo-domain-publication.v1", "sourceSha": sha, "account": ACCOUNT,
               "domain": HOST, "upstream": UPSTREAM, "state": "starting", "attachmentAttempted": False}

    def save():
        receipt_path.write_text(json.dumps(receipt, sort_keys=True, indent=2) + "\n")

    save()
    try:
        run(Cloudflare(token), receipt, save)
    except Exception as error:
        code = str(error) if isinstance(error, Failure) else "unexpected_publication_error"
        receipt["failure"] = code
        if receipt["state"] != "publication_failed":
            receipt["state"] = "blocked_or_failed"
        save()
        print("LEO_DOMAIN_PUBLICATION " + json.dumps({"state": receipt["state"], "phase": receipt.get("phase"), "reason": code,
                                                    "rollback": receipt.get("rollback", "not_attempted")}))
        return 1
    print("LEO_DOMAIN_PUBLICATION " + json.dumps({"state": receipt["state"], "domain": HOST}))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Failure as error:
        print("LEO_DOMAIN_PUBLICATION " + json.dumps({"state": "blocked", "reason": str(error)}))
        raise SystemExit(1)

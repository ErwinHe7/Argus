"""Bounded, GET-only inspection; output contains only whitelisted resource metadata."""
import json
import os
from pathlib import Path
import re
import urllib.error
import urllib.request

ACCOUNT = "5cc3bc33ca089258d20b6e80e67e5333"
ZONE = "84e6285e3d2a72d9fd9b4676346b96ed"
HOST = "leoinvesting.com"
API = "https://api.cloudflare.com/client/v4"
PROBES = {
    "account_token": f"/accounts/{ACCOUNT}/tokens/verify",
    "account_identity": f"/accounts/{ACCOUNT}",
    "zones_name": f"/zones?name={HOST}",
    "zones_name_account": f"/zones?name={HOST}&account.id={ACCOUNT}",
    "known_zone": f"/zones/{ZONE}",
    "custom_domains": f"/accounts/{ACCOUNT}/workers/domains",
}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def safe_id(value):
    return value if isinstance(value, str) and re.fullmatch(r"[a-f0-9]{32}", value) else None


def safe_name(value):
    return value if isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9_.-]{1,253}", value) else None


def enum(value, allowed):
    return value if isinstance(value, str) and value in allowed else None


def read(token, path, opener=None):
    if path not in PROBES.values():
        raise ValueError("unapproved_read_endpoint")
    request = urllib.request.Request(API + path, method="GET", headers={
        "Authorization": "Bearer " + token, "Accept": "application/json",
        "User-Agent": "LeoDomainDiagnostic/1.0"})
    try:
        response = (opener or urllib.request.build_opener(NoRedirect())).open(request, timeout=30)
    except urllib.error.HTTPError as error:
        response = error
    except Exception:
        return 0, {}, "network_request_failed"
    with response:
        raw = response.read(4 * 1024 * 1024 + 1)
        if len(raw) > 4 * 1024 * 1024:
            return response.status, {}, "response_size_limit"
        try:
            body = json.loads(raw)
        except (ValueError, UnicodeError):
            return response.status, {}, "invalid_json"
        return response.status, body if isinstance(body, dict) else {}, None


def zone_metadata(value):
    account = value.get("account")
    return {"id": safe_id(value.get("id")), "name": safe_name(value.get("name")),
            "status": enum(value.get("status"), {"active", "pending", "initializing", "moved", "deleted", "deactivated"}),
            "account_id": safe_id(account.get("id")) if isinstance(account, dict) else None,
            "account_shape": "object" if isinstance(account, dict) else "missing_or_other"}


def sanitize(kind, status, body, error=None):
    result = body.get("result")
    output = {"probe": kind, "http_status": status, "success": body.get("success") is True,
              "error_codes": [item["code"] for item in (body.get("errors") or [])
                              if isinstance(item, dict) and type(item.get("code")) is int]}
    if error:
        output["read_error"] = error
    if kind == "account_token":
        output["token_status"] = enum(result.get("status"), {"active", "disabled", "expired"}) if isinstance(result, dict) else None
    elif kind == "account_identity":
        output["account_id"] = safe_id(result.get("id")) if isinstance(result, dict) else None
    elif kind == "known_zone":
        output["zone"] = zone_metadata(result) if isinstance(result, dict) else None
    else:
        output["result_shape"] = "array" if isinstance(result, list) else "missing_or_other"
        rows = result if isinstance(result, list) else []
        output["count"] = len(rows)
        info = body.get("result_info") or {}
        output["total_count"] = info.get("total_count") if isinstance(info, dict) and type(info.get("total_count")) is int else None
        if kind == "custom_domains":
            output["records"] = [{"hostname": safe_name(row.get("hostname")),
                                   "service": safe_name(row.get("service")),
                                   "zone_id": safe_id(row.get("zone_id")),
                                   "zone_name": safe_name(row.get("zone_name"))}
                                  for row in rows if isinstance(row, dict)]
        else:
            output["records"] = [zone_metadata(row) for row in rows if isinstance(row, dict)]
    return output


def main():
    sha = os.environ.get("GITHUB_SHA", "")
    if not (os.environ.get("GITHUB_REPOSITORY") == "ErwinHe7/Argus"
            and os.environ.get("GITHUB_REF") == "refs/heads/main"
            and os.environ.get("CLOUDFLARE_ACCOUNT_ID") == ACCOUNT
            and re.fullmatch(r"[a-f0-9]{40}", sha)
            and os.environ.get("REVIEWED_SHA") == sha):
        raise ValueError("unexpected_diagnostic_target")
    token = os.environ.get("CLOUDFLARE_API_TOKEN", "")
    if not token:
        raise ValueError("cloudflare_secret_missing")
    results = []
    for kind, path in PROBES.items():
        status, body, error = read(token, path)
        result = sanitize(kind, status, body, error)
        results.append(result)
        print("LEO_DOMAIN_DIAGNOSTIC " + json.dumps(result, sort_keys=True))
    receipt = {"schemaVersion": "leo-domain-diagnostic.v1", "sourceSha": sha,
               "account": ACCOUNT, "zone": ZONE, "readOnly": True, "probes": results}
    (Path(os.environ["RUNNER_TEMP"]) / "leo-domain-diagnostic.json").write_text(json.dumps(receipt, indent=2) + "\n")


if __name__ == "__main__":
    main()

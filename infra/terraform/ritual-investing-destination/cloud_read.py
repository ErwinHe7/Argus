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


class CloudRead:
    ORIGIN = "https://api.cloudflare.com/client/v4"

    def __init__(self, account, directory):
        BackendSpec(account, "bootstrap")
        self.account = account
        self.directory = Path(directory) / "api"
        self.token = os.environ.get("CLOUDFLARE_API_TOKEN", "")
        if not re.fullmatch(r"[A-Za-z0-9_-]+", self.token):
            raise CloudError("A destination API token is required.")

    def get(self, path, *, headers=None):
        # The caller may select only account-scoped read paths. No redirects,
        # environment proxies, credentials in URLs, or configurable API origin.
        if (not path.startswith(f"/accounts/{self.account}") or
                not re.fullmatch(r"/accounts/[0-9a-f]{32}(?:/[A-Za-z0-9_./%-]+)?(?:\?[A-Za-z0-9_=&%.-]+)?", path)
                or ".." in path):
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

    def verify_buckets(self, spec):
        return {f"ritual-investing-terraform-state-{target}" for target in ("prod", "staging")} <= self.buckets()

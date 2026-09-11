import importlib.util
import io
import json
from pathlib import Path
import unittest
from unittest.mock import Mock

spec = importlib.util.spec_from_file_location("domain_diagnose", Path(__file__).with_name("diagnose.py"))
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)


class DiagnosticTests(unittest.TestCase):
    def test_only_six_exact_get_endpoints_are_allowed(self):
        opener = Mock()
        for path in ("/user", "/accounts/other/workers/domains", "/zones", "//example.test"):
            with self.assertRaisesRegex(ValueError, "unapproved_read_endpoint"):
                d.read("test-only", path, opener)
        opener.open.assert_not_called()
        for path in d.PROBES.values():
            response = io.BytesIO(b'{"success":true,"result":[]}')
            response.status = 200
            opener.open.return_value = response
            d.read("test-only", path, opener)
            request = opener.open.call_args.args[0]
            self.assertEqual(request.method, "GET")
            self.assertIsNone(request.data)
            self.assertEqual(request.full_url, d.API + path)

    def test_authentication_errors_do_not_print_messages_or_headers(self):
        result = d.sanitize("known_zone", 403, {"success": False,
            "errors": [{"code": 10000, "message": "private-secret"}], "Authorization": "private-secret"})
        self.assertEqual(result["error_codes"], [10000])
        self.assertNotIn("private-secret", json.dumps(result))

    def test_account_name_credentials_and_arbitrary_fields_are_omitted(self):
        result = d.sanitize("zones_name", 200, {"success": True, "result": [{"id": d.ZONE,
            "name": d.HOST, "status": "active", "account": {"id": d.ACCOUNT, "name": "private-secret"},
            "token": "private-secret"}]})
        self.assertEqual(result["records"][0]["account_id"], d.ACCOUNT)
        self.assertNotIn("private-secret", json.dumps(result))

    def test_missing_account_and_moved_zone_are_visible(self):
        result = d.zone_metadata({"id": d.ZONE, "name": d.HOST, "status": "moved"})
        self.assertEqual(result["status"], "moved")
        self.assertEqual(result["account_shape"], "missing_or_other")
        self.assertIsNone(result["account_id"])

    def test_domain_inventory_retains_only_mapping_metadata(self):
        result = d.sanitize("custom_domains", 200, {"result": [{"hostname": d.HOST,
            "service": "ritual-investing-member", "zone_id": d.ZONE, "zone_name": d.HOST,
            "secret": "private-secret"}], "result_info": {"total_count": 1}})
        self.assertEqual(result["count"], result["total_count"])
        self.assertEqual(set(result["records"][0]), {"hostname", "service", "zone_id", "zone_name"})
        self.assertNotIn("private-secret", json.dumps(result))

    def test_redirects_cannot_forward_authorization(self):
        self.assertIsNone(d.NoRedirect().redirect_request(None, None, 302, None, None, "https://example.test"))


if __name__ == "__main__":
    unittest.main()

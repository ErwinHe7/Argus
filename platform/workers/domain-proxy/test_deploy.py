import copy
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location("domain_deploy", Path(__file__).with_name("deploy.py"))
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)


class FakeCloud:
    def __init__(self):
        self.domains = [
            {"id": "apex", "hostname": d.HOST, "service": d.PREVIOUS_WORKER,
             "zone_id": d.ZONE, "zone_name": d.HOST, "environment": "production"},
            {"id": "www", "hostname": "www.leoinvesting.com", "service": d.PREVIOUS_WORKER,
             "zone_id": d.ZONE, "zone_name": d.HOST, "environment": "production"},
        ]
        self.writes = []
        self.settings = None
        self.zone = d.ZONE
        self.attach_timeout = False
        self.concurrent_on_attach = False
        self.inventory_count = 0
        self.change_before_attach = False

    def call(self, method, path, payload=None, content_type=None, allow_missing=False):
        if method != "GET":
            self.writes.append((method, path, copy.deepcopy(payload)))
            if path.endswith("/workers/domains"):
                self.domains[0]["service"] = payload["service"]
                if payload["service"] == d.WORKER:
                    if self.concurrent_on_attach:
                        self.domains[0]["service"] = "operator-new-target"
                    if self.attach_timeout:
                        raise d.Failure("network_request_failed")
            return {"success": True, "result": {}}
        if path == "/user/tokens/verify":
            return {"result": {"status": "active"}}
        if path.startswith("/zones?"):
            return {"result": [{"id": self.zone, "account": {"id": d.ACCOUNT}, "status": "active"}]}
        if path.endswith("/workers/domains"):
            self.inventory_count += 1
            if self.change_before_attach and self.inventory_count == 2:
                self.domains[1]["service"] = "new-www-target"
            return {"result": copy.deepcopy(self.domains)}
        if path.endswith("/deployments"):
            return {"result": {"deployments": [{"id": "deployment", "created_on": "2026-09-10T00:00:00Z",
                                                "versions": [{"version_id": "retained-version", "percentage": 100}]}]}}
        if path.endswith("/settings"):
            return self.settings
        raise AssertionError(path)


class DeploymentTests(unittest.TestCase):
    def test_active_user_token_does_not_use_account_endpoint(self):
        cloud = Mock()
        cloud.call.return_value = {"result": {"status": "active"}}
        self.assertEqual(d.verify_token(cloud), "user")
        cloud.call.assert_called_once_with("GET", "/user/tokens/verify")

    def test_account_token_fallback_only_on_auth_rejection(self):
        for status in (401, 403):
            with self.subTest(status=status):
                cloud = Mock()
                cloud.call.side_effect = [d.CloudflareFailure(status, "user_endpoint_rejected"),
                                          {"result": {"status": "active"}}]
                self.assertEqual(d.verify_token(cloud), "account")
                self.assertEqual(cloud.call.call_count, 2)
                cloud.call.assert_called_with("GET", f"/accounts/{d.ACCOUNT}/tokens/verify")

    def test_token_fallback_cannot_override_inactive_or_missing_status(self):
        for body in ({"result": {"status": "disabled"}}, {"result": {}}):
            cloud = Mock()
            cloud.call.return_value = body
            with self.assertRaisesRegex(d.Failure, "cloudflare_token_not_active"):
                d.verify_token(cloud)
            self.assertEqual(cloud.call.call_count, 1)

    def test_network_service_and_rate_limit_failures_do_not_try_other_endpoint(self):
        for error in (d.Failure("network_request_failed"), d.CloudflareFailure(429, "rate_limit"),
                      d.CloudflareFailure(500, "service_unavailable")):
            cloud = Mock()
            cloud.call.side_effect = error
            with self.assertRaises(d.Failure):
                d.verify_token(cloud)
            self.assertEqual(cloud.call.call_count, 1)

    def test_account_token_rejection_stops_before_ownership_or_writes(self):
        for response in (d.CloudflareFailure(401, "account_endpoint_rejected"),
                         {"result": {"status": "expired"}}):
            cloud = Mock()
            cloud.call.side_effect = [d.CloudflareFailure(401, "user_endpoint_rejected"), response]
            _, _, error = self.execute(cloud)
            self.assertIn(error, {"account_endpoint_rejected", "cloudflare_token_not_active"})
            self.assertEqual(cloud.call.call_count, 2)
            self.assertTrue(all(args.args[0] == "GET" for args in cloud.call.call_args_list))

    def test_verified_account_token_still_requires_exact_owned_zone(self):
        cloud = FakeCloud()
        original_call = cloud.call
        def account_token(method, path, *args, **kwargs):
            if path == "/user/tokens/verify":
                raise d.CloudflareFailure(401, "user_endpoint_rejected")
            if path == f"/accounts/{d.ACCOUNT}/tokens/verify":
                return {"result": {"status": "active"}}
            return original_call(method, path, *args, **kwargs)
        cloud.call = account_token
        cloud.zone = "another-zone"
        receipt, _, error = self.execute(cloud)
        self.assertEqual(receipt["tokenVerificationScope"], "account")
        self.assertEqual(error, "owning_zone_not_accessible_or_active")
        self.assertEqual(cloud.writes, [])

    def execute(self, cloud, site_error=False):
        receipt = {"sourceSha": "a" * 40, "attachmentAttempted": False}
        saved = []

        def site(origin, release, proxy=False):
            if site_error and proxy:
                raise d.Failure("asset_identity_mismatch")
            return [{"origin": origin, "checked": True}]

        with patch.object(d, "dns_records", return_value={"NS": ["retained"], "MX": ["retained"]}), \
             patch.object(d, "www_redirect", return_value={"status": 301}), \
             patch.object(d, "verify_site", side_effect=site):
            try:
                d.run(cloud, receipt, lambda: saved.append(copy.deepcopy(receipt)), sleep=lambda _: None)
                error = None
            except d.Failure as caught:
                error = str(caught)
        return receipt, saved, error

    def test_success_changes_only_new_worker_and_apex(self):
        cloud = FakeCloud()
        receipt, saved, error = self.execute(cloud)
        self.assertIsNone(error)
        self.assertEqual(receipt["state"], "published")
        self.assertEqual(cloud.domains[0]["service"], d.WORKER)
        self.assertEqual(cloud.domains[1]["service"], d.PREVIOUS_WORKER)
        self.assertEqual(len(cloud.writes), 3)
        self.assertTrue(any(item.get("state") == "preflight_passed" and "before" in item for item in saved))
        self.assertTrue(any(item.get("attachmentAttempted") is True and item.get("phase") == "attach_apex_and_verify" for item in saved))

    def test_changed_apex_fails_before_any_write(self):
        cloud = FakeCloud()
        cloud.domains[0]["service"] = "another-worker"
        _, _, error = self.execute(cloud)
        self.assertEqual(error, "existing_apex_target_changed")
        self.assertEqual(cloud.writes, [])

    def test_wrong_zone_fails_before_any_write(self):
        cloud = FakeCloud()
        cloud.zone = "wrong-zone"
        _, _, error = self.execute(cloud)
        self.assertEqual(error, "owning_zone_not_accessible_or_active")
        self.assertEqual(cloud.writes, [])

    def test_preexisting_proxy_is_never_overwritten(self):
        cloud = FakeCloud()
        cloud.settings = {"result": {"name": "existing"}}
        _, _, error = self.execute(cloud)
        self.assertEqual(error, "proxy_worker_already_exists_review_before_replacement")
        self.assertEqual(cloud.writes, [])

    def test_inventory_race_stops_before_attachment(self):
        cloud = FakeCloud()
        cloud.change_before_attach = True
        receipt, _, error = self.execute(cloud)
        self.assertEqual(error, "domain_inventory_changed_during_preflight")
        self.assertFalse(receipt["attachmentAttempted"])
        self.assertEqual(len(cloud.writes), 2)

    def test_timeout_reconciles_and_restores_possible_success(self):
        cloud = FakeCloud()
        cloud.attach_timeout = True
        receipt, _, error = self.execute(cloud)
        self.assertEqual(error, "network_request_failed")
        self.assertEqual(receipt["rollback"], "previous_apex_restored")
        self.assertEqual(cloud.domains[0]["service"], d.PREVIOUS_WORKER)

    def test_failed_public_checks_restore_previous_mapping(self):
        cloud = FakeCloud()
        receipt, _, error = self.execute(cloud, site_error=True)
        self.assertEqual(error, "asset_identity_mismatch")
        self.assertEqual(receipt["rollback"], "previous_apex_restored")
        self.assertEqual(cloud.domains[0]["service"], d.PREVIOUS_WORKER)

    def test_rollback_never_overwrites_other_operator_target(self):
        cloud = FakeCloud()
        cloud.concurrent_on_attach = True
        receipt, _, error = self.execute(cloud)
        self.assertEqual(error, "attachment_verification_failed")
        self.assertEqual(receipt["rollback"], "operator_changed_target_manual_review_required")
        self.assertEqual(cloud.domains[0]["service"], "operator-new-target")
        self.assertEqual(len(cloud.writes), 3)

    def test_controller_rejects_unrelated_write_endpoints(self):
        client = d.Cloudflare("test-only")
        for method, path, payload in [
            ("DELETE", f"/accounts/{d.ACCOUNT}/workers/scripts/{d.PREVIOUS_WORKER}", None),
            ("PUT", f"/accounts/{d.ACCOUNT}/workers/domains", {**d.attachment(d.WORKER), "hostname": "www.leoinvesting.com"}),
            ("POST", f"/accounts/{d.ACCOUNT}/workers/scripts/{d.WORKER}/subdomain", {"enabled": True}),
        ]:
            with self.assertRaises(d.Failure):
                client.call(method, path, payload)

    def test_http_auth_failure_does_not_echo_provider_body(self):
        client = d.Cloudflare("test-only")
        body = b'{"success":false,"errors":[{"code":10000,"message":"test-secret-value"}]}'
        with patch.object(d, "request_bytes", return_value=(403, {}, body)):
            with self.assertRaisesRegex(d.Failure, "cloudflare_http_403_permission_or_token_access_codes_10000") as result:
                client.call("GET", "/user/tokens/verify")
            self.assertNotIn("test-secret-value", str(result.exception))


if __name__ == "__main__":
    unittest.main()

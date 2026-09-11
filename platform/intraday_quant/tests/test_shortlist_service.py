"""Local injected tests; these are not broker or performance evidence."""
from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
import urllib.error

from intraday_quant import shortlist
from intraday_quant import shortlist_service as service
from test_shortlist import asset, source

NOW = datetime(2026, 9, 8, 4, 30, tzinfo=timezone.utc)
PLATFORM = Path(__file__).resolve().parents[2]


class ShortlistServiceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="leo-shortlist-tests-")
        self.root = Path(self.temporary.name)
        self.config = service.Config(self.root / "source.json", None, self.root / "private", self.root / "public", 5)
        self.data = source(asset("AAA"), asset("BBB", close=99))
        for row in self.data["symbols"]:
            row["coverage"].update(sourceSessions=60, validationExcludedPrefixSessions=0,
                                   expectedSessions=None, invalidDates=[], validationNote="Injected unit-test coverage.")
        self.put(self.data)

    def tearDown(self):
        self.temporary.cleanup()

    def put(self, data):
        self.config.input.write_bytes(service.json_bytes(data))

    def current(self):
        return service.parse_json((self.config.public_dir / "current.json").read_bytes())

    def test_canonical_result_hash_and_dates_preserved_across_ticks_and_restart(self):
        worker = service.Publisher(self.config)
        first = worker.tick(NOW)
        expected = shortlist.build_shortlist(self.data, None, self.config.input.read_bytes())
        self.assertEqual(first["shortlist"], expected)
        self.assertEqual(first["publisher"]["artifactSha256"], service.digest((self.config.public_dir / "shortlist.json").read_bytes()))
        self.assertEqual(first["publisher"]["state"], "waiting")
        with patch.object(shortlist, "build_shortlist", side_effect=AssertionError("unchanged source recomputed")):
            later = worker.tick(NOW + timedelta(hours=1))
            restarted = service.Publisher(self.config).tick(NOW + timedelta(hours=2))
        for result in (later, restarted):
            self.assertEqual(result["shortlist"], first["shortlist"])
            self.assertEqual(result["publisher"]["publishedAt"], first["publisher"]["publishedAt"])
            self.assertEqual(result["publisher"]["revision"], first["publisher"]["revision"])
            self.assertEqual(result["publisher"]["llmCalls"], 0)
            self.assertFalse(result["publisher"]["executionEnabled"])
        self.assertEqual(len(list((self.config.state_dir / "receipts").glob("*.json"))), 1)

    def test_changed_valid_data_is_regenerated_and_prior_receipt_is_immutable(self):
        worker = service.Publisher(self.config)
        first = worker.tick(NOW)
        receipt_path = next((self.config.state_dir / "receipts").glob("*.json"))
        receipt = receipt_path.read_bytes()
        self.data["symbols"][0]["retrievedAt"] = "2026-09-08T03:00:00Z"
        self.data["symbols"][0]["latest"]["changePercent"] = 2.2
        self.put(self.data)
        second = worker.tick(NOW + timedelta(minutes=1))
        self.assertNotEqual(first["publisher"]["revision"], second["publisher"]["revision"])
        self.assertEqual(second["shortlist"]["stocks"][0]["changePercent"], 2.2)
        self.assertEqual(receipt_path.read_bytes(), receipt)
        self.assertEqual(len(list((self.config.state_dir / "receipts").glob("*.json"))), 2)

    def test_missing_invalid_future_and_regressed_sources_preserve_last_values(self):
        worker = service.Publisher(self.config)
        original = worker.tick(NOW)
        cases = []
        future = deepcopy(self.data)
        future["symbols"][0]["retrievedAt"] = "2027-01-01T00:00:00Z"
        cases.append((future, "source_future"))
        regressed = deepcopy(self.data)
        regressed["symbols"][0]["retrievedAt"] = "2026-09-05T00:00:00Z"
        cases.append((regressed, "source_regressed"))
        private = deepcopy(self.data)
        private["symbols"][0]["coverage"]["accountPassword"] = "DO-NOT-PUBLISH"
        cases.append((private, "source_invalid"))
        for data, expected_code in cases:
            self.put(data)
            result = worker.tick(NOW + timedelta(minutes=1))
            self.assertEqual(result["shortlist"], original["shortlist"])
            self.assertEqual(result["publisher"]["lastError"]["code"], expected_code)
            self.assertNotIn("DO-NOT-PUBLISH", (self.config.public_dir / "current.json").read_text(encoding="utf8"))
        self.config.input.unlink()
        missing = worker.tick(NOW + timedelta(minutes=2))
        self.assertEqual(missing["shortlist"], original["shortlist"])
        self.assertEqual(missing["publisher"]["lastError"]["code"], "source_unavailable")
        self.config.input.write_bytes(b'{"symbols":[],"symbols":[1]}')
        invalid = worker.tick(NOW + timedelta(minutes=3))
        self.assertEqual(invalid["publisher"]["lastError"]["code"], "source_invalid")
        self.assertEqual(invalid["shortlist"], original["shortlist"])
        self.put(self.data)
        self.assertIsNone(worker.tick(NOW + timedelta(minutes=4))["publisher"]["lastError"])

    def test_no_eligible_rows_does_not_zero_existing_shortlist(self):
        worker = service.Publisher(self.config)
        original = worker.tick(NOW)
        for row in self.data["symbols"]:
            row["latest"]["rsi14"] = None
        self.put(self.data)
        result = worker.tick(NOW)
        self.assertEqual(result["shortlist"], original["shortlist"])
        self.assertEqual(result["publisher"]["lastError"]["code"], "source_invalid")

    def test_private_input_objects_are_not_exported_or_retained_in_receipts(self):
        self.data["brokerAccount"] = {"token": "SECRET-SENTINEL"}
        self.data["symbols"][0]["account"] = {"balance": "PRIVATE-SENTINEL"}
        self.put(self.data)
        service.Publisher(self.config).tick(NOW)
        for directory in (self.config.public_dir, self.config.state_dir / "receipts"):
            for path in directory.glob("*.json"):
                payload = path.read_text(encoding="utf8")
                self.assertNotIn("SECRET-SENTINEL", payload)
                self.assertNotIn("PRIVATE-SENTINEL", payload)
                self.assertNotIn(str(self.config.input), payload)
                self.assertNotIn('"series":', payload)

    def test_atomic_publish_failure_retains_complete_envelope_and_recovers_from_receipt(self):
        worker = service.Publisher(self.config)
        worker.tick(NOW)
        old_bytes = (self.config.public_dir / "current.json").read_bytes()
        self.data["symbols"][0]["latest"]["changePercent"] = 3.3
        self.put(self.data)
        real_replace = os.replace
        def fail_current(source_path, target_path):
            if Path(target_path).name == "current.json":
                raise OSError("injected full-disk publication failure")
            return real_replace(source_path, target_path)
        with patch.object(service.os, "replace", side_effect=fail_current):
            with self.assertRaises(OSError):
                worker.tick(NOW + timedelta(minutes=1))
        self.assertEqual((self.config.public_dir / "current.json").read_bytes(), old_bytes)
        self.assertFalse(list(self.config.public_dir.glob(".pending-*")))
        with patch.object(shortlist, "build_shortlist", side_effect=AssertionError("committed receipt recomputed")):
            recovered = service.Publisher(self.config).tick(NOW + timedelta(minutes=2))
        self.assertEqual(recovered["shortlist"]["stocks"][0]["changePercent"], 3.3)

    def test_corrupt_private_receipt_does_not_replace_prior_publication_with_null(self):
        service.Publisher(self.config).tick(NOW)
        public = (self.config.public_dir / "current.json").read_bytes()
        receipt_path = next((self.config.state_dir / "receipts").glob("*.json"))
        receipt_path.write_bytes(b"{}")
        with self.assertRaisesRegex(service.ServiceError, "integrity"):
            service.Publisher(self.config).tick(NOW + timedelta(minutes=1))
        self.assertEqual((self.config.public_dir / "current.json").read_bytes(), public)

    def test_stop_pause_and_generator_change_fail_closed(self):
        worker = service.Publisher(self.config)
        first = worker.tick(NOW)
        (self.config.state_dir / "STOP").write_text("pause")
        paused = service.Publisher(self.config).tick(NOW)
        self.assertEqual(paused["publisher"]["state"], "paused")
        self.assertEqual(paused["shortlist"], first["shortlist"])
        (self.config.state_dir / "STOP").unlink()
        with patch.object(service, "code_identity", return_value={"changed": True}):
            result = worker.tick(NOW)
        self.assertEqual(result["publisher"]["lastError"]["code"], "generator_changed")
        (self.config.state_dir / "SHUTDOWN").write_text("stop")
        self.assertEqual(worker.tick(NOW)["publisher"]["state"], "stopped")

    def test_public_corruption_is_replaced_from_verified_private_receipt(self):
        worker = service.Publisher(self.config)
        first = worker.tick(NOW)
        (self.config.public_dir / "shortlist.json").write_text("bad")
        recovered = service.Publisher(self.config).tick(NOW)
        self.assertEqual(first["shortlist"], recovered["shortlist"])
        self.assertEqual(service.digest((self.config.public_dir / "shortlist.json").read_bytes()), recovered["publisher"]["artifactSha256"])

    def test_retained_real_artifact_exact_and_calendar_change_invalidates_cache(self):
        self.config.input.write_bytes((PLATFORM / "features/research-desk/data/desk-data.json").read_bytes())
        calendar = self.root / "calendar.ts"
        calendar.write_bytes((PLATFORM / "workers/public-market-map/us-calendar.ts").read_bytes())
        config = service.Config(self.config.input, calendar, self.config.state_dir, self.config.public_dir, 5)
        worker = service.Publisher(config)
        first = worker.tick(NOW)
        canonical = shortlist.build_shortlist(service.parse_json(config.input.read_bytes()), calendar, config.input.read_bytes())
        self.assertEqual(first["shortlist"], canonical)
        self.assertEqual([row["symbol"] for row in canonical["stocks"][:3]], ["NVDA", "ZM", "AMZN"])
        self.assertEqual(canonical["universe"]["observedAssets"], 8)
        calendar.write_bytes(calendar.read_bytes() + b"\n// same calendar dates, new source revision\n")
        second = worker.tick(NOW)
        self.assertNotEqual(first["publisher"]["revision"], second["publisher"]["revision"])
        self.assertEqual(second["shortlist"], first["shortlist"])

    def test_strict_configuration_bounds_and_public_private_separation(self):
        path = self.root / "config.json"
        config = {"schemaVersion": service.CONFIG_VERSION, "input": str(self.config.input), "calendar": None,
                  "state_dir": str(self.config.state_dir), "public_dir": str(self.config.public_dir), "interval_seconds": 5}
        path.write_bytes(service.json_bytes(config))
        self.assertEqual(service.load_config(path), self.config)
        for changes in ({"interval_seconds": True}, {"interval_seconds": 30.5}, {"interval_seconds": 3601}, {"extra": 1}, {"public_dir": str(self.config.state_dir / "public")}, {"input": str(self.config.public_dir / "private.json")}, {"publish_url": "https://other.example/publication"}):
            path.write_bytes(service.json_bytes(config | changes))
            with self.assertRaises(ValueError):
                service.load_config(path)

    def test_upload_is_opt_in_and_missing_token_cannot_send(self):
        envelope = service.Publisher(self.config).tick(NOW)
        with patch.object(service.urllib.request, "build_opener", side_effect=AssertionError("unexpected network")):
            self.assertTrue(service.upload(self.config, envelope))
            configured = service.Config(self.config.input, None, self.config.state_dir, self.config.public_dir, 5, service.PUBLISH_URL)
            with patch.dict(os.environ, {}, clear=True):
                self.assertFalse(service.upload(configured, envelope))
        diagnostic = service.parse_json((self.config.state_dir / "delivery-status.json").read_bytes())
        self.assertEqual(diagnostic["errorCode"], "token_unavailable")

    def test_upload_uses_allowlisted_https_no_redirect_bounded_timeout_and_safe_diagnostics(self):
        envelope = service.Publisher(self.config).tick(NOW)
        configured = service.Config(self.config.input, None, self.config.state_dir, self.config.public_dir, 5, service.PUBLISH_URL)
        token = "unit-test-token-that-is-never-a-real-key"
        class Reply:
            status = 200
            def __enter__(self):
                return self
            def __exit__(self, *_args):
                pass
            def read(self, count):
                self.limit = count
                return b'{"ok":true}'
        reply = Reply()
        calls = []
        class Opener:
            def open(self, request, timeout):
                calls.append((request, timeout))
                return reply
        with patch.dict(os.environ, {service.PUBLISH_TOKEN_ENV: token}), patch.object(service.urllib.request, "build_opener", return_value=Opener()) as build:
            self.assertTrue(service.upload(configured, envelope))
        request, timeout = calls[0]
        self.assertEqual(request.full_url, service.PUBLISH_URL)
        self.assertEqual(request.method, "POST")
        self.assertEqual(request.data, service.json_bytes(envelope))
        self.assertEqual(timeout, 10)
        self.assertEqual(reply.limit, 65537)
        self.assertEqual(request.get_header("Authorization"), "Bearer " + token)
        self.assertEqual(request.get_header("User-agent"), "LeoShortlistPublisher/1.0")
        self.assertEqual(request.get_header("Accept"), "application/json")
        self.assertTrue(any(isinstance(handler, service._NoRedirect) for handler in build.call_args.args))
        with self.assertRaises(urllib.error.HTTPError) as redirected:
            service._NoRedirect().redirect_request(request, None, 302, "redirect", {}, "https://other.invalid/")
        redirected.exception.close()
        diagnostic_path = self.config.state_dir / "delivery-status.json"
        self.assertEqual(service.parse_json(diagnostic_path.read_bytes())["state"], "delivered")
        self.assertNotIn(token, diagnostic_path.read_text(encoding="utf8"))
        original = (self.config.public_dir / "current.json").read_bytes()
        with patch.dict(os.environ, {service.PUBLISH_TOKEN_ENV: token}), patch.object(service.urllib.request, "build_opener", side_effect=OSError("secret response " + token)):
            self.assertFalse(service.upload(configured, envelope))
        self.assertEqual((self.config.public_dir / "current.json").read_bytes(), original)
        self.assertNotIn(token, diagnostic_path.read_text(encoding="utf8"))
        self.assertEqual(service.parse_json(diagnostic_path.read_bytes())["errorCode"], "upload_failed")

    def test_real_process_lock_excludes_second_publisher_and_releases_on_exit(self):
        env = os.environ.copy()
        env["PYTHONPATH"] = str(PLATFORM / "intraday_quant/src")
        code = "from pathlib import Path; import sys,time; from intraday_quant.shortlist_service import exclusive_lock\nwith exclusive_lock(Path(sys.argv[1])):\n print('locked',flush=True)\n time.sleep(20)"
        child = subprocess.Popen([sys.executable, "-c", code, str(self.config.state_dir)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)
        try:
            self.assertEqual(child.stdout.readline().strip(), "locked")
            with self.assertRaisesRegex(RuntimeError, "another shortlist publisher"):
                with service.exclusive_lock(self.config.state_dir):
                    self.fail("duplicate lock acquired")
        finally:
            child.terminate()
            child.communicate(timeout=5)
        with service.exclusive_lock(self.config.state_dir):
            pass

    @unittest.skipUnless(hasattr(os, "mkfifo"), "POSIX FIFO protection test")
    def test_fifo_source_rejected_without_blocking(self):
        fifo = self.root / "fifo"
        os.mkfifo(fifo)
        start = time.monotonic()
        with self.assertRaises(ValueError):
            service.read_bytes(fifo, 1000)
        self.assertLess(time.monotonic() - start, 1)


if __name__ == "__main__":
    unittest.main()

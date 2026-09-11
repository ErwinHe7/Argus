"""Injected calendar/journal checks; no market outcomes or performance evidence."""
from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import patch

from intraday_quant import radar

NOW = datetime(2026, 9, 10, 19, 30, tzinfo=timezone.utc)


def seeds():
    stamp = radar.iso(NOW - timedelta(minutes=5))
    return {
        "schemaVersion": "astra-event-radar-seeds.v1",
        "sources": [{"id": "bls-test", "title": "Injected calendar fixture", "url": "https://www.bls.gov/schedule/2026/09_sched.htm",
            "mode": "manual_verified", "state": "success", "lastAttemptAt": stamp,
            "retrievedAt": stamp, "reviewAfter": radar.iso(NOW + timedelta(hours=1)),
            "contentSha256": "a" * 64, "error": None}],
        "events": [{"id": "cpi-test", "kind": "macro", "title": "CPI fixture", "symbols": [],
            "startDate": "2026-09-11", "endDate": "2026-09-11", "scheduledAt": "2026-09-11T12:30:00Z",
            "timing": "exact", "sourceId": "bls-test", "sourceUrl": "https://www.bls.gov/schedule/2026/09_sched.htm",
            "availableAt": stamp, "referencePeriod": "August 2026", "summary": "Injected unit-test event.",
            "watchFor": "Compare actual release with the retained source.", "limitation": "Not broker or predictive evidence.", "scenarios": []}],
        "limitations": ["Injected unit tests only."]}


class RadarTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="leo-radar-tests-")
        self.root = Path(self.temporary.name)
        self.db = self.root / "journal.sqlite3"
        self.data = seeds()

    def tearDown(self):
        self.temporary.cleanup()

    def append_hypothesis(self, at=NOW, **changes):
        with patch.object(radar, "utcnow", return_value=at):
            return radar.append_record(self.db, self.data, "hypothesis", "cpi-test", "Injected research hypothesis.", **changes)

    def records(self):
        with radar.journal_connection(self.db) as db:
            return radar.load_records(db)

    def test_export_is_deterministic_and_does_not_renew_verification(self):
        first = radar.compile_artifact(self.data, now=NOW)
        same = radar.compile_artifact(self.data, now=NOW)
        self.assertEqual(radar.bytes_json(first), radar.bytes_json(same))
        later = radar.compile_artifact(self.data, now=NOW + timedelta(days=2))
        self.assertNotEqual(first["generatedAt"], later["generatedAt"])
        self.assertEqual(first["sources"], later["sources"])
        self.assertEqual(first["reviewAfter"], later["reviewAfter"])
        self.assertEqual(first["events"], later["events"])
        self.assertFalse(first["predictionEnabled"])
        self.assertFalse(first["executionEnabled"])
        self.assertEqual(first["llmCalls"], 0)

    def test_failed_source_retains_last_good_events_and_cutoff(self):
        row = self.data["sources"][0]
        row.update(state="error", lastAttemptAt=radar.iso(NOW), error="Official source unavailable.")
        result = radar.compile_artifact(self.data, now=NOW)
        self.assertEqual(len(result["events"]), 1)
        self.assertEqual(result["coverage"]["failedSourceCount"], 1)
        self.assertEqual(result["sources"][0]["retrievedAt"], radar.iso(NOW - timedelta(minutes=5)))

    def test_unknown_source_has_no_event_or_success_metadata(self):
        self.data["sources"][0].update(state="error", retrievedAt=None, reviewAfter=None, contentSha256=None, error="Fetch failed.")
        with self.assertRaises(ValueError):
            radar.compile_artifact(self.data, now=NOW)
        self.data["events"] = []
        self.assertEqual(radar.compile_artifact(self.data, now=NOW)["events"], [])

    def test_rejects_future_noncausal_source_metadata(self):
        mutations = [
            ("sources", "lastAttemptAt", radar.iso(NOW + timedelta(seconds=1))),
            ("sources", "retrievedAt", radar.iso(NOW)),
            ("events", "availableAt", radar.iso(NOW)),
        ]
        for collection, key, value in mutations:
            with self.subTest(key=key):
                data = deepcopy(self.data)
                data[collection][0][key] = value
                with self.assertRaises(ValueError):
                    radar.compile_artifact(data, now=NOW)

    def test_rejects_forged_primary_urls_and_unknown_fields(self):
        for url in ["http://www.bls.gov/a", "https://www.bls.gov.evil.example/a", "https://user@www.bls.gov/a", "https://www.bls.gov:444/a", "javascript:alert(1)"]:
            data = deepcopy(self.data)
            data["sources"][0]["url"] = url
            with self.subTest(url=url), self.assertRaises(ValueError):
                radar.compile_artifact(data, now=NOW)
        self.data["events"][0]["probabilityUp"] = 0.8
        with self.assertRaises(ValueError):
            radar.compile_artifact(self.data, now=NOW)

    def test_exact_time_must_be_inside_eastern_day(self):
        self.data["events"][0]["scheduledAt"] = "2026-09-11T01:00:00Z"
        with self.assertRaises(ValueError):
            radar.compile_artifact(self.data, now=NOW)
        self.data["events"][0].update(scheduledAt=None, timing="date_only")
        self.assertIsNone(radar.compile_artifact(self.data, now=NOW)["events"][0]["scheduledAt"])

    def test_duplicates_and_invalid_date_types_fail(self):
        for mutate in [
            lambda data: data["events"].append(deepcopy(data["events"][0])),
            lambda data: data["sources"].append(deepcopy(data["sources"][0])),
            lambda data: data["events"][0].update(startDate=20260911),
            lambda data: data["events"][0].update(symbols=[{}]),
        ]:
            data = deepcopy(self.data)
            mutate(data)
            with self.assertRaises(ValueError):
                radar.compile_artifact(data, now=NOW)

    def test_bounded_strict_json(self):
        for raw in [b'{"a":1,"a":2}', b'{"a":NaN}', b'\xff', b' ' * (radar.MAX_BYTES + 1)]:
            with self.assertRaises((ValueError, UnicodeDecodeError)):
                radar.decode(raw)

    def test_append_assigns_clock_and_export_round_trips(self):
        item = self.append_hypothesis()
        self.assertEqual(item["registeredAt"], radar.iso(NOW))
        self.assertEqual(item["sequence"], 1)
        self.assertEqual(item["contentSha256"], radar.record_hash(item))
        artifact = radar.compile_artifact(self.data, now=NOW, records=self.records())
        self.assertEqual(artifact["records"], [item])

    def test_stale_source_or_late_hypothesis_rejected_without_partial_append(self):
        with self.assertRaises(ValueError):
            self.append_hypothesis(at=NOW + timedelta(hours=2))
        self.data["sources"][0]["reviewAfter"] = "2026-09-12T12:30:00Z"
        with self.assertRaises(ValueError):
            self.append_hypothesis(at=datetime(2026, 9, 11, 12, 30, tzinfo=timezone.utc))
        self.assertEqual(self.records(), [])

    def test_date_only_registration_closes_at_start_of_eastern_day(self):
        self.data["events"][0].update(scheduledAt=None, timing="date_only")
        self.data["sources"][0]["reviewAfter"] = "2026-09-12T12:30:00Z"
        self.append_hypothesis(at=datetime(2026, 9, 11, 3, 59, tzinfo=timezone.utc))
        with self.assertRaises(ValueError):
            self.append_hypothesis(at=datetime(2026, 9, 11, 4, tzinfo=timezone.utc))

    def test_journal_is_append_only_and_hash_tampering_detected(self):
        self.append_hypothesis()
        with radar.journal_connection(self.db) as db:
            for sql in ["UPDATE records SET body='{}'", "DELETE FROM records", "UPDATE event_snapshots SET body='{}'", "DELETE FROM event_snapshots"]:
                with self.assertRaises(sqlite3.IntegrityError):
                    db.execute(sql)
        records = self.records()
        records[0]["statement"] = "Modified claim."
        with self.assertRaises(ValueError):
            radar.compile_artifact(self.data, now=NOW, records=records)

    def test_journaled_event_revision_cannot_be_rewritten(self):
        self.append_hypothesis()
        self.data["events"][0]["scheduledAt"] = "2026-09-11T13:30:00Z"
        with self.assertRaisesRegex(ValueError, "journaled event changed"):
            self.append_hypothesis()

    def test_outcome_requires_prior_hypothesis_and_post_event_source(self):
        hypothesis = self.append_hypothesis()
        after = datetime(2026, 9, 11, 12, 31, tzinfo=timezone.utc)
        with patch.object(radar, "utcnow", return_value=after):
            for available, parent in [("2026-09-11T12:29:00Z", hypothesis["id"]), ("2026-09-11T12:32:00Z", hypothesis["id"]), ("2026-09-11T12:30:00Z", "missing-parent")]:
                with self.assertRaises(ValueError):
                    radar.append_record(self.db, self.data, "outcome", "cpi-test", "Injected outcome.", hypothesis_id=parent, source_url="https://www.bls.gov/news.release/cpi.htm", source_available_at=available)
            record = radar.append_record(self.db, self.data, "outcome", "cpi-test", "Injected outcome.", hypothesis_id=hypothesis["id"], source_url="https://www.bls.gov/news.release/cpi.htm", source_available_at="2026-09-11T12:30:00Z")
            self.assertEqual(record["sequence"], 2)
            with self.assertRaises(ValueError):
                radar.append_record(self.db, self.data, "outcome", "cpi-test", "Duplicate outcome.", hypothesis_id=hypothesis["id"], source_url="https://www.bls.gov/news.release/cpi.htm", source_available_at="2026-09-11T12:30:00Z")
        self.assertEqual(len(self.records()), 2)

    def test_concurrent_appends_serialize_and_clock_regression_rejected(self):
        with patch.object(radar, "utcnow", return_value=NOW):
            with ThreadPoolExecutor(max_workers=2) as pool:
                records = list(pool.map(lambda _: radar.append_record(self.db, self.data, "hypothesis", "cpi-test", "Injected hypothesis."), range(2)))
        self.assertEqual({item["sequence"] for item in records}, {1, 2})
        with self.assertRaises(ValueError):
            self.append_hypothesis(at=NOW - timedelta(seconds=1))
        radar.validate_records(self.records(), {"cpi-test": self.data["events"][0]}, NOW)

    def test_cli_preserves_last_good_output_on_invalid_input(self):
        source, output = self.root / "seeds.json", self.root / "output.json"
        source.write_bytes(radar.bytes_json(self.data))
        arguments = ["--seeds", str(source), "--output", str(output), "--once"]
        with patch.object(radar, "utcnow", return_value=NOW):
            self.assertEqual(radar.main(arguments), 0)
            previous = output.read_bytes()
            source.write_bytes(b'{"broken":true}')
            self.assertEqual(radar.main(arguments), 1)
            self.assertEqual(output.read_bytes(), previous)


if __name__ == "__main__":
    unittest.main()

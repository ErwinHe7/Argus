"""Offline tests for the IBKR momentum scanner; no account or network access."""

from __future__ import annotations

import importlib.util
import json
import sys
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path

SCRIPT_PATH = Path(__file__).with_name("scan.py")
SPEC = importlib.util.spec_from_file_location("ibkr_momentum_scan_under_test", SCRIPT_PATH)
assert SPEC and SPEC.loader
scan = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = scan  # dataclasses resolve the module by name
SPEC.loader.exec_module(scan)

NOW = datetime(2026, 9, 28, 14, 30, tzinfo=UTC)
NOW_MS = int(NOW.timestamp() * 1000)
READ_ONLY_PATHS = (
    "iserver/auth/status",
    "iserver/accounts",
    "iserver/scanner/params",
    "iserver/scanner/run",
    "iserver/marketdata/snapshot?",
    "iserver/marketdata/unsubscribeall",
)


def snapshot_row(conid, *, last, prior, volume="3000000", avg="400K", cap="30M", availability="RpB", updated=NOW_MS):
    return {
        "conid": conid,
        "_updated": updated,
        "31": last,
        "55": str(conid),
        "6509": availability,
        "7282": avg,
        "7289": cap,
        "7741": prior,
        "7762": volume,
    }


class FakeGateway:
    def __init__(self, bands, snapshots, *, filters=("priceAbove", "priceBelow", "changePercAbove")):
        self.bands = list(bands)
        self.snapshots = snapshots
        self.filters = filters
        self.calls = []
        self.scan_bodies = []
        self.snapshot_polls = 0

    def request(self, path="", **kwargs):
        self.calls.append(path)
        if not path.startswith(READ_ONLY_PATHS):
            raise AssertionError(f"scanner called a non read-only endpoint: {path}")
        if path == "iserver/auth/status":
            return {"authenticated": True, "connected": True, "competing": False}
        if path == "iserver/scanner/params":
            return {
                "scan_type_list": [{"code": "TOP_PERC_GAIN", "display_name": "Top % Gainers"}],
                "filter_list": [{"code": code} for code in self.filters],
            }
        if path == "iserver/scanner/run":
            self.scan_bodies.append(kwargs["body"])
            return {"contracts": self.bands.pop(0)}
        if path.startswith("iserver/marketdata/snapshot?"):
            self.snapshot_polls += 1
            requested = path.split("conids=", 1)[1].split("&", 1)[0].split(",")
            if self.snapshot_polls == 1:
                return [{"conid": int(conid)} for conid in requested]
            return [self.snapshots[int(conid)] for conid in requested if int(conid) in self.snapshots]
        return {}


def contract(symbol, conid):
    return {"symbol": symbol, "con_id": conid, "company_name": symbol + " Inc", "listing_exchange": "NASDAQ.NMS"}


def run_scan(bands, snapshots, **kwargs):
    gateway = FakeGateway(bands, snapshots, **kwargs)
    criteria = scan.Criteria()
    scanner = scan.MomentumScanner(
        gateway,
        criteria,
        bands=scan.price_bands(criteria, (5.0,)),
        max_age_seconds=120,
        sleep=lambda _seconds: None,
        clock=lambda: NOW,
    )
    return gateway, scanner.run()


class MomentumScanTests(unittest.TestCase):
    def test_full_scan_rechecks_every_criterion_on_realtime_snapshot(self):
        gateway, artifact = run_scan(
            [
                [contract("AAA", 1), contract("BBB", 2), contract("DDD", 4)],
                [contract("CCC", 3), contract("AAA", 1)],
            ],
            {
                # +20%, 7.5x volume, 30M cap / $4 prior close = 7.5M shares.
                1: snapshot_row(1, last="4.80", prior="4.00"),
                # +12%, only 2x volume.
                2: snapshot_row(2, last="3.36", prior="3.00", volume="800000"),
                # Delayed data must not be treated as realtime.
                3: snapshot_row(3, last="11.00", prior="9.00", availability="DpB"),
                # +50% but market cap implies up to 50M shares: float unknown, not failed.
                4: snapshot_row(4, last="3.00", prior="2.00", cap="100M"),
            },
        )
        self.assertEqual([body["filter"][0]["value"] for body in gateway.scan_bodies], [1.49, 4.99])
        self.assertEqual([body["filter"][1]["value"] for body in gateway.scan_bodies], [5.01, 25.01])
        self.assertEqual(gateway.scan_bodies[0]["filter"][2], {"code": "changePercAbove", "value": 10.0})
        self.assertEqual(gateway.calls.count("iserver/marketdata/unsubscribeall"), 1)

        rows = {row["symbol"]: row for row in artifact["rows"]}
        self.assertEqual(list(rows), ["AAA", "DDD", "BBB", "CCC"])
        self.assertEqual(rows["AAA"]["status"], "eligible")
        self.assertEqual(rows["AAA"]["change_pct"], 20.0)
        self.assertEqual(rows["AAA"]["relative_volume"], 7.5)
        self.assertEqual(rows["AAA"]["shares_outstanding_max"], 7_500_000)
        self.assertEqual(
            rows["AAA"]["checks"],
            {"price": "pass", "change": "pass", "relative_volume": "pass", "float": "pass", "news": "unverified"},
        )
        self.assertEqual(rows["DDD"]["status"], "eligible")
        self.assertEqual(rows["DDD"]["checks"]["float"], "unverified")
        self.assertEqual(rows["BBB"]["status"], "fail")
        self.assertEqual(rows["BBB"]["checks"]["relative_volume"], "fail")
        self.assertEqual(rows["CCC"]["status"], "blocked")
        self.assertIn("not realtime", rows["CCC"]["reason"])
        self.assertEqual(artifact["coverage"]["candidates"], 4)
        self.assertFalse(artifact["coverage"]["complete"])
        json.dumps(artifact, allow_nan=False)
        self.assertIn("AAA", scan.format_table(artifact))

    def test_halted_last_price_is_flagged(self):
        _gateway, artifact = run_scan(
            [[contract("HLT", 10)], []],
            {10: snapshot_row(10, last="H4.80", prior="4.00")},
        )
        self.assertEqual(artifact["rows"][0]["last"], 4.8)
        self.assertTrue(artifact["rows"][0]["halted"])
        self.assertIn("HALTED", scan.format_table(artifact))

    def test_scanner_rows_outside_the_band_fail_the_price_check(self):
        _gateway, artifact = run_scan(
            [[contract("LOW", 5)], []],
            {5: snapshot_row(5, last="1.20", prior="1.00")},
        )
        self.assertEqual(artifact["rows"][0]["status"], "fail")
        self.assertEqual(artifact["rows"][0]["checks"]["price"], "fail")

    def test_stale_or_future_snapshot_is_blocked(self):
        stale = int((NOW - timedelta(minutes=10)).timestamp() * 1000)
        _gateway, artifact = run_scan(
            [[contract("OLD", 6)], []],
            {6: snapshot_row(6, last="4.80", prior="4.00", updated=stale)},
        )
        self.assertEqual(artifact["rows"][0]["status"], "blocked")
        self.assertIn("stale", artifact["rows"][0]["reason"])

    def test_missing_snapshot_fields_are_blocked_or_unverified(self):
        row = snapshot_row(7, last="4.80", prior="4.00")
        del row["7282"], row["7289"]
        _gateway, artifact = run_scan([[contract("GAP", 7), contract("NIL", 8)], []], {7: row})
        rows = {row["symbol"]: row for row in artifact["rows"]}
        self.assertEqual(rows["GAP"]["status"], "eligible")
        self.assertEqual(rows["GAP"]["checks"]["relative_volume"], "unverified")
        self.assertEqual(rows["GAP"]["checks"]["float"], "unverified")
        self.assertEqual(rows["NIL"]["status"], "blocked")

    def test_float_bound_uses_the_lower_of_last_and_prior_close(self):
        # 50M cap / $2.50 prior close = 20M shares, not 50M / $3.00 = 16.7M.
        _gateway, artifact = run_scan(
            [[contract("DIL", 9)], []],
            {9: snapshot_row(9, last="3.00", prior="2.50", cap="50M")},
        )
        self.assertEqual(artifact["rows"][0]["shares_outstanding_max"], 20_000_000)
        self.assertEqual(artifact["rows"][0]["checks"]["float"], "unverified")

    def test_band_at_ibkr_row_cap_is_marked_truncated(self):
        full = [contract(f"S{index}", 100 + index) for index in range(scan.MAX_SCANNER_ROWS)]
        snapshots = {100 + index: snapshot_row(100 + index, last="4.80", prior="4.00") for index in range(50)}
        gateway, artifact = run_scan([full, []], snapshots)
        self.assertTrue(artifact["coverage"]["bands"][0]["truncated"])
        self.assertFalse(artifact["coverage"]["complete"])
        self.assertIn("50-row cap", scan.format_table(artifact))

    def test_missing_price_filter_fails_closed_before_scanning(self):
        with self.assertRaisesRegex(scan.RelayError, "priceBelow"):
            run_scan([[], []], {}, filters=("priceAbove",))

    def test_change_filter_is_optional(self):
        gateway, _artifact = run_scan([[], []], {}, filters=("priceAbove", "priceBelow"))
        self.assertEqual(len(gateway.scan_bodies[0]["filter"]), 2)

    def test_price_bands_clip_to_criteria(self):
        criteria = scan.Criteria(min_price=1.5, max_price=25)
        self.assertEqual(
            scan.price_bands(criteria, (1.0, 3.0, 5.0, 10.0, 30.0)),
            [(1.5, 3.0), (3.0, 5.0), (5.0, 10.0), (10.0, 25)],
        )


if __name__ == "__main__":
    unittest.main()

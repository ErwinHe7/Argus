"""Narrow offline descriptor/lineage tests; no account or network access."""
import copy
import importlib.util
import json
import math
from datetime import date, timedelta
from pathlib import Path
import sys
import unittest

PLATFORM = Path(__file__).resolve().parents[3]
MODULE = PLATFORM / "intraday_quant/src/intraday_quant/desk_export.py"
sys.path.insert(0, str(MODULE.parent))
spec = importlib.util.spec_from_file_location("desk_export", MODULE)
desk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(desk)


def bars(count):
    return [{"date": (date(2025, 1, 1) + timedelta(days=index)).isoformat(),
             "open": 100 + index, "high": 102 + index, "low": 99 + index,
             "close": 101 + index, "volume": 1000} for index in range(count)]


class DeskExportTests(unittest.TestCase):
    def test_sma50_warmup_and_arithmetic_window(self):
        output = desk.daily_descriptors(bars(51))
        self.assertIsNone(output["series"][48]["sma50"])
        self.assertEqual(output["series"][49]["sma50"], 125.5)
        self.assertEqual(output["latest"]["sma50"], 126.5)

    def test_observed_range_uses_only_latest_twenty_and_no_future(self):
        data = bars(21)
        data[0]["high"] = 10000
        output = desk.daily_descriptors(data)
        self.assertEqual(output["latest"]["high20"], 122)
        self.assertEqual(output["latest"]["low20"], 100)
        self.assertIsNone(desk.daily_descriptors(data[:19])["latest"]["high20"])
        future = bars(22)
        future[-1].update(open=100000, close=100000, high=100001, low=99999)
        self.assertEqual(desk.daily_descriptors(bars(21))["series"], desk.daily_descriptors(future)["series"][:-1])

    def test_truncation_does_not_reset_indicator_warmup(self):
        data = bars(180)
        full = desk.daily_descriptors(data)
        self.assertEqual(len(full["series"]), 120)
        self.assertEqual(full["series"][0]["sma50"], 136.5)
        prefix = desk.daily_descriptors(data[:90])
        self.assertEqual(prefix["series"][-1], full["series"][29])

    def test_bad_ohlc_is_disclosed_and_excluded_without_repair(self):
        data = bars(70)
        data[2]["high"] = 1
        suffix, coverage = desk.validated_suffix(data)
        self.assertEqual(coverage["validationExcludedPrefixSessions"], 3)
        self.assertEqual(coverage["invalidDates"], [data[2]["date"]])
        self.assertEqual(suffix[0]["close"], data[3]["close"])
        data[3]["close"] = math.nan
        with self.assertRaises(ValueError):
            desk.validated_suffix(data)

    def test_actual_export_keeps_field_timestamps_and_distinguishes_proxies(self):
        artifact = json.loads((Path(__file__).parent / "desk-data.json").read_text(encoding="utf8"))
        self.assertEqual(artifact["dataMode"], "historical_snapshot_not_live")
        self.assertEqual(len(artifact["symbols"]), 8)
        self.assertEqual(artifact["indexContext"]["symbols"], ["SPY", "QQQ"])
        self.assertFalse(artifact["indexContext"]["indicesObserved"])
        by_symbol = {item["symbol"]: item for item in artifact["symbols"]}
        self.assertEqual(by_symbol["AVGO"]["retrievedAt"], "2026-09-06 09:50:06 UTC")
        self.assertEqual(by_symbol["SPY"]["retrievedAt"], "2026-09-07 10:01:18 UTC")
        self.assertEqual(by_symbol["DXYZ"]["assetType"], "closed_end_fund")
        for item in artifact["symbols"]:
            self.assertIsNone(item["ivObservedAt"])
            self.assertIsNone(item["dailyBarCloseObservedAt"])
            self.assertEqual(item["series"][-1]["date"], item["dailyBarLastDate"])
            self.assertFalse(item["executionEnabled"])
            self.assertIn("descriptive_not_price_targets", item["rangeBasis"])

    def test_incomplete_proxy_arrays_and_future_quote_fail_closed(self):
        bad = {"symbol": "SPY", "history": {"structuredContent": {"time": [], "close": [1]}},
               "snapshot": {"structuredContent": {}}}
        with self.assertRaises(ValueError):
            desk.proxy_record(bad, "2026-09-07T00:00:00Z")
        with self.assertRaises(ValueError):
            desk.symbol_record("SPY", "SPY ETF", "IBKR", "2026-09-04T00:00:00Z",
                               "2026-09-05T00:00:00Z", 100, .2, .5, bars(60))


if __name__ == "__main__":
    unittest.main()

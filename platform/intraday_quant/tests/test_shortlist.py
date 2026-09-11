from copy import deepcopy
from datetime import date, timedelta
from hashlib import sha256
from pathlib import Path
import json
import unittest
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from intraday_quant.shortlist import build_shortlist, calendar_review, shortlist_row

PLATFORM = Path(__file__).resolve().parents[2]
try:
    ZoneInfo("America/New_York")
    TIMEZONE_AVAILABLE = True
except ZoneInfoNotFoundError:
    TIMEZONE_AVAILABLE = False


def asset(symbol="TEST", close=102, rsi=55, sma20=100, sma50=95, atr=2):
    dates = []
    session = date(2026, 9, 4)
    while len(dates) < 60:
        if session.weekday() < 5:
            dates.append(session.isoformat())
        session -= timedelta(days=1)
    dates.reverse()
    return {
        "symbol": symbol, "name": "Test company", "assetType": "stock", "currency": "USD",
        "source": "Explicit unit-test observations", "retrievedAt": "2026-09-07T10:00:00Z",
        "observedAt": "2026-09-04T23:00:00Z", "dailyBarLastDate": "2026-09-04",
        "dailyBarCloseObservedAt": None, "freshness": "historical_snapshot_not_live",
        "spot": 9999, "iv": 9999, "ivPercentile": 9999,
        "coverage": {"state": "observed_sessions_only_calendar_unverified", "observedSessions": 60,
                     "startDate": dates[0], "endDate": "2026-09-04", "adjustmentPolicy": "unknown"},
        "latest": {"sma20": sma20, "sma50": sma50, "rsi14": rsi, "atr14": atr, "changePercent": 1.5},
        "series": [{"date": session_date, "close": close, "sma20": sma20, "sma50": sma50, "rsi14": rsi} for session_date in dates],
    }


def source(*assets):
    return {"schemaVersion": "leo-research-desk.v1", "dataMode": "historical_snapshot_not_live", "symbols": list(assets)}


class ShortlistTests(unittest.TestCase):
    def test_fixed_thresholds_include_band_endpoints_and_exclude_trend_equality(self):
        for rsi, passed in ((49.999, False), (50, True), (65, True), (65.001, False)):
            self.assertEqual(shortlist_row(asset(rsi=rsi), "2026-09-04")["criteria"][1]["passed"], passed)
        for close, passed in ((99.999, False), (100, True), (105, True), (105.001, False)):
            self.assertEqual(shortlist_row(asset(close=close), "2026-09-04")["criteria"][2]["passed"], passed)
        self.assertFalse(shortlist_row(asset(close=95), "2026-09-04")["criteria"][0]["passed"])

    def test_completed_close_is_used_and_spot_iv_never_change_ranking(self):
        original = asset()
        changed = deepcopy(original)
        changed.update({"spot": 0.01, "iv": None, "ivPercentile": None})
        self.assertEqual(shortlist_row(original, "2026-09-04"), shortlist_row(changed, "2026-09-04"))
        self.assertEqual(shortlist_row(original, "2026-09-04")["close"], 102)

    def test_ranking_orders_condition_count_then_normalized_atr_then_symbol(self):
        result = build_shortlist(source(asset("B", atr=3), asset("C", atr=2), asset("A", atr=2), asset("Z", close=99, atr=.01)), None)
        self.assertEqual([row["symbol"] for row in result["stocks"]], ["A", "C", "B", "Z"])
        self.assertEqual([row["rank"] for row in result["stocks"]], [1, 2, 3, 4])

    def test_funds_are_separate_and_missing_indicators_are_excluded_not_zeroed(self):
        fund = asset("FUND")
        fund["assetType"] = "closed_end_fund"
        missing = asset("MISSING")
        missing["latest"]["rsi14"] = None
        result = build_shortlist(source(asset(), fund, missing), None)
        self.assertEqual([row["symbol"] for row in result["stocks"]], ["TEST"])
        self.assertEqual([row["symbol"] for row in result["funds"]], ["FUND"])
        self.assertEqual(result["exclusions"][0]["symbol"], "MISSING")
        self.assertEqual(result["universe"]["companyStocks"], 2)
        self.assertEqual(result["universe"]["eligibleCompanyStocks"], 1)

    def test_stale_cutoff_bad_timestamp_and_series_mismatch_fail_closed(self):
        for mutation in (lambda row: row.update(dailyBarLastDate="2026-09-03"),
                         lambda row: row.update(observedAt="2026-09-08T00:00:00Z"),
                         lambda row: row["series"][-1].update(sma20=99),
                         lambda row: row["coverage"].update(observedSessions=49)):
            bad = asset("BAD")
            mutation(bad)
            result = build_shortlist(source(asset(), bad), None)
            self.assertEqual([row["symbol"] for row in result["stocks"]], ["TEST"])
            self.assertEqual(result["exclusions"][0]["symbol"], "BAD")
        future = asset()
        future["dailyBarLastDate"] = "2027-01-01"
        with self.assertRaises(ValueError):
            build_shortlist(source(future), None)

    def test_nonfinite_and_duplicate_inputs_are_rejected(self):
        with self.assertRaises(ValueError):
            build_shortlist(source(asset(), asset()), None)
        broken = asset()
        broken["latest"]["atr14"] = float("nan")
        with self.assertRaises(ValueError):
            build_shortlist(source(broken), None)
        broken = asset()
        broken["latest"]["rsi14"] = True
        self.assertEqual(build_shortlist(source(broken), None)["stocks"], [])

    def test_retained_series_count_dates_and_prices_are_validated(self):
        for mutation in (lambda row: row["series"].pop(0),
                         lambda row: row["series"][0].update(date=row["series"][1]["date"]),
                         lambda row: row["series"][0].update(date="2026-09-03"),
                         lambda row: row["series"][0].update(close=0),
                         lambda row: row["series"][0].update(close=-1)):
            bad = asset("BAD")
            mutation(bad)
            result = build_shortlist(source(asset(), bad), None)
            self.assertEqual([row["symbol"] for row in result["stocks"]], ["TEST"])
            self.assertEqual(result["exclusions"][0]["symbol"], "BAD")

    def test_exact_source_file_bytes_are_bound_and_mismatched_bytes_rejected(self):
        data = source(asset())
        raw = (json.dumps(data, indent=2) + "\n").encode("utf8")
        self.assertEqual(build_shortlist(data, None, raw)["inputSha256"], sha256(raw).hexdigest())
        with self.assertRaises(ValueError):
            build_shortlist(data, None, b"{}")

    @unittest.skipUnless(TIMEZONE_AVAILABLE, "IANA time-zone data unavailable; export correctly leaves reviewAfter null")
    def test_calendar_deadline_holiday_and_early_close(self):
        calendar = PLATFORM / "workers/public-market-map/us-calendar.ts"
        self.assertEqual(calendar_review("2026-09-04", calendar)[0], "2026-09-08T20:00:00Z")
        self.assertEqual(calendar_review("2026-11-25", calendar)[0], "2026-11-27T18:00:00Z")

    def test_calendar_missing_source_and_outside_coverage_fail_closed(self):
        calendar = PLATFORM / "workers/public-market-map/us-calendar.ts"
        self.assertEqual(calendar_review("2030-01-01", calendar)[0], None)
        self.assertEqual(calendar_review("2026-09-04", None), (None, None, None))
        self.assertEqual(calendar_review("2026-09-04", PLATFORM / "missing-calendar"), (None, None, None))

    def test_retained_artifact_reproducible_and_preserves_source_evidence(self):
        data = json.loads((PLATFORM / "features/research-desk/data/desk-data.json").read_text(encoding="utf8"))
        original = deepcopy(data)
        first = build_shortlist(data)
        self.assertEqual(first, build_shortlist(data))
        self.assertEqual(data, original)
        self.assertEqual([row["symbol"] for row in first["stocks"][:3]], ["NVDA", "ZM", "AMZN"])
        self.assertEqual([row["criteriaMet"] for row in first["stocks"][:3]], [3, 2, 1])
        self.assertEqual(first["asOf"], "2026-09-04")
        self.assertEqual(first["reviewAfter"], "2026-09-08T20:00:00Z" if TIMEZONE_AVAILABLE else None)
        self.assertEqual(first["sourceRetrievedAt"], "2026-09-07T10:01:18Z")
        self.assertEqual(first["stocks"][0]["sourceRetrievedAt"], "2026-09-06T09:50:06Z")
        self.assertEqual(first["universe"]["observedAssets"], 8)
        self.assertEqual(len(first["stocks"]), 5)
        self.assertEqual(len(first["funds"]), 3)
        self.assertEqual(first["stocks"][0]["coverage"]["validationExcludedPrefixSessions"], 192)
        self.assertIsNone(first["stocks"][0]["dailyCloseObservedAt"])
        self.assertFalse(first["predictionEnabled"])
        self.assertFalse(first["executionEnabled"])


if __name__ == "__main__":
    unittest.main()

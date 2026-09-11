"""Build deterministic descriptive market reads from the retained Desk artifact.

No network calls, new indicators, orders, forecasts or quantified probabilities.
Run with --test for focused threshold, missing-data and source-cutoff checks.
"""
from __future__ import annotations

import argparse
import copy
from datetime import date
import json
from pathlib import Path
import sys
import unittest
from typing import Any

PLATFORM = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PLATFORM / "intraday_quant/src/intraday_quant"))
from iv_lab import _number, _timestamp  # noqa: E402


def optional_number(value: Any, name: str, *, rsi: bool = False) -> float | None:
    if value is None:
        return None
    return _number(value, name, minimum=0 if rsi else 1e-8, maximum=100 if rsi else 1e9)


def market_read(asset: dict[str, Any]) -> dict[str, Any]:
    symbol = asset["symbol"]
    if not isinstance(symbol, str) or not symbol:
        raise ValueError("symbol is required")
    as_of = date.fromisoformat(asset["dailyBarLastDate"]).isoformat()
    retrieved = _timestamp(asset["retrievedAt"], "retrievedAt")
    if as_of > retrieved.date().isoformat():
        raise ValueError("daily observation cannot follow retrieval")
    series = asset["series"]
    if not series or series[-1]["date"] != as_of:
        raise ValueError("daily cutoff must match the final retained series point")
    close = _number(series[-1]["close"], "completed daily close", strictly_positive=True)
    latest = asset["latest"]
    sma20 = optional_number(latest.get("sma20"), "sma20")
    sma50 = optional_number(latest.get("sma50"), "sma50")
    rsi = optional_number(latest.get("rsi14"), "rsi14", rsi=True)
    low = optional_number(latest.get("low20"), "low20")
    high = optional_number(latest.get("high20"), "high20")
    if low is not None and high is not None and not low <= close <= high:
        raise ValueError("completed daily close must be inside the observed 20-session range")
    for field, value in (("sma20", sma20), ("sma50", sma50), ("rsi14", rsi)):
        if series[-1].get(field) != value:
            raise ValueError(f"latest {field} must match the final series point")

    trend = "Unavailable" if sma20 is None or sma50 is None else (
        "Uptrend" if close > sma20 and close > sma50 else
        "Downtrend" if close < sma20 and close < sma50 else "Mixed")
    momentum = "Unavailable" if rsi is None else (
        "Overbought" if rsi >= 70 else "Oversold" if rsi <= 30 else "Neutral")
    trend_text = {
        "Uptrend": "Price closed above the 20- and 50-session averages",
        "Downtrend": "Price closed below the 20- and 50-session averages",
        "Mixed": "Price closed between or at the two moving averages",
        "Unavailable": "Not enough daily data to classify the trend",
    }[trend]
    momentum_text = f"RSI14: {rsi:.1f} ({momentum.lower()})" if rsi is not None else "RSI14: unavailable"
    basis = [f"Completed daily close: ${close:,.2f} on {as_of}."]
    if sma20 is not None:
        basis.append(f"20-session simple moving average: ${sma20:,.2f}.")
    if sma50 is not None:
        basis.append(f"50-session simple moving average: ${sma50:,.2f}.")
    if rsi is not None:
        basis.append(f"RSI14: {rsi:.1f}; oversold at or below 30, overbought at or above 70.")
    if trend == "Uptrend":
        watch = f"Watch ${sma20:,.2f}, the snapshot's 20-session average. A daily close at or below it would change this trend reading."
    elif trend == "Downtrend":
        watch = f"Watch ${sma20:,.2f}, the snapshot's 20-session average. A daily close at or above it would change this trend reading."
    elif trend == "Mixed":
        watch = f"Watch the snapshot averages at ${sma20:,.2f} (20 sessions) and ${sma50:,.2f} (50 sessions)."
    else:
        watch = "Wait for enough completed daily data to compare both averages."
    if low is not None and high is not None:
        basis.append(f"Observed 20-session low/high: ${low:,.2f} / ${high:,.2f}; historical reference levels, not targets.")
        reference = f"The observed 20-session {'low' if trend == 'Uptrend' else 'high'} is ${low if trend == 'Uptrend' else high:,.2f}."
        watch += f" {reference}" if trend in ("Uptrend", "Downtrend") else ""
    return {"symbol": symbol, "asOf": as_of, "source": asset["source"],
            "sourceRetrievedAt": asset["retrievedAt"], "trend": trend, "momentum": momentum,
            "summary": f"{trend_text}. {momentum_text}.", "watch": watch, "basis": basis}


def build_analysis(data: dict[str, Any]) -> dict[str, Any]:
    if data.get("schemaVersion") != "leo-research-desk.v1" or data.get("dataMode") != "historical_snapshot_not_live":
        raise ValueError("expected the retained historical Desk artifact")
    assets = data.get("symbols")
    if not isinstance(assets, list) or not assets:
        raise ValueError("nonempty symbols required")
    reads = [market_read(asset) for asset in assets]
    if len({row["symbol"] for row in reads}) != len(reads):
        raise ValueError("duplicate symbols")
    generated = max((row["sourceRetrievedAt"] for row in reads), key=lambda item: _timestamp(item, "retrievedAt"))
    return {"schemaVersion": "astra-market-analysis.v1", "generatedAt": generated,
            "dataMode": "historical_snapshot_not_live", "methodology": {
                "featureVersion": "astra-daily-market-read.v1",
                "generatedAtMeaning": "Latest retained source retrieval, fixed for reproducibility; not a refresh timestamp.",
                "asOfMeaning": "Completed source daily-session date. Independent close observation times remain unavailable.",
                "trend": "Uptrend: daily close strictly above SMA20 and SMA50. Downtrend: strictly below both. Equality or disagreement is Mixed; missing averages are Unavailable. No slope or predictive strength is inferred.",
                "momentum": "RSI14 >=70 is Overbought; <=30 is Oversold; between is Neutral. These describe observations and do not predict reversals.",
                "watch": "Conditional comparisons with frozen snapshot reference levels; not monitored alerts, validated trading rules or price targets. Refresh all indicators before a later assessment.",
                "sourceCoverage": "Inherits the Desk artifact's observed-session, excluded-prefix and adjustment limitations.",
                "predictionEnabled": False, "executionEnabled": False,
            }, "symbols": reads}


class MarketReadTests(unittest.TestCase):
    def fixture(self) -> dict[str, Any]:
        return {"symbol": "TEST", "source": "unit-test fixture", "retrievedAt": "2026-09-07T00:00:00Z",
                "dailyBarLastDate": "2026-09-04", "spot": 1,
                "latest": {"sma20": 100, "sma50": 95, "rsi14": 60, "low20": 80, "high20": 120},
                "series": [{"date": "2026-09-04", "close": 110, "sma20": 100, "sma50": 95, "rsi14": 60}]}

    def test_trend_uses_completed_daily_close_not_spot_and_equality_is_mixed(self):
        data = self.fixture()
        self.assertEqual(market_read(data)["trend"], "Uptrend")
        data["series"][-1]["close"] = 90
        self.assertEqual(market_read(data)["trend"], "Downtrend")
        data["series"][-1]["close"] = 100
        self.assertEqual(market_read(data)["trend"], "Mixed")

    def test_rsi_thresholds_and_missing_fields(self):
        for rsi, expected in ((70, "Overbought"), (30, "Oversold"), (30.01, "Neutral"), (None, "Unavailable")):
            data = self.fixture()
            data["latest"]["rsi14"] = data["series"][-1]["rsi14"] = rsi
            self.assertEqual(market_read(data)["momentum"], expected)
        data["latest"]["sma50"] = data["series"][-1]["sma50"] = None
        self.assertEqual(market_read(data)["trend"], "Unavailable")

    def test_invalid_values_and_mismatched_source_cutoff_rejected(self):
        for field, value in (("rsi14", float("nan")), ("rsi14", 101), ("sma20", True), ("low20", 119)):
            data = self.fixture()
            data["latest"][field] = value
            with self.assertRaises(ValueError):
                market_read(data)
        for value in ("2026-09-03", "2027-01-01"):
            data = self.fixture()
            data["dailyBarLastDate"] = value
            with self.assertRaises(ValueError):
                market_read(data)

    def test_artifact_reproducible_source_dates_and_no_source_mutation(self):
        source = json.loads((PLATFORM / "features/research-desk/data/desk-data.json").read_text(encoding="utf8"))
        before = copy.deepcopy(source)
        result = build_analysis(source)
        self.assertEqual(result, build_analysis(source))
        self.assertEqual(source, before)
        self.assertEqual(len(result["symbols"]), 8)
        self.assertEqual({row["asOf"] for row in result["symbols"]}, {"2026-09-04"})
        self.assertFalse(result["methodology"]["predictionEnabled"])
        source["symbols"].append(source["symbols"][0])
        with self.assertRaises(ValueError):
            build_analysis(source)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=PLATFORM / "features/research-desk/data/desk-data.json")
    parser.add_argument("--output", type=Path, default=PLATFORM / "features/research-desk/data/market-analysis.json")
    parser.add_argument("--test", action="store_true")
    args = parser.parse_args()
    if args.test:
        result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(MarketReadTests))
        raise SystemExit(0 if result.wasSuccessful() else 1)
    output = build_analysis(json.loads(args.input.read_text(encoding="utf8")))
    args.output.write_text(json.dumps(output, ensure_ascii=False, allow_nan=False, indent=2) + "\n", encoding="utf8")
    print(f"Exported {len(output['symbols'])} descriptive historical market reads to {args.output}")


if __name__ == "__main__":
    main()

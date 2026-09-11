"""Narrow standard-library checks: python -m unittest discover -s tests -p test_iv_lab.py.

Artificial prices below are mathematical unit-test fixtures, never exported as
market observations. No network, pandas, pytest fixtures or model training used.
"""
from __future__ import annotations

import copy
import json
import math
import sys
import unittest
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from intraday_quant.iv_lab import AXES, black_scholes, build_artifact, scenario_cell, technical_indicators


def bars(count=60, flat=False):
    start = date(2026, 1, 1)
    result = []
    for index in range(count):
        close = 100.0 if flat else 100.0 + index
        result.append({"date": (start + timedelta(days=index)).isoformat(),
                       "open": close, "high": close + 1, "low": close - 1,
                       "close": close, "volume": 1000.0})
    return result


def evidence():
    return {
        "provider": "UNIT TEST fixture, not market data", "retrievedAt": "2026-09-06 10:00:00 UTC",
        "symbols": [{"symbol": "TEST", "name": "Test", "currency": "USD",
                     "snapshot": {"last": 100, "lastTradeTime": "2026-09-04T20:01:00Z",
                                  "underlyingIvAnnual": 0.358, "ivPercentile52w": 0.004},
                     "history": {"bars": bars(), "adjustmentPolicy": "unit test"}}],
        "options": [],
    }


class BlackScholesTests(unittest.TestCase):
    def test_known_european_values_and_greek_units(self):
        call = black_scholes(100, 100, 365, 0.2, "call", 0.05)
        put = black_scholes(100, 100, 365, 0.2, "put", 0.05)
        self.assertAlmostEqual(call["premium"], 10.450583572185565, places=10)
        self.assertAlmostEqual(put["premium"], 5.573526022256971, places=10)
        self.assertAlmostEqual(call["delta"], 0.6368306511756191, places=10)
        self.assertAlmostEqual(call["gamma"], 0.018762017345846895, places=10)
        self.assertAlmostEqual(call["vegaPerPp"], 0.3752403469169379, places=10)
        self.assertAlmostEqual(call["thetaPerDay"], -6.414027546438197 / 365, places=10)

    def test_put_call_parity_with_dividend_and_negative_rates(self):
        for rate in (-0.02, 0.0, 0.04):
            for days in (14, 30, 90, 365):
                call = black_scholes(357.07, 360, days, .358, "call", rate, .025)
                put = black_scholes(357.07, 360, days, .358, "put", rate, .025)
                expected = 357.07 * math.exp(-.025 * days / 365) - 360 * math.exp(-rate * days / 365)
                self.assertAlmostEqual(call["premium"] - put["premium"], expected, places=10)
                self.assertAlmostEqual(call["delta"] - put["delta"], math.exp(-.025 * days / 365), places=10)
                self.assertAlmostEqual(call["gamma"], put["gamma"], places=12)
                self.assertAlmostEqual(call["vegaPerPp"], put["vegaPerPp"], places=12)

    def test_monotonicity_and_finite_tail_prices(self):
        for right in ("call", "put"):
            low = black_scholes(100, 105, 30, .2, right)
            high = black_scholes(100, 105, 30, .5, right)
            self.assertGreater(high["premium"], low["premium"])
            self.assertGreater(low["vegaPerPp"], 0)
            rising = black_scholes(110, 105, 30, .2, right)
            if right == "call":
                self.assertGreater(rising["premium"], low["premium"])
            else:
                self.assertLess(rising["premium"], low["premium"])
            for spot, strike in ((1, 10000), (10000, 1)):
                self.assertGreaterEqual(black_scholes(spot, strike, 14, .01, right)["premium"], 0)

    def test_greeks_match_finite_differences(self):
        for right in ("call", "put"):
            base = black_scholes(103, 100, 60, .35, right, .04, .01)
            def price(spot=103, days=60, sigma=.35):
                return black_scholes(spot, 100, days, sigma, right, .04, .01)["premium"]
            step = .001
            self.assertAlmostEqual(base["delta"], (price(103 + step) - price(103 - step)) / (2 * step), places=7)
            self.assertAlmostEqual(base["gamma"], (price(103 + step) - 2 * price() + price(103 - step)) / step**2, places=6)
            vol_step = .0001
            self.assertAlmostEqual(base["vegaPerPp"], (price(sigma=.35 + vol_step) - price(sigma=.35 - vol_step)) / (2 * vol_step) / 100, places=7)
            self.assertAlmostEqual(base["thetaPerDay"], (price(days=60 - step) - price(days=60 + step)) / (2 * step), places=7)

    def test_expiry_payoffs_and_undefined_atm_greeks(self):
        for right, spot, payoff, delta in (("call", 110, 10, 1), ("call", 90, 0, 0),
                                            ("put", 110, 0, 0), ("put", 90, 10, -1)):
            value = black_scholes(spot, 100, 0, .35, right)
            self.assertEqual(value["premium"], payoff)
            self.assertEqual(value["delta"], delta)
            self.assertEqual(value["gamma"], 0)
            self.assertEqual(value["vegaPerPp"], 0)
            self.assertIsNone(value["thetaPerDay"])
        atm = black_scholes(100, 100, 0, .35)
        self.assertIsNone(atm["delta"])
        self.assertIsNone(atm["gamma"])

    def test_invalid_inputs_fail_closed(self):
        base = dict(spot=100, strike=100, days=30, sigma=.35, right="call", rate=.04, dividend_yield=0)
        for key in ("spot", "strike", "days", "sigma", "rate", "dividend_yield"):
            for bad in (float("nan"), float("inf"), -float("inf"), None, "0.35", True):
                with self.subTest(key=key, bad=bad), self.assertRaises(ValueError):
                    black_scholes(**dict(base, **{key: bad}))
        for key, bad in (("spot", 0), ("strike", -1), ("days", -1), ("sigma", 0),
                         ("sigma", 35), ("rate", 5), ("right", "buy")):
            with self.subTest(key=key, bad=bad), self.assertRaises(ValueError):
                black_scholes(**dict(base, **{key: bad}))


class ScenarioTests(unittest.TestCase):
    def test_zero_shocks_have_zero_pnl_and_interactions(self):
        for right in ("call", "put"):
            cell = scenario_cell(100, 105, 30, .35, right, 0, 0, 0)
            for key in ("pnl", "pnlPercent", "pnlPerContract", "priceOnlyPnl", "ivOnlyPnl", "timeOnlyPnl", "interactionPnl"):
                self.assertEqual(cell[key], 0)
            self.assertEqual(cell["daysRemaining"], 30)

    def test_percentage_points_and_percentage_return_are_distinct(self):
        cell = scenario_cell(100, 100, 30, .358, "call", 7, 10, 10)
        base = black_scholes(100, 100, 30, .358)["premium"]
        expected = black_scholes(110, 100, 23, .458)["premium"]
        self.assertAlmostEqual(cell["newSpot"], 110)
        self.assertAlmostEqual(cell["newIvPercent"], 45.8)
        self.assertAlmostEqual(cell["price"], expected)
        self.assertAlmostEqual(cell["pnlPercent"], (expected / base - 1) * 100)
        self.assertAlmostEqual(cell["pnlPerContract"], cell["pnl"] * 100)
        self.assertAlmostEqual(cell["premiumPerContract"], cell["price"] * 100)
        self.assertAlmostEqual(cell["pnl"], sum(cell[key] for key in ("priceOnlyPnl", "ivOnlyPnl", "timeOnlyPnl", "interactionPnl")))

    def test_nonpositive_changed_iv_is_invalid_not_clamped(self):
        for shift in (-20, -10):
            cell = scenario_cell(100, 100, 30, .10, "call", 7, 5, shift)
            self.assertEqual(cell["status"], "invalid_iv")
            self.assertIsNone(cell["price"])
            self.assertIsNone(cell["pnlPercent"])
            self.assertIsNone(cell["ivOnlyPnl"])
            self.assertLessEqual(cell["newIvPercent"], 0)
        with self.assertRaises(ValueError):
            scenario_cell(100, 100, 30, .35, "call", 31, 0, 0)
        with self.assertRaises(ValueError):
            scenario_cell(100, 100, 30, .35, "call", 7, -100, 0)

    def test_expiry_scenario_equals_intrinsic(self):
        cell = scenario_cell(100, 100, 14, .35, "call", 14, 10, 20)
        self.assertAlmostEqual(cell["price"], 10)
        self.assertEqual(cell["daysRemaining"], 0)
        only_time = scenario_cell(100, 100, 30, .35, "call", 7, 0, 0)
        self.assertAlmostEqual(only_time["pnl"], only_time["timeOnlyPnl"])
        self.assertAlmostEqual(only_time["interactionPnl"], 0)


class TechnicalTests(unittest.TestCase):
    def test_exact_warmup_and_seed_definitions(self):
        series = technical_indicators(bars(40))["series"]
        for point in series[:19]:
            self.assertIsNone(point["sma20"])
        self.assertEqual(series[19]["sma20"], 109.5)
        self.assertAlmostEqual(series[19]["bollingerUpper"], 109.5 + 2 * math.sqrt(33.25))
        for point in series[:14]:
            self.assertIsNone(point["rsi14"])
            self.assertIsNone(point["atr14"])
        self.assertEqual(series[14]["rsi14"], 100)
        self.assertAlmostEqual(series[14]["atr14"], 2)
        self.assertTrue(all(point["k"] is None for point in series[:8]))
        self.assertAlmostEqual(series[8]["k"], (100 + 90) / 3)
        self.assertAlmostEqual(series[8]["d"], (100 + (100 + 90) / 3) / 3)
        self.assertTrue(all(point["realizedVol20Percent"] is None for point in series[:20]))
        self.assertIsNotNone(series[20]["realizedVol20Percent"])
        self.assertTrue(all(point["macd"] is None for point in series[:25]))
        self.assertAlmostEqual(series[25]["macd"], 7)
        self.assertIsNone(series[32]["macdSignal"])
        self.assertAlmostEqual(series[33]["macdSignal"], 7)
        self.assertAlmostEqual(series[33]["macdHistogram"], 0)
        self.assertEqual(series[-1]["relativeVolume20"], 1)
        self.assertEqual(series[-1]["trend"], "bullish")

    def test_flat_market_conventions_and_zero_volume(self):
        history = bars(40, flat=True)
        for bar in history:
            bar["high"] = bar["low"] = bar["close"]
            bar["volume"] = 0
        latest = technical_indicators(history)["latest"]
        for key in ("rsi14", "k", "d", "j"):
            self.assertEqual(latest[key], 50)
        self.assertEqual(latest["realizedVol20Percent"], 0)
        self.assertEqual(latest["atr14"], 0)
        self.assertIsNone(latest["relativeVolume20"])
        self.assertEqual(latest["trend"], "neutral")

    def test_prefix_causality_for_all_output_fields(self):
        history = bars(90)
        for index, row in enumerate(history):
            close = 100 + 10 * math.sin(index / 4) + index * .1
            row.update(open=close, high=close + 1, low=close - 1, close=close)
        full = technical_indicators(history)["series"]
        for cutoff in (1, 8, 9, 14, 15, 19, 20, 21, 26, 34, 50, 89):
            self.assertEqual(technical_indicators(history[:cutoff])["series"], full[:cutoff])

    def test_bar_validation_no_sort_repair_or_fill(self):
        for history in ([], bars(2)[::-1], [bars(1)[0], bars(1)[0]]):
            with self.assertRaises(ValueError):
                technical_indicators(history)
        for key, bad in (("high", 90), ("close", float("nan")), ("volume", -1), ("date", "invalid")):
            history = bars(40)
            history[10][key] = bad
            with self.subTest(key=key), self.assertRaises(ValueError):
                technical_indicators(history)
        history = bars(40)
        history[-1]["volume"] = None
        self.assertIsNone(technical_indicators(history)["latest"]["relativeVolume20"])


class ExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.artifact = build_artifact(evidence())

    def test_reproducible_complete_grid_and_safe_serialization(self):
        output = self.artifact
        self.assertEqual(output, build_artifact(evidence()))
        self.assertEqual(output["axes"], AXES)
        configs = output["symbols"][0]["configurations"]
        self.assertEqual(len(configs), 24)
        self.assertEqual(len({item["id"] for item in configs}), 24)
        self.assertEqual(sum(len(scenario["cells"]) for config in configs for scenario in config["scenarios"]), 2160)
        serialized = json.dumps(output, allow_nan=False)
        self.assertNotIn("sourceContractId", serialized)
        self.assertLess(len(serialized.encode()), 1_000_000)

    def test_assumptions_not_promoted_to_observations(self):
        symbol = self.artifact["symbols"][0]
        self.assertEqual(symbol["ivAssumption"]["annualIv"], .358)
        self.assertEqual(symbol["ivAssumption"]["ivPercentilePercent"], .4)
        self.assertEqual(symbol["ivAssumption"]["classification"], "user_scenario_assumption")
        self.assertIsNone(symbol["ivAssumption"]["observedAt"])
        self.assertIsNone(symbol["market"]["dailyBarCloseObservedAt"])
        self.assertFalse(symbol["market"]["executionEligible"])
        self.assertFalse(self.artifact["methodology"]["predictionModelPromoted"])
        self.assertFalse(self.artifact["methodology"]["executionEnabled"])
        self.assertFalse(symbol["technical"]["predictionModelApplied"])

    def test_invalid_prefix_is_disclosed_and_only_valid_suffix_used(self):
        raw = evidence()
        raw["symbols"][0]["history"]["bars"][10]["close"] = 500
        output = build_artifact(raw)["symbols"][0]
        coverage = output["market"]["coverage"]
        self.assertEqual(coverage["validationExcludedPrefixSessions"], 11)
        self.assertEqual(coverage["sourceSessions"], 60)
        self.assertEqual(coverage["observedSessions"], 49)
        self.assertEqual(coverage["invalidDates"], ["2026-01-11"])
        self.assertEqual(output["technical"]["series"][0]["date"], "2026-01-12")
        self.assertIsNone(output["technical"]["series"][0]["return1dPercent"])
        raw["symbols"][0]["history"]["bars"][-1]["close"] = 500
        with self.assertRaises(ValueError):
            build_artifact(raw)

    def test_noncausal_missing_stale_iv_units_and_duplicate_inputs_rejected(self):
        for mutate in (
            lambda raw: raw.update(retrievedAt="2026-01-01T00:00:00Z"),
            lambda raw: raw.update(retrievedAt="2026-09-06"),
            lambda raw: raw["symbols"][0]["snapshot"].update(underlyingIvAnnual=None),
            lambda raw: raw["symbols"][0]["snapshot"].update(underlyingIvAnnual=35.8),
            lambda raw: raw["symbols"][0]["snapshot"].update(ivPercentile52w=31.9),
            lambda raw: raw["symbols"][0]["snapshot"].update(lastTradeTime=None),
            lambda raw: raw["symbols"].append(copy.deepcopy(raw["symbols"][0])),
            lambda raw: raw["symbols"][0].update(currency="EUR"),
        ):
            raw = evidence()
            mutate(raw)
            with self.assertRaises(ValueError):
                build_artifact(raw)

    def test_contract_identifiers_removed_and_no_execution_eligibility(self):
        raw = evidence()
        raw["options"] = [{"symbol": "TEST", "sourceContractId": 1234, "bid": 3, "ask": 3.2,
                           "ivAsOf": None, "bidAskAsOf": None}]
        option = build_artifact(raw)["symbols"][0]["optionEvidence"][0]
        self.assertNotIn("sourceContractId", option)
        self.assertFalse(option["executionEligible"])
        self.assertEqual(option["evidenceStatus"], "incomplete_independent_field_timestamps")


if __name__ == "__main__":
    unittest.main()

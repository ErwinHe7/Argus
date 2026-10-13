"""Overlay lab tests. Every input is a deterministic synthetic_fixture, never market evidence."""
from __future__ import annotations

import copy
import csv
import hashlib
import json
import math
import random
import sys
import tempfile
import unittest
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

import exchange_calendars as xcals

from intraday_quant.iv_lab import black_scholes
from intraday_quant.overlay_lab import MODEL_LABEL, public_projection, run_overlay, slice_metrics
from intraday_quant.overlay_lab.__main__ import main as overlay_main
from intraday_quant.strategy_lab import research

SYMBOL = "ZZSYN"
EXPIRY = date(2024, 2, 16)
STRIKES = range(80, 125, 5)


def schedule(start: str, end: str) -> list[tuple[date, datetime, datetime]]:
    calendar = xcals.get_calendar("XNYS", start=start, end=end)
    return [(stamp.date(), row["open"].to_pydatetime(), row["close"].to_pydatetime())
            for stamp, row in calendar.schedule.loc[start:end].iterrows()]


SHORT = schedule("2024-01-02", "2024-02-16")
LONG = schedule("2023-01-03", "2024-06-28")


def z(value: datetime) -> str:
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def linear(end_price: float, wiggle: float = 0.6) -> list[float]:
    """Synthetic path from exactly 100.00 to ``end_price`` with a deterministic wiggle."""
    n = len(SHORT)
    path = [100 + (end_price - 100) * i / (n - 1) + wiggle * math.sin(i * 1.3) * (0 < i < n - 1) for i in range(n)]
    return [round(value, 2) for value in path]


def walk(n: int, seed: int = 11) -> list[float]:
    rng = random.Random(seed)
    price, path = 100.0, []
    for _ in range(n):
        path.append(round(price, 2))
        price *= math.exp(0.0003 + 0.013 * rng.gauss(0, 1))
    return path


def bars(sessions, closes):
    rows, previous = [], closes[0]
    for (day, _open, close_at), close in zip(sessions, closes, strict=True):
        rows.append({"session_date": day.isoformat(), "available_at": z(close_at + timedelta(minutes=1)),
                     "open": f"{previous:.2f}", "high": f"{max(previous, close) + 0.5:.2f}",
                     "low": f"{min(previous, close) - 0.5:.2f}", "close": f"{close:.2f}", "volume": 1000})
        previous = close
    return rows


def source(sessions, closes, **extra):
    raw = {"schema_version": "leo-overlay-source.v1", "symbol": SYMBOL, "code_revision": "unit-test",
           "evidence": {"source": "synthetic overlay fixture", "dataset_sha256": "b" * 64, "calendar_source": "pending_official_verification",
                        "adjustment_verified": True, "coverage_verified": False, "availability_verified": True,
                        "classification": "synthetic_fixture", "license_scope": "test_only"},
           "bars": bars(sessions, closes), "corporate_actions": {"splits": []}, "dividend_policy": "included_verified",
           "dividends": [], "option_quotes": None, "iv_marks": None}
    raw.update(extra)
    return raw


def quote_rows(sessions, closes):
    rows = []
    for (day, _open, close_at), spot in zip(sessions, closes, strict=True):
        days = (EXPIRY - day).days
        if days <= 0:
            continue
        for strike in STRIKES:
            for right in ("call", "put"):
                value = black_scholes(spot, strike, days, 0.3, right, rate=0.03)
                rows.append({"session_date": day.isoformat(), "observed_at": z(close_at - timedelta(minutes=5)),
                             "available_at": z(close_at + timedelta(minutes=1)), "contract": f"SYN{right[0].upper()}{strike}",
                             "expiry": EXPIRY.isoformat(), "strike": str(strike), "right": right,
                             "bid": f"{max(0.01, value['premium'] * 0.97 - 0.01):.2f}", "ask": f"{value['premium'] * 1.03 + 0.02:.2f}",
                             "multiplier": "100", "delta": f"{value['delta']:.4f}", "source": "synthetic_quote_fixture"})
    return rows


def write_quotes(folder: Path, rows, name: str = "quotes.csv") -> dict[str, str]:
    path = folder / name
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    return {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def config(structure="covered_call", *, call=0.05, put=0.05, mode="EXECUTABLE_QUOTES", model=None, **extra):
    raw = {"schema_version": "leo-overlay-config.v1", "structure": structure, "shares": 200, "pricing_mode": mode,
           "call_rule": None if structure == "protective_put" else {"kind": "otm_pct", "value": call},
           "put_rule": None if structure == "covered_call" else {"kind": "otm_pct", "value": put},
           "target_dte": 45, "min_dte": 30, "max_dte": 60, "max_spread_fraction": 2.0, "model": model,
           "costs": {"commission_per_contract": "0", "share_slippage_bps": 0}}
    raw.update(extra)
    return raw


def model_settings(**extra):
    return {"iv_source": "realized_vol", "realized_vol_window": 20, "iv_premium_multiplier": 1.1, "rate": 0.03,
            "dividend_yield": 0.0, "strike_increment": "1", "half_spread_fraction": 0.02, "max_iv_mark_age_sessions": 2, **extra}


def model_config(structure="covered_call", **extra):
    return config(structure, mode="MODEL_PRICED", model=model_settings(**extra.pop("model", {})),
                  target_dte=30, min_dte=21, max_dte=45, **extra)


def nav(artifact, row=-1):
    base = artifact["cycles"][0]["shares"] * artifact["cycles"][0]["open_close"] if artifact["cycles"] else None
    return artifact["daily"][row]["overlay_nav_index"] * base


def keys(value):
    if isinstance(value, dict):
        for key, item in value.items():
            yield key
            yield from keys(item)
    elif isinstance(value, list):
        for item in value:
            yield from keys(item)


class OverlayLabTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.long_closes = walk(len(LONG))
        cls.long_source = source(LONG, cls.long_closes)
        cls.long_artifact = run_overlay(cls.long_source, model_config(), resamples=200)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="leo-overlay-tests-")
        self.root = Path(self.temporary.name)

    def tearDown(self):
        self.temporary.cleanup()

    def executable(self, closes, rows=None, **extra):
        quotes = write_quotes(self.root, quote_rows(SHORT, closes) if rows is None else rows)
        return source(SHORT, closes, option_quotes=quotes, **extra)

    # -- payoff identities ---------------------------------------------------
    def test_expiry_payoff_identities(self):
        for end_price in (112.0, 90.0):
            closes = linear(end_price)
            raw = self.executable(closes)
            spot = closes[-1]
            for structure in ("covered_call", "protective_put", "collar"):
                with self.subTest(structure=structure, end=end_price):
                    artifact = run_overlay(raw, config(structure), resamples=200)
                    cycle = artifact["cycles"][0]
                    legs = {leg["right"]: leg for leg in cycle["legs"]}
                    shares = cycle["shares"]
                    self.assertEqual(cycle["expiry"], EXPIRY.isoformat())
                    self.assertEqual(cycle["closed"], EXPIRY.isoformat())
                    if structure == "covered_call":
                        expected = shares * min(spot, legs["call"]["strike"]) + shares * legs["call"]["fill_price"]
                        self.assertEqual(legs["call"]["fill_side"], "bid")
                    elif structure == "protective_put":
                        expected = shares * max(spot, legs["put"]["strike"]) - shares * legs["put"]["fill_price"]
                        self.assertEqual(legs["put"]["fill_side"], "ask")
                    else:
                        clipped = min(max(spot, legs["put"]["strike"]), legs["call"]["strike"])
                        expected = shares * clipped + shares * (legs["call"]["fill_price"] - legs["put"]["fill_price"])
                    self.assertAlmostEqual(nav(artifact), expected, places=6)
                    up = end_price > 100
                    outcome = {"covered_call": "call_assigned" if up else "expired_worthless",
                               "protective_put": "expired_worthless" if up else "put_exercised",
                               "collar": "call_assigned" if up else "put_exercised"}[structure]
                    self.assertEqual(cycle["outcome"], outcome)
                    counts = artifact["metrics"]["counts"]
                    self.assertEqual(counts["assignments"], int(outcome == "call_assigned"))
                    self.assertEqual(counts["put_exercises"], int(outcome == "put_exercised"))
                    # Physical settlement plus repurchase leaves buy-and-hold's share exposure unchanged.
                    self.assertEqual(cycle["contracts"] * 100, shares)

    def test_same_strike_collar_nav_is_path_invariant(self):
        values = []
        for end_price in (118.0, 84.0, 100.0):
            closes = linear(end_price)
            artifact = run_overlay(self.executable(closes), config("collar", call=0, put=0), resamples=200)
            legs = {leg["right"]: leg for leg in artifact["cycles"][0]["legs"]}
            self.assertEqual(legs["call"]["strike"], legs["put"]["strike"])
            strike = legs["call"]["strike"]
            shares = artifact["cycles"][0]["shares"]
            self.assertAlmostEqual(nav(artifact), shares * strike + shares * (legs["call"]["fill_price"] - legs["put"]["fill_price"]), places=6)
            values.append(nav(artifact))
        self.assertAlmostEqual(values[0], values[1], places=6)
        self.assertAlmostEqual(values[0], values[2], places=6)

    def test_model_priced_same_strike_collar_obeys_put_call_parity(self):
        settings = {"half_spread_fraction": 0.0, "dividend_yield": 0.01, "rate": 0.04}
        artifact = run_overlay(self.long_source, model_config("collar", call=0, put=0, model=settings), resamples=200)
        self.assertGreater(len(artifact["cycles"]), 5)
        for cycle in artifact["cycles"]:
            legs = {leg["right"]: leg for leg in cycle["legs"]}
            strike, spot, dte = legs["call"]["strike"], cycle["open_close"], legs["call"]["dte"]
            self.assertEqual(strike, legs["put"]["strike"])
            time = dte / 365
            parity = spot * math.exp(-0.01 * time) - strike * math.exp(-0.04 * time)
            self.assertAlmostEqual(legs["call"]["fill_price"] - legs["put"]["fill_price"], parity, places=9)
            sigma = legs["call"]["provenance"]["sigma"]
            direct = black_scholes(spot, strike, dte, sigma, "call", 0.04, 0.01)["premium"]
            self.assertAlmostEqual(legs["call"]["fill_price"], direct, places=12)

    def test_delta_rules_pick_the_nearest_delta(self):
        closes = linear(112.0)
        rules = {"call_rule": {"kind": "delta", "value": 0.3}, "put_rule": {"kind": "delta", "value": 0.2}}
        artifact = run_overlay(self.executable(closes), config("collar", **rules), resamples=200)
        legs = {leg["right"]: leg for leg in artifact["cycles"][0]["legs"]}
        opening = [row for row in quote_rows(SHORT, closes) if row["session_date"] == SHORT[0][0].isoformat()]
        for right, target in (("call", 0.3), ("put", 0.2)):
            best = min((row for row in opening if row["right"] == right), key=lambda row: abs(abs(float(row["delta"])) - target))
            self.assertEqual(legs[right]["contract"], best["contract"])
        model = run_overlay(self.long_source, model_config(call_rule={"kind": "delta", "value": 0.25}), resamples=200)
        for cycle in model["cycles"]:
            leg = cycle["legs"][0]
            for neighbour in (leg["strike"] - 1, leg["strike"] + 1):
                delta = black_scholes(cycle["open_close"], neighbour, leg["dte"], leg["provenance"]["sigma"], "call", 0.03, 0.0)["delta"]
                self.assertLessEqual(abs(leg["delta_at_open"] - 0.25), abs(delta - 0.25) + 1e-12)

    # -- daily marks ---------------------------------------------------------
    def test_executable_daily_marks_take_short_legs_at_ask_and_long_legs_at_bid(self):
        closes = linear(112.0)
        rows = quote_rows(SHORT, closes)
        artifact = run_overlay(self.executable(closes, rows), config("collar"), resamples=200)
        cycle = artifact["cycles"][0]
        self.assertEqual(cycle["opened"], SHORT[0][0].isoformat())
        legs = {leg["right"]: leg for leg in cycle["legs"]}
        shares = cycle["shares"]
        quotes = {(row["session_date"], row["contract"]): row for row in rows}
        for index in (5, 12, 20):
            with self.subTest(index=index):
                day = SHORT[index][0].isoformat()
                self.assertEqual(artifact["daily"][index]["cycle_id"], cycle["cycle_id"])
                call, put = quotes[(day, legs["call"]["contract"])], quotes[(day, legs["put"]["contract"])]
                expected = (shares * closes[index] + shares * (legs["call"]["fill_price"] - legs["put"]["fill_price"])
                            + shares * (float(put["bid"]) - float(call["ask"])))
                self.assertAlmostEqual(artifact["daily"][index]["overlay_nav_index"] * shares * closes[0], expected, places=6)

    def test_model_priced_daily_marks_apply_the_half_spread_against_the_holder(self):
        sessions, closes = LONG[:120], self.long_closes[:120]
        marks = [{"session_date": day.isoformat(), "observed_at": z(close_at - timedelta(minutes=10)),
                  "available_at": z(close_at - timedelta(minutes=8)), "iv": 0.25, "source": "synthetic_iv_fixture"}
                 for day, _open, close_at in sessions]
        settings = {"iv_source": "iv_marks", "half_spread_fraction": 0.02}
        artifact = run_overlay(source(sessions, closes, iv_marks=marks), model_config("collar", model=settings), resamples=200)
        cycle = artifact["cycles"][0]
        self.assertEqual(cycle["opened"], sessions[0][0].isoformat())
        shares = cycle["shares"]
        for index in (3, 10):
            with self.subTest(index=index):
                day, spot = sessions[index][0], closes[index]
                self.assertEqual(artifact["daily"][index]["cycle_id"], cycle["cycle_id"])
                mark = 0.0
                for leg in cycle["legs"]:
                    days = (date.fromisoformat(leg["expiry"]) - day).days
                    value = black_scholes(spot, leg["strike"], days, 0.25, leg["right"], 0.03, 0.0)["premium"]
                    mark += -value * 1.02 if leg["side"] == "short" else value * 0.98
                premium = sum(leg["fill_price"] if leg["side"] == "short" else -leg["fill_price"] for leg in cycle["legs"])
                expected = shares * spot + shares * premium + shares * mark
                self.assertAlmostEqual(artifact["daily"][index]["overlay_nav_index"] * shares * closes[0], expected, places=6)

    # -- causality -----------------------------------------------------------
    def test_prefix_stability_no_look_ahead(self):
        cut = 200
        prefix = copy.deepcopy(self.long_source)
        prefix["bars"] = prefix["bars"][:cut]
        partial = run_overlay(prefix, model_config(), resamples=200)
        full = self.long_artifact
        rows = len(partial["daily"])
        self.assertEqual(partial["daily"], full["daily"][:rows])
        closed = [cycle for cycle in partial["cycles"] if cycle["outcome"] != "open_at_end"]
        self.assertGreater(len(closed), 3)
        self.assertEqual(closed, full["cycles"][:len(closed)])

        closes = linear(112.0)
        raw = self.executable(closes)
        whole = run_overlay(raw, config("collar"), resamples=200)
        truncated = copy.deepcopy(raw)
        truncated["bars"] = truncated["bars"][:20]
        head = run_overlay(truncated, config("collar"), resamples=200)
        self.assertEqual(head["daily"], whole["daily"][:20])
        self.assertGreater(head["coverage"]["option_quotes"]["outside_coverage_rows"], 0)

    def test_quotes_observed_after_close_or_available_after_next_open_are_rejected(self):
        closes = linear(112.0)
        first, second = SHORT[0], SHORT[1]
        baseline = run_overlay(self.executable(closes), config(), resamples=200)
        self.assertEqual(baseline["cycles"][0]["opened"], first[0].isoformat())
        for label, mutate in (("observed_after_close", lambda row: row.update(observed_at=z(first[2] + timedelta(minutes=1)),
                                                                              available_at=z(first[2] + timedelta(minutes=2)))),
                              ("available_after_next_open", lambda row: row.update(available_at=z(second[1] + timedelta(minutes=1)))),
                              ("observed_too_early", lambda row: row.update(observed_at=z(first[2] - timedelta(minutes=31))))):
            with self.subTest(label):
                rows = quote_rows(SHORT, closes)
                for row in rows:
                    if row["session_date"] == first[0].isoformat():
                        mutate(row)
                artifact = run_overlay(self.executable(closes, rows), config(), resamples=200)
                self.assertEqual(artifact["cycles"][0]["opened"], second[0].isoformat())
                self.assertEqual(artifact["metrics"]["counts"]["deferred_rolls"], baseline["metrics"]["counts"]["deferred_rolls"] + 1)
                self.assertGreater(artifact["coverage"]["option_quotes"]["rejected_non_causal_rows"], 0)
        rows = quote_rows(SHORT, closes)
        held_day = SHORT[10]
        for row in rows:
            if row["session_date"] == held_day[0].isoformat():
                row["observed_at"] = z(held_day[2] + timedelta(minutes=1))
        with self.assertRaisesRegex(ValueError, "missing executable quote"):
            run_overlay(self.executable(closes, rows), config(), resamples=200)

    def test_iv_marks_must_be_point_in_time_and_fresh(self):
        def marks(skip=(), late=()):
            result = []
            for index, (day, _open, close_at) in enumerate(LONG[:120]):
                if index in skip:
                    continue
                observed = close_at + timedelta(minutes=1) if index in late else close_at - timedelta(minutes=10)
                result.append({"session_date": day.isoformat(), "observed_at": z(observed),
                               "available_at": z(observed + timedelta(minutes=2)), "iv": 0.25 + 0.001 * (index % 7), "source": "synthetic_iv_fixture"})
            return result
        raw = source(LONG[:120], self.long_closes[:120], iv_marks=marks())
        settings = {"iv_source": "iv_marks", "max_iv_mark_age_sessions": 1}
        artifact = run_overlay(raw, model_config(model=settings), resamples=200)
        self.assertEqual(artifact["coverage"]["warmup_sessions"], 0)
        self.assertEqual(artifact["source"]["iv_sources"], ["synthetic_iv_fixture"])
        late = copy.deepcopy(raw)
        late["iv_marks"] = marks(late={40})
        accepted = run_overlay(late, model_config(model=settings), resamples=200)
        self.assertEqual(accepted["coverage"]["iv_marks"]["rejected_non_causal_rows"], 1)
        self.assertNotEqual(accepted["daily"][40], artifact["daily"][40])
        with self.assertRaisesRegex(ValueError, "stale or missing point-in-time IV mark"):
            run_overlay(late, model_config(model={**settings, "max_iv_mark_age_sessions": 0}), resamples=200)
        stale = copy.deepcopy(raw)
        stale["iv_marks"] = marks(skip={50, 51})
        with self.assertRaisesRegex(ValueError, "stale or missing point-in-time IV mark"):
            run_overlay(stale, model_config(model=settings), resamples=200)

    # -- fail closed ---------------------------------------------------------
    def test_fail_closed_inputs(self):
        closes = linear(112.0)
        good = self.executable(closes)
        run_overlay(good, config(), resamples=200)

        rows = [row for row in quote_rows(SHORT, closes) if not (row["session_date"] == SHORT[12][0].isoformat() and row["contract"] == "SYNC105")]
        with self.assertRaisesRegex(ValueError, "missing executable quote for held contract"):
            run_overlay(self.executable(closes, rows), config(), resamples=200)

        gap = copy.deepcopy(good)
        del gap["bars"][7]
        with self.assertRaisesRegex(ValueError, "coverage incomplete"):
            run_overlay(gap, config(), resamples=200)

        early = copy.deepcopy(good)
        early["bars"][3]["available_at"] = z(SHORT[3][2] - timedelta(hours=1))
        with self.assertRaisesRegex(ValueError, "before its session close"):
            run_overlay(early, config(), resamples=200)

        unadjusted = copy.deepcopy(good)
        unadjusted["evidence"]["adjustment_verified"] = False
        with self.assertRaisesRegex(ValueError, "unverified split adjustments"):
            run_overlay(unadjusted, config(), resamples=200)

        split = copy.deepcopy(good)
        split["corporate_actions"]["splits"] = [{"ex_date": "2024-01-22", "ratio": "2:1"}]
        with self.assertRaisesRegex(ValueError, "split"):
            run_overlay(split, config(), resamples=200)

        rows = quote_rows(SHORT, closes)
        rows[5]["multiplier"] = "50"
        with self.assertRaisesRegex(ValueError, "non-100 contract multiplier"):
            run_overlay(self.executable(closes, rows), config(), resamples=200)

        mismatch = copy.deepcopy(good)
        mismatch["option_quotes"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "sha256 mismatch"):
            run_overlay(mismatch, config(), resamples=200)

        rows = quote_rows(SHORT, closes)
        rows[3]["bid"], rows[3]["ask"] = "2.00", "1.00"
        with self.assertRaisesRegex(ValueError, "crossed bid/ask"):
            run_overlay(self.executable(closes, rows), config(), resamples=200)

        with self.assertRaisesRegex(ValueError, "multiple of 100"):
            run_overlay(good, config(shares=150), resamples=200)
        with self.assertRaisesRegex(ValueError, "requires a hash-bound option quote file"):
            run_overlay(source(SHORT, closes), config(), resamples=200)
        with self.assertRaisesRegex(ValueError, "excluded_price_only"):
            run_overlay({**good, "dividend_policy": "excluded_price_only",
                         "dividends": [{"ex_date": "2024-01-22", "amount": "0.5", "available_at": "2024-01-02T22:00:00Z"}]}, config(), resamples=200)
        with self.assertRaisesRegex(ValueError, "not known before its ex-date open"):
            run_overlay({**good, "dividends": [{"ex_date": "2024-01-22", "amount": "0.5", "available_at": "2024-01-22T15:00:00Z"}]}, config(), resamples=200)

        model = copy.deepcopy(self.long_source)
        model["bars"][100]["available_at"] = z(LONG[100][2] - timedelta(minutes=5))
        with self.assertRaisesRegex(ValueError, "before its session close"):
            run_overlay(model, model_config(), resamples=200)

    def test_no_eligible_quotes_defers_every_roll(self):
        closes = linear(112.0)
        artifact = run_overlay(self.executable(closes), config(max_spread_fraction=0.0001), resamples=200)
        counts = artifact["metrics"]["counts"]
        self.assertEqual(counts["cycles"], 0)
        self.assertEqual(counts["deferred_rolls"], len(SHORT))
        self.assertTrue(all(row["active_return"] == 0 for row in artifact["daily"]))
        self.assertIsNone(artifact["metrics"]["overlay"]["premium_yield_annualized"])

    def test_dividends_are_credited_equally_and_itm_short_calls_flagged(self):
        closes = linear(112.0)
        ex_index = len(SHORT) - 5
        ex_day, ex_open = SHORT[ex_index][0], SHORT[ex_index][1]
        dividend = {"ex_date": ex_day.isoformat(), "amount": "0.75", "available_at": z(ex_open - timedelta(days=10))}
        plain = run_overlay(self.executable(closes), config(), resamples=200)
        paid = run_overlay(self.executable(closes, dividends=[dividend]), config(), resamples=200)
        shares = plain["cycles"][0]["shares"]
        base = shares * closes[0]
        overlay_gain = (paid["daily"][-1]["overlay_nav_index"] - plain["daily"][-1]["overlay_nav_index"]) * base
        baseline_gain = (paid["daily"][-1]["baseline_nav_index"] - plain["daily"][-1]["baseline_nav_index"]) * base
        self.assertAlmostEqual(overlay_gain, shares * 0.75, places=6)
        self.assertAlmostEqual(baseline_gain, shares * 0.75, places=6)
        self.assertGreater(closes[ex_index - 1], paid["cycles"][0]["legs"][0]["strike"])
        self.assertEqual(paid["metrics"]["counts"]["ex_dividend_itm_short_call_events"], 1)
        self.assertEqual(plain["metrics"]["counts"]["ex_dividend_itm_short_call_events"], 0)

    # -- labelling and serialization -----------------------------------------
    def test_model_priced_artifacts_are_labelled_not_executable(self):
        artifact = self.long_artifact
        self.assertEqual(artifact["evidence_status"], MODEL_LABEL)
        self.assertTrue(artifact["caveats"][1].startswith(MODEL_LABEL))
        self.assertTrue(all(leg["fill_side"] == "model" and leg["provenance"]["label"] == MODEL_LABEL
                            for cycle in artifact["cycles"] for leg in cycle["legs"]))
        self.assertEqual(public_projection(artifact)["evidenceStatus"], MODEL_LABEL)
        self.assertEqual(artifact["coverage"]["warmup_sessions"], 20)
        self.assertTrue(artifact["source"]["iv_sources"][0].startswith("trailing_realized_vol_20"))
        closes = linear(112.0)
        executable = run_overlay(self.executable(closes), config(), resamples=200)
        self.assertEqual(executable["evidence_status"], "SYNTHETIC_FIXTURE_NOT_MARKET_EVIDENCE")
        tampered = copy.deepcopy(artifact)
        tampered["evidence_status"] = "EXECUTABLE_QUOTES_OBSERVED"
        with self.assertRaisesRegex(ValueError, MODEL_LABEL):
            public_projection(tampered)

    def test_artifact_json_contract_and_cli_write_once(self):
        artifact = self.long_artifact
        json.dumps(artifact, allow_nan=False)
        required = {"schema_version", "engine_version", "symbol", "structure", "pricing_mode", "evidence_status", "fill_timing",
                    "source", "observation_cutoff", "availability_cutoff", "freshness", "coverage", "input_sha256",
                    "config_sha256", "code_identity", "config", "metrics", "cycles", "daily", "assumptions", "caveats",
                    "execution_authorized", "options_execution_enabled", "promotion_eligible"}
        self.assertLessEqual(required, set(artifact))
        self.assertEqual(artifact["schema_version"], "leo-overlay-lab.v1")
        self.assertEqual(artifact["freshness"], "historical_backtest_not_live")
        self.assertEqual(artifact["fill_timing"], "session_close_snapshot")
        for flag in ("execution_authorized", "options_execution_enabled", "promotion_eligible"):
            self.assertIs(artifact[flag], False)
        self.assertEqual(artifact["input_sha256"], research.digest(self.long_source))
        self.assertEqual(artifact["observation_cutoff"], LONG[-1][2].isoformat())
        self.assertTrue(artifact["source"]["evidence"]["coverage_verified"])
        self.assertIsNotNone(artifact["metrics"]["overlay"]["annualized_return"])
        self.assertEqual(artifact["coverage"]["sessions"], len(LONG) - 20)
        for key in ("downside_capture", "upside_capture", "premium_yield_annualized"):
            self.assertIsInstance(artifact["metrics"]["overlay"][key], float)
        self.assertEqual(artifact["daily"][0]["baseline_return"], 0.0)

        source_path, config_path, output = self.root / "source.json", self.root / "config.json", self.root / "out" / "overlay.json"
        closes = linear(112.0)
        raw = self.executable(closes)
        raw["option_quotes"]["path"] = "quotes.csv"
        source_path.write_text(json.dumps(raw), encoding="utf-8")
        config_path.write_text(json.dumps(config("collar")), encoding="utf-8")
        argv = ["overlay_lab", "--source", str(source_path), "--config", str(config_path), "--output", str(output)]
        with patch.object(sys, "argv", argv):
            overlay_main()
        written = json.loads(output.read_text(encoding="utf-8"))
        self.assertEqual(written["structure"], "collar")
        self.assertIs(written["execution_authorized"], False)
        with patch.object(sys, "argv", argv), self.assertRaises(FileExistsError):
            overlay_main()

    def test_public_projection_strips_raw_fields(self):
        closes = linear(112.0)
        for artifact in (self.long_artifact, run_overlay(self.executable(closes), config("collar"), resamples=200)):
            public = public_projection(artifact)
            self.assertEqual(set(public), {
                "symbolLabel", "structure", "pricingMode", "evidenceStatus", "engineVersion", "inputSha256", "configSha256",
                "observationCutoff", "availabilityCutoff", "freshness", "coverage", "source", "metrics", "cycles",
                "assumptions", "caveats", "executionAuthorized", "optionsExecutionEnabled", "promotionEligible"})
            self.assertEqual(set(public["metrics"]), {"overlay", "buyAndHold", "difference", "counts", "activeReturnBootstrap", "activeReturnSignFlipP"})
            self.assertEqual(set(public["coverage"]), {"sessions", "start", "end", "calendarSource", "cycles", "deferredRolls"})
            self.assertEqual(set(public["cycles"][0]["legs"][0]), {"right", "side", "strikeMoneynessPct", "dte", "fillSide"})
            forbidden = {"bid", "ask", "close", "shares", "contracts", "contract", "strike", "fill_price", "fillPrice",
                         "open_close", "openClose", "settlement_close", "settlementClose", "daily", "symbol", "nav"}
            names = set(keys(public))
            self.assertFalse(names & forbidden)
            self.assertFalse({name for name in names if name.lower().endswith(("bid", "ask", "close", "shares", "price"))})
            dumped = json.dumps(public, allow_nan=False)
            self.assertNotIn(SYMBOL, dumped)
            self.assertNotIn("SYNC", dumped)
            self.assertNotIn("model:", dumped)
            self.assertEqual(public["symbolLabel"], "Redacted holding")
            self.assertEqual(public_projection(artifact, public_symbol=True)["symbolLabel"], SYMBOL)
            for flag in ("executionAuthorized", "optionsExecutionEnabled", "promotionEligible"):
                self.assertIs(public[flag], False)
            percents = [value for name, value in self._items(public) if name.endswith("Pct")]
            self.assertTrue(percents)
            self.assertTrue(all(value is None or value == round(value, 2) for value in percents))
            self.assertAlmostEqual(public["metrics"]["overlay"]["totalReturnPct"],
                                   round(artifact["metrics"]["overlay"]["total_return"] * 100, 2))

    def _items(self, value):
        if isinstance(value, dict):
            for key, item in value.items():
                yield key, item
                yield from self._items(item)
        elif isinstance(value, list):
            for item in value:
                yield from self._items(item)

    # -- inference -----------------------------------------------------------
    def test_bootstrap_and_sign_flip_are_deterministic_under_seed(self):
        again = run_overlay(self.long_source, model_config(), resamples=200)
        first = self.long_artifact["metrics"]
        self.assertEqual(again["metrics"], first)
        bootstrap, sign_flip = first["active_return_bootstrap"], first["active_return_sign_flip"]
        self.assertEqual(bootstrap["block_length"], 21)
        self.assertEqual(bootstrap["seed"], 7)
        self.assertLessEqual(bootstrap["lower_95"], bootstrap["upper_95"])
        self.assertAlmostEqual(bootstrap["point_estimate"], math.prod(1 + row["active_return"] for row in self.long_artifact["daily"]) - 1)
        self.assertEqual(sign_flip["status"], "reported_diagnostic_not_promotion_evidence")
        self.assertEqual(sign_flip["cluster_definition"], "roll_cycle_start")
        daily, cycles = self.long_artifact["daily"], self.long_artifact["cycles"]
        clusters = {row["cluster_date"] for row in daily}
        self.assertEqual(sign_flip["session_count"], len(clusters))
        # Every session after a cycle opens, through its expiry close, clusters on that cycle's opening date.
        for cycle in cycles:
            end = cycle["closed"] or daily[-1]["session_date"]
            for row in daily:
                if cycle["opened"] < row["session_date"] <= end:
                    self.assertEqual(row["cluster_date"], cycle["opened"])
        uncovered = {row["session_date"] for row in daily if row["cycle_id"] is None}
        self.assertLessEqual(clusters, {cycle["opened"] for cycle in cycles} | uncovered)
        self.assertLess(len(clusters), len(daily) // 10)
        self.assertTrue(0 < sign_flip["two_sided_plus_one_p_value"] <= 1)
        other = run_overlay(self.long_source, model_config(), seed=8, resamples=200)["metrics"]
        self.assertNotEqual(other["active_return_bootstrap"]["lower_95"], bootstrap["lower_95"])
        self.assertEqual(other["overlay"], first["overlay"])

    def test_slice_metrics_partition_windows(self):
        daily = self.long_artifact["daily"]
        split = daily[150]["session_date"]
        dev = slice_metrics(daily, daily[0]["session_date"], daily[149]["session_date"], resamples=200)
        holdout = slice_metrics(daily, split, daily[-1]["session_date"], resamples=200)
        full = self.long_artifact["metrics"]
        for side in ("overlay", "buy_and_hold"):
            self.assertAlmostEqual((1 + dev[side]["total_return"]) * (1 + holdout[side]["total_return"]),
                                   1 + full[side]["total_return"], places=12)
        self.assertEqual(dev["sessions"] + holdout["sessions"], len(daily))
        self.assertIsNone(dev["overlay"]["annualized_return"])
        with self.assertRaisesRegex(ValueError, "empty metric window"):
            slice_metrics(daily, "1990-01-01", "1990-12-31")


if __name__ == "__main__":
    unittest.main()

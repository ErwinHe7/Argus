"""Foundry tests. Inputs are deterministic fixtures; stubs stand in for the Rust engines in orchestration tests only.

Regenerate the TypeScript drift fixture with:
python -c "from intraday_quant.foundry.agents import write_synthetic_fixture as w; w('../features/research-desk/foundry/fixtures/synthetic-publication.json')"
"""
from __future__ import annotations

import contextlib
import copy
import csv
import io
import json
import math
import random
import re
import shutil
import sys
import tempfile
import unittest
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

import exchange_calendars as xcals
import pandas as pd

from intraday_quant.backtest.validation import benjamini_hochberg
from intraday_quant.foundry import agents, ledger, templates
from intraday_quant.foundry.__main__ import main as foundry_main
from intraday_quant.overlay_lab import engine as overlay_engine
from intraday_quant.strategy_lab import research
from intraday_quant.strategy_lab.continuous import IntegrityError, _json_bytes, _sha

PLATFORM = Path(__file__).resolve().parents[2]
DATA = PLATFORM / "features/research-desk/data/foundry.json"
FIXTURE = PLATFORM / "features/research-desk/foundry/fixtures/synthetic-publication.json"
SYMBOL = "ZZTEST"
IDEA = "PRIVATE OWNER IDEA: buy oversold dips in a held name"
DEV_END, HOLDOUT_START, HOLDOUT_END = date(2023, 9, 29), date(2023, 10, 2), date(2024, 3, 28)
REPORT_KEYS = {"schema_version", "run_id", "artifact_sha256", "strategy", "symbol", "evidence_status", "source_evidence",
               "observation_cutoff", "research_variant", "research_parameters", "availability_cutoff", "code_revision",
               "cost_assumptions", "execution_authorized", "promotion_eligible", "metrics", "benchmarks", "uncertainty",
               "holdout", "fill_model", "quote_window_experiment_available", "limitations"}


def schedule(start: str, end: str) -> list[tuple[date, datetime, datetime]]:
    calendar = xcals.get_calendar("XNYS", start=start, end=end)
    return [(stamp.date(), row["open"].to_pydatetime(), row["close"].to_pydatetime())
            for stamp, row in calendar.schedule.loc[start:end].iterrows()]


LONG = schedule("2022-01-03", "2024-06-28")


def z(value: datetime) -> str:
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def walk(n: int, *, drift: float = 0.002, vol: float = 0.006, seed: int = 5) -> list[float]:
    rng = random.Random(seed)
    price, path = 100.0, []
    for _ in range(n):
        path.append(round(price, 2))
        price *= math.exp(drift + vol * rng.gauss(0, 1))
    return path


CLOSES = walk(len(LONG))


def bars(sessions, closes):
    rows, previous = [], closes[0]
    for (day, _open, close_at), close in zip(sessions, closes, strict=True):
        rows.append({"session_date": day.isoformat(), "available_at": z(close_at + timedelta(minutes=1)),
                     "open": f"{previous:.2f}", "high": f"{max(previous, close) + 0.5:.2f}",
                     "low": f"{min(previous, close) - 0.5:.2f}", "close": f"{close:.2f}", "volume": 1000})
        previous = close
    return rows


def evidence(classification: str = "observed") -> dict:
    return {"source": "foundry unit fixture", "dataset_sha256": "a" * 64, "calendar_source": "pending_official_verification",
            "adjustment_verified": True, "coverage_verified": False, "availability_verified": True,
            "classification": classification, "license_scope": "unit_test_only"}


def window(end: date, closes=CLOSES):
    pairs = [(session, close) for session, close in zip(LONG, closes, strict=True) if session[0] <= end]
    return [session for session, _ in pairs], [close for _, close in pairs]


def strategy_source(*, end: date = HOLDOUT_END, closes=CLOSES, classification: str = "observed", strategy: str = "MR-v1") -> dict:
    sessions, values = window(end, closes)
    return {"schema_version": "leo-strategy-source.v1", "symbol": SYMBOL, "strategy": strategy, "code_revision": "unit-test",
            "evidence": evidence(classification), "bars": bars(sessions, values)}


def overlay_source(classification: str = "observed") -> dict:
    sessions, values = window(date(2024, 6, 28))
    selected = [(session, close) for session, close in zip(sessions, values, strict=True) if session[0] >= date(2023, 1, 3)]
    return {"schema_version": "leo-overlay-source.v1", "symbol": SYMBOL, "code_revision": "unit-test", "evidence": evidence(classification),
            "bars": bars([s for s, _ in selected], [c for _, c in selected]), "corporate_actions": {"splits": []},
            "dividend_policy": "excluded_price_only", "dividends": [], "option_quotes": None, "iv_marks": None}


def grid_source() -> dict:
    sessions, values = window(HOLDOUT_END)
    verified, calendar_source = research.verified_xnys_bars([research.RawBar.model_validate(bar) for bar in bars(sessions, values)])
    return {"schema_version": "leo-grid-request.v1", "symbol": SYMBOL, "configured_at": "2021-12-31T00:00:00Z",
            "as_of": z(sessions[-1][2] + timedelta(hours=1)), "lower": "80", "upper": "400", "intervals": 4, "spacing": "geometric",
            "tick_size": "0.01", "starting_capital": "10000", "commission_per_order": "1", "slippage_bps": 10,
            "portfolio_loss_limit_bps": 2000,
            "source_evidence": {"source": "foundry unit fixture", "dataset_sha256": "c" * 64, "calendar_source": calendar_source,
                                "adjustment": "split_adjusted", "coverage": "user_asserted_complete", "availability": "point_in_time",
                                "classification": "observed", "license_scope": "unit_test_only"},
            "bars": verified}


class EngineStub:
    """Stand-in for the Rust replay: buy-and-hold returns, independent of parameters. Never market evidence."""

    def __init__(self, fail=None):
        self.calls: list[dict] = []
        self.fail = fail

    def __call__(self, _engine, request):
        parameters = request.get("research_parameters")
        self.calls.append({"parameters": copy.deepcopy(parameters), "last": date.fromisoformat(request["bars"][-1]["session_date"])})
        if self.fail is not None and self.fail(parameters):
            raise ValueError("Rust replay rejected input: stub failure")
        closes = [float(bar["close"]) for bar in request["bars"]]
        equity = [{"session_date": bar["session_date"], "net_return": 0.0 if index == 0 else closes[index] / closes[index - 1] - 1}
                  for index, bar in enumerate(request["bars"])]
        return {"schema_version": "leo-strategy-lab.v1", "run_id": f"{len(self.calls):064x}", "strategy": request["strategy"],
                "symbol": request["symbol"], "input_manifest": request, "fill_model": "UNIT_TEST_STUB",
                "equity": equity, "trades": [], "open_position": None, "metrics": {"evaluation_sessions": len(equity) - 220},
                "caveats": ["Unit-test stub; not market evidence."], "execution_authorized": False, "promotion_eligible": False}


class ParamStub(EngineStub):
    """Stand-in Rust replay whose daily returns depend on the swept ``mr_z_abs``. Never market evidence."""

    def __init__(self, returns):
        super().__init__()
        self.returns = returns

    def __call__(self, engine, request):
        result = super().__call__(engine, request)
        point = request.get("research_parameters") or templates.TEMPLATES["MR-v1"].baseline
        for index, row in enumerate(result["equity"]):
            row["net_return"] = 0.0 if index == 0 else self.returns[point["mr_z_abs"]](index, date.fromisoformat(row["session_date"]))
        return result


# Daily-return shapes (index = session position). Bootstrap blocks see autocorrelation; the sign flip does not.
STRONG = lambda index, day: 0.004 + 0.002 * math.sin(index)  # noqa: E731 - BH rejected, lower bound > 0
CHOPPY = lambda index, day: 0.0008 + (0.01 if index % 2 else -0.01)  # noqa: E731 - lower bound > 0, not BH rejected
TRENDING = lambda index, day: 0.0025 + (0.012 if (index // 10) % 2 else -0.012)  # noqa: E731 - BH rejected, lower bound <= 0
NEGATIVE = lambda index, day: -0.002 + 0.001 * math.sin(index)  # noqa: E731
THREE_POINTS = {"mr_z_abs": [1.8, 2.0, 2.2], "mr_rsi_max": [30], "stop_multiple": [2.0]}  # index 1 is the baseline


def grid_stub(_engine, request):
    closes = [float(bar["close"]) for bar in request["bars"]]
    return {"schema_version": "leo-grid-result.v1", "strategy": "GRID-R1", "execution_authorized": False,
            "paper_execution_available": False, "promotion_eligible": False,
            "equity": [{"session_date": bar["session_date"], "total_return": close / closes[0] - 1}
                       for bar, close in zip(request["bars"], closes, strict=True)]}


def overlay_stub(source, _config, *, base_dir=None, seed=7, resamples=2000):
    rows = source["bars"]
    return {"daily": [{"session_date": bar["session_date"], "active_return": 0.0008 + 0.0004 * math.sin(index),
                       "cluster_date": rows[index - index % 21]["session_date"]} for index, bar in enumerate(rows)]}


def model_settings() -> dict:
    return {"iv_source": "realized_vol", "realized_vol_window": 20, "iv_premium_multiplier": 1.1, "rate": 0.03,
            "dividend_yield": 0.0, "strike_increment": "1", "half_spread_fraction": 0.02, "max_iv_mark_age_sessions": 2}


def keys(value):
    if isinstance(value, dict):
        for key, item in value.items():
            yield key
            yield from keys(item)
    elif isinstance(value, list):
        for item in value:
            yield from keys(item)


class FoundryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="leo-foundry-tests-")
        self.root = Path(self.temporary.name).resolve()
        self.state = self.root / "state"
        self.clock = agents.StepClock(datetime(2026, 1, 5, 12, tzinfo=timezone.utc))
        self.engine = self.root / "strategy-lab"
        self.engine.write_bytes(b"\x7fELF unit-test bytes; never launched")

    def tearDown(self):
        self.temporary.cleanup()

    # -- helpers ---------------------------------------------------------------
    def write(self, name: str, value) -> Path:
        path = self.root / name
        path.write_bytes(_json_bytes(value))
        return path

    def spec(self, source: Path, *, template: str = "MR-v1", spec_id: str = "mr-test", **changes) -> Path:
        value = {"schema_version": "leo-foundry-spec.v1", "spec_id": spec_id, "template": template, "symbol": SYMBOL, "idea": IDEA,
                 "input": {"path": source.name, "sha256": _sha(source.read_bytes())}, "engine": self.engine.name,
                 "evaluation": {"development_end": DEV_END.isoformat(), "holdout_start": HOLDOUT_START.isoformat(),
                                "holdout_end": HOLDOUT_END.isoformat(), "minimum_dev_sessions": 100, "minimum_holdout_sessions": 20,
                                "maximum_forward_drawdown": 0.2},
                 "inference": {"seed": 7, "resamples": 200},
                 "sweep": {"mr_z_abs": [2.0, 2.2], "mr_rsi_max": [30], "stop_multiple": [2.0]}}
        value.update(changes)
        return self.write(f"{spec_id}.json", {key: item for key, item in value.items() if item is not None})

    def overlay_spec(self, source: Path, *, spec_id: str, pricing_mode: str = "EXECUTABLE_QUOTES") -> Path:
        base = {"shares": 200, "pricing_mode": pricing_mode, "min_dte": 20, "max_dte": 50, "max_spread_fraction": 0.5,
                "model": model_settings() if pricing_mode == "MODEL_PRICED" else None,
                "costs": {"commission_per_contract": "0.65", "share_slippage_bps": 2}}
        return self.spec(source, template="OVERLAY-v1", spec_id=spec_id, engine=None, overlay=base,
                         evaluation={"development_end": "2023-12-29", "holdout_start": "2024-01-02", "holdout_end": "2024-06-28",
                                     "minimum_dev_sessions": 100, "minimum_holdout_sessions": 40, "maximum_forward_drawdown": 0.2},
                         sweep={"structure": "covered_call", "call_otm_pct": [0.03, 0.05], "target_dte": [30]})

    def draft(self, path: Path) -> dict:
        return agents.draft(path, self.state, now=self.clock)

    def synthetic_overlay_draft(self, source_path: Path, spec_id: str) -> dict:
        value = {"schema_version": templates.SPEC_VERSION, "spec_id": spec_id, "template": "OVERLAY-v1", "symbol": "ZZSYN", "idea": IDEA,
                 "input": {"path": source_path.name, "sha256": _sha(source_path.read_bytes())},
                 "evaluation": {"development_end": "2024-03-28", "holdout_start": "2024-04-01", "holdout_end": "2024-06-28",
                                "minimum_dev_sessions": 60, "minimum_holdout_sessions": 40, "maximum_forward_drawdown": 0.2},
                 "inference": {"seed": 7, "resamples": 200},
                 "sweep": {"structure": "covered_call", "call_otm_pct": [0.05], "target_dte": [30]}, "overlay": agents._synthetic_overlay_base()}
        path = source_path.parent / f"{spec_id}.json"
        path.write_bytes(_json_bytes(value))
        return self.draft(path)

    def advance(self, **options) -> list[dict]:
        return agents.advance(self.state, now=self.clock, **options)

    def fold(self) -> dict:
        return ledger.fold_state(self.state)

    def kinds(self) -> list[str]:
        return [event["kind"] for event in self.fold()["events"]]

    def run_mr(self, stub: EngineStub, *, classification: str = "observed", **spec_changes) -> dict:
        source = self.write("mr-source.json", strategy_source(classification=classification))
        with patch("intraday_quant.strategy_lab.research.run_engine", stub):
            self.assertEqual(self.draft(self.spec(source, **spec_changes))["kind"], "SPEC_FROZEN")
            self.advance(until_blocked=True)
        return self.fold()["specs"]["mr-test"]

    # -- Prototype Builder -----------------------------------------------------
    def test_schema_offers_only_enumerated_sweep_values(self):
        schema = templates.spec_schema()
        definitions = schema["$defs"]
        self.assertEqual(definitions["MrSweep"]["properties"]["mr_z_abs"]["items"]["enum"], [1.8, 2.0, 2.2])
        self.assertEqual(definitions["MomSweep"]["properties"]["momentum_lookback"]["items"]["enum"], [50, 55, 60])
        self.assertEqual(definitions["GridSweep"]["properties"]["intervals"]["items"]["enum"], [4, 6, 8, 10])
        call = definitions["OverlaySweep"]["properties"]["call_otm_pct"]["anyOf"][0]["items"]["enum"]
        self.assertEqual(call, [0.02, 0.03, 0.05, 0.08, 0.1])
        self.assertEqual(definitions["Inference"]["properties"]["resamples"]["enum"], [200, 500, 1000, 2000])
        self.assertEqual(definitions["OverlaySpec"]["additionalProperties"], False)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            foundry_main(["schema"])
        self.assertEqual(json.loads(output.getvalue()), json.loads(json.dumps(schema)))
        sizes = {"MR-v1": 27, "MOM-v1": 9, "GRID-R1": 4}
        for template, size in sizes.items():
            raw = json.loads(self.spec(self.write("x.json", {}), template=template, spec_id="size", sweep=None).read_text())
            self.assertEqual(len(templates.grid_points(templates.SPEC.validate_python(raw))), size)
        collar = json.loads(self.overlay_spec(self.write("y.json", {}), spec_id="collar").read_text())
        collar["sweep"] = {"structure": "collar", "call_otm_pct": [0.02, 0.03, 0.05, 0.08, 0.1], "put_otm_pct": [0.03, 0.05, 0.08, 0.1]}
        self.assertEqual(len(templates.grid_points(templates.SPEC.validate_python(collar))), 60)

    def test_spec_rejections_are_recorded_without_the_idea(self):
        source = self.write("mr-source.json", strategy_source())
        good = json.loads(self.spec(source).read_text())
        mutations = {
            "value_outside_enum": lambda raw: raw["sweep"].update(mr_z_abs=[1.9]),
            "undeclared_field": lambda raw: raw.update(prompt="free text"),
            "baseline_not_swept": lambda raw: raw["sweep"].update(mr_z_abs=[1.8, 2.2]),
            "holdout_overlaps_development": lambda raw: raw["evaluation"].update(holdout_start=DEV_END.isoformat()),
            "input_hash_mismatch": lambda raw: raw["input"].update(sha256="0" * 64),
            "symbol_mismatch": lambda raw: raw.update(symbol="OTHER"),
            "template_mismatch": lambda raw: raw.update(template="MOM-v1", sweep={"momentum_lookback": [55], "stop_multiple": [3.0]}),
            "holdout_beyond_input": lambda raw: raw["evaluation"].update(holdout_end="2024-06-28"),
            "live_stage_requested": lambda raw: raw.update(stage="LIVE_SMALL"),
            "overlay_point_invalid": lambda raw: raw.update(
                template="OVERLAY-v1", engine=None, sweep={"structure": "covered_call", "call_otm_pct": [0.05], "target_dte": [21]},
                overlay={"shares": 200, "pricing_mode": "EXECUTABLE_QUOTES", "min_dte": 25, "max_dte": 50, "max_spread_fraction": 0.5,
                         "costs": {"commission_per_contract": "0", "share_slippage_bps": 0}}),
        }
        for label, mutate in mutations.items():
            with self.subTest(label):
                raw = copy.deepcopy(good)
                mutate(raw)
                event = self.draft(self.write("bad.json", {key: value for key, value in raw.items() if value is not None}))
                self.assertEqual((event["kind"], event["status"], event["role"]), ("SPEC_REJECTED", "BLOCKED", "prototype_builder"))
                self.assertEqual((event["from_stage"], event["to_stage"]), (None, None))
                receipt = ledger.read_receipt(self.state, event["receipt"])
                self.assertNotIn("PRIVATE", json.dumps(event) + json.dumps(receipt))
        self.assertEqual(self.fold()["specs"], {})
        frozen = self.draft(self.write("good.json", good))
        self.assertEqual((frozen["kind"], frozen["to_stage"], frozen["status"]), ("SPEC_FROZEN", "PROBE", "ACTIVE"))
        receipt = ledger.read_receipt(self.state, frozen["receipt"])
        self.assertEqual(receipt["llm_calls"], 0)
        self.assertFalse(Path(receipt["spec"]["input"]["path"]).is_absolute())
        count = len(self.fold()["events"])
        with self.assertRaisesRegex(ValueError, "already frozen"):
            self.draft(self.write("good.json", good))
        state = self.fold()
        self.assertEqual(len(state["events"]), count)
        self.assertEqual(len(state["rejected_drafts"]), len(mutations))

    # -- Sweeper ---------------------------------------------------------------
    def test_sweeper_uses_development_data_records_every_trial_and_deduplicates(self):
        stub = EngineStub(fail=lambda parameters: parameters == {"mr_z_abs": 2.2, "mr_rsi_max": 32, "stop_multiple": 2.0})
        source = self.write("mr-source.json", strategy_source())
        sweep = {"mr_z_abs": [2.0, 2.2], "mr_rsi_max": [30, 32], "stop_multiple": [2.0]}
        with patch("intraday_quant.strategy_lab.research.run_engine", stub):
            self.draft(self.spec(source, sweep=sweep))
            self.assertEqual([event["kind"] for event in self.advance()], ["PROBE_COMPLETED"])
            self.assertEqual(stub.calls, [{"parameters": None, "last": DEV_END}])
            self.assertEqual([event["kind"] for event in self.advance()], ["BACKTEST_COMPLETED"])
        # Four grid points, four engine calls: the probe is the baseline trial, reused by content address.
        self.assertEqual(len(stub.calls), 4)
        self.assertTrue(all(call["last"] <= DEV_END for call in stub.calls))
        self.assertEqual([call["parameters"] for call in stub.calls].count(None), 1)
        spec = self.fold()["specs"]["mr-test"]
        backtest = spec["backtest"]
        self.assertEqual(backtest["family_trial_count"], 4)
        self.assertEqual(len(list((self.state / "trials").glob("*.json"))), 4)
        self.assertEqual(spec["probe"]["trial"]["key"], backtest["trials"][0]["trial_key"])
        self.assertEqual(sorted(spec["trial_keys"]), sorted(row["trial_key"] for row in backtest["trials"]))
        rejected = [row for row in backtest["trials"] if row["state"] == "rejected"]
        self.assertEqual(len(rejected), 1)
        self.assertEqual(rejected[0]["p_value"], 1.0)
        self.assertEqual(rejected[0]["adjusted_p_value"], 1.0)
        self.assertFalse(rejected[0]["survivor"])
        trial = json.loads((self.state / "trials" / f"{rejected[0]['trial_key']}.json").read_text())
        self.assertIn("stub failure", trial["reason"])
        # One BH family per spec, sized by the whole predeclared grid including the failed trial.
        frame = pd.DataFrame({"hypothesis_id": [row["hypothesis_id"] for row in backtest["trials"]], "family": "mr-test",
                              "p_value": [row["p_value"] for row in backtest["trials"]], "test_kind": "primary", "pre_registered": True})
        family = benjamini_hochberg(frame)["families"]
        self.assertEqual(len(family), 1)
        self.assertEqual(family[0]["hypothesis_count"], 4)
        expected = {row["hypothesis_id"]: row["adjusted_p_value"] for row in family[0]["results"]}
        self.assertEqual({row["hypothesis_id"]: row["adjusted_p_value"] for row in backtest["trials"]}, expected)
        self.assertEqual(backtest["survivors"], [0, 1, 2])
        self.assertEqual(spec["status"], "ACTIVE")

    def test_environment_failures_are_retried_not_recorded_as_trials(self):
        source = self.write("mr-source.json", strategy_source())
        self.draft(self.spec(source))

        def unavailable(_engine, _request):
            raise PermissionError("engine not executable")

        with patch("intraday_quant.strategy_lab.research.run_engine", unavailable), self.assertRaises(PermissionError):
            self.advance()
        self.assertEqual(self.kinds(), ["SPEC_FROZEN"])
        self.assertFalse((self.state / "trials").exists())
        with patch("intraday_quant.strategy_lab.research.run_engine", EngineStub()):
            self.assertEqual([event["kind"] for event in self.advance()], ["PROBE_COMPLETED"])
        self.assertEqual(self.fold()["specs"]["mr-test"]["probe"]["state"], "completed")

    def test_probe_rejects_short_or_non_positive_development_evidence(self):
        falling = [round(100 * 0.999 ** index, 2) for index in range(len(LONG))]
        cases = {"NON_POSITIVE_PROBE_STATISTIC": ({"closes": falling}, 100), "INSUFFICIENT_DEVELOPMENT_SESSIONS": ({}, 1000)}
        for reason, (source_changes, minimum) in cases.items():
            with self.subTest(reason):
                self.state = self.root / reason
                source = self.write(f"{reason}.json", strategy_source(**source_changes))
                evaluation = {"development_end": DEV_END.isoformat(), "holdout_start": HOLDOUT_START.isoformat(),
                              "holdout_end": HOLDOUT_END.isoformat(), "minimum_dev_sessions": minimum, "minimum_holdout_sessions": 20,
                              "maximum_forward_drawdown": 0.2}
                with patch("intraday_quant.strategy_lab.research.run_engine", EngineStub()):
                    self.draft(self.spec(source, evaluation=evaluation))
                    event = self.advance(until_blocked=True)[-1]
                self.assertEqual((event["kind"], event["from_stage"], event["reasons"]), ("REJECTED_NO_DEPLOYABLE_EDGE", "PROBE", [reason]))

    def test_survivors_need_a_bh_rejection_and_a_positive_bootstrap_lower_bound(self):
        cases = {
            "mixed": ({1.8: TRENDING, 2.0: STRONG, 2.2: CHOPPY}, [1]),
            "nothing_bh_rejected": ({1.8: CHOPPY, 2.0: CHOPPY, 2.2: CHOPPY}, []),
            "no_positive_lower_bound": ({1.8: TRENDING, 2.0: TRENDING, 2.2: TRENDING}, []),
        }
        for label, (returns, survivors) in cases.items():
            with self.subTest(label):
                self.state = self.root / label
                source = self.write(f"{label}.json", strategy_source())
                with patch("intraday_quant.strategy_lab.research.run_engine", ParamStub(returns)):
                    self.draft(self.spec(source, sweep=THREE_POINTS))
                    self.advance(until_blocked=True)
                trials = self.fold()["specs"]["mr-test"]["backtest"]["trials"]
                self.assertEqual(self.fold()["specs"]["mr-test"]["backtest"]["survivors"], survivors)
                for row, z in zip(trials, (1.8, 2.0, 2.2), strict=True):
                    self.assertGreater(row["statistic"], 0)
                    if returns[z] is CHOPPY:  # bootstrap lower bound above zero, but no BH rejection
                        self.assertFalse(row["bh_rejected"])
                        self.assertGreater(row["lower_95"], 0)
                    elif returns[z] is TRENDING:  # BH rejection, but the bootstrap lower bound is not above zero
                        self.assertTrue(row["bh_rejected"])
                        self.assertLessEqual(row["lower_95"], 0)
                    self.assertEqual(row["survivor"], row["index"] in survivors)
                if survivors:
                    self.assertEqual(self.kinds()[-1], "PAPER_PROPOSAL_ISSUED")
                else:
                    last = self.fold()["events"][-1]
                    self.assertEqual((last["kind"], last["from_stage"], last["reasons"]),
                                     ("REJECTED_NO_DEPLOYABLE_EDGE", "BACKTEST", ["NO_GRID_SURVIVORS"]))
                    self.assertNotIn("HOLDOUT_EVALUATED", self.kinds())

    def test_unstable_grid_neighbours_reject_before_the_holdout(self):
        stub = ParamStub({1.8: NEGATIVE, 2.0: STRONG, 2.2: NEGATIVE})
        source = self.write("mr-source.json", strategy_source())
        with patch("intraday_quant.strategy_lab.research.run_engine", stub):
            self.draft(self.spec(source, sweep=THREE_POINTS))
            self.advance(until_blocked=True)
        spec = self.fold()["specs"]["mr-test"]
        self.assertEqual(spec["backtest"]["survivors"], [1])
        last = self.fold()["events"][-1]
        self.assertEqual((last["kind"], last["role"], last["reasons"]), ("REJECTED_NO_DEPLOYABLE_EDGE", "grower", ["UNSTABLE_GRID_NEIGHBOURS"]))
        gates = {gate["id"]: gate for gate in ledger.read_receipt(self.state, last["receipt"])["gates"]}
        self.assertFalse(gates["neighbours_positive"]["passed"])
        self.assertTrue(gates["baseline_selected"]["passed"])
        self.assertIsNone(spec["holdout"])
        self.assertTrue(all(call["last"] <= DEV_END for call in stub.calls))
        self.assertFalse((self.state / "proposals").exists())

    def test_failed_holdout_is_terminal_and_other_specs_still_advance(self):
        pivot = [session[0] for session in LONG].index(DEV_END)  # rise through development, fall through the holdout
        falling = [round(100 * 1.002 ** min(index, pivot) * 0.998 ** max(0, index - pivot), 2) for index in range(len(LONG))]
        cases = {"NON_POSITIVE_HOLDOUT_STATISTIC": (falling, 20), "INSUFFICIENT_HOLDOUT_SESSIONS": (CLOSES, 5000)}
        for reason, (closes, minimum) in cases.items():
            with self.subTest(reason):
                self.state = self.root / reason
                failing = self.write(f"{reason}.json", strategy_source(closes=closes))
                other = strategy_source()
                other["code_revision"] = "unit-test-other-input"
                evaluation = {"development_end": DEV_END.isoformat(), "holdout_start": HOLDOUT_START.isoformat(),
                              "holdout_end": HOLDOUT_END.isoformat(), "minimum_dev_sessions": 100, "minimum_holdout_sessions": minimum,
                              "maximum_forward_drawdown": 0.2}
                stub = EngineStub()
                with patch("intraday_quant.strategy_lab.research.run_engine", stub):
                    self.draft(self.spec(failing, spec_id="failing", evaluation=evaluation))
                    self.draft(self.spec(self.write("other-source.json", other), spec_id="other"))
                    self.advance(until_blocked=True)
                    count = len(stub.calls)
                    self.assertEqual(self.advance(until_blocked=True), [])
                    with self.assertRaisesRegex(ValueError, "second attempt is refused"):
                        agents.grow(self.state, "failing", now=self.clock)
                self.assertEqual(len(stub.calls), count)
                specs = self.fold()["specs"]
                self.assertEqual((specs["failing"]["stage"], specs["failing"]["status"]), ("BACKTEST", "REJECTED_NO_DEPLOYABLE_EDGE"))
                self.assertFalse(specs["failing"]["holdout"]["passed"])
                self.assertEqual(specs["failing"]["holdout"]["reasons"], [reason])
                events = [event for event in self.fold()["events"] if event["spec_id"] == "failing"]
                self.assertEqual([event["kind"] for event in events][-2:], ["HOLDOUT_EVALUATED", "REJECTED_NO_DEPLOYABLE_EDGE"])
                self.assertEqual(events[-1]["reasons"], [reason])
                self.assertEqual(ledger.read_receipt(self.state, events[-1]["receipt"])["kind"], "grower")
                self.assertNotIn("PROMOTED", [event["kind"] for event in events])
                self.assertFalse((self.state / "proposals" / "failing").exists())
                self.assertEqual((specs["other"]["stage"], specs["other"]["status"]), ("PAPER", "AWAITING_HUMAN_RESUME"))
                public = ledger.ledger_public(self.state)
                gates = {gate["id"]: gate["passed"] for gate in public["specs"][0]["gates"]}
                self.assertFalse(gates["holdout_once"])

    def test_a_holdout_is_never_reused_by_another_spec_on_the_same_input(self):
        stub = EngineStub()
        source = self.write("mr-source.json", strategy_source())
        with patch("intraday_quant.strategy_lab.research.run_engine", stub):
            self.draft(self.spec(source, spec_id="first-look"))
            self.draft(self.spec(source, spec_id="second-look", sweep={"mr_z_abs": [2.0], "mr_rsi_max": [30], "stop_multiple": [2.0]}))
            self.advance(until_blocked=True)
        specs = self.fold()["specs"]
        self.assertEqual((specs["first-look"]["stage"], specs["first-look"]["status"]), ("PAPER", "AWAITING_HUMAN_RESUME"))
        self.assertEqual((specs["second-look"]["stage"], specs["second-look"]["status"]), ("BACKTEST", "BLOCKED"))
        self.assertIsNone(specs["second-look"]["holdout"])
        last = self.fold()["events"][-1]
        self.assertEqual((last["spec_id"], last["kind"], last["reasons"]), ("second-look", "BLOCKED", ["HOLDOUT_ALREADY_CONSUMED"]))
        self.assertEqual([call for call in stub.calls if call["last"] > DEV_END], [{"parameters": None, "last": HOLDOUT_END}])
        self.assertEqual(self.kinds().count("HOLDOUT_EVALUATED"), 1)

    # -- Grower ----------------------------------------------------------------
    def test_holdout_runs_once_and_the_paper_proposal_is_importable(self):
        stub = EngineStub()
        spec = self.run_mr(stub)
        self.assertEqual(self.kinds(), ["SPEC_FROZEN", "PROBE_COMPLETED", "BACKTEST_COMPLETED", "HOLDOUT_EVALUATED", "PROMOTED",
                                        "PAPER_PROPOSAL_ISSUED"])
        self.assertEqual((spec["stage"], spec["status"]), ("PAPER", "AWAITING_HUMAN_RESUME"))
        holdout_calls = [call for call in stub.calls if call["last"] > DEV_END]
        self.assertEqual(holdout_calls, [{"parameters": None, "last": HOLDOUT_END}])
        self.assertTrue(spec["holdout"]["passed"])
        self.assertEqual(spec["holdout"]["window"], {"start": HOLDOUT_START.isoformat(), "end": HOLDOUT_END.isoformat()})
        count = len(stub.calls)
        with patch("intraday_quant.strategy_lab.research.run_engine", stub):
            with self.assertRaisesRegex(ValueError, "second attempt is refused"):
                agents.grow(self.state, "mr-test", now=self.clock)
            self.assertEqual(self.advance(until_blocked=True), [])
        self.assertEqual(len(stub.calls), count)
        self.assertEqual(self.kinds().count("HOLDOUT_EVALUATED"), 1)

        folder = self.state / "proposals" / "mr-test"
        report = json.loads((folder / "research-report.json").read_text())
        self.assertEqual(set(report), REPORT_KEYS)
        self.assertFalse({"bars", "input_manifest"} & set(keys(report)))
        self.assertEqual((report["schema_version"], report["strategy"], report["research_variant"]), (research.VERSION, "MR-v1", False))
        self.assertIs(report["execution_authorized"], False)
        proposal = json.loads((folder / "proposal.json").read_text())
        self.assertEqual(set(proposal), {"strategyId", "symbol", "parameters", "mode", "steps"})
        self.assertEqual((proposal["strategyId"], proposal["symbol"], proposal["parameters"], proposal["mode"]),
                         ("MR-v1", SYMBOL, {}, "paper"))
        self.assertTrue(proposal["steps"] and all(isinstance(step, str) and step for step in proposal["steps"]))

        resumed = agents.resume(self.state, "mr-test", now=self.clock)
        self.assertEqual((resumed["role"], resumed["kind"], resumed["status"]), ("human", "HUMAN_RESUMED", "ACTIVE"))
        with patch("intraday_quant.strategy_lab.research.run_engine", stub):
            self.assertEqual(self.advance(until_blocked=True), [])
        self.assertEqual(self.fold()["specs"]["mr-test"]["stage"], "PAPER")
        with self.assertRaisesRegex(ValueError, "paused or awaiting"):
            agents.resume(self.state, "mr-test", now=self.clock)

    def test_interrupted_grower_resumes_without_a_second_holdout(self):
        stub = EngineStub()
        source = self.write("mr-source.json", strategy_source())
        real, interrupted = agents._append, []

        def crash_once(root, now, spec_id, role, kind, *args, **kwargs):
            if kind in ("PROMOTED", "PAPER_PROPOSAL_ISSUED") and kind not in interrupted:
                interrupted.append(kind)
                raise RuntimeError("simulated crash before the event was recorded")
            return real(root, now, spec_id, role, kind, *args, **kwargs)

        with patch("intraday_quant.strategy_lab.research.run_engine", stub), patch.object(agents, "_append", crash_once):
            self.draft(self.spec(source))
            for _ in range(2):
                with self.assertRaisesRegex(RuntimeError, "simulated crash"):
                    self.advance(until_blocked=True)
            self.assertEqual(self.advance(until_blocked=True)[-1]["kind"], "PAPER_PROPOSAL_ISSUED")
        self.assertEqual(interrupted, ["PROMOTED", "PAPER_PROPOSAL_ISSUED"])
        self.assertEqual(self.kinds(), ["SPEC_FROZEN", "PROBE_COMPLETED", "BACKTEST_COMPLETED", "HOLDOUT_EVALUATED", "PROMOTED",
                                        "PAPER_PROPOSAL_ISSUED"])
        self.assertEqual([call for call in stub.calls if call["last"] > DEV_END], [{"parameters": None, "last": HOLDOUT_END}])

    def test_synthetic_evidence_is_capped_at_backtest(self):
        stub = EngineStub()
        spec = self.run_mr(stub, classification="synthetic_fixture")
        self.assertEqual(self.kinds()[-2:], ["BACKTEST_COMPLETED", "BLOCKED"])
        self.assertEqual((spec["stage"], spec["status"]), ("BACKTEST", "BLOCKED"))
        self.assertEqual(self.fold()["events"][-1]["reasons"], ["SYNTHETIC_EVIDENCE_CAPPED_AT_BACKTEST"])
        self.assertIsNone(spec["holdout"])
        self.assertTrue(all(call["last"] <= DEV_END for call in stub.calls))
        self.assertFalse((self.state / "proposals").exists())

    def test_mr_and_mom_non_baseline_selection_is_blocked(self):
        cases = {"MR-v1": {"mr_z_abs": [1.8, 2.0], "mr_rsi_max": [30], "stop_multiple": [2.0]},
                 "MOM-v1": {"momentum_lookback": [50, 55], "stop_multiple": [3.0]}}
        for template, sweep in cases.items():
            with self.subTest(template):
                self.state = self.root / template
                source = self.write(f"{template}.json", strategy_source(strategy=template))
                with patch("intraday_quant.strategy_lab.research.run_engine", EngineStub()):
                    self.draft(self.spec(source, template=template, spec_id=template.lower().replace("-", ""), sweep=sweep))
                    event = self.advance(until_blocked=True)[-1]
                self.assertEqual((event["kind"], event["role"], event["reasons"]), ("BLOCKED", "grower", ["SELECTED_POINT_NOT_BASELINE"]))
                grower = ledger.read_receipt(self.state, event["receipt"])
                self.assertEqual(grower["selected"]["index"], 0)
                self.assertNotIn("HOLDOUT_EVALUATED", self.kinds())

    def test_overlays_model_priced_capped_executable_enters_forward_shadow(self):
        source = self.write("overlay-source.json", overlay_source())
        with patch("intraday_quant.overlay_lab.engine.run_overlay", overlay_stub):
            self.draft(self.overlay_spec(source, spec_id="model-priced", pricing_mode="MODEL_PRICED"))
            self.draft(self.overlay_spec(source, spec_id="executable"))
            self.advance(until_blocked=True)
        specs = self.fold()["specs"]
        self.assertEqual((specs["model-priced"]["stage"], specs["model-priced"]["status"]), ("BACKTEST", "BLOCKED"))
        blocked = [event for event in self.fold()["events"] if event["spec_id"] == "model-priced"][-1]
        self.assertEqual(blocked["reasons"], ["MODEL_PRICED_CAPPED_AT_BACKTEST"])
        self.assertEqual((specs["executable"]["stage"], specs["executable"]["status"]), ("PAPER", "FORWARD_SHADOW"))
        self.assertEqual(specs["executable"]["shadow"]["orders"], "none_placed")
        self.assertIs(specs["executable"]["shadow"]["execution_authorized"], False)
        self.assertFalse((self.state / "proposals").exists())
        last = json.loads(source.read_text())["bars"][-1]
        with patch("intraday_quant.overlay_lab.engine.run_overlay", overlay_stub):
            check = agents.observe(self.state, "executable", source, research.utc(last["available_at"]) + timedelta(hours=1), now=self.clock)
        self.assertEqual((check["kind"], check["status"], check["reasons"]), ("MAINTAINER_CHECK", "FORWARD_SHADOW", []))

    def test_grid_template_never_reaches_paper(self):
        source = self.write("grid-source.json", grid_source())
        with patch("intraday_quant.strategy_lab.grid.run_grid_engine", grid_stub):
            self.draft(self.spec(source, template="GRID-R1", spec_id="grid-test", sweep={"intervals": [4, 6, 8, 10]}))
            self.advance()
            self.assertEqual(self.advance()[-1]["kind"], "BACKTEST_COMPLETED")
            forged = ledger.put_receipt(self.state, agents._receipt("grower", "grid-test", gates=[]))
            with self.assertRaisesRegex(ValueError, "capped at BACKTEST"):
                ledger.append(self.state, now=self.clock, spec_id="grid-test", role="grower", kind="PROMOTED",
                              from_stage="BACKTEST", to_stage="PAPER", status="ACTIVE", reasons=[], receipt=forged)
            event = self.advance(until_blocked=True)[-1]
        self.assertEqual((event["kind"], event["reasons"]), ("BLOCKED", ["TEMPLATE_CAPPED_AT_BACKTEST"]))
        self.assertEqual(self.fold()["specs"]["grid-test"]["stage"], "BACKTEST")
        self.assertNotIn("PAPER", {event["to_stage"] for event in self.fold()["events"]})

    def test_live_stages_are_locked_and_unreachable(self):
        self.assertEqual([stage["id"] for stage in templates.LADDER], ["PROBE", "BACKTEST", "PAPER", "LIVE_SMALL", "LIVE_SCALED"])
        for stage in templates.LADDER[3:]:
            self.assertTrue(stage["locked"])
            self.assertFalse(stage["automatic"])
            self.assertTrue(stage["lockReason"])
            self.assertEqual(len(stage["futureGates"]), 6)
        for stage in templates.LADDER[:3]:
            self.assertEqual((stage["locked"], stage["lockReason"], stage["futureGates"]), (False, None, []))
        self.assertEqual(templates.TRANSITIONS, {"PROBE": "BACKTEST", "BACKTEST": "PAPER"})
        self.assertFalse({"LIVE_SMALL", "LIVE_SCALED"} & (set(templates.TRANSITIONS) | set(templates.TRANSITIONS.values())))
        self.assertEqual({template.max_stage for template in templates.TEMPLATES.values()}, {"PAPER", "BACKTEST"})
        source = self.write("mr-source.json", strategy_source())
        self.draft(self.spec(source))
        with self.assertRaisesRegex(ValueError, "live stages are locked"):
            ledger.append(self.state, now=self.clock, spec_id="mr-test", role="sweeper", kind="PROBE_COMPLETED",
                          from_stage="PROBE", to_stage="LIVE_SMALL", status="ACTIVE", reasons=[], receipt=None)
        events = ledger.read_events(self.state)
        forged = {"schema_version": ledger.EVENT_VERSION, "seq": 2, "at": "2026-01-05T13:00:00+00:00", "prev_sha256": events[-1][1],
                  "spec_id": "mr-test", "role": "human", "kind": "HUMAN_RESUMED", "from_stage": "PAPER", "to_stage": "LIVE_SMALL",
                  "status": "ACTIVE", "reasons": [], "receipt": None}
        (self.state / "events" / "00000002.json").write_bytes(_json_bytes(forged))
        with self.assertRaisesRegex(IntegrityError, "live stages are locked"):
            self.fold()

    # -- Maintainer ------------------------------------------------------------
    def test_maintainer_rules_pause_and_never_resume(self):
        stub = EngineStub()
        self.run_mr(stub)
        last = LONG[-1]
        frozen_count = len(window(HOLDOUT_END)[0])

        def observation(name, closes=CLOSES, end=last[0], mutate=None):
            raw = strategy_source(end=end, closes=closes)
            if mutate:
                mutate(raw)
            return self.write(name, raw)

        def path_after_holdout(step, sessions):
            closes = list(CLOSES[:frozen_count])
            for index in range(frozen_count, len(LONG)):
                closes.append(round(closes[-1] * (step if index < frozen_count + sessions else 1.0), 2))
            return closes

        def revise(raw):
            raw["bars"][300]["close"] = raw["bars"][300]["low"]

        drawdown_end = LONG[frozen_count + 19]
        cases = [
            ("ok", observation("ok.json"), last[2] + timedelta(hours=1), []),
            ("stale", observation("ok.json"), datetime(2024, 7, 15, 21, tzinfo=timezone.utc), ["STALE_DATA"]),
            ("revised", observation("revised.json", mutate=revise), last[2] + timedelta(hours=1), ["SOURCE_REVISED"]),
            ("drawdown", observation("drawdown.json", closes=path_after_holdout(0.965, 10), end=drawdown_end[0]),
             drawdown_end[2] + timedelta(hours=1), ["DECAY_DRAWDOWN"]),
            ("decay", observation("decay.json", closes=path_after_holdout(0.999, 63)), last[2] + timedelta(hours=1), ["DECAY_RETURN"]),
            ("ok-while-paused", observation("ok.json"), last[2] + timedelta(hours=1), []),
        ]
        with patch("intraday_quant.strategy_lab.research.run_engine", stub):
            for label, path, as_of, reasons in cases:
                with self.subTest(label):
                    before = self.fold()["specs"]["mr-test"]["status"]
                    event = agents.observe(self.state, "mr-test", path, as_of, now=self.clock)
                    self.assertEqual(event["role"], "maintainer")
                    self.assertEqual(event["reasons"], reasons)
                    if reasons:
                        self.assertEqual((event["kind"], event["status"]), ("PAUSE_REQUESTED", "PAUSED"))
                    else:
                        self.assertEqual((event["kind"], event["status"]), ("MAINTAINER_CHECK", before))
                    check = self.fold()["specs"]["mr-test"]["last_check"]
                    self.assertEqual(check["checks"]["DECAY_RETURN"]["applicable"], True)
            self.assertEqual(self.fold()["specs"]["mr-test"]["status"], "PAUSED")
            self.assertEqual(self.fold()["specs"]["mr-test"]["last_check"]["checks"]["DECAY_RETURN"]["forward_sessions"], 63)
            count = len(self.fold()["events"])
            with self.assertRaisesRegex(ValueError, "non-causal"):
                agents.observe(self.state, "mr-test", observation("ok.json"), last[2], now=self.clock)
            with self.assertRaisesRegex(ValueError, "future"):
                agents.observe(self.state, "mr-test", observation("ok.json"), datetime(2027, 1, 1, tzinfo=timezone.utc), now=self.clock)
            self.assertEqual(len(self.fold()["events"]), count)
        self.assertNotIn("HUMAN_RESUMED", self.kinds())
        self.assertEqual(agents.resume(self.state, "mr-test", now=self.clock)["status"], "ACTIVE")

    def test_stale_data_counts_sessions_on_weekends_and_holidays(self):
        cases = [(date(2024, 3, 28), datetime(2024, 4, 1, 21, tzinfo=timezone.utc), 1),  # Good Friday is not a session
                 (date(2024, 3, 28), datetime(2024, 4, 6, 12, tzinfo=timezone.utc), 5),  # Saturday
                 (date(2024, 3, 28), datetime(2024, 4, 7, 12, tzinfo=timezone.utc), 5),  # Sunday
                 (date(2024, 5, 24), datetime(2024, 5, 27, 21, tzinfo=timezone.utc), 0),  # Memorial Day
                 (date(2024, 3, 28), datetime(2024, 4, 8, 12, tzinfo=timezone.utc), 5)]  # Monday before its close
        for last, as_of, missed in cases:
            with self.subTest(as_of=as_of.isoformat()):
                self.assertEqual(agents._sessions_missed(last, as_of), missed)
        stub = EngineStub()
        self.run_mr(stub)
        observation = self.write("ok.json", strategy_source(end=LONG[-1][0]))
        with patch("intraday_quant.strategy_lab.research.run_engine", stub):
            fresh = agents.observe(self.state, "mr-test", observation, datetime(2024, 6, 29, 12, tzinfo=timezone.utc), now=self.clock)
            stale = agents.observe(self.state, "mr-test", observation, datetime(2024, 7, 6, 12, tzinfo=timezone.utc), now=self.clock)
        self.assertEqual((fresh["kind"], fresh["reasons"]), ("MAINTAINER_CHECK", []))
        self.assertEqual((stale["kind"], stale["reasons"]), ("PAUSE_REQUESTED", ["STALE_DATA"]))

    def test_overlay_quote_file_is_bound_and_revised_or_late_quotes_fail_closed(self):
        source_path = agents._synthetic_inputs(self.root / "overlay-inputs")
        quotes = source_path.parent / "synthetic-quotes.csv"
        self.assertEqual(self.synthetic_overlay_draft(source_path, "quotes-a")["kind"], "SPEC_FROZEN")
        as_of = "2024-06-28T21:00:00+00:00"

        def observation(name, change=None):
            with quotes.open(encoding="utf-8", newline="") as handle:
                rows = list(csv.DictReader(handle))
            if change is not None:
                change(rows)
            folder = self.root / name
            folder.mkdir()
            with (folder / "quotes.csv").open("w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
                writer.writeheader()
                writer.writerows(rows)
            raw = json.loads(source_path.read_text())
            raw["option_quotes"] = {"path": "quotes.csv", "sha256": _sha((folder / "quotes.csv").read_bytes())}
            (folder / "source.json").write_bytes(_json_bytes(raw))
            return folder / "source.json"

        def restate(rows):  # a vendor restates one historical session's bids; the bars are unchanged
            for row in rows:
                if row["session_date"] == "2023-08-01":
                    row["bid"] = f"{float(row['bid']) * 1.5 + 0.01:.2f}"
                    row["ask"] = f"{max(float(row['ask']), float(row['bid']) + 0.01):.2f}"

        def late(rows):  # last-session quotes arrive after as_of, though still before the next open
            for row in rows:
                if row["session_date"] == "2024-06-28":
                    row["available_at"] = "2024-07-01T13:00:00+00:00"

        unchanged = agents.observe(self.state, "quotes-a", observation("unchanged"), as_of, now=self.clock)
        self.assertEqual((unchanged["kind"], unchanged["reasons"]), ("MAINTAINER_CHECK", []))
        check = ledger.read_receipt(self.state, unchanged["receipt"])["checks"]["SOURCE_REVISED"]
        self.assertEqual(check["compared_inputs"], ["bars", "option_quotes", "dividends", "iv_marks"])
        count = len(self.fold()["events"])
        with self.assertRaisesRegex(ValueError, "non-causal"):
            agents.observe(self.state, "quotes-a", observation("late", late), as_of, now=self.clock)
        self.assertEqual(len(self.fold()["events"]), count)
        revised = agents.observe(self.state, "quotes-a", observation("restated", restate), as_of, now=self.clock)
        self.assertEqual((revised["kind"], revised["status"], revised["reasons"]), ("PAUSE_REQUESTED", "PAUSED", ["SOURCE_REVISED"]))
        check = ledger.read_receipt(self.state, revised["receipt"])["checks"]["SOURCE_REVISED"]
        self.assertEqual((check["revised_or_missing_sessions"], check["first_revised"]), (1, "2023-08-01"))

        # A moved quote file blocks the spec without recording a trial; the restored file serves a new spec normally.
        self.synthetic_overlay_draft(source_path, "quotes-b")
        moved = quotes.with_name("moved.csv")
        quotes.rename(moved)
        events = self.advance()
        self.assertEqual([(event["spec_id"], event["kind"], event["reasons"]) for event in events],
                         [("quotes-b", "BLOCKED", ["FROZEN_INPUT_UNAVAILABLE"])])
        self.assertFalse((self.state / "trials").exists())
        self.assertEqual(self.synthetic_overlay_draft(source_path, "quotes-x")["kind"], "SPEC_REJECTED")
        moved.rename(quotes)
        self.synthetic_overlay_draft(source_path, "quotes-c")
        self.assertEqual([(event["spec_id"], event["kind"]) for event in self.advance()], [("quotes-c", "PROBE_COMPLETED")])
        self.assertEqual(self.fold()["specs"]["quotes-c"]["probe"]["state"], "completed")
        quotes.write_bytes(quotes.read_bytes() + b"\n")
        self.assertEqual([(event["kind"], event["reasons"]) for event in self.advance()], [("BLOCKED", ["FROZEN_INPUT_CHANGED"])])
        rejected = self.synthetic_overlay_draft(source_path, "quotes-d")
        self.assertEqual(rejected["kind"], "SPEC_REJECTED")
        self.assertIn("sha256 mismatch", rejected["reasons"][0])

    # -- ledger integrity ------------------------------------------------------
    def test_ledger_tampering_raises_integrity_error(self):
        self.run_mr(EngineStub())
        state = self.fold()
        backtest = state["specs"]["mr-test"]["backtest"]

        def rewrite(path: Path, change):
            value = json.loads(path.read_text())
            change(value)
            path.write_bytes(_json_bytes(value))

        mutations = {
            "event_rewritten": lambda root: rewrite(root / "events" / "00000002.json", lambda value: value.update(reasons=["edited"])),
            "last_event_receipt_swapped": lambda root: rewrite(root / "events" / "00000006.json",
                                                              lambda value: value.update(receipt=state["events"][2]["receipt"])),
            "event_deleted": lambda root: (root / "events" / "00000003.json").unlink(),
            "receipt_edited": lambda root: rewrite(root / state["events"][2]["receipt"]["file"], lambda value: value.update(survivors=[])),
            "trial_edited": lambda root: rewrite(root / "trials" / f"{backtest['trials'][0]['trial_key']}.json",
                                                 lambda value: value.update(statistic=9.9)),
            "proposal_edited": lambda root: rewrite(root / "proposals" / "mr-test" / "proposal.json",
                                                    lambda value: value.update(parameters={"mr_z_abs": 1.8})),
            "stray_event_file": lambda root: (root / "events" / "notes.json").write_text("{}"),
        }
        for label, mutate in mutations.items():
            with self.subTest(label):
                copy_root = self.root / f"tampered-{label}"
                shutil.copytree(self.state, copy_root)
                mutate(copy_root)
                with self.assertRaises(IntegrityError):
                    ledger.fold_state(copy_root)
                with self.assertRaises(IntegrityError):
                    agents.publish(self.root / f"{label}.json", state_dir=copy_root, rights_confirmed=True, now=self.clock)
                self.assertFalse((self.root / f"{label}.json").exists())
        self.assertEqual(len(ledger.fold_state(self.state)["events"]), 6)

    def test_stop_file_blocks_advance(self):
        stub = EngineStub()
        source = self.write("mr-source.json", strategy_source())
        self.draft(self.spec(source))
        (self.state / "STOP").touch()
        with patch("intraday_quant.strategy_lab.research.run_engine", stub):
            with self.assertRaisesRegex(agents.FoundryStopped, "STOP"):
                self.advance(until_blocked=True)
            with self.assertRaises(SystemExit) as stopped, contextlib.redirect_stderr(io.StringIO()):
                foundry_main(["advance", "--state-dir", str(self.state)])
            self.assertEqual(stopped.exception.code, 2)
            self.assertEqual(self.kinds(), ["SPEC_FROZEN"])
            self.assertEqual(stub.calls, [])
            (self.state / "STOP").unlink()
            self.assertEqual([event["kind"] for event in self.advance()], ["PROBE_COMPLETED"])
            self.assertEqual([event["kind"] for event in self.advance()], ["BACKTEST_COMPLETED"])
            (self.state / "STOP").touch()
            calls = len(stub.calls)
            with self.assertRaisesRegex(agents.FoundryStopped, "STOP"):
                agents.grow(self.state, "mr-test", now=self.clock)
        self.assertEqual(self.kinds(), ["SPEC_FROZEN", "PROBE_COMPLETED", "BACKTEST_COMPLETED"])
        self.assertEqual(len(stub.calls), calls)

    # -- publication -----------------------------------------------------------
    def test_publish_refusals_and_deterministic_pending_output(self):
        first, second = self.root / "pending-1.json", self.root / "pending-2.json"
        agents.publish(first)
        agents.publish(second)
        self.assertEqual(first.read_bytes(), second.read_bytes())
        self.assertEqual(first.read_bytes(), DATA.read_bytes())
        pending = json.loads(first.read_text())
        self.assertEqual((pending["generatedAt"], pending["derivedPublicationRightsConfirmed"]), (None, False))
        self.assertEqual((pending["overlay"]["status"], pending["ledger"]["status"]), ("ARTIFACT_PENDING", "ARTIFACT_PENDING"))
        self.assertEqual([role["id"] for role in pending["roles"]], list(templates.ROLE_IDS))

        self.run_mr(EngineStub())
        output = self.root / "published.json"
        with self.assertRaisesRegex(ValueError, "rights-confirmed"):
            agents.publish(output, state_dir=self.state)
        self.assertFalse(output.exists())
        with self.assertRaisesRegex(ValueError, "follow the publication time"):
            agents.publish(output, state_dir=self.state, rights_confirmed=True, generated_at="2026-01-05T11:00:00Z")
        value = agents.publish(output, state_dir=self.state, rights_confirmed=True, generated_at="2026-02-01T00:00:00Z")
        written = output.read_bytes()
        self.assertEqual(written, agents.publication_bytes(value))
        self.assertEqual(agents.publish(self.root / "again.json", state_dir=self.state, rights_confirmed=True,
                                        generated_at="2026-02-01T00:00:00Z"), value)
        self.assertEqual((value["generatedAt"], value["derivedPublicationRightsConfirmed"]), ("2026-02-01T00:00:00+00:00", True))
        public = value["ledger"]["ledger"]
        self.assertEqual((public["eventCount"], public["llmCalls"], public["trialsTotal"]), (6, 0, 2))
        self.assertEqual(public["headSha256"], self.fold()["head_sha256"])
        self.assertEqual(public["specs"][0]["symbolLabel"], "Redacted holding")
        self.assertEqual((public["specs"][0]["familyTrialCount"], public["specs"][0]["survivors"]), (2, 2))
        self.assertNotIn("PRIVATE", written.decode())
        self.assertNotIn(SYMBOL, written.decode())
        self.assertNotIn(str(self.root), written.decode())
        named = agents.publish(output, state_dir=self.state, rights_confirmed=True, public_symbols=True, generated_at="2026-02-01T00:00:00Z")
        self.assertEqual(named["ledger"]["ledger"]["specs"][0]["symbolLabel"], SYMBOL)

        synthetic_state = self.root / "synthetic-state"
        self.state = synthetic_state
        source = self.write("synthetic-source.json", strategy_source(classification="synthetic_fixture"))
        self.assertEqual(self.draft(self.spec(source, spec_id="synthetic"))["kind"], "SPEC_FROZEN")
        with self.assertRaisesRegex(ValueError, "synthetic-fixture research"):
            agents.publish(output, state_dir=synthetic_state, rights_confirmed=True, generated_at="2026-02-01T00:00:00Z")

        folder = self.root / "overlay-inputs"
        source_path = agents._synthetic_inputs(folder)
        raw = json.loads(source_path.read_text())
        config = {"schema_version": "leo-overlay-config.v1", "structure": "covered_call", "shares": 100, "pricing_mode": "EXECUTABLE_QUOTES",
                  "call_rule": {"kind": "otm_pct", "value": 0.05}, "put_rule": None, "target_dte": 30, "min_dte": 20, "max_dte": 50,
                  "max_spread_fraction": 0.5, "model": None, "costs": {"commission_per_contract": "0.65", "share_slippage_bps": 2}}
        synthetic = overlay_engine.run_overlay(raw, config, base_dir=folder, resamples=200)
        artifact = self.write("synthetic-artifact.json", synthetic)
        with self.assertRaisesRegex(ValueError, "synthetic fixtures are never published"):
            agents.publish(output, overlay_artifact=artifact, rights_confirmed=True, generated_at="2026-02-01T00:00:00Z")
        # A model-priced artifact may be published, but only labelled not executable.
        raw["evidence"]["classification"] = "observed"
        modelled = overlay_engine.run_overlay(raw, {**config, "pricing_mode": "MODEL_PRICED", "model": model_settings()}, base_dir=folder,
                                              resamples=200)
        published = agents.publish(output, overlay_artifact=self.write("model.json", modelled), rights_confirmed=True,
                                   generated_at="2026-02-01T00:00:00Z")
        overlay = published["overlay"]["artifact"]
        self.assertEqual((overlay["pricingMode"], overlay["evidenceStatus"]), ("MODEL_PRICED", overlay_engine.MODEL_LABEL))
        self.assertEqual(published["ledger"]["status"], "ARTIFACT_PENDING")
        self.assertTrue(all(leg["fillSide"] == "model" for cycle in overlay["cycles"] for leg in cycle["legs"]))
        relabelled = {**modelled, "evidence_status": "EXECUTABLE_QUOTES_OBSERVED"}
        with self.assertRaisesRegex(ValueError, overlay_engine.MODEL_LABEL):
            agents.publish(output, overlay_artifact=self.write("relabelled.json", relabelled), rights_confirmed=True,
                           generated_at="2026-02-01T00:00:00Z")
        with self.assertRaisesRegex(ValueError, "rights-confirmed"):
            agents.publication(overlay=overlay, ledger_section=None, rights_confirmed=False, generated_at="2026-02-01T00:00:00Z")

    def test_synthetic_fixture_is_regenerated_byte_for_byte(self):
        real = overlay_engine.run_overlay
        with patch("intraday_quant.overlay_lab.engine.run_overlay", wraps=real) as recorded:
            regenerated = agents.publication_bytes(agents.synthetic_publication())

        def environment_neutral(payload: bytes) -> bytes:
            # Unpinned CI installs may carry newer dependency releases. Trial receipts record dependency
            # versions as provenance, so the ledger head hash legitimately differs by environment.
            payload = re.sub(rb"exchange_calendars/[^/\"]+/XNYS", b"exchange_calendars/VERSION/XNYS", payload)
            return re.sub(rb'"headSha256": "[0-9a-f]{64}"', b'"headSha256": "HEAD"', payload)
        self.assertEqual(environment_neutral(regenerated), environment_neutral(FIXTURE.read_bytes()))
        fixture = json.loads(regenerated)
        self.assertRegex(fixture["ledger"]["ledger"]["headSha256"], r"^[0-9a-f]{64}$")
        self.assertEqual(fixture["overlay"]["artifact"]["evidenceStatus"], agents.SYNTHETIC)
        self.assertEqual(fixture["ledger"]["ledger"]["specs"][0]["status"], "BLOCKED")
        self.assertIn(["SYNTHETIC_EVIDENCE_CAPPED_AT_BACKTEST"], [event["reasons"] for event in fixture["ledger"]["ledger"]["events"]])
        # Sweeper trials saw development sessions only; the one full-window call is the published overlay itself.
        ends = sorted(max(bar["session_date"] for bar in call.args[0]["bars"]) for call in recorded.call_args_list)
        self.assertEqual(ends, ["2024-03-28"] * 3 + ["2024-06-28"])

    def test_cli_round_trip(self):
        source = self.write("mr-source.json", strategy_source())
        spec = self.spec(source)
        stub = EngineStub()

        def run(*argv):
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                foundry_main(list(argv))
            return json.loads(output.getvalue())

        with patch("intraday_quant.strategy_lab.research.run_engine", stub):
            self.assertEqual(run("draft", "--spec", str(spec), "--state-dir", str(self.state))["kind"], "SPEC_FROZEN")
            kinds = [event["kind"] for event in run("advance", "--state-dir", str(self.state), "--until-blocked")]
        self.assertEqual(kinds[-1], "PAPER_PROPOSAL_ISSUED")
        exported = self.root / "export.json"
        self.assertEqual(run("export", "--state-dir", str(self.state), "--output", str(exported))["event_count"], 6)
        dump = exported.read_text()
        self.assertNotIn("PRIVATE", dump)
        self.assertIs(json.loads(dump)["execution_authorized"], False)
        with self.assertRaises(SystemExit) as again, contextlib.redirect_stderr(io.StringIO()):
            foundry_main(["export", "--state-dir", str(self.state), "--output", str(exported)])
        self.assertEqual(again.exception.code, 2)
        summary = run("publish", "--output", str(self.root / "cli.json"), "--state-dir", str(self.state), "--rights-confirmed")
        self.assertEqual((summary["ledger"], summary["overlay"]), ("PUBLISHED", "ARTIFACT_PENDING"))
        self.assertIsNotNone(summary["generatedAt"])
        with self.assertRaises(SystemExit) as refused, contextlib.redirect_stderr(io.StringIO()):
            foundry_main(["publish", "--output", str(self.root / "refused.json"), "--state-dir", str(self.state)])
        self.assertEqual(refused.exception.code, 2)
        self.assertFalse((self.root / "refused.json").exists())


if __name__ == "__main__":
    unittest.main(argv=sys.argv[:1])

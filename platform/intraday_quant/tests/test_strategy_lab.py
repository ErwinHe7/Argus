from __future__ import annotations
import copy
import json
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

from intraday_quant.strategy_lab.research import (
    Registration, assess_retained_source, block_interval, evaluate_result, money, prepare, sensitivity, write_new,
)


def raw_source():
    return {"schema_version": "leo-strategy-source.v1", "symbol": "TEST", "strategy": "MR-v1", "code_revision": "unit-test",
            "evidence": {"source": "synthetic unit fixture", "dataset_sha256": "a" * 64, "calendar_source": "pending_official_verification",
                         "adjustment_verified": True, "coverage_verified": False, "availability_verified": True,
                         "classification": "synthetic_fixture", "license_scope": "test_only"},
            "bars": [{"session_date": day, "available_at": day + "T21:01:00Z", "open": "100", "high": "101", "low": "99", "close": "100", "volume": 100}
                     for day in ("2024-07-02", "2024-07-03", "2024-07-05")]}


def artifact():
    # Numerical fixtures test report accounting only; never export as market performance.
    points = [{"session_date": "2024-01-02", "net_return": 0.0}] * 220
    points += [{"session_date": f"2025-01-{day:02d}", "net_return": .001 if day % 2 else -.001} for day in range(1, 29)]
    return {"schema_version": "leo-strategy-lab.v1", "run_id": "a" * 64, "strategy": "MR-v1", "symbol": "TEST",
            "promotion_eligible": False, "execution_authorized": False, "fill_model": "DAILY_OPEN_PROXY_WITH_BAR_STOP_AND_ADVERSE_GAPS",
            "input_manifest": {"evidence": {"classification": "observed"}, "code_revision": "unit-test", "commission_per_order": "1", "slippage_bps": 10,
                               "bars": [{"close_at": "2025-01-28T21:00:00Z", "available_at": "2025-01-28T21:01:00Z"}]},
            "equity": points, "trades": [], "metrics": {}, "caveats": [], "open_position": None}


class StrategyResearchTests(unittest.TestCase):
    def test_exact_decimal_no_silent_rounding(self):
        self.assertEqual(money("0.10"), "0.100000")
        for value in (0.1, "NaN", "0.1234567"):
            with self.assertRaises(ValueError):
                money(value)

    def test_official_holiday_and_early_close_preparation(self):
        prepared = prepare(raw_source())
        self.assertTrue(prepared["evidence"]["coverage_verified"])
        self.assertEqual(prepared["bars"][1]["close_at"], "2024-07-03T17:00:00+00:00")
        self.assertEqual(prepared["bars"][2]["open_at"], "2024-07-05T13:30:00+00:00")

    def test_missing_or_duplicate_sessions_fail_closed(self):
        raw = raw_source()
        raw["bars"].pop(1)
        with self.assertRaisesRegex(ValueError, "coverage incomplete"):
            prepare(raw)
        raw = raw_source()
        raw["bars"].append(raw["bars"][-1])
        with self.assertRaisesRegex(ValueError, "duplicate"):
            prepare(raw)

    def test_unverified_adjustments_and_future_availability_fail_closed(self):
        raw = raw_source()
        raw["evidence"]["adjustment_verified"] = False
        with self.assertRaises(ValueError):
            prepare(raw)
        raw = raw_source()
        raw["bars"][0]["available_at"] = "2024-07-02T15:00:00Z"
        with self.assertRaisesRegex(ValueError, "before its session close"):
            prepare(raw)

    def test_synthetic_performance_is_rejected(self):
        result = artifact()
        result["input_manifest"]["evidence"]["classification"] = "synthetic_fixture"
        with self.assertRaisesRegex(ValueError, "synthetic"):
            evaluate_result(result)

    def test_bootstrap_reproducibility_and_no_promotion(self):
        returns = [.001, -.002, .002, -.001] * 8
        first = block_interval(returns, resamples=100)
        self.assertEqual(first, block_interval(returns, resamples=100))
        self.assertLess(first["lower_95"], first["upper_95"])
        self.assertEqual(block_interval([.001] * 5)["status"], "insufficient_sessions")
        report = evaluate_result(artifact(), resamples=100)
        self.assertFalse(report["promotion_eligible"])
        self.assertEqual(report["holdout"]["status"], "no_preregistration")

    def test_registration_cannot_retroactively_become_frozen(self):
        raw = {"schema_version": "leo-strategy-registration.v1", "experiment_id": "test", "strategy": "MR-v1", "symbol": "TEST",
               "frozen_at": "2025-01-02T00:00:00Z", "development_end": "2024-12-31", "holdout_start": "2025-01-01", "holdout_end": "2025-01-28",
               "minimum_sessions": 20, "minimum_net_return": .01, "maximum_drawdown": .05, "trial_count": 1, "prior_history_inspected": True}
        with self.assertRaises(ValueError):
            Registration.model_validate(raw)
        raw["frozen_at"] = "2024-12-31T00:00:00Z"
        result = artifact()
        result["trades"] = [{"entry_session": "2024-12-30", "exit_session": "2025-01-03"}]
        report = evaluate_result(result, raw, resamples=100)
        self.assertTrue(report["holdout"]["cross_boundary_position"])
        self.assertFalse(report["holdout"]["objective_checks_passed"])

    def test_capability_receipt_contains_no_private_market_values(self):
        raw = {"provider": "retained provider", "retrievedAt": "2026-09-06T00:00:00Z", "symbols": [
            {"symbol": "TEST", "history": {"bars": [{"date": "2026-09-04", "close": 123.456}], "adjustmentPolicy": "unknown"}, "snapshot": {"last": 123.456}}]}
        receipt = assess_retained_source(raw)
        self.assertFalse(receipt["strategy_evaluation_available"])
        self.assertNotIn("123.456", json.dumps(receipt))
        self.assertIn("fewer_than_220_completed_sessions", receipt["symbols"][0]["blockers"])

    def test_artifacts_are_immutable_by_default(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "receipt.json"
            write_new(path, {"a": 1})
            with self.assertRaises(FileExistsError):
                write_new(path, {"a": 2})
            self.assertEqual(json.loads(path.read_text())["a"], 1)

    def test_parameter_neighbors_use_rust_and_do_not_select_a_winner(self):
        calls = []
        def engine_stub(_engine, request):
            calls.append(copy.deepcopy(request))
            return {"run_id": str(len(calls)), "input_manifest": {"evidence": {"classification": "observed"}}, "metrics": {}}
        with patch("intraday_quant.strategy_lab.research.run_engine", side_effect=engine_stub):
            result = sensitivity(Path("unused-test-engine"), {"strategy": "MR-v1", "commission_per_order": "1", "slippage_bps": 10})
        self.assertEqual(len(calls), 9)
        self.assertFalse(result["selection_performed"])
        self.assertFalse(result["promotion_eligible"])
        self.assertIn({"mr_z_abs": 1.8}, [row.get("research_parameters") for row in calls])


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import json

import numpy as np
import pandas as pd
import pytest

from intraday_quant.backtest.validation import (
    HOLDOUT_MANIFEST_SCHEMA_VERSION,
    MARKET_BASELINE_MANIFEST_SCHEMA_VERSION,
    VALIDATION_SCHEMA_VERSION,
    benjamini_hochberg,
    build_validation_metrics,
    canonical_evidence_sha256,
    canonical_frame_sha256,
)


def _trades() -> pd.DataFrame:
    dates = pd.date_range("2026-01-05", periods=4, freq="B")
    gross = [0.010, 0.020, -0.010, 0.005]
    net = [value - 0.001 for value in gross]
    starts = pd.to_datetime(
        [
            "2026-01-05 10:00",
            "2026-01-06 10:00",
            "2026-01-07 10:00",
            "2026-01-08 10:00",
        ],
        utc=True,
    )
    return pd.DataFrame(
        {
            "date": dates.date,
            "gross_return": gross,
            "net_return": net,
            "entry_time": starts,
            "exit_time": starts + pd.Timedelta(minutes=15),
        }
    )


def test_validation_reports_gross_net_breakeven_and_cost_sensitivity() -> None:
    trades = _trades()
    result = build_validation_metrics(
        trades,
        configured_round_trip_cost_bps=10,
        bootstrap_resamples=200,
        random_seed=11,
    )

    assert result["schema_version"] == VALIDATION_SCHEMA_VERSION
    assert result["evidence_status"] == "descriptive_not_promotion_evidence"
    returns = result["return_metrics"]
    assert returns["gross_compounded_total_return"] == pytest.approx(
        np.prod(1 + trades["gross_return"]) - 1
    )
    assert returns["net_compounded_total_return"] == pytest.approx(
        np.prod(1 + trades["net_return"]) - 1
    )
    costs = result["cost_analysis"]
    assert costs["breakeven_round_trip_cost_bps"] == pytest.approx(62.5)
    assert costs["mean_inferred_realized_round_trip_cost_bps"] == pytest.approx(10)
    assert costs["cost_contract_status"] == (
        "configured_and_inferred_costs_match_within_0_1_bps"
    )
    assert costs["observed_net_edge_status"] == "positive_mean_net_return"
    ten_bps = next(
        row for row in costs["sensitivity"] if row["round_trip_cost_bps"] == 10
    )
    assert ten_bps["mean_net_return_per_trade"] == pytest.approx(
        trades["net_return"].mean()
    )
    assert costs["status"] == (
        "incomplete_without_historical_executable_quotes_and_order_size"
    )
    json.dumps(result, allow_nan=False)


def test_session_block_bootstrap_is_deterministic_and_never_claims_promotion() -> None:
    kwargs = {
        "configured_round_trip_cost_bps": 10,
        "bootstrap_resamples": 250,
        "random_seed": 19,
    }
    first = build_validation_metrics(_trades(), **kwargs)
    second = build_validation_metrics(_trades(), **kwargs)

    assert first["confidence_intervals"] == second["confidence_intervals"]
    confidence = first["confidence_intervals"]
    assert confidence["method"] == "moving_block_bootstrap_over_ordered_sessions"
    assert confidence["status"] == (
        "exploratory_small_sample_lt_30_sessions_and_trades"
    )
    assert confidence["mean_net_return_per_trade"]["lower"] is not None
    assert "promotion" in confidence["caveat"]
    effective = first["effective_sample_size"]
    assert effective["status"] == "estimated"
    assert 1 <= effective["effective_independent_sessions"] <= 4


def test_overlap_accounting_distinguishes_model_rows_from_fold_collisions() -> None:
    trades = pd.DataFrame(
        {
            "date": [pd.Timestamp("2026-01-05").date()] * 3,
            "gross_return": [0.01, 0.01, 0.01],
            "net_return": [0.009, 0.009, 0.009],
            "entry_time": pd.to_datetime(
                [
                    "2026-01-05 10:00",
                    "2026-01-05 10:15",
                    "2026-01-05 11:00",
                ],
                utc=True,
            ),
            "exit_time": pd.to_datetime(
                [
                    "2026-01-05 10:30",
                    "2026-01-05 10:20",
                    "2026-01-05 11:10",
                ],
                utc=True,
            ),
        }
    )
    predictions = pd.DataFrame(
        [
            {
                "candidate_id": "a",
                "horizon_minutes": 15,
                "fold": 0,
                "timestamp": "2026-01-05 10:00Z",
                "model": "logistic",
            },
            {
                "candidate_id": "a",
                "horizon_minutes": 15,
                "fold": 0,
                "timestamp": "2026-01-05 10:00Z",
                "model": "gradient_boosting",
            },
            {
                "candidate_id": "a",
                "horizon_minutes": 15,
                "fold": 1,
                "timestamp": "2026-01-05 10:00Z",
                "model": "logistic",
            },
        ]
    )

    overlap = build_validation_metrics(
        trades, predictions=predictions, bootstrap_resamples=20
    )["overlap_accounting"]
    intervals = overlap["executed_trade_intervals"]
    assert intervals["status"] == "overlap_detected"
    assert intervals["overlapping_trade_pairs"] == 1
    assert intervals["trades_in_any_overlap"] == 2
    assert intervals["maximum_concurrent_trades"] == 2
    folds = overlap["oos_prediction_fold_assignments"]
    assert folds["status"] == "test_fold_overlap_detected"
    assert folds["candidate_horizon_assignments_in_multiple_test_folds"] == 1
    assert folds["horizon_sessions_in_multiple_test_folds"] == 1
    assert folds["duplicate_model_family_rows_ignored"] == 1
    assert folds["training_vs_display_window_overlap"].startswith("not_assessable")


def test_label_accounting_keeps_late_and_missing_events_in_denominator() -> None:
    candidates = pd.DataFrame({"candidate_id": ["a", "b", "c"]})
    labels = pd.DataFrame(
        {
            "candidate_id": ["a", "b"],
            "forward_return_15m": [0.01, np.nan],
            "forward_label_status_15m": [
                "eligible",
                "excluded_insufficient_forward_bars",
            ],
        }
    )
    predictions = pd.DataFrame(
        {
            "candidate_id": ["a"],
            "horizon_minutes": [15],
            "fold": [0],
            "timestamp": ["2026-01-05 10:00Z"],
        }
    )
    result = build_validation_metrics(
        pd.DataFrame(),
        candidates=candidates,
        labels=labels,
        predictions=predictions,
        forecast_horizons=[15],
        configured_round_trip_cost_bps=5,
        bootstrap_resamples=20,
    )

    accounting = result["label_exclusion_accounting"]
    assert accounting["status"] == "explicit_exclusion_reasons_reported"
    assert accounting["detected_candidate_rows"] == 3
    assert accounting["candidates_dropped_before_label_row"] == 1
    horizon = accounting["horizons"][0]
    assert horizon["detected_candidate_count"] == 3
    assert horizon["finite_forward_label_count"] == 1
    assert horizon["nonfinite_forward_label_count"] == 1
    assert horizon["late_or_session_boundary_exclusion_count"] == 1
    assert horizon["status_value_mismatch_count"] == 0
    assert horizon["finite_label_coverage_rate"] == pytest.approx(1 / 3)
    assert horizon["distinct_candidates_with_oos_prediction"] == 1
    assert horizon["status_counts"] == {
        "eligible": 1,
        "excluded_insufficient_forward_bars": 1,
    }
    baseline = result["baselines"]
    assert baseline["candidate_universe_no_model_selection"][0][
        "mean_gross_return"
    ] == pytest.approx(0.01)
    assert baseline["market_unconditional_baseline_status"].startswith(
        "not_available"
    )


@pytest.mark.parametrize("columns", [[], ["gross_return", "net_return", "date"]])
def test_empty_validation_is_explicitly_unavailable(columns) -> None:
    result = build_validation_metrics(pd.DataFrame(columns=columns), forecast_horizons=[5])

    assert result["return_metrics"]["paired_finite_trade_count"] == 0
    assert result["confidence_intervals"]["status"] == "insufficient_data"
    assert result["cost_analysis"]["breakeven_round_trip_cost_bps"] is None
    assert result["effective_sample_size"]["status"].startswith("not_estimable")
    assert result["label_exclusion_accounting"]["horizons"][0][
        "finite_label_coverage_rate"
    ] is None
    assert result["stability"]["monthly"]["status"].startswith(("unavailable", "insufficient_data"))
    assert result["stability"]["regime"]["status"] == "unavailable_no_trades"
    assert result["untouched_holdout"]["status"] == "not_supplied"
    assert result["baselines"]["point_in_time_market"]["status"].startswith(
        "not_available"
    )


def test_monthly_and_causal_regime_stability_are_separate_diagnostics() -> None:
    signal_times = pd.to_datetime(
        [
            "2026-01-05 15:00Z",
            "2026-01-06 15:00Z",
            "2026-02-05 15:00Z",
            "2026-02-06 15:00Z",
            "2026-03-05 15:00Z",
            "2026-03-06 15:00Z",
            "2026-04-06 15:00Z",
            "2026-04-07 15:00Z",
        ]
    )
    trades = pd.DataFrame(
        {
            "date": signal_times.date,
            "gross_return": [0.01, -0.004, 0.006, 0.003, -0.002, 0.005, 0.004, 0.002],
            "net_return": [0.009, -0.005, 0.005, 0.002, -0.003, 0.004, 0.003, 0.001],
            "signal_time": signal_times,
            "entry_time": signal_times + pd.Timedelta(minutes=1),
            "exit_time": signal_times + pd.Timedelta(minutes=16),
            "regime": ["calm"] * 4 + ["volatile"] * 4,
            "regime_observed_at": signal_times - pd.Timedelta(minutes=1),
            "regime_model_version": ["hmm-v3"] * 8,
            "regime_feature_version": ["features-v7"] * 8,
        }
    )
    candidate_dates = list(signal_times.date) + [
        pd.Timestamp("2026-01-07").date(),
        pd.Timestamp("2026-04-08").date(),
    ]

    result = build_validation_metrics(
        trades,
        candidate_dates=candidate_dates,
        forecast_horizons=[15],
        bootstrap_resamples=20,
        monthly_stability_minimum_months=4,
        regime_stability_minimum_trades=4,
        placebo_minimum_sessions=4,
        placebo_resamples=100,
        random_seed=23,
    )

    monthly = result["stability"]["monthly"]
    assert monthly["status"] == "reported_descriptive"
    assert monthly["month_count"] == 4
    assert sum(row["observed_session_count"] for row in monthly["months"]) == 10
    assert sum(row["no_trade_session_count"] for row in monthly["months"]) == 2
    regime = result["stability"]["regime"]
    assert regime["status"] == "reported_descriptive"
    assert regime["regime_model_version"] == "hmm-v3"
    assert regime["regime_feature_version"] == "features-v7"
    assert [row["regime"] for row in regime["regimes"]] == ["calm", "volatile"]
    assert all(row["trade_count"] == 4 for row in regime["regimes"])
    assert regime["scope"] == "selected out-of-sample trades only"

    noncausal = trades.copy()
    noncausal.loc[0, "regime_observed_at"] = noncausal.loc[0, "signal_time"] + pd.Timedelta(
        minutes=1
    )
    blocked = build_validation_metrics(
        noncausal,
        forecast_horizons=[15],
        bootstrap_resamples=20,
        placebo_minimum_sessions=4,
        placebo_resamples=20,
    )["stability"]["regime"]
    assert blocked["status"] == "invalid_or_noncausal_regime_rows_fail_closed"
    assert blocked["regime_observed_after_signal_rows"] == 1
    assert blocked["regimes"] == []


def test_placebo_and_benjamini_hochberg_are_deterministic_and_fail_closed() -> None:
    trades = _trades()
    kwargs = {
        "forecast_horizons": [15],
        "bootstrap_resamples": 20,
        "placebo_resamples": 250,
        "placebo_minimum_sessions": 4,
        "random_seed": 31,
    }
    first = build_validation_metrics(trades, **kwargs)
    second = build_validation_metrics(trades, **kwargs)
    placebo = first["negative_controls"]["session_clustered_sign_flip"]
    assert placebo == second["negative_controls"]["session_clustered_sign_flip"]
    assert placebo["status"] == "reported_diagnostic_not_promotion_evidence"
    assert placebo["resamples"] == 250
    assert 0 < placebo["two_sided_plus_one_p_value"] <= 1

    hypotheses = pd.DataFrame(
        {
            "hypothesis_id": ["h1", "h2", "h3", "control"],
            "family": ["returns", "returns", "returns", "diagnostics"],
            "p_value": [0.01, 0.03, 0.20, 0.04],
            "test_kind": ["primary", "primary", "primary", "negative_control"],
            "pre_registered": [True, True, False, True],
        }
    )
    corrected = benjamini_hochberg(hypotheses, alpha=0.05)
    assert corrected["status"] == "reported_descriptive_not_promotion_evidence"
    returns_family = next(
        family for family in corrected["families"] if family["family"] == "returns"
    )
    results = {
        row["hypothesis_id"]: row for row in returns_family["results"]
    }
    assert results["h1"]["adjusted_p_value"] == pytest.approx(0.03)
    assert results["h2"]["adjusted_p_value"] == pytest.approx(0.045)
    assert results["h3"]["adjusted_p_value"] == pytest.approx(0.20)
    assert results["h1"]["rejected_at_alpha"] is True
    assert results["h3"]["evidence_scope"] == "exploratory_not_pre_registered"

    invalid = hypotheses.copy()
    invalid.loc[1, "p_value"] = 1.2
    blocked = benjamini_hochberg(invalid)
    assert blocked["status"] == "partial_fail_closed_invalid_families"
    invalid_family = next(
        family for family in blocked["families"] if family["family"] == "returns"
    )
    assert invalid_family["status"] == "invalid_p_values_fail_closed"
    assert invalid_family["results"] == []


def test_untouched_holdout_is_hash_bound_temporally_separate_and_not_merged() -> None:
    primary = _trades()
    holdout_times = pd.to_datetime(
        ["2026-02-02 15:00Z", "2026-02-03 15:00Z"]
    )
    holdout = pd.DataFrame(
        {
            "trade_id": ["holdout-1", "holdout-2"],
            "date": holdout_times.date,
            "gross_return": [0.02, -0.005],
            "net_return": [0.019, -0.006],
        }
    )
    bound_columns = list(holdout.columns)
    manifest = {
        "schema_version": HOLDOUT_MANIFEST_SCHEMA_VERSION,
        "dataset_columns": bound_columns,
        "dataset_sha256": canonical_frame_sha256(holdout, bound_columns),
        "artifact_sha256": "a" * 64,
        "training_end": "2025-12-31T23:59:59Z",
        "validation_end": "2026-01-31T23:59:59Z",
        "holdout_start": "2026-02-01T00:00:00Z",
        "holdout_end": "2026-02-28T23:59:59Z",
        "selection_completed_at": "2026-01-31T20:00:00Z",
        "holdout_sealed_at": "2026-02-28T23:59:59Z",
        "evaluation_started_at": "2026-03-01T00:00:00Z",
        "used_for_model_selection": False,
        "used_for_threshold_selection": False,
        "used_for_calibration": False,
    }
    result = build_validation_metrics(
        primary,
        untouched_holdout_trades=holdout,
        untouched_holdout_manifest=manifest,
        forecast_horizons=[15],
        bootstrap_resamples=20,
    )

    report = result["untouched_holdout"]
    assert report["status"] == (
        "reported_separate_holdout_descriptive_not_promotion_evidence"
    )
    assert report["hash_status"] == "dataset_sha256_verified"
    assert report["holdout_trade_count"] == 2
    assert report["mean_net_return_per_trade"] == pytest.approx(0.0065)
    assert report["mean_inferred_round_trip_cost_bps"] == pytest.approx(10)
    assert result["return_metrics"]["paired_finite_trade_count"] == len(primary)
    json.dumps(result, allow_nan=False)

    tampered = holdout.copy()
    tampered.loc[0, "net_return"] = 0.20
    blocked = build_validation_metrics(
        primary,
        untouched_holdout_trades=tampered,
        untouched_holdout_manifest=manifest,
        forecast_horizons=[15],
        bootstrap_resamples=20,
    )["untouched_holdout"]
    assert blocked["status"] == "holdout_dataset_receipt_invalid_fail_closed"
    assert blocked["hash_status"] == "dataset_sha256_mismatch"

    naive_manifest = dict(manifest)
    naive_manifest["evaluation_started_at"] = "2026-03-01T00:00:00"
    blocked = build_validation_metrics(
        primary,
        untouched_holdout_trades=holdout,
        untouched_holdout_manifest=naive_manifest,
        forecast_horizons=[15],
        bootstrap_resamples=20,
    )["untouched_holdout"]
    assert blocked["status"] == (
        "invalid_or_overlapping_manifest_boundaries_fail_closed"
    )


def test_verified_point_in_time_market_baseline_and_exact_time_placebo() -> None:
    timestamps = pd.to_datetime(
        [
            "2026-01-05 15:00Z",
            "2026-01-06 15:00Z",
            "2026-01-07 15:00Z",
            "2026-01-08 15:00Z",
        ]
    )
    grid = pd.DataFrame(
        {
            "timestamp": timestamps,
            "symbol": ["SPY"] * 4,
            "horizon_minutes": [15] * 4,
            "forward_return": [0.01, -0.004, 0.006, -0.002],
            "label_status": ["eligible"] * 4,
            "source": ["databento"] * 4,
        }
    )
    grid_columns = list(grid.columns)
    integrity_receipt = {
        "status": "complete_point_in_time_grid",
        "synthetic": False,
        "duplicate_rows": 0,
        "conflicting_rows": 0,
        "incomplete_sessions": 0,
        "causality_violations": 0,
        "source": "databento",
        "observed_rows": 4,
        "expected_rows": 4,
        "session_count": 4,
    }
    manifest = {
        "schema_version": MARKET_BASELINE_MANIFEST_SCHEMA_VERSION,
        "dataset_columns": grid_columns,
        "dataset_sha256": canonical_frame_sha256(grid, grid_columns),
        "integrity_receipt": integrity_receipt,
        "integrity_receipt_sha256": canonical_evidence_sha256(integrity_receipt),
        "point_in_time_data": True,
        "regular_grid": True,
        "synthetic": False,
        "bar_interval_minutes": 1,
        "entry_lag_minutes": 1,
        "return_convention": "entry_open_t_plus_1_to_close_t_plus_h",
        "source": "databento",
    }
    candidates = pd.DataFrame(
        {
            "candidate_id": ["a", "b", "c", "d"],
            "timestamp": timestamps,
            "direction": [1, -1, 1, -1],
        }
    )
    trades = pd.DataFrame(
        {
            "trade_id": ["a", "b", "c", "d"],
            "date": timestamps.date,
            "gross_return": [0.009, 0.003, 0.005, 0.001],
            "net_return": [0.008, 0.002, 0.004, 0.0],
            "signal_time": timestamps,
            "entry_time": timestamps + pd.Timedelta(minutes=1),
            "exit_time": timestamps + pd.Timedelta(minutes=16),
            "direction": [1, -1, 1, -1],
            "horizon_minutes": [15] * 4,
        }
    )

    result = build_validation_metrics(
        trades,
        candidates=candidates,
        point_in_time_market_grid=grid,
        point_in_time_market_manifest=manifest,
        forecast_horizons=[15],
        configured_round_trip_cost_bps=10,
        bootstrap_resamples=20,
        market_baseline_minimum_observations=4,
        market_baseline_minimum_sessions=4,
        market_baseline_minimum_match_rate=1.0,
        direction_placebo_minimum_observations=4,
    )

    baseline = result["baselines"]["point_in_time_market"]
    assert baseline["status"] == "reported_descriptive"
    assert result["baselines"]["market_unconditional_baseline_status"] == (
        "available_from_verified_point_in_time_grid"
    )
    assert baseline["hash_status"] == "dataset_sha256_verified"
    full_market = baseline["full_market_by_horizon"][0]
    assert full_market["status"] == "reported_descriptive"
    assert full_market["mean_gross_return"] == pytest.approx(0.0025)
    matched = baseline["candidate_time_matched"]
    assert matched["status"] == "reported_descriptive"
    assert matched["exact_match_rate"] == 1.0
    assert matched["mean_event_direction_signed_market_return"] == pytest.approx(
        0.0055
    )
    shift = matched["direction_shift_placebos"][0]
    assert shift["status"] == "reported_diagnostic_not_promotion_evidence"
    assert shift["placebo_shift_count"] == 3
    assert result["negative_controls"]["candidate_direction_label_shift"] == [
        shift
    ]
    assert result["multiple_testing"]["generated_placebo_hypothesis_count"] == 2
    assert result["multiple_testing"]["status"] == (
        "reported_descriptive_not_promotion_evidence"
    )
    json.dumps(result, allow_nan=False)

    bad_manifest = dict(manifest)
    bad_manifest["synthetic"] = True
    blocked = build_validation_metrics(
        trades,
        candidates=candidates,
        point_in_time_market_grid=grid,
        point_in_time_market_manifest=bad_manifest,
        forecast_horizons=[15],
        bootstrap_resamples=20,
    )["baselines"]["point_in_time_market"]
    assert blocked["status"] == "point_in_time_grid_manifest_invalid_fail_closed"


def test_canonical_frame_hash_is_order_invariant_and_value_sensitive() -> None:
    frame = pd.DataFrame(
        {
            "timestamp": pd.to_datetime(
                ["2026-01-05 15:00Z", "2026-01-06 15:00Z"]
            ),
            "value": [0.01, np.nan],
            "label": ["a", "b"],
        }
    )
    first = canonical_frame_sha256(frame)
    reordered = frame.iloc[::-1][["label", "value", "timestamp"]]
    assert canonical_frame_sha256(reordered) == first
    changed = frame.copy()
    changed.loc[0, "value"] = 0.011
    assert canonical_frame_sha256(changed) != first

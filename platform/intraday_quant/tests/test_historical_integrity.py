from __future__ import annotations

from datetime import date

import numpy as np
import pandas as pd
import pytest

from intraday_quant.data.clean import clean_bars
from intraday_quant.data.integrity import (
    DataIntegrityError,
    enforce_complete_panel_sessions,
)
from intraday_quant.labels.pipeline import build_labels
from intraday_quant.models.walk_forward import _dataset
from intraday_quant.training.cuda_challenger import aggregate_to_five_minutes


def _bar(timestamp: object, symbol: str = "SPX", close: float = 100.0) -> dict[str, object]:
    return {
        "timestamp": timestamp,
        "symbol": symbol,
        "open": close,
        "high": close + 0.5,
        "low": close - 0.5,
        "close": close,
        "volume": 100,
        "vwap": close,
        "bid": close - 0.1,
        "ask": close + 0.1,
        "trade_count": 10,
        "source": "licensed-test",
        "data_quality": "ok",
    }


def _candidate(timestamp: pd.Timestamp) -> pd.DataFrame:
    return pd.DataFrame(
        [
            {
                "candidate_id": "event-1",
                "timestamp": timestamp,
                "session_date": timestamp.date(),
                "setup_type": "test",
                "direction": 1,
                "entry_reference": 100.0,
                "feature_snapshot": "{}",
                "reason_codes": "test",
            }
        ]
    )


def _feature_frame(timestamps: pd.DatetimeIndex) -> pd.DataFrame:
    values = np.linspace(100.0, 101.0, len(timestamps))
    return pd.DataFrame(
        {
            "timestamp": timestamps,
            "open": values,
            "high": values + 0.1,
            "low": values - 0.1,
            "close": values,
            "rolling_atr": 0.2,
            "ret_1m": 0.001,
        }
    )


def test_malformed_timestamp_fails_closed_instead_of_being_skipped() -> None:
    raw = pd.DataFrame(
        [_bar("2026-03-09 09:30"), _bar("not-a-timestamp", close=101.0)]
    )
    with pytest.raises(DataIntegrityError, match="session coverage cannot be proven"):
        clean_bars(raw, "America/New_York")


def test_exact_duplicate_collapses_but_conflicting_duplicate_is_quarantined() -> None:
    exact = pd.DataFrame([_bar("2026-03-09 09:30")] * 2)
    cleaned, stats = clean_bars(exact, "America/New_York")
    assert len(cleaned) == 1
    assert stats["exact_duplicate_rows_removed"] == 1
    assert stats["ambiguous_duplicate_rows_removed"] == 0

    conflicting = pd.DataFrame(
        [_bar("2026-03-09 09:30"), _bar("2026-03-09 09:30", close=101.0)]
    )
    cleaned, stats = clean_bars(conflicting, "America/New_York")
    assert cleaned.empty
    assert stats["ambiguous_duplicate_keys"] == 1
    assert stats["ambiguous_duplicate_rows_removed"] == 2


def test_non_minute_and_malformed_numeric_rows_are_never_filled() -> None:
    raw = pd.DataFrame(
        [
            _bar("2026-03-09 09:30:30"),
            {**_bar("2026-03-09 09:31"), "close": "not-a-price"},
        ]
    )
    cleaned, stats = clean_bars(raw, "America/New_York", price_ffill_limit=99)
    assert cleaned.empty
    assert stats["non_minute_aligned_rows_removed"] == 1
    assert stats["malformed_numeric_rows_removed"] == 1
    assert stats["price_values_forward_filled"] == 0


def test_incomplete_symbol_excludes_the_entire_panel_session() -> None:
    timezone = "America/New_York"
    first = date(2026, 1, 5)
    second = date(2026, 1, 6)
    schedule = pd.DataFrame(
        {
            "open": [
                pd.Timestamp("2026-01-05 09:30", tz=timezone),
                pd.Timestamp("2026-01-06 09:30", tz=timezone),
            ],
            "close": [
                pd.Timestamp("2026-01-05 09:35", tz=timezone),
                pd.Timestamp("2026-01-06 09:35", tz=timezone),
            ],
        },
        index=[first, second],
    )
    rows: list[dict[str, object]] = []
    for day in ("2026-01-05", "2026-01-06"):
        for symbol in ("SPX", "SPY"):
            for timestamp in pd.date_range(
                f"{day} 09:30", periods=5, freq="1min", tz=timezone
            ):
                if day == "2026-01-05" and symbol == "SPY" and timestamp.minute == 32:
                    continue
                rows.append(_bar(timestamp, symbol))
    result = enforce_complete_panel_sessions(
        pd.DataFrame(rows),
        schedule,
        ["SPX", "SPY"],
    )
    assert set(result.bars["timestamp"].dt.date) == {second}
    assert result.stats["complete_panel_sessions"] == 1
    assert result.stats["excluded_incomplete_panel_sessions"] == 1
    assert result.stats["missing_expected_bars"] == 1
    rejected = result.session_audit.query(
        "session_date == @first and symbol == 'SPY'"
    ).iloc[0]
    assert rejected["status"] == "excluded_incomplete"
    assert rejected["missing_bars"] == 1


def test_five_minute_schedule_rejects_off_grid_timestamp() -> None:
    timezone = "America/New_York"
    session_date = date(2026, 1, 5)
    schedule = pd.DataFrame(
        {
            "open": [pd.Timestamp("2026-01-05 09:30", tz=timezone)],
            "close": [pd.Timestamp("2026-01-05 09:45", tz=timezone)],
        },
        index=[session_date],
    )
    timestamps = pd.DatetimeIndex(
        [
            pd.Timestamp("2026-01-05 09:30", tz=timezone),
            pd.Timestamp("2026-01-05 09:35", tz=timezone),
            pd.Timestamp("2026-01-05 09:41", tz=timezone),
        ]
    )
    result = enforce_complete_panel_sessions(
        pd.DataFrame([_bar(timestamp) for timestamp in timestamps]),
        schedule,
        ["SPX"],
        frequency="5min",
    )
    assert result.bars.empty
    assert result.stats["missing_expected_bars"] == 1
    assert result.stats["unexpected_timestamp_bars"] == 1


def test_forward_label_requires_exact_real_minutes_and_accounts_for_event(config) -> None:
    timestamps = pd.date_range(
        "2026-01-05 09:30",
        periods=20,
        freq="1min",
        tz="America/New_York",
    ).delete(4)
    cfg = config.model_copy(update={"forecast_horizons": [5, 15]})
    labels = build_labels(
        _candidate(pd.Timestamp("2026-01-05 09:30", tz="America/New_York")),
        _feature_frame(timestamps),
        cfg,
    )
    assert len(labels) == 1
    label = labels.iloc[0]
    assert label["entry_status"] == "eligible"
    assert label["forward_label_status_5m"] == "excluded_non_contiguous_forward_bars"
    assert label["forward_label_status_15m"] == "excluded_non_contiguous_forward_bars"
    assert pd.isna(label["forward_return_5m"])
    assert label["eligible_forward_horizon_count"] == 0
    assert label["excluded_forward_horizon_count"] == 2


def test_late_event_is_retained_with_explicit_insufficient_forward_status(config) -> None:
    timestamps = pd.date_range(
        "2026-01-05 15:55",
        periods=5,
        freq="1min",
        tz="America/New_York",
    )
    cfg = config.model_copy(update={"forecast_horizons": [5, 15]})
    labels = build_labels(
        _candidate(pd.Timestamp("2026-01-05 15:58", tz="America/New_York")),
        _feature_frame(timestamps),
        cfg,
    )
    assert len(labels) == 1
    label = labels.iloc[0]
    assert label["entry_status"] == "eligible"
    assert label["forward_label_status_5m"] == "excluded_insufficient_forward_bars"
    assert label["forward_label_status_15m"] == "excluded_insufficient_forward_bars"
    assert label["barrier_label_status"] == "eligible_truncated_at_session_close"
    assert pd.notna(label["triple_barrier_return"])


def test_missing_exact_entry_does_not_silently_drop_candidate(config) -> None:
    timestamps = pd.date_range(
        "2026-01-05 09:58",
        periods=5,
        freq="1min",
        tz="America/New_York",
    ).delete(3)
    cfg = config.model_copy(update={"forecast_horizons": [5]})
    labels = build_labels(
        _candidate(pd.Timestamp("2026-01-05 10:00", tz="America/New_York")),
        _feature_frame(timestamps),
        cfg,
    )
    assert len(labels) == 1
    assert labels.iloc[0]["entry_status"] == "excluded_missing_exact_next_minute_entry"
    assert (
        labels.iloc[0]["forward_label_status_5m"]
        == "excluded_missing_exact_next_minute_entry"
    )


def test_training_dataset_only_accepts_explicitly_eligible_labels() -> None:
    timestamp = pd.Timestamp("2026-01-05 10:00", tz="America/New_York")
    labels = pd.DataFrame(
        [
            {
                "candidate_id": "eligible",
                "timestamp": timestamp,
                "session_date": timestamp.date(),
                "direction": 1,
                "forward_return_5m": 0.01,
                "MFE_5m": 0.02,
                "MAE_5m": 0.005,
                "forward_label_status_5m": "eligible",
            },
            {
                "candidate_id": "excluded",
                "timestamp": timestamp + pd.Timedelta(minutes=1),
                "session_date": timestamp.date(),
                "direction": 1,
                "forward_return_5m": np.nan,
                "MFE_5m": np.nan,
                "MAE_5m": np.nan,
                "forward_label_status_5m": "excluded_insufficient_forward_bars",
            },
        ]
    )
    features = pd.DataFrame(
        {
            "timestamp": [timestamp, timestamp + pd.Timedelta(minutes=1)],
            "ret_1m": [0.001, 0.002],
        }
    )
    dataset = _dataset(labels, features, 5, 0.001)
    assert dataset["candidate_id"].tolist() == ["eligible"]


def test_training_dataset_rejects_legacy_labels_without_eligibility() -> None:
    timestamp = pd.Timestamp("2026-01-05 10:00", tz="America/New_York")
    labels = pd.DataFrame(
        [
            {
                "candidate_id": "legacy",
                "timestamp": timestamp,
                "session_date": timestamp.date(),
                "direction": 1,
                "forward_return_5m": 0.01,
                "MFE_5m": 0.02,
                "MAE_5m": 0.005,
            }
        ]
    )
    features = pd.DataFrame({"timestamp": [timestamp], "ret_1m": [0.001]})
    with pytest.raises(DataIntegrityError, match="missing explicit label eligibility"):
        _dataset(labels, features, 5, 0.001)


def test_cuda_five_minute_aggregation_uses_complete_real_minutes() -> None:
    timestamps = pd.date_range(
        "2026-01-05 09:30",
        periods=390,
        freq="1min",
        tz="America/New_York",
    )
    bars = pd.DataFrame(
        {
            "symbol": "SPY",
            "timestamp": timestamps,
            "open": 100.0,
            "high": 100.1,
            "low": 99.9,
            "close": 100.0,
            "volume": 100,
        }
    )
    complete = aggregate_to_five_minutes(bars)
    assert len(complete) == 78
    assert complete["source_minutes"].eq(5).all()
    assert complete["source_unique_minutes"].eq(5).all()
    assert complete["source_contiguous"].all()

    incomplete = aggregate_to_five_minutes(bars.drop(index=2))
    assert incomplete.empty
    assert incomplete.attrs["integrity_stats"]["excluded_incomplete_panel_sessions"] == 1

    missing_symbol = aggregate_to_five_minutes(
        bars,
        required_symbols=["SPY", "QQQ"],
    )
    assert missing_symbol.empty
    assert missing_symbol.attrs["integrity_stats"]["missing_expected_bars"] == 390

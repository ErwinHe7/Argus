from __future__ import annotations

import numpy as np
import pandas as pd
import pytest

from intraday_quant.demo.dataset import load_and_normalize_spy
from intraday_quant.demo.features import (
    FEATURE_COLUMNS,
    build_examples,
    chronological_split,
)


@pytest.fixture
def normalized_bars(sample_parquet) -> pd.DataFrame:
    normalized, report = load_and_normalize_spy(sample_parquet)
    assert report.unresolved_gap_rows == 0
    return normalized


def _timestamp_at(bars: pd.DataFrame, session_date: object, minute: int) -> pd.Timestamp:
    return bars.loc[
        (bars["session_date"] == session_date) & (bars["minute_of_session"] == minute),
        "timestamp",
    ].iloc[0]


def test_future_rows_do_not_change_existing_features(normalized_bars: pd.DataFrame) -> None:
    cutoff_session = sorted(normalized_bars.session_date.unique())[24]
    cutoff = normalized_bars.loc[
        normalized_bars.session_date == cutoff_session, "timestamp"
    ].iloc[80]

    before = build_examples(normalized_bars.loc[normalized_bars.timestamp <= cutoff])
    after = build_examples(normalized_bars)
    columns = ["timestamp", *FEATURE_COLUMNS]

    pd.testing.assert_frame_equal(
        before[columns].reset_index(drop=True),
        after.loc[after.timestamp.isin(before.timestamp), columns].reset_index(drop=True),
    )


def test_target_is_exactly_five_minutes_forward(normalized_bars: pd.DataFrame) -> None:
    examples = build_examples(normalized_bars)
    row = examples.iloc[0]
    future = normalized_bars.loc[
        normalized_bars.timestamp == row.timestamp + pd.Timedelta(minutes=5)
    ].iloc[0]

    assert row.target_return == pytest.approx(future.close / row.close - 1.0)
    assert row.target_up == int(future.close > row.close)


def test_506_session_split_has_two_embargoes() -> None:
    dates = pd.bdate_range("2024-01-02", periods=506).date.tolist()
    split = chronological_split(dates)

    assert len(split.train) == 354
    assert len(split.validation) == 75
    assert len(split.test) == 75
    assert split.train_validation_embargo == dates[354]
    assert split.validation_test_embargo == dates[430]


def test_unresolved_gap_excludes_lookback_and_outcome_windows(
    normalized_bars: pd.DataFrame,
) -> None:
    bars = normalized_bars.copy()
    session_date = sorted(bars.session_date.unique())[30]
    gap_timestamp = _timestamp_at(bars, session_date, 50)
    bars.loc[bars.timestamp == gap_timestamp, "is_unresolved_gap"] = True

    examples = build_examples(bars)

    assert _timestamp_at(bars, session_date, 45) not in set(examples.timestamp)
    assert _timestamp_at(bars, session_date, 80) not in set(examples.timestamp)
    session_examples = examples.loc[examples.session_date == session_date]
    assert all(
        not (
            (gap_timestamp >= example.timestamp - pd.Timedelta(minutes=30))
            and (gap_timestamp <= example.timestamp + pd.Timedelta(minutes=5))
        )
        for example in session_examples.itertuples()
    )


def test_causal_fill_window_is_retained_and_flagged(normalized_bars: pd.DataFrame) -> None:
    bars = normalized_bars.copy()
    session_date = sorted(bars.session_date.unique())[30]
    fill_timestamp = _timestamp_at(bars, session_date, 50)
    bars.loc[bars.timestamp == fill_timestamp, "is_causal_fill"] = True

    examples = build_examples(bars)
    example = examples.loc[
        examples.timestamp == _timestamp_at(bars, session_date, 80)
    ].iloc[0]

    assert example.quality_flags == ("WINDOW_CONTAINS_CAUSAL_FILL",)


def test_same_minute_relative_volume_uses_only_prior_sessions(
    normalized_bars: pd.DataFrame,
) -> None:
    bars = normalized_bars.copy()
    dates = sorted(bars.session_date.unique())
    minute = 100
    for session_date in dates[5:25]:
        bars.loc[
            (bars.session_date == session_date) & (bars.minute_of_session == minute),
            "volume",
        ] = 100.0
    target_date = dates[25]
    bars.loc[
        (bars.session_date == target_date) & (bars.minute_of_session == minute),
        "volume",
    ] = 1000.0

    examples = build_examples(bars)
    example = examples.loc[
        examples.timestamp == _timestamp_at(bars, target_date, minute)
    ].iloc[0]

    assert example.rvol_same_minute_20d == pytest.approx(10.0)


def test_split_membership_uses_all_normalized_sessions_before_exclusions(
    normalized_bars: pd.DataFrame,
) -> None:
    examples = build_examples(normalized_bars)
    dates = sorted(normalized_bars.session_date.unique())
    expected = chronological_split(dates)
    test_date = expected.test[0]
    example = examples.loc[examples.session_date == test_date].iloc[0]

    assert example.split == "test"
    assert len(expected.train) == int(len(dates) * 0.70)
    assert expected.train_validation_embargo not in set(examples.session_date.unique())
    assert expected.validation_test_embargo not in set(examples.session_date.unique())
    assert examples.attrs["eligible_examples"] == len(examples)
    assert examples.attrs["excluded_examples"] == len(normalized_bars) - len(examples)
    assert examples.attrs["split_definition"] == expected


def test_zero_feature_denominators_are_excluded_instead_of_emitting_infinity(
    normalized_bars: pd.DataFrame,
) -> None:
    bars = normalized_bars.copy()
    session_date = sorted(bars.session_date.unique())[30]
    zero_range = bars.session_date == session_date
    bars.loc[zero_range, "high"] = bars.loc[zero_range, "close"]
    bars.loc[zero_range, "low"] = bars.loc[zero_range, "close"]

    examples = build_examples(bars)

    assert examples.loc[examples.session_date == session_date].empty
    assert np.isfinite(examples.loc[:, FEATURE_COLUMNS].to_numpy(dtype=float)).all()

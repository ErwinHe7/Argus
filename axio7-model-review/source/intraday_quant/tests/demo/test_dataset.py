from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from .conftest import bars_for
from intraday_quant.demo.dataset import (
    load_and_normalize_spy,
    normalize_spy_frame,
    read_spy_parquet,
    strict_xnys_schedule,
)


def test_early_close_discards_post_close_prints() -> None:
    frame = bars_for("2025-07-03", periods=211)
    normalized, report = normalize_spy_frame(frame)
    assert (
        normalized.loc[~normalized.is_unresolved_gap, "timestamp"]
        .max()
        .tz_convert("America/New_York")
        .strftime("%H:%M")
        == "12:59"
    )
    assert report.post_close_rows_removed == 1


def test_two_minute_gap_is_causally_filled() -> None:
    frame = bars_for("2026-01-05").drop(index=[1, 2])
    normalized, report = normalize_spy_frame(frame, max_fill_minutes=2)
    filled = normalized.loc[normalized.is_causal_fill]
    assert filled.close.tolist() == [frame.iloc[0].close, frame.iloc[0].close]
    assert filled.volume.tolist() == [0, 0]
    assert report.causal_fill_rows == 2


def test_three_minute_gap_remains_unresolved() -> None:
    frame = bars_for("2026-01-05").drop(index=[1, 2, 3])
    normalized, report = normalize_spy_frame(frame, max_fill_minutes=2)
    assert normalized.is_unresolved_gap.sum() == 3
    assert report.unresolved_gap_rows == 3


def test_strict_schedule_uses_official_xnys_early_close() -> None:
    session_date = pd.Timestamp("2025-07-03").date()
    schedule = strict_xnys_schedule(session_date, session_date)
    assert schedule.loc[pd.Timestamp("2025-07-03").date(), "close"].tz_convert(
        "America/New_York"
    ).strftime("%H:%M") == "13:00"


def test_read_spy_parquet_rejects_non_spy_symbol(tmp_path: Path) -> None:
    frame = bars_for("2026-01-05", periods=1)
    frame.loc[0, "symbol"] = "QQQ"
    path = tmp_path / "wrong-symbol.parquet"
    frame.to_parquet(path, index=False)
    with pytest.raises(ValueError, match="only symbol SPY"):
        read_spy_parquet(path)


def test_read_spy_parquet_rejects_missing_required_column(tmp_path: Path) -> None:
    path = tmp_path / "missing-column.parquet"
    bars_for("2026-01-05", periods=1).drop(columns="source").to_parquet(path, index=False)
    with pytest.raises(ValueError, match="missing columns"):
        read_spy_parquet(path)


def test_load_and_normalize_spy_reads_deterministic_sample(sample_parquet: Path) -> None:
    normalized, report = load_and_normalize_spy(sample_parquet)
    assert len(normalized) == 40 * 390
    assert report.sessions == 40
    assert report.unresolved_gap_rows == 0
    assert normalized.timestamp.dt.tz is not None


def test_invalid_ohlcv_row_is_removed_without_backward_fill() -> None:
    frame = bars_for("2026-01-05", periods=3)
    frame.loc[1, "close"] = np.nan
    normalized, report = normalize_spy_frame(frame, max_fill_minutes=2)
    row = normalized.loc[normalized.minute_of_session == 1].iloc[0]
    assert bool(row.is_unresolved_gap)
    assert pd.isna(row.close)
    assert report.invalid_rows == 1


def test_off_grid_source_timestamp_blocks_official_minute_from_causal_fill() -> None:
    frame = bars_for("2026-01-05", periods=3)
    frame.loc[1, "timestamp"] += pd.Timedelta(seconds=30)

    normalized, report = normalize_spy_frame(frame, max_fill_minutes=2)

    official_minute = normalized.loc[normalized.minute_of_session == 1].iloc[0]
    assert bool(official_minute.is_unresolved_gap)
    assert not bool(official_minute.is_causal_fill)
    assert pd.isna(official_minute.close)
    assert report.invalid_rows == 1


def test_overlapping_invalid_reasons_count_source_row_once() -> None:
    frame = bars_for("2026-01-05", start="09:29", periods=1)
    frame.loc[0, "close"] = np.nan

    _, report = normalize_spy_frame(frame)

    assert report.source_rows == 1
    assert report.invalid_rows == 1
    assert report.invalid_rows <= report.source_rows

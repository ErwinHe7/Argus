"""Strict, causal normalization of downloaded Databento SPY minute bars."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from pathlib import Path

import numpy as np
import pandas as pd


REQUIRED_COLUMNS = {
    "timestamp",
    "symbol",
    "open",
    "high",
    "low",
    "close",
    "volume",
    "source",
    "data_quality",
}

_OHLCV_COLUMNS = ("open", "high", "low", "close", "volume")
_OUTPUT_COLUMNS = (
    "timestamp",
    "symbol",
    "open",
    "high",
    "low",
    "close",
    "volume",
    "source",
    "data_quality",
    "session_date",
    "minute_of_session",
    "is_causal_fill",
    "is_unresolved_gap",
    "official_close",
)


@dataclass(frozen=True)
class DatasetQualityReport:
    """Accounting for source rejections, gaps, and accepted-observation cutoffs."""

    source_rows: int
    normalized_rows: int
    sessions: int
    post_close_rows_removed: int
    duplicate_rows_removed: int
    causal_fill_rows: int
    unresolved_gap_rows: int
    invalid_rows: int
    first_timestamp: pd.Timestamp | None
    last_timestamp: pd.Timestamp | None


def strict_xnys_schedule(start: date, end: date) -> pd.DataFrame:
    """Return the official XNYS minute-bar bounds, indexed by session date."""
    import exchange_calendars as xcals

    calendar = xcals.get_calendar("XNYS")
    sessions = calendar.sessions_in_range(pd.Timestamp(start), pd.Timestamp(end))
    return pd.DataFrame(
        {
            "open": [calendar.session_open(session) for session in sessions],
            "close": [calendar.session_close(session) for session in sessions],
        },
        index=pd.Index(pd.to_datetime(sessions).date, name="session_date"),
    )


def read_spy_parquet(path: Path) -> pd.DataFrame:
    """Read a downloaded SPY Parquet file after enforcing its input contract."""
    if not path.is_file():
        raise FileNotFoundError(f"SPY Parquet input does not exist: {path}")
    frame = pd.read_parquet(path)
    missing = REQUIRED_COLUMNS.difference(frame.columns)
    if missing:
        raise ValueError(f"SPY Parquet input is missing columns: {sorted(missing)}")
    _require_spy_identity(frame)
    frame["timestamp"] = pd.to_datetime(frame["timestamp"], utc=True)
    return frame.sort_values("timestamp").reset_index(drop=True)


def _validate_frame(frame: pd.DataFrame) -> pd.DataFrame:
    missing = REQUIRED_COLUMNS.difference(frame.columns)
    if missing:
        raise ValueError(f"SPY input is missing columns: {sorted(missing)}")
    _require_spy_identity(frame)

    validated = frame.copy()
    validated["timestamp"] = pd.to_datetime(validated["timestamp"], utc=True, errors="coerce")
    return validated.sort_values("timestamp", kind="stable").reset_index(drop=True)


def _require_spy_identity(frame: pd.DataFrame) -> None:
    every_row_is_spy = frame["symbol"].map(
        lambda value: isinstance(value, str) and value == "SPY"
    )
    if not bool(every_row_is_spy.all()):
        raise ValueError("SPY demo input requires every row to contain only symbol SPY")


def _valid_ohlcv_rows(frame: pd.DataFrame) -> pd.Series:
    numeric = frame.loc[:, _OHLCV_COLUMNS].apply(pd.to_numeric, errors="coerce")
    finite = np.isfinite(numeric.to_numpy(dtype=float)).all(axis=1)
    positive_prices = (numeric.loc[:, ["open", "high", "low", "close"]] > 0.0).all(axis=1)
    non_negative_volume = numeric["volume"] >= 0.0
    integral_volume = numeric["volume"] == np.floor(numeric["volume"])
    consistent_ohlc = (numeric["low"] <= numeric[["open", "close"]].min(axis=1)) & (
        numeric["high"] >= numeric[["open", "close"]].max(axis=1)
    )
    return pd.Series(
        finite
        & positive_prices
        & non_negative_volume
        & integral_volume
        & consistent_ohlc,
        index=frame.index,
        dtype=bool,
    )


def _valid_metadata_rows(frame: pd.DataFrame) -> pd.Series:
    def is_nonempty_string(value: object) -> bool:
        return isinstance(value, str) and bool(value.strip())

    return frame["source"].map(is_nonempty_string) & frame["data_quality"].map(
        is_nonempty_string
    )


def _empty_normalized_frame() -> pd.DataFrame:
    return pd.DataFrame(
        {
            "timestamp": pd.Series(dtype="datetime64[ns, UTC]"),
            "symbol": pd.Series(dtype="object"),
            "open": pd.Series(dtype="float64"),
            "high": pd.Series(dtype="float64"),
            "low": pd.Series(dtype="float64"),
            "close": pd.Series(dtype="float64"),
            "volume": pd.Series(dtype="float64"),
            "source": pd.Series(dtype="object"),
            "data_quality": pd.Series(dtype="object"),
            "session_date": pd.Series(dtype="object"),
            "minute_of_session": pd.Series(dtype="int64"),
            "is_causal_fill": pd.Series(dtype=bool),
            "is_unresolved_gap": pd.Series(dtype=bool),
            "official_close": pd.Series(dtype="datetime64[ns, UTC]"),
        }
    ).loc[:, _OUTPUT_COLUMNS]


def _reindex_session(
    session_date: date,
    session_rows: pd.DataFrame,
    session_open: pd.Timestamp,
    session_close: pd.Timestamp,
    max_fill_minutes: int,
    blocked_timestamps: set[pd.Timestamp],
) -> tuple[pd.DataFrame, int, int]:
    expected_timestamps = pd.date_range(
        session_open, session_close, freq="1min", inclusive="left", tz="UTC"
    )
    indexed = session_rows.set_index("timestamp").reindex(expected_timestamps)
    normalized = indexed.reset_index(names="timestamp")
    normalized["session_date"] = session_date
    normalized["minute_of_session"] = np.arange(len(normalized), dtype=int)
    normalized["official_close"] = session_close
    normalized["is_causal_fill"] = False
    normalized["is_unresolved_gap"] = False

    missing = normalized.loc[:, _OHLCV_COLUMNS].isna().all(axis=1).to_numpy()
    causal_fills = 0
    unresolved_gaps = 0
    index = 0
    while index < len(normalized):
        if not missing[index]:
            index += 1
            continue
        gap_start = index
        while index < len(normalized) and missing[index]:
            index += 1
        gap_end = index
        gap_length = gap_end - gap_start
        gap_timestamps = normalized.loc[gap_start:gap_end - 1, "timestamp"]
        can_fill = (
            gap_start > 0
            and gap_length <= max_fill_minutes
            and not missing[gap_start - 1]
            and not gap_timestamps.isin(blocked_timestamps).any()
        )
        gap_rows = normalized.index[gap_start:gap_end]
        if can_fill:
            prior_close = normalized.at[gap_start - 1, "close"]
            normalized.loc[gap_rows, ["open", "high", "low", "close"]] = prior_close
            normalized.loc[gap_rows, "volume"] = 0
            normalized.loc[gap_rows, "source"] = "CAUSAL_FORWARD_FILL"
            normalized.loc[gap_rows, "data_quality"] = "causal_forward_fill"
            normalized.loc[gap_rows, "is_causal_fill"] = True
            causal_fills += gap_length
        else:
            normalized.loc[gap_rows, _OHLCV_COLUMNS] = np.nan
            normalized.loc[gap_rows, "source"] = "UNRESOLVED_GAP"
            normalized.loc[gap_rows, "data_quality"] = "unresolved_gap"
            normalized.loc[gap_rows, "is_unresolved_gap"] = True
            unresolved_gaps += gap_length

    normalized["symbol"] = "SPY"
    return normalized.loc[:, _OUTPUT_COLUMNS], causal_fills, unresolved_gaps


def normalize_spy_frame(
    frame: pd.DataFrame, max_fill_minutes: int = 2
) -> tuple[pd.DataFrame, DatasetQualityReport]:
    """Normalize SPY bars to official XNYS minutes without observing future prices."""
    if max_fill_minutes < 0:
        raise ValueError("max_fill_minutes must be non-negative")

    source_rows = len(frame)
    validated = _validate_frame(frame)
    timestamps = validated["timestamp"]
    valid_timestamps = timestamps.notna()
    valid_observations = _valid_ohlcv_rows(validated) & _valid_metadata_rows(validated)
    timestamped = validated.loc[valid_timestamps].copy()

    if timestamped.empty:
        normalized = _empty_normalized_frame()
        return normalized, DatasetQualityReport(
            source_rows=source_rows,
            normalized_rows=0,
            sessions=0,
            post_close_rows_removed=0,
            duplicate_rows_removed=0,
            causal_fill_rows=0,
            unresolved_gap_rows=0,
            invalid_rows=source_rows,
            first_timestamp=None,
            last_timestamp=None,
        )

    local_dates = timestamped["timestamp"].dt.tz_convert("America/New_York").dt.date
    schedule = strict_xnys_schedule(local_dates.min(), local_dates.max())
    if schedule.empty:
        normalized = _empty_normalized_frame()
        return normalized, DatasetQualityReport(
            source_rows=source_rows,
            normalized_rows=0,
            sessions=0,
            post_close_rows_removed=0,
            duplicate_rows_removed=0,
            causal_fill_rows=0,
            unresolved_gap_rows=0,
            invalid_rows=source_rows,
            first_timestamp=None,
            last_timestamp=None,
        )

    timestamped["session_date"] = local_dates
    timestamped["official_timestamp"] = timestamped["timestamp"].dt.floor("min")
    timestamped = timestamped.join(schedule, on="session_date", how="left", rsuffix="_official")
    in_official_session = timestamped["open_official"].notna()
    post_close = in_official_session & (timestamped["timestamp"] >= timestamped["close_official"])
    post_close_rows_removed = int(post_close.sum())
    before_open_or_non_session = ~in_official_session | (
        timestamped["timestamp"] < timestamped["open_official"]
    )
    on_minute_grid = timestamped["timestamp"] == timestamped["official_timestamp"]
    row_invalid = (
        ~valid_observations.loc[timestamped.index]
        | ~on_minute_grid
        | before_open_or_non_session
    )
    invalid_rows = int((~valid_timestamps).sum()) + int(row_invalid.sum())
    allowed_time = ~post_close & ~before_open_or_non_session
    invalid_in_session = timestamped.loc[allowed_time & row_invalid]
    candidates = timestamped.loc[allowed_time & ~row_invalid].copy()

    duplicate_rows_removed = int(candidates.duplicated(subset="timestamp", keep="last").sum())
    candidates = candidates.drop_duplicates(subset="timestamp", keep="last")
    first_timestamp = candidates["timestamp"].min() if not candidates.empty else None
    last_timestamp = candidates["timestamp"].max() if not candidates.empty else None
    blocked_timestamps = set(invalid_in_session["official_timestamp"]).difference(
        candidates["timestamp"]
    )

    normalized_sessions: list[pd.DataFrame] = []
    causal_fill_rows = 0
    unresolved_gap_rows = 0
    for session_date, bounds in schedule.iterrows():
        session_rows = candidates.loc[candidates["session_date"] == session_date].drop(
            columns=["official_timestamp", "open_official", "close_official"], errors="ignore"
        )
        normalized_session, fills, gaps = _reindex_session(
            session_date,
            session_rows,
            bounds["open"],
            bounds["close"],
            max_fill_minutes,
            blocked_timestamps,
        )
        normalized_sessions.append(normalized_session)
        causal_fill_rows += fills
        unresolved_gap_rows += gaps

    normalized = pd.concat(normalized_sessions, ignore_index=True)
    return normalized, DatasetQualityReport(
        source_rows=source_rows,
        normalized_rows=len(normalized),
        sessions=len(schedule),
        post_close_rows_removed=post_close_rows_removed,
        duplicate_rows_removed=duplicate_rows_removed,
        causal_fill_rows=causal_fill_rows,
        unresolved_gap_rows=unresolved_gap_rows,
        invalid_rows=invalid_rows,
        first_timestamp=first_timestamp,
        last_timestamp=last_timestamp,
    )


def load_and_normalize_spy(
    path: Path, max_fill_minutes: int = 2
) -> tuple[pd.DataFrame, DatasetQualityReport]:
    """Load a strict Databento SPY input and normalize it to XNYS minutes."""
    return normalize_spy_frame(read_spy_parquet(path), max_fill_minutes=max_fill_minutes)

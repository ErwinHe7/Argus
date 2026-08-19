"""Causal SPY minute-bar features and embargoed demo examples."""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date

import numpy as np
import pandas as pd


FEATURE_COLUMNS = (
    "ret_1m",
    "ret_3m",
    "ret_5m",
    "ret_15m",
    "ret_30m",
    "realized_vol_15m",
    "true_range",
    "atr_14m",
    "bar_range",
    "close_location",
    "dist_session_open",
    "dist_session_vwap",
    "volume_zscore_30m",
    "rvol_same_minute_20d",
    "minute_sin",
    "minute_cos",
)

_REQUIRED_BAR_COLUMNS = {
    "timestamp",
    "session_date",
    "minute_of_session",
    "official_close",
    "open",
    "high",
    "low",
    "close",
    "volume",
    "is_causal_fill",
    "is_unresolved_gap",
}


@dataclass(frozen=True)
class SplitDefinition:
    """Chronological train, validation, and test date sets with two embargoes."""

    train: tuple[date, ...]
    train_validation_embargo: date
    validation: tuple[date, ...]
    validation_test_embargo: date
    test: tuple[date, ...]


def chronological_split(session_dates: Sequence[date]) -> SplitDefinition:
    """Split distinct dates chronologically with one excluded session at each boundary."""
    ordered = tuple(sorted(set(session_dates)))
    if len(ordered) < 12:
        raise ValueError("At least 12 sessions are required for train/validation/test plus two embargoes")
    train_count = int(len(ordered) * 0.70)
    remaining_effective = len(ordered) - train_count - 2
    validation_count = remaining_effective // 2
    validation_start = train_count + 1
    validation_end = validation_start + validation_count
    return SplitDefinition(
        train=ordered[:train_count],
        train_validation_embargo=ordered[train_count],
        validation=ordered[validation_start:validation_end],
        validation_test_embargo=ordered[validation_end],
        test=ordered[validation_end + 1 :],
    )


def _backward_window_max(values: pd.Series, width: int) -> pd.Series:
    """Return a complete-window, inclusive backwards maximum."""
    return values.rolling(width, min_periods=width).max()


def _forward_window_max(values: pd.Series, width: int) -> pd.Series:
    """Return the maximum over the next ``width`` rows, excluding the current row."""
    next_values = values.shift(-1)
    return next_values.iloc[::-1].rolling(width, min_periods=width).max().iloc[::-1]


def _split_names(split: SplitDefinition) -> dict[date, str]:
    names = {session_date: "train" for session_date in split.train}
    names.update({session_date: "validation" for session_date in split.validation})
    names.update({session_date: "test" for session_date in split.test})
    return names


def _validate_normalized_bars(bars: pd.DataFrame) -> pd.DataFrame:
    missing = _REQUIRED_BAR_COLUMNS.difference(bars.columns)
    if missing:
        raise ValueError(f"normalized SPY bars are missing columns: {sorted(missing)}")

    frame = bars.copy()
    frame["timestamp"] = pd.to_datetime(frame["timestamp"], utc=True, errors="coerce")
    frame["official_close"] = pd.to_datetime(frame["official_close"], utc=True, errors="coerce")
    frame["session_date"] = pd.to_datetime(frame["session_date"], errors="coerce").dt.date
    for column in ("open", "high", "low", "close", "volume"):
        frame[column] = pd.to_numeric(frame[column], errors="coerce")
    frame["minute_of_session"] = pd.to_numeric(frame["minute_of_session"], errors="coerce")
    frame["is_causal_fill"] = frame["is_causal_fill"].fillna(False).astype(bool)
    frame["is_unresolved_gap"] = frame["is_unresolved_gap"].fillna(False).astype(bool)
    return frame.sort_values(["session_date", "timestamp"], kind="stable").reset_index(drop=True)


def _session_feature_frame(frame: pd.DataFrame) -> pd.DataFrame:
    """Add only values observable at each minute-bar close."""
    grouped = frame.groupby("session_date", sort=False)
    for minutes in (1, 3, 5, 15, 30):
        frame[f"ret_{minutes}m"] = grouped["close"].transform(
            lambda prices, periods=minutes: prices / prices.shift(periods) - 1.0
        )

    previous_close = grouped["close"].shift(1)
    frame["true_range"] = pd.concat(
        (
            frame["high"] - frame["low"],
            (frame["high"] - previous_close).abs(),
            (frame["low"] - previous_close).abs(),
        ),
        axis=1,
    ).max(axis=1)
    frame["atr_14m"] = frame["true_range"].groupby(frame["session_date"], sort=False).transform(
        lambda ranges: ranges.rolling(14, min_periods=14).mean()
    )
    frame["realized_vol_15m"] = frame["ret_1m"].groupby(
        frame["session_date"], sort=False
    ).transform(lambda returns: returns.rolling(15, min_periods=15).std())

    price_range = frame["high"] - frame["low"]
    frame["bar_range"] = price_range / frame["close"].replace(0.0, np.nan)
    frame["close_location"] = (
        (frame["close"] - frame["low"]) - (frame["high"] - frame["close"])
    ) / price_range.replace(0.0, np.nan)

    session_open = grouped["open"].transform(lambda values: values.iloc[0])
    frame["dist_session_open"] = frame["close"] / session_open.replace(0.0, np.nan) - 1.0
    typical_price = (frame["high"] + frame["low"] + frame["close"]) / 3.0
    cumulative_notional = (typical_price * frame["volume"]).groupby(
        frame["session_date"], sort=False
    ).cumsum()
    cumulative_volume = frame["volume"].groupby(frame["session_date"], sort=False).cumsum()
    session_vwap = cumulative_notional / cumulative_volume.replace(0.0, np.nan)
    frame["dist_session_vwap"] = frame["close"] / session_vwap.replace(0.0, np.nan) - 1.0

    volume_mean = frame["volume"].groupby(frame["session_date"], sort=False).transform(
        lambda volume: volume.rolling(30, min_periods=30).mean()
    )
    volume_std = frame["volume"].groupby(frame["session_date"], sort=False).transform(
        lambda volume: volume.rolling(30, min_periods=30).std()
    )
    frame["volume_zscore_30m"] = (frame["volume"] - volume_mean) / volume_std.replace(
        0.0, np.nan
    )

    same_minute_history = frame.groupby("minute_of_session", sort=False)["volume"].transform(
        lambda volume: volume.shift(1).rolling(20, min_periods=20).mean()
    )
    frame["rvol_same_minute_20d"] = frame["volume"] / same_minute_history.replace(
        0.0, np.nan
    )
    frame["minute_sin"] = np.sin(2.0 * np.pi * frame["minute_of_session"] / 390.0)
    frame["minute_cos"] = np.cos(2.0 * np.pi * frame["minute_of_session"] / 390.0)
    return frame.replace([np.inf, -np.inf], np.nan)


def _future_availability(frame: pd.DataFrame, horizon_minutes: int) -> tuple[pd.Series, pd.Series]:
    """Return the exact target close and a flag for each intervening official minute."""
    grouped = frame.groupby("session_date", sort=False)
    target_close = grouped["close"].shift(-horizon_minutes)
    available = pd.Series(True, index=frame.index, dtype=bool)
    for step in range(1, horizon_minutes + 1):
        future_timestamp = grouped["timestamp"].shift(-step)
        available &= future_timestamp.eq(frame["timestamp"] + pd.Timedelta(minutes=step))
    return target_close, available


def build_examples(
    bars: pd.DataFrame, lookback_minutes: int = 30, horizon_minutes: int = 5
) -> pd.DataFrame:
    """Build finite, gap-safe minute-bar examples with exact session-local targets.

    Every split is derived from all normalized session dates before feature, target,
    or quality exclusions. The two embargo dates therefore have no examples.
    """
    if lookback_minutes < 1:
        raise ValueError("lookback_minutes must be positive")
    if horizon_minutes < 1:
        raise ValueError("horizon_minutes must be positive")

    frame = _validate_normalized_bars(bars)
    all_session_dates = tuple(sorted(set(frame["session_date"].dropna())))
    split = chronological_split(all_session_dates)
    frame = _session_feature_frame(frame)

    target_close, has_exact_future_minutes = _future_availability(frame, horizon_minutes)
    frame["target_return"] = target_close / frame["close"].replace(0.0, np.nan) - 1.0
    frame["target_up"] = (target_close > frame["close"]).astype(int)

    unresolved = frame["is_unresolved_gap"].astype("int8")
    causal_fill = frame["is_causal_fill"].astype("int8")
    window_width = lookback_minutes + 1
    unresolved_backward = unresolved.groupby(frame["session_date"], sort=False).transform(
        lambda values: _backward_window_max(values, window_width)
    )
    unresolved_forward = unresolved.groupby(frame["session_date"], sort=False).transform(
        lambda values: _forward_window_max(values, horizon_minutes)
    )
    causal_fill_backward = causal_fill.groupby(frame["session_date"], sort=False).transform(
        lambda values: _backward_window_max(values, window_width)
    )
    causal_fill_forward = causal_fill.groupby(frame["session_date"], sort=False).transform(
        lambda values: _forward_window_max(values, horizon_minutes)
    )
    contaminated = unresolved_backward.eq(1.0) | unresolved_forward.eq(1.0)
    contains_causal_fill = causal_fill_backward.eq(1.0) | causal_fill_forward.eq(1.0)
    frame["quality_flags"] = [
        ("WINDOW_CONTAINS_CAUSAL_FILL",) if flag else () for flag in contains_causal_fill
    ]

    frame["split"] = frame["session_date"].map(_split_names(split))
    finite_features = np.isfinite(frame.loc[:, FEATURE_COLUMNS].to_numpy(dtype=float)).all(axis=1)
    eligible = (
        frame["minute_of_session"].ge(lookback_minutes)
        & has_exact_future_minutes
        & (frame["timestamp"] + pd.Timedelta(minutes=horizon_minutes)).lt(
            frame["official_close"]
        )
        & ~contaminated
        & finite_features
        & np.isfinite(frame["target_return"])
        & frame["split"].notna()
    )

    columns = [
        "timestamp",
        "session_date",
        "official_close",
        "close",
        "split",
        *FEATURE_COLUMNS,
        "target_return",
        "target_up",
        "quality_flags",
    ]
    examples = frame.loc[eligible, columns].reset_index(drop=True)
    examples.attrs.update(
        eligible_examples=len(examples),
        excluded_examples=int((~eligible).sum()),
        split_definition=split,
    )
    return examples

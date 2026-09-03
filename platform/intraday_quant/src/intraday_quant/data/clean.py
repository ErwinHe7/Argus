from __future__ import annotations

import numpy as np
import pandas as pd

from intraday_quant.data.integrity import DataIntegrityError
from intraday_quant.schemas import BAR_COLUMNS


def clean_bars(raw: pd.DataFrame, timezone: str, price_ffill_limit: int = 2) -> tuple[pd.DataFrame, dict[str, int]]:
    """Normalize minute bars without inventing or choosing market observations.

    Rows whose timestamp or symbol cannot be identified abort the load because
    they cannot be assigned to a session for quarantine. Invalid rows with a
    known identity are removed; the session-integrity gate in ``ingest`` then
    excludes the affected panel session. Exact duplicate copies are harmlessly
    collapsed, while every row belonging to a conflicting duplicate key is
    rejected instead of choosing an arbitrary winner.
    """

    missing = [c for c in BAR_COLUMNS if c not in raw.columns]
    if missing:
        raise ValueError(f"bar data missing columns: {missing}")
    df = raw[BAR_COLUMNS].copy()
    before = len(df)
    try:
        ts = pd.to_datetime(df["timestamp"], errors="coerce", format="mixed")
        if ts.dt.tz is None:
            ts = ts.dt.tz_localize(timezone, ambiguous="raise", nonexistent="raise")
        else:
            ts = ts.dt.tz_convert(timezone)
    except (AttributeError, TypeError, ValueError) as exc:
        raise DataIntegrityError(
            "bar timestamps must use one consistent timezone representation"
        ) from exc
    df["timestamp"] = ts
    df["symbol"] = df["symbol"].astype("string").str.strip().str.upper()
    malformed_identity = df["timestamp"].isna() | df["symbol"].isna() | df["symbol"].eq("")
    malformed_identity_count = int(malformed_identity.sum())
    if malformed_identity_count:
        raise DataIntegrityError(
            f"{malformed_identity_count} bar rows have an unparseable timestamp "
            "or missing symbol; session coverage cannot be proven"
        )

    numeric = ["open", "high", "low", "close", "volume", "vwap", "bid", "ask", "trade_count"]
    numeric_coercion_failed = pd.Series(False, index=df.index)
    for col in numeric:
        original = df[col]
        converted = pd.to_numeric(original, errors="coerce")
        numeric_coercion_failed |= original.notna() & converted.isna()
        df[col] = converted

    # An exact repeated copy carries no ambiguity. Collapse it before checking
    # whether a timestamp/symbol key contains conflicting observations.
    exact_duplicate = df.duplicated(BAR_COLUMNS, keep="first")
    exact_duplicate_count = int(exact_duplicate.sum())
    df = df.loc[~exact_duplicate].copy()
    duplicate_key_mask = df.duplicated(["timestamp", "symbol"], keep=False)
    ambiguous_duplicate_rows = int(duplicate_key_mask.sum())
    ambiguous_duplicate_keys = int(
        df.loc[duplicate_key_mask, ["timestamp", "symbol"]].drop_duplicates().shape[0]
    )
    df = df.loc[~duplicate_key_mask].copy()

    minute_aligned = (
        df["timestamp"].dt.second.eq(0)
        & df["timestamp"].dt.microsecond.eq(0)
        & df["timestamp"].dt.nanosecond.eq(0)
    )
    non_minute_aligned = ~minute_aligned
    required_numeric = ["open", "high", "low", "close", "volume"]
    required_missing = df[required_numeric].isna().any(axis=1)
    finite_required = pd.Series(
        np.isfinite(df[required_numeric].to_numpy(dtype=float)).all(axis=1),
        index=df.index,
    )
    invalid_price = (df[["open", "high", "low", "close"]] <= 0).any(axis=1)
    invalid_ohlc = (
        (df["high"] < df[["open", "close", "low"]].max(axis=1))
        | (df["low"] > df[["open", "close", "high"]].min(axis=1))
    )
    invalid_volume = df["volume"].lt(0) | ~np.isfinite(df["volume"])
    invalid_optional_price = pd.Series(False, index=df.index)
    for column in ("vwap", "bid", "ask"):
        invalid_optional_price |= df[column].notna() & (
            df[column].le(0) | ~np.isfinite(df[column])
        )
    invalid_trade_count = df["trade_count"].notna() & (
        df["trade_count"].lt(0) | ~np.isfinite(df["trade_count"])
    )
    crossed_quote = (
        df["bid"].notna()
        & df["ask"].notna()
        & df["bid"].gt(df["ask"])
    )
    invalid_source = (
        df["source"].isna()
        | df["source"].astype("string").str.strip().eq("")
    )
    invalid = (
        numeric_coercion_failed.reindex(df.index, fill_value=False)
        | non_minute_aligned
        | required_missing
        | ~finite_required
        | invalid_price
        | invalid_ohlc
        | invalid_volume
        | invalid_optional_price
        | invalid_trade_count
        | crossed_quote
        | invalid_source
    )
    malformed_numeric_count = int(
        numeric_coercion_failed.reindex(df.index, fill_value=False).sum()
    )
    invalid_count = int(invalid.sum())
    df = df.loc[~invalid].copy()

    # The argument remains for configuration compatibility. Historical market
    # observations are deliberately never forward-filled.
    _ = price_ffill_limit
    df["trade_count"] = df["trade_count"].fillna(0)
    df["data_quality"] = df["data_quality"].fillna("not_reported")
    stats = {
        "input_rows": before,
        "output_rows": len(df),
        "duplicates_removed": exact_duplicate_count + ambiguous_duplicate_rows,
        "exact_duplicate_rows_removed": exact_duplicate_count,
        "ambiguous_duplicate_keys": ambiguous_duplicate_keys,
        "ambiguous_duplicate_rows_removed": ambiguous_duplicate_rows,
        "invalid_rows_removed": invalid_count,
        "non_minute_aligned_rows_removed": int(non_minute_aligned.sum()),
        "malformed_numeric_rows_removed": malformed_numeric_count,
        "price_values_forward_filled": 0,
    }
    return df.sort_values(["symbol", "timestamp"]).reset_index(drop=True), stats

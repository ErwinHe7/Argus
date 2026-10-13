from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from typing import Literal

import pandas as pd


class DataIntegrityError(ValueError):
    """Raised when historical observations cannot be used without guessing."""


@dataclass(frozen=True, slots=True)
class SessionIntegrityResult:
    bars: pd.DataFrame
    session_audit: pd.DataFrame
    stats: dict[str, int]


def _expected_timestamps(
    session_open: pd.Timestamp,
    session_close: pd.Timestamp,
    frequency: Literal["1min", "5min"],
) -> pd.DatetimeIndex:
    return pd.date_range(
        session_open,
        session_close,
        freq=frequency,
        inclusive="left",
    )


def enforce_complete_panel_sessions(
    frame: pd.DataFrame,
    schedule: pd.DataFrame,
    required_symbols: list[str],
    frequency: Literal["1min", "5min"] = "1min",
) -> SessionIntegrityResult:
    """Exclude any session whose required symbol/minute panel is incomplete.

    Completeness is established against the official session clock. A session
    is retained only when every required symbol contains exactly one bar at
    every expected timestamp. The function never fills a missing observation.
    """

    if frequency not in {"1min", "5min"}:
        raise ValueError("session integrity supports only 1min or 5min bars")
    required = list(dict.fromkeys(str(symbol).strip().upper() for symbol in required_symbols))
    if not required or any(not symbol for symbol in required):
        raise ValueError("required_symbols must contain at least one non-empty symbol")
    if "timestamp" not in frame or "symbol" not in frame:
        raise ValueError("bar frame must contain timestamp and symbol")

    bars = frame.copy()
    if not bars.empty:
        if bars["timestamp"].dt.tz is None:
            raise DataIntegrityError("session validation requires timezone-aware timestamps")
        if bars.duplicated(["timestamp", "symbol"]).any():
            raise DataIntegrityError(
                "duplicate timestamp/symbol keys reached the session-integrity gate"
            )
        bars["symbol"] = bars["symbol"].astype("string").str.strip().str.upper()
        bars["_session_date"] = bars["timestamp"].dt.date
        observed_by_key = {
            (session_date, str(symbol)): pd.DatetimeIndex(
                group["timestamp"].sort_values()
            )
            for (session_date, symbol), group in bars.groupby(
                ["_session_date", "symbol"],
                sort=False,
                observed=True,
            )
        }
    else:
        observed_by_key = {}

    audits: list[dict[str, object]] = []
    complete_dates: set[date] = set()
    missing_total = 0
    unexpected_total = 0
    incomplete_symbol_sessions = 0

    for session_date, schedule_row in schedule.sort_index().iterrows():
        expected = _expected_timestamps(
            pd.Timestamp(schedule_row["open"]),
            pd.Timestamp(schedule_row["close"]),
            frequency,
        )
        all_symbols_complete = True
        for symbol in required:
            observed = observed_by_key.get(
                (session_date, symbol),
                pd.DatetimeIndex([]),
            )
            missing = expected.difference(observed)
            unexpected = observed.difference(expected)
            complete = len(missing) == 0 and len(unexpected) == 0 and len(observed) == len(expected)
            all_symbols_complete &= complete
            if not complete:
                incomplete_symbol_sessions += 1
            missing_total += len(missing)
            unexpected_total += len(unexpected)
            audits.append(
                {
                    "session_date": session_date,
                    "symbol": symbol,
                    "frequency": frequency,
                    "status": "complete" if complete else "excluded_incomplete",
                    "expected_bars": len(expected),
                    "observed_bars": len(observed),
                    "missing_bars": len(missing),
                    "unexpected_bars": len(unexpected),
                    "first_missing_timestamp": missing[0] if len(missing) else pd.NaT,
                    "last_observed_timestamp": observed[-1] if len(observed) else pd.NaT,
                }
            )
        if all_symbols_complete:
            complete_dates.add(session_date)

    audit = pd.DataFrame(audits)
    if bars.empty:
        eligible = frame.copy()
    else:
        eligible = bars.loc[bars["_session_date"].isin(complete_dates)].drop(
            columns="_session_date"
        )
    scheduled_sessions = len(schedule)
    complete_sessions = len(complete_dates)
    stats = {
        "scheduled_sessions": scheduled_sessions,
        "complete_panel_sessions": complete_sessions,
        "excluded_incomplete_panel_sessions": scheduled_sessions - complete_sessions,
        "incomplete_symbol_sessions": incomplete_symbol_sessions,
        "missing_expected_bars": missing_total,
        "unexpected_timestamp_bars": unexpected_total,
        "rows_removed_with_incomplete_sessions": len(frame) - len(eligible),
    }
    return SessionIntegrityResult(
        bars=eligible.sort_values(["symbol", "timestamp"]).reset_index(drop=True),
        session_audit=audit,
        stats=stats,
    )

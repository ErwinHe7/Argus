from __future__ import annotations

import pandas as pd


def market_schedule(start_date: str, end_date: str, timezone: str = "America/New_York") -> pd.DataFrame:
    """Return the official XNYS schedule, including DST and early closes."""
    try:
        import exchange_calendars as xcals

        cal = xcals.get_calendar("XNYS")
        schedule = cal.schedule.loc[start_date:end_date, ["open", "close"]].copy()
        schedule["open"] = schedule["open"].dt.tz_convert(timezone)
        schedule["close"] = schedule["close"].dt.tz_convert(timezone)
        schedule.index = pd.to_datetime(schedule.index).date
        return schedule
    except ImportError as exc:
        raise RuntimeError("official XNYS sessions require exchange-calendars; no weekday fallback") from exc


def session_minutes(schedule: pd.DataFrame) -> pd.DatetimeIndex:
    chunks: list[pd.DatetimeIndex] = []
    for row in schedule.itertuples():
        chunks.append(pd.date_range(row.open, row.close, freq="1min", inclusive="left"))
    if not chunks:
        return pd.DatetimeIndex([])
    result = chunks[0]
    for chunk in chunks[1:]:
        result = result.append(chunk)
    return result


def filter_regular_session(frame: pd.DataFrame, schedule: pd.DataFrame) -> pd.DataFrame:
    """Keep official XNYS minutes, including early closes and excluding the 16:00 tick."""
    if frame.empty:
        return frame.copy()
    if schedule.empty:
        return frame.iloc[0:0].copy()
    opens = schedule["open"].to_dict()
    closes = schedule["close"].to_dict()
    dates = frame["timestamp"].dt.date
    open_values = dates.map(opens)
    close_values = dates.map(closes)
    mask = open_values.notna() & (frame["timestamp"] >= open_values) & (frame["timestamp"] < close_values)
    return frame.loc[mask].copy()

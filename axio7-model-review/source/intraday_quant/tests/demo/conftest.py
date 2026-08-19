from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import pytest


def bars_for(session: str, *, start: str = "09:30", periods: int = 390) -> pd.DataFrame:
    timestamps = pd.date_range(
        f"{session} {start}", periods=periods, freq="1min", tz="America/New_York"
    )
    close = 700.0 + np.sin(np.arange(periods) / 7.0)
    return pd.DataFrame(
        {
            "timestamp": timestamps.tz_convert("UTC"),
            "symbol": "SPY",
            "open": close,
            "high": close + 0.05,
            "low": close - 0.05,
            "close": close,
            "volume": np.arange(periods) + 100,
            "source": "TEST",
            "data_quality": "vendor_aggregate",
        }
    )


@pytest.fixture
def sample_parquet(tmp_path: Path) -> Path:
    """Write forty deterministic, consecutive complete XNYS sessions."""
    import exchange_calendars as xcals

    calendar = xcals.get_calendar("XNYS")
    sessions = calendar.sessions_in_range(
        pd.Timestamp("2026-01-02"), pd.Timestamp("2026-03-31")
    )[:40]
    frames: list[pd.DataFrame] = []
    for session_number, session in enumerate(sessions):
        opening_timestamp = calendar.session_open(session)
        session_name = opening_timestamp.tz_convert("America/New_York").strftime("%Y-%m-%d")
        frame = bars_for(session_name)
        minute = np.arange(len(frame))
        drift = 0.03 if session_number % 2 == 0 else -0.03
        close = 700.0 + session_number * 0.2 + drift * minute + np.sin(minute / 7.0)
        frame["open"] = close
        frame["high"] = close + 0.05
        frame["low"] = close - 0.05
        frame["close"] = close
        frames.append(frame)

    path = tmp_path / "spy-sample.parquet"
    pd.concat(frames, ignore_index=True).to_parquet(path, index=False)
    return path

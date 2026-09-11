"""Offline Market Map input preparation; no production inference in JavaScript.

Minute observations become regular-session, split-adjusted daily OHLCV here.
Cash dividends are kept as explicit price-return caveats, not reinvested returns.
The calendar path has no weekday-only fallback.
"""
from __future__ import annotations

import argparse
import importlib.metadata
import json
import math
from datetime import datetime
from pathlib import Path


def epoch(value: str) -> int:
    return int(datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp() * 1000)


def exchange_schedule(start: str, end: str) -> dict:
    import exchange_calendars as xcals

    calendar = xcals.get_calendar("XNYS", start=start, end=end)
    schedule = calendar.schedule.loc[start:end]
    return {
        "schema_version": "market-map-calendar.v1",
        "source": f"exchange_calendars/{importlib.metadata.version('exchange-calendars')}/XNYS",
        "sessions": [
            {
                "date": str(index.date()),
                "open": row["open"].isoformat(),
                "close": row["close"].isoformat(),
            }
            for index, row in schedule.iterrows()
        ],
    }


def regular_daily_bars(raw: dict) -> list[dict]:
    if raw.get("adjusted") is not True:
        raise ValueError("split_adjustment_not_verified")
    minutes = raw["minutes"]
    seen = set()
    for minute in minutes:
        if minute["t"] in seen:
            raise ValueError("duplicate_minute")
        seen.add(minute["t"])
        if not all(isinstance(minute[key], (int, float)) and math.isfinite(minute[key]) for key in ("t", "o", "h", "l", "c", "v")):
            raise ValueError("invalid_minute")
        if not (0 < minute["l"] <= minute["o"] <= minute["h"] and minute["l"] <= minute["c"] <= minute["h"] and minute["v"] >= 0):
            raise ValueError("invalid_minute_range")
    minutes.sort(key=lambda minute: minute["t"])
    result = []
    for session in raw["sessions"]:
        opened, closed = epoch(session["open"]), epoch(session["close"])
        selected = [minute for minute in minutes if opened <= minute["t"] < closed]
        expected = list(range(opened, closed, 60000))
        # Strict coverage is appropriate for the initial liquid stock/ETF scope.
        # Sparse/no-trade intervals require an explicit provider coverage policy.
        if [minute["t"] for minute in selected] != expected:
            raise ValueError("regular_session_minute_coverage_incomplete")
        result.append({
            "observed_at": session["close"],
            "open": selected[0]["o"],
            "high": max(minute["h"] for minute in selected),
            "low": min(minute["l"] for minute in selected),
            "close": selected[-1]["c"],
            "volume": sum(minute["v"] for minute in selected),
            "session": "regular",
        })
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--calendar", nargs=2, metavar=("START", "END"))
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.calendar:
        result = exchange_schedule(*args.calendar)
    elif args.input:
        result = regular_daily_bars(json.loads(args.input.read_text(encoding="utf-8-sig")))
    else:
        parser.error("--calendar or --input is required")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, allow_nan=False), encoding="utf-8")


if __name__ == "__main__":
    main()

from copy import deepcopy
from datetime import datetime
import unittest

from intraday_quant.market_map import regular_daily_bars


def minute(time: str, price: float, volume: int) -> dict:
    return {"t": int(datetime.fromisoformat(time).timestamp() * 1000), "o": price, "h": price + 1, "l": price - 1, "c": price + 0.5, "v": volume}


def check_regular_session_excludes_extended_hours_and_uses_calendar_close():
    raw = {"adjusted": True, "sessions": [{"open": "2026-07-02T13:30:00Z", "close": "2026-07-02T13:32:00Z"}], "minutes": [
        minute("2026-07-02T13:29:00+00:00", 3, 999),
        minute("2026-07-02T13:30:00+00:00", 100, 10),
        minute("2026-07-02T13:31:00+00:00", 101, 20),
        minute("2026-07-02T13:32:00+00:00", 999, 999),
    ]}
    bars = regular_daily_bars(raw)
    assert bars == [{"observed_at": "2026-07-02T13:32:00Z", "open": 100, "high": 102, "low": 99, "close": 101.5, "volume": 30, "session": "regular"}]
    incomplete = deepcopy(raw)
    incomplete["minutes"].pop(1)
    with unittest.TestCase().assertRaisesRegex(ValueError, "coverage_incomplete"):
        regular_daily_bars(incomplete)
    duplicate = deepcopy(raw)
    duplicate["minutes"].append(duplicate["minutes"][1])
    with unittest.TestCase().assertRaisesRegex(ValueError, "duplicate_minute"):
        regular_daily_bars(duplicate)


def check_unverified_split_adjustments_are_rejected():
    with unittest.TestCase().assertRaisesRegex(ValueError, "split_adjustment_not_verified"):
        regular_daily_bars({"adjusted": False, "sessions": [], "minutes": []})


class MarketMapNormalizationTests(unittest.TestCase):
    def test_regular_session_normalization(self):
        check_regular_session_excludes_extended_hours_and_uses_calendar_close()

    def test_adjustments_fail_closed(self):
        check_unverified_split_adjustments_are_rejected()

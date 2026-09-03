from __future__ import annotations

from datetime import date

from intraday_quant.storage.occ_open_interest import (
    _month_requests,
    parse_occ_month,
)


def test_occ_csv_is_parsed_as_market_totals_not_contract_rows() -> None:
    raw = b"""Daily Open Interest - July 2026
Date,Equity,,,Index/Other,,,Debt,,,Futures,OCC Total
,Calls,Puts,Total,Calls,Puts,Total,Calls,Puts,Total,Total,
07/24/2026,"316,797,957","237,145,483","553,943,440","20,767,818","18,901,537","39,669,355","0","0","0","368,368","593,981,163",
"""
    rows = parse_occ_month(raw)
    assert len(rows) == 1
    assert rows[0].observation_date == date(2026, 7, 24)
    assert rows[0].equity_total == 553_943_440
    assert rows[0].occ_total == 593_981_163


def test_month_requests_cover_each_month_once() -> None:
    requests = _month_requests(date(2024, 7, 18), date(2024, 9, 4))
    assert requests == [date(2024, 7, 31), date(2024, 8, 31), date(2024, 9, 4)]

from __future__ import annotations

from datetime import UTC, date, datetime

from intraday_quant.storage.massive_options import (
    basic_eod_availability,
    parse_bars,
    parse_contract,
)


def test_parse_contract_preserves_reference_lineage() -> None:
    contract = parse_contract(
        {
            "ticker": "O:NVDA260724C00210000",
            "underlying_ticker": "NVDA",
            "expiration_date": "2026-07-24",
            "strike_price": 210,
            "contract_type": "call",
            "shares_per_contract": 100,
            "exercise_style": "american",
            "primary_exchange": "BATO",
        }
    )
    assert contract.option_symbol == "O:NVDA260724C00210000"
    assert contract.expiration_date == date(2026, 7, 24)
    assert contract.option_right == "C"


def test_basic_data_is_never_available_to_same_day_intraday_model() -> None:
    event_at = datetime(2026, 7, 24, 14, 35, tzinfo=UTC)
    available_at = basic_eod_availability(event_at)
    assert available_at == datetime(2026, 7, 25, 16, 0, tzinfo=UTC)
    assert available_at > event_at


def test_parse_minute_aggregate_does_not_claim_quote_or_oi_fields() -> None:
    bars = parse_bars(
        "O:NVDA260724C00210000",
        {
            "status": "OK",
            "results": [
                {
                    "t": 1784903400000,
                    "o": 1.0,
                    "h": 1.4,
                    "l": 0.9,
                    "c": 1.2,
                    "v": 17,
                    "n": 4,
                }
            ],
        },
    )
    assert len(bars) == 1
    assert bars[0].volume == 17
    assert bars[0].transaction_count == 4

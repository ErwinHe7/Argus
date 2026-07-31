from __future__ import annotations

import sqlite3
from pathlib import Path

import pytest

from intraday_quant.storage.live_postgres_archive import (
    database_connection_target,
    inspect_live_sqlite,
    validate_live_row,
)


def live_row() -> tuple[object, ...]:
    return (
        "databento",
        "EQUS.MINI",
        "ohlcv-1m",
        "SKYY",
        "2026-07-30T13:30:00+00:00",
        "2026-07-30T13:31:02+00:00",
        "2026-07-30T13:31:03+00:00",
        "2026-07-30T13:31:02+00:00",
        100.0,
        101.0,
        99.0,
        100.5,
        1_000.0,
        100.25,
        12,
        "DATABENTO_EQUS_MINI_OHLCV_1M",
        "REALTIME_SUBSCRIPTION_ACKNOWLEDGED",
        "REALTIME_ENTITLEMENT_VERIFIED",
        1,
    )


def test_live_row_validation_rejects_noncausal_or_unmapped_rows() -> None:
    validate_live_row(live_row(), "databento", "EQUS.MINI", "ohlcv-1m")

    too_early = list(live_row())
    too_early[5] = "2026-07-30T13:30:30+00:00"
    too_early[7] = too_early[5]
    with pytest.raises(ValueError, match="before bar completion"):
        validate_live_row(too_early, "databento", "EQUS.MINI", "ohlcv-1m")

    unmapped = list(live_row())
    unmapped[18] = 0
    with pytest.raises(ValueError, match="verified symbol mapping"):
        validate_live_row(unmapped, "databento", "EQUS.MINI", "ohlcv-1m")


def test_inspect_live_sqlite_reports_exact_source_and_symbol_coverage(tmp_path: Path) -> None:
    database = tmp_path / "databento_live.sqlite3"
    connection = sqlite3.connect(database)
    connection.execute(
        """
        CREATE TABLE live_minute_bars (
            provider TEXT, dataset TEXT, schema_name TEXT, symbol TEXT,
            event_at TEXT, available_at TEXT, recorded_at TEXT, finalized_at TEXT,
            open REAL, high REAL, low REAL, close REAL, volume REAL, vwap REAL,
            trade_count INTEGER, source TEXT, data_quality TEXT, entitlement TEXT,
            symbol_mapping_verified INTEGER
        )
        """
    )
    connection.executemany(
        "INSERT INTO live_minute_bars VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [live_row(), (*live_row()[:3], "IGV", *live_row()[4:])],
    )
    connection.commit()
    connection.close()

    inventory = inspect_live_sqlite(database)
    assert inventory.rows == 2
    assert inventory.symbol_counts == {"IGV": 1, "SKYY": 1}
    assert inventory.providers == ["databento"]
    assert inventory.datasets == ["EQUS.MINI"]
    assert inventory.schemas == ["ohlcv-1m"]
    assert inventory.minimum_event_at == "2026-07-30T13:30:00+00:00"
    assert inventory.maximum_recorded_at == "2026-07-30T13:31:03+00:00"


def test_postgres_schema_requires_recorded_at_for_asof_and_append_only_live() -> None:
    schema = (
        Path(__file__).parents[2] / "infra" / "market-data" / "postgres" / "schema.sql"
    ).read_text(encoding="utf-8")
    assert "CREATE TABLE IF NOT EXISTS market_data.live_equity_minute_bars" in schema
    assert "live_equity_minute_bars_reject_update_delete" in schema
    assert "live_archive_receipts_reject_update_delete" in schema
    assert "CREATE OR REPLACE FUNCTION market_data.equity_minute_bars_unified_asof" in schema
    assert schema.count("recorded_at <= decision_cutoff") >= 3


def test_database_target_accepts_managed_url_or_complete_libpq_environment(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("MARKET_DATABASE_URL", "postgresql://managed.example/market")
    assert database_connection_target("MARKET_DATABASE_URL") == (
        "postgresql://managed.example/market"
    )

    monkeypatch.delenv("MARKET_DATABASE_URL")
    for name, value in {
        "PGHOST": "postgres",
        "PGPORT": "5432",
        "PGDATABASE": "axio7_market",
        "PGUSER": "axio7",
        "PGPASSWORD": "server-only-secret",
    }.items():
        monkeypatch.setenv(name, value)
    assert database_connection_target("MARKET_DATABASE_URL") == ""

    monkeypatch.delenv("PGPASSWORD")
    with pytest.raises(ValueError, match="missing PGPASSWORD"):
        database_connection_target("MARKET_DATABASE_URL")

from __future__ import annotations

import sqlite3
from pathlib import Path

from intraday_quant.storage.postgres_migration import inspect_sqlite, month_starts


def test_month_starts_are_utc_and_inclusive() -> None:
    starts = month_starts(
        "2024-12-31T23:59:00+00:00",
        "2025-02-01T00:00:00+00:00",
    )
    assert [(value.year, value.month) for value in starts] == [
        (2024, 12),
        (2025, 1),
        (2025, 2),
    ]
    assert all(value.tzinfo is not None for value in starts)


def test_inspect_sqlite_reports_exact_coverage(tmp_path: Path) -> None:
    database = tmp_path / "market.sqlite3"
    connection = sqlite3.connect(database)
    connection.executescript(
        """
        CREATE TABLE market_data_batches (batch_id TEXT PRIMARY KEY);
        CREATE TABLE minute_bars (symbol TEXT NOT NULL, event_at TEXT NOT NULL);
        INSERT INTO market_data_batches VALUES ('batch-a');
        INSERT INTO minute_bars VALUES
            ('SPY', '2026-07-24T13:30:00+00:00'),
            ('SPY', '2026-07-24T13:31:00+00:00'),
            ('QQQ', '2026-07-24T13:30:00+00:00');
        """
    )
    connection.commit()
    connection.close()

    inventory = inspect_sqlite(database)
    assert inventory.batches == 1
    assert inventory.minute_bars == 3
    assert inventory.minimum_event_at == "2026-07-24T13:30:00+00:00"
    assert inventory.maximum_event_at == "2026-07-24T13:31:00+00:00"
    assert inventory.symbol_counts == {"QQQ": 1, "SPY": 2}

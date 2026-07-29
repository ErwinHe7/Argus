from __future__ import annotations

import argparse
import json
import os
import sqlite3
from collections.abc import Iterator, Sequence
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path


@dataclass(frozen=True)
class SqliteMarketInventory:
    batches: int
    minute_bars: int
    minimum_event_at: str | None
    maximum_event_at: str | None
    symbol_counts: dict[str, int]


def inspect_sqlite(path: Path) -> SqliteMarketInventory:
    connection = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)
    try:
        batches = int(connection.execute("SELECT COUNT(*) FROM market_data_batches").fetchone()[0])
        minute_bars = int(connection.execute("SELECT COUNT(*) FROM minute_bars").fetchone()[0])
        minimum, maximum = connection.execute(
            "SELECT MIN(event_at), MAX(event_at) FROM minute_bars"
        ).fetchone()
        symbol_counts = {
            str(symbol): int(count)
            for symbol, count in connection.execute(
                "SELECT symbol, COUNT(*) FROM minute_bars GROUP BY symbol ORDER BY symbol"
            )
        }
        return SqliteMarketInventory(
            batches=batches,
            minute_bars=minute_bars,
            minimum_event_at=minimum,
            maximum_event_at=maximum,
            symbol_counts=symbol_counts,
        )
    finally:
        connection.close()


def month_starts(minimum: str, maximum: str) -> list[datetime]:
    current = datetime.fromisoformat(minimum).astimezone(UTC).replace(
        day=1, hour=0, minute=0, second=0, microsecond=0
    )
    last = datetime.fromisoformat(maximum).astimezone(UTC).replace(
        day=1, hour=0, minute=0, second=0, microsecond=0
    )
    result: list[datetime] = []
    while current <= last:
        result.append(current)
        year = current.year + (1 if current.month == 12 else 0)
        month = 1 if current.month == 12 else current.month + 1
        current = current.replace(year=year, month=month)
    return result


def _next_month(value: datetime) -> datetime:
    year = value.year + (1 if value.month == 12 else 0)
    month = 1 if value.month == 12 else value.month + 1
    return value.replace(year=year, month=month)


def _chunks(cursor: sqlite3.Cursor, size: int) -> Iterator[list[tuple[object, ...]]]:
    while rows := cursor.fetchmany(size):
        yield rows


def _create_month_partitions(connection: object, starts: Sequence[datetime]) -> None:
    from psycopg import sql

    partitioned_tables = (
        "equity_minute_bars",
        "equity_nbbo_quotes",
        "option_quotes",
        "option_trades",
        "option_minute_bars",
    )
    with connection.cursor() as cursor:
        for start in starts:
            end = _next_month(start)
            suffix = f"{start.year:04d}_{start.month:02d}"
            for parent in partitioned_tables:
                partition = f"{parent}_{suffix}"
                cursor.execute(
                    sql.SQL(
                        "CREATE TABLE IF NOT EXISTS market_data.{} "
                        "PARTITION OF market_data.{} FOR VALUES FROM ({}) TO ({})"
                    ).format(
                        sql.Identifier(partition),
                        sql.Identifier(parent),
                        sql.Literal(start),
                        sql.Literal(end),
                    )
                )
                if parent == "equity_minute_bars":
                    cursor.execute(
                        sql.SQL(
                            "CREATE INDEX IF NOT EXISTS {} ON market_data.{} "
                            "(symbol, event_at DESC, available_at DESC)"
                        ).format(
                            sql.Identifier(f"{partition}_symbol_event_idx"),
                            sql.Identifier(partition),
                        )
                    )


def migrate(
    sqlite_path: Path,
    database_url: str,
    schema_path: Path,
    chunk_size: int = 50_000,
) -> dict[str, object]:
    import psycopg

    inventory = inspect_sqlite(sqlite_path)
    if not inventory.minimum_event_at or not inventory.maximum_event_at:
        raise ValueError("SQLite market store contains no minute bars")

    source = sqlite3.connect(f"file:{sqlite_path.as_posix()}?mode=ro", uri=True)
    destination = psycopg.connect(database_url)
    inserted = 0
    try:
        destination.execute(schema_path.read_text(encoding="utf-8"))
        _create_month_partitions(
            destination,
            month_starts(inventory.minimum_event_at, inventory.maximum_event_at),
        )
        destination.commit()

        batches = source.execute(
            """
            SELECT batch_id, provider, dataset, source_file_sha256, source_path,
                   captured_at, availability_policy, availability_delay_seconds,
                   license_scope, license_reference, input_rows, accepted_rows,
                   duplicate_rows, rejected_rows
            FROM market_data_batches
            ORDER BY captured_at
            """
        ).fetchall()
        with destination.cursor() as cursor:
            cursor.executemany(
                """
                INSERT INTO market_data.batches (
                    batch_id, provider, dataset, source_file_sha256, source_path,
                    captured_at, availability_policy, availability_delay_seconds,
                    license_scope, license_reference, input_rows, accepted_rows,
                    duplicate_rows, rejected_rows
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                )
                ON CONFLICT (batch_id) DO NOTHING
                """,
                batches,
            )
        destination.commit()

        source_cursor = source.execute(
            """
            SELECT batch_id, symbol, event_at, available_at, recorded_at,
                   open, high, low, close, volume, vwap, bid, ask, trade_count,
                   source, data_quality
            FROM minute_bars
            ORDER BY event_at, symbol, batch_id
            """
        )
        for rows in _chunks(source_cursor, chunk_size):
            with destination.cursor() as cursor:
                cursor.execute(
                    """
                    CREATE TEMP TABLE minute_bars_stage
                    (LIKE market_data.equity_minute_bars INCLUDING DEFAULTS)
                    ON COMMIT DROP
                    """
                )
                with cursor.copy(
                    """
                    COPY minute_bars_stage (
                        batch_id, symbol, event_at, available_at, recorded_at,
                        open, high, low, close, volume, vwap, bid, ask, trade_count,
                        source, data_quality
                    ) FROM STDIN
                    """
                ) as copy:
                    for row in rows:
                        copy.write_row(row)
                cursor.execute(
                    """
                    INSERT INTO market_data.equity_minute_bars
                    SELECT * FROM minute_bars_stage
                    ON CONFLICT (batch_id, symbol, event_at) DO NOTHING
                    """
                )
                inserted += cursor.rowcount
            destination.commit()

        destination_count = int(
            destination.execute(
                "SELECT COUNT(*) FROM market_data.equity_minute_bars"
            ).fetchone()[0]
        )
        if destination_count != inventory.minute_bars:
            raise RuntimeError(
                f"row-count mismatch: sqlite={inventory.minute_bars} "
                f"postgres={destination_count}"
            )
        destination.execute(
            """
            INSERT INTO market_data.coverage_receipts (
                batch_id, dataset, symbol, minimum_event_at, maximum_event_at,
                row_count, vwap_row_count, bid_row_count, ask_row_count,
                trade_count_row_count
            )
            SELECT
                batch_id,
                'EQUITY_MINUTE_BARS',
                symbol,
                MIN(event_at),
                MAX(event_at),
                COUNT(*),
                COUNT(vwap),
                COUNT(bid),
                COUNT(ask),
                COUNT(trade_count)
            FROM market_data.equity_minute_bars
            GROUP BY batch_id, symbol
            ON CONFLICT (batch_id, dataset, symbol) DO NOTHING
            """
        )
        destination.commit()
        coverage_receipts = int(
            destination.execute(
                "SELECT COUNT(*) FROM market_data.coverage_receipts"
            ).fetchone()[0]
        )
        return {
            "status": "MIGRATED",
            "source": asdict(inventory),
            "postgres_minute_bars": destination_count,
            "newly_inserted": inserted,
            "coverage_receipts": coverage_receipts,
        }
    finally:
        source.close()
        destination.close()


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Migrate the append-only AXIO7 SQLite market archive to PostgreSQL."
    )
    parser.add_argument("--sqlite", type=Path, required=True)
    parser.add_argument("--schema", type=Path, required=True)
    parser.add_argument("--database-url-env", default="MARKET_DATABASE_URL")
    parser.add_argument("--chunk-size", type=int, default=50_000)
    parser.add_argument("--inventory-only", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    inventory = inspect_sqlite(args.sqlite)
    if args.inventory_only:
        print(json.dumps({"status": "INVENTORIED", **asdict(inventory)}, sort_keys=True))
        return 0

    database_url = os.getenv(args.database_url_env)
    if not database_url:
        raise SystemExit(f"{args.database_url_env} is not configured")
    if args.chunk_size < 1_000:
        raise SystemExit("--chunk-size must be at least 1000")
    result = migrate(args.sqlite, database_url, args.schema, args.chunk_size)
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import sqlite3
import time
from collections.abc import Iterator, Sequence
from dataclasses import asdict, dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path

from intraday_quant.storage.postgres_migration import _create_month_partitions, month_starts


LIVE_COLUMNS = (
    "provider",
    "dataset",
    "schema_name",
    "symbol",
    "event_at",
    "available_at",
    "recorded_at",
    "finalized_at",
    "open",
    "high",
    "low",
    "close",
    "volume",
    "vwap",
    "trade_count",
    "source",
    "data_quality",
    "entitlement",
    "symbol_mapping_verified",
)
LICENSE_SCOPES = ("RESEARCH_ONLY", "INTERNAL_USE", "PUBLIC_DISPLAY", "REDISTRIBUTION")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SOURCE_ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{2,63}$")
LIBPQ_ENVIRONMENT = ("PGHOST", "PGPORT", "PGDATABASE", "PGUSER", "PGPASSWORD")
LIVE_SELECTION_ORDER = "provider, dataset, schema_name, symbol, event_at"


@dataclass(frozen=True)
class LiveSqliteInventory:
    rows: int
    minimum_event_at: str | None
    maximum_event_at: str | None
    minimum_recorded_at: str | None
    maximum_recorded_at: str | None
    symbol_counts: dict[str, int]
    providers: list[str]
    datasets: list[str]
    schemas: list[str]


def _open_readonly(path: Path) -> sqlite3.Connection:
    return sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)


def inspect_live_sqlite(path: Path) -> LiveSqliteInventory:
    connection = _open_readonly(path)
    try:
        row = connection.execute(
            """
            SELECT COUNT(*), MIN(event_at), MAX(event_at),
                   MIN(recorded_at), MAX(recorded_at)
            FROM live_minute_bars
            """
        ).fetchone()
        symbol_counts = {
            str(symbol): int(count)
            for symbol, count in connection.execute(
                "SELECT symbol, COUNT(*) FROM live_minute_bars "
                "GROUP BY symbol ORDER BY symbol"
            )
        }
        distinct = lambda column: [
            str(value)
            for (value,) in connection.execute(
                f"SELECT DISTINCT {column} FROM live_minute_bars ORDER BY {column}"
            )
        ]
        return LiveSqliteInventory(
            rows=int(row[0]),
            minimum_event_at=row[1],
            maximum_event_at=row[2],
            minimum_recorded_at=row[3],
            maximum_recorded_at=row[4],
            symbol_counts=symbol_counts,
            providers=distinct("provider"),
            datasets=distinct("dataset"),
            schemas=distinct("schema_name"),
        )
    finally:
        connection.close()


def _parse_timestamp(value: object, field: str) -> datetime:
    if not isinstance(value, str):
        raise ValueError(f"{field} must be an ISO-8601 string")
    parsed = datetime.fromisoformat(value)
    if parsed.tzinfo is None:
        raise ValueError(f"{field} must include a timezone")
    return parsed.astimezone(UTC)


def validate_live_row(
    row: Sequence[object],
    expected_provider: str,
    expected_dataset: str,
    expected_schema: str,
) -> None:
    if len(row) != len(LIVE_COLUMNS):
        raise ValueError("live archive row has an unexpected column count")
    values = dict(zip(LIVE_COLUMNS, row, strict=True))
    if (
        values["provider"] != expected_provider
        or values["dataset"] != expected_dataset
        or values["schema_name"] != expected_schema
    ):
        raise ValueError("live archive row source contract mismatch")
    symbol = values["symbol"]
    if not isinstance(symbol, str) or not symbol or symbol != symbol.upper():
        raise ValueError("live archive symbol must be non-empty uppercase text")
    if values["symbol_mapping_verified"] not in (1, True):
        raise ValueError("live archive row lacks verified symbol mapping")
    event_at = _parse_timestamp(values["event_at"], "event_at")
    available_at = _parse_timestamp(values["available_at"], "available_at")
    recorded_at = _parse_timestamp(values["recorded_at"], "recorded_at")
    finalized_at = _parse_timestamp(values["finalized_at"], "finalized_at")
    if available_at < event_at + timedelta(minutes=1):
        raise ValueError("live archive row became available before bar completion")
    if recorded_at < available_at or finalized_at != available_at:
        raise ValueError("live archive row has non-causal recorded/finalized clocks")
    prices = [float(values[name]) for name in ("open", "high", "low", "close")]
    if any(not math.isfinite(value) or value <= 0 for value in prices):
        raise ValueError("live archive row contains invalid OHLC")
    open_, high, low, close = prices
    if high < max(open_, low, close) or low > min(open_, high, close):
        raise ValueError("live archive row violates OHLC bounds")
    volume = float(values["volume"])
    if not math.isfinite(volume) or volume < 0:
        raise ValueError("live archive row contains invalid volume")
    if values["vwap"] is not None:
        vwap = float(values["vwap"])
        if not math.isfinite(vwap) or vwap <= 0:
            raise ValueError("live archive row contains invalid VWAP")
    if values["trade_count"] is not None and int(values["trade_count"]) < 0:
        raise ValueError("live archive row contains invalid trade count")
    for field in ("source", "data_quality", "entitlement"):
        if not isinstance(values[field], str) or not values[field].strip():
            raise ValueError(f"live archive row requires {field}")


def _chunks(cursor: sqlite3.Cursor, size: int) -> Iterator[list[tuple[object, ...]]]:
    while rows := cursor.fetchmany(size):
        yield rows


def _hash_row(hasher: hashlib._Hash, row: Sequence[object]) -> None:
    payload = json.dumps(list(row), ensure_ascii=True, separators=(",", ":"))
    hasher.update(payload.encode("utf-8"))
    hasher.update(b"\n")


def _selection_bounds(
    source: sqlite3.Connection,
    expected_provider: str,
    expected_dataset: str,
    expected_schema: str,
    recorded_after: datetime | None,
    decision_cutoff: datetime,
) -> tuple[str | None, str | None, str | None, str | None]:
    conditions = [
        "provider = ?",
        "dataset = ?",
        "schema_name = ?",
        "recorded_at <= ?",
    ]
    parameters: list[object] = [
        expected_provider,
        expected_dataset,
        expected_schema,
        decision_cutoff.isoformat(),
    ]
    if recorded_after is not None:
        conditions.append("recorded_at >= ?")
        parameters.append(recorded_after.isoformat())
    return source.execute(
        f"""
        SELECT MIN(event_at), MAX(event_at), MIN(recorded_at), MAX(recorded_at)
        FROM live_minute_bars
        WHERE {' AND '.join(conditions)}
        """,
        parameters,
    ).fetchone()


def sync_live_archive(
    sqlite_path: Path,
    database_url: str,
    schema_path: Path,
    source_id: str,
    expected_provider: str,
    expected_dataset: str,
    expected_schema: str,
    license_scope: str,
    license_reference_sha256: str,
    decision_cutoff: datetime,
    overlap_seconds: int = 600,
    chunk_size: int = 50_000,
) -> dict[str, object]:
    import psycopg

    if not SOURCE_ID_RE.fullmatch(source_id):
        raise ValueError("source_id must be a stable lowercase identifier")
    if license_scope not in LICENSE_SCOPES:
        raise ValueError("unsupported license scope")
    if not SHA256_RE.fullmatch(license_reference_sha256):
        raise ValueError("license reference must be a lowercase SHA-256")
    if decision_cutoff.tzinfo is None:
        raise ValueError("decision cutoff must include a timezone")
    decision_cutoff = decision_cutoff.astimezone(UTC)
    if overlap_seconds < 60 or overlap_seconds > 86_400:
        raise ValueError("overlap_seconds must be between 60 and 86400")
    if chunk_size < 1_000:
        raise ValueError("chunk_size must be at least 1000")

    source = _open_readonly(sqlite_path)
    destination = psycopg.connect(database_url)
    attempted_rows = 0
    inserted_rows = 0
    first_event_at: str | None = None
    last_event_at: str | None = None
    first_recorded_at: str | None = None
    last_recorded_at: str | None = None
    content_hasher = hashlib.sha256()
    try:
        destination.execute(schema_path.read_text(encoding="utf-8"))
        destination.commit()
        watermark = destination.execute(
            """
            SELECT MAX(recorded_at)
            FROM market_data.live_equity_minute_bars
            WHERE provider = %s AND dataset = %s AND schema_name = %s
            """,
            (expected_provider, expected_dataset, expected_schema),
        ).fetchone()[0]
        recorded_after = (
            watermark.astimezone(UTC) - timedelta(seconds=overlap_seconds)
            if watermark is not None
            else None
        )
        bounds = _selection_bounds(
            source,
            expected_provider,
            expected_dataset,
            expected_schema,
            recorded_after,
            decision_cutoff,
        )
        if bounds[0] is not None and bounds[1] is not None:
            _create_month_partitions(destination, month_starts(bounds[0], bounds[1]))
            destination.commit()

        conditions = [
            "provider = ?",
            "dataset = ?",
            "schema_name = ?",
            "recorded_at <= ?",
        ]
        parameters: list[object] = [
            expected_provider,
            expected_dataset,
            expected_schema,
            decision_cutoff.isoformat(),
        ]
        if recorded_after is not None:
            conditions.append("recorded_at >= ?")
            parameters.append(recorded_after.isoformat())
        source_cursor = source.execute(
            f"""
            SELECT {', '.join(LIVE_COLUMNS)}
            FROM live_minute_bars
            WHERE {' AND '.join(conditions)}
            ORDER BY {LIVE_SELECTION_ORDER}
            """,
            parameters,
        )
        for rows in _chunks(source_cursor, chunk_size):
            staged_rows = []
            for row in rows:
                validate_live_row(row, expected_provider, expected_dataset, expected_schema)
                _hash_row(content_hasher, row)
                attempted_rows += 1
                event_at = str(row[4])
                recorded_at = str(row[6])
                first_event_at = event_at if first_event_at is None else min(first_event_at, event_at)
                last_event_at = event_at if last_event_at is None else max(last_event_at, event_at)
                first_recorded_at = (
                    recorded_at
                    if first_recorded_at is None
                    else min(first_recorded_at, recorded_at)
                )
                last_recorded_at = (
                    recorded_at
                    if last_recorded_at is None
                    else max(last_recorded_at, recorded_at)
                )
                staged_rows.append((*row, license_scope, license_reference_sha256))
            with destination.cursor() as cursor:
                cursor.execute(
                    """
                    CREATE TEMP TABLE live_minute_bars_stage
                    (LIKE market_data.live_equity_minute_bars INCLUDING DEFAULTS)
                    ON COMMIT DROP
                    """
                )
                with cursor.copy(
                    """
                    COPY live_minute_bars_stage (
                        provider, dataset, schema_name, symbol, event_at,
                        available_at, recorded_at, finalized_at, open, high, low,
                        close, volume, vwap, trade_count, source, data_quality,
                        entitlement, symbol_mapping_verified, license_scope,
                        license_reference_sha256
                    ) FROM STDIN
                    """
                ) as copy:
                    for staged in staged_rows:
                        copy.write_row(staged)
                cursor.execute(
                    """
                    INSERT INTO market_data.live_equity_minute_bars
                    SELECT * FROM live_minute_bars_stage
                    ON CONFLICT (provider, dataset, schema_name, symbol, event_at)
                    DO NOTHING
                    """
                )
                inserted_rows += cursor.rowcount
            destination.commit()

        content_sha256 = content_hasher.hexdigest()
        duplicate_rows = attempted_rows - inserted_rows
        receipt_payload = {
            "source_id": source_id,
            "decision_cutoff": decision_cutoff.isoformat(),
            "first_recorded_at": first_recorded_at,
            "last_recorded_at": last_recorded_at,
            "first_event_at": first_event_at,
            "last_event_at": last_event_at,
            "attempted_rows": attempted_rows,
            "inserted_rows": inserted_rows,
            "duplicate_rows": duplicate_rows,
            "content_sha256": content_sha256,
            "license_scope": license_scope,
            "license_reference_sha256": license_reference_sha256,
        }
        receipt_id = hashlib.sha256(
            json.dumps(receipt_payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
        ).hexdigest()
        destination.execute(
            """
            INSERT INTO market_data.live_archive_receipts (
                receipt_id, source_id, decision_cutoff, first_recorded_at,
                last_recorded_at, first_event_at, last_event_at, attempted_rows,
                inserted_rows, duplicate_rows, content_sha256, license_scope,
                license_reference_sha256
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            ON CONFLICT (receipt_id) DO NOTHING
            """,
            (
                receipt_id,
                source_id,
                decision_cutoff,
                first_recorded_at,
                last_recorded_at,
                first_event_at,
                last_event_at,
                attempted_rows,
                inserted_rows,
                duplicate_rows,
                content_sha256,
                license_scope,
                license_reference_sha256,
            ),
        )
        destination.commit()
        return {"status": "ARCHIVED_APPEND_ONLY", "receipt_id": receipt_id, **receipt_payload}
    finally:
        source.close()
        destination.close()


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Archive finalized AXIO7 live SQLite bars into append-only PostgreSQL."
    )
    parser.add_argument("--sqlite", type=Path, required=True)
    parser.add_argument("--schema", type=Path, required=True)
    parser.add_argument("--source-id", required=True)
    parser.add_argument("--expected-provider", required=True)
    parser.add_argument("--expected-dataset", required=True)
    parser.add_argument("--expected-schema", required=True)
    parser.add_argument("--license-scope", choices=LICENSE_SCOPES, required=True)
    parser.add_argument("--database-url-env", default="MARKET_DATABASE_URL")
    parser.add_argument(
        "--license-reference-sha256-env",
        default="AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256",
    )
    parser.add_argument("--decision-cutoff")
    parser.add_argument("--safety-lag-seconds", type=int, default=120)
    parser.add_argument("--overlap-seconds", type=int, default=600)
    parser.add_argument("--chunk-size", type=int, default=50_000)
    parser.add_argument("--watch-interval-seconds", type=int, default=0)
    parser.add_argument("--inventory-only", action="store_true")
    return parser


def database_connection_target(database_url_env: str) -> str:
    database_url = os.getenv(database_url_env, "").strip()
    if database_url:
        return database_url
    missing = [name for name in LIBPQ_ENVIRONMENT if not os.getenv(name, "").strip()]
    if missing:
        raise ValueError(
            f"{database_url_env} or the complete libpq environment must be configured; "
            f"missing {','.join(missing)}"
        )
    # An empty conninfo tells psycopg/libpq to use PGHOST, PGPORT, PGDATABASE,
    # PGUSER, and PGPASSWORD without copying the password into an argument.
    return ""


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    inventory = inspect_live_sqlite(args.sqlite)
    if args.inventory_only:
        print(json.dumps({"status": "INVENTORIED", **asdict(inventory)}, sort_keys=True))
        return 0
    try:
        database_url = database_connection_target(args.database_url_env)
    except ValueError as error:
        raise SystemExit(str(error)) from error
    license_reference_sha256 = os.getenv(args.license_reference_sha256_env, "").lower()
    if not SHA256_RE.fullmatch(license_reference_sha256):
        raise SystemExit(
            f"{args.license_reference_sha256_env} must contain a lowercase SHA-256"
        )
    if args.safety_lag_seconds < 60 or args.safety_lag_seconds > 3600:
        raise SystemExit("--safety-lag-seconds must be between 60 and 3600")
    if args.watch_interval_seconds not in (0,) and not (
        60 <= args.watch_interval_seconds <= 3600
    ):
        raise SystemExit("--watch-interval-seconds must be zero or between 60 and 3600")
    if args.decision_cutoff and args.watch_interval_seconds:
        raise SystemExit("a fixed --decision-cutoff cannot be combined with watch mode")
    while True:
        decision_cutoff = (
            _parse_timestamp(args.decision_cutoff, "decision_cutoff")
            if args.decision_cutoff
            else datetime.now(UTC) - timedelta(seconds=args.safety_lag_seconds)
        )
        result = sync_live_archive(
            sqlite_path=args.sqlite,
            database_url=database_url,
            schema_path=args.schema,
            source_id=args.source_id,
            expected_provider=args.expected_provider,
            expected_dataset=args.expected_dataset,
            expected_schema=args.expected_schema,
            license_scope=args.license_scope,
            license_reference_sha256=license_reference_sha256,
            decision_cutoff=decision_cutoff,
            overlap_seconds=args.overlap_seconds,
            chunk_size=args.chunk_size,
        )
        print(json.dumps(result, sort_keys=True), flush=True)
        if args.watch_interval_seconds == 0:
            return 0
        time.sleep(args.watch_interval_seconds)


if __name__ == "__main__":
    raise SystemExit(main())

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import io
import json
import os
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import UTC, date, datetime, time as datetime_time, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo


OCC_REPORT_URL = "https://marketdata.theocc.com/daily-open-interest"
OCC_LICENSE_REFERENCE = (
    "https://www.theocc.com/market-data/market-data-reports/"
    "other-market-data-info/batch-processing/daily-open-interest"
)


@dataclass(frozen=True)
class OccDailyOpenInterestTotal:
    observation_date: date
    available_at: datetime
    equity_calls: int
    equity_puts: int
    equity_total: int
    index_other_calls: int
    index_other_puts: int
    index_other_total: int
    debt_calls: int
    debt_puts: int
    debt_total: int
    futures_total: int
    occ_total: int


def conservative_availability(observation_date: date) -> datetime:
    eastern = ZoneInfo("America/New_York")
    return datetime.combine(
        observation_date + timedelta(days=1), datetime_time(12, 0), eastern
    ).astimezone(UTC)


def _integer(value: str) -> int:
    return int(value.replace(",", "").strip())


def parse_occ_month(raw: bytes) -> list[OccDailyOpenInterestTotal]:
    text = raw.decode("utf-8-sig")
    rows = list(csv.reader(io.StringIO(text)))
    if len(rows) < 4 or not rows[0] or not rows[0][0].startswith(
        "Daily Open Interest - "
    ):
        raise ValueError("not an OCC Daily Open Interest monthly CSV")
    parsed: list[OccDailyOpenInterestTotal] = []
    for row in rows[3:]:
        if not row or not row[0].strip():
            continue
        observation_date = datetime.strptime(row[0], "%m/%d/%Y").date()
        values = [_integer(value) for value in row[1:12]]
        record = OccDailyOpenInterestTotal(
            observation_date=observation_date,
            available_at=conservative_availability(observation_date),
            equity_calls=values[0],
            equity_puts=values[1],
            equity_total=values[2],
            index_other_calls=values[3],
            index_other_puts=values[4],
            index_other_total=values[5],
            debt_calls=values[6],
            debt_puts=values[7],
            debt_total=values[8],
            futures_total=values[9],
            occ_total=values[10],
        )
        if record.equity_total != record.equity_calls + record.equity_puts:
            raise ValueError(f"invalid OCC equity total on {observation_date}")
        if record.index_other_total != (
            record.index_other_calls + record.index_other_puts
        ):
            raise ValueError(f"invalid OCC index total on {observation_date}")
        if record.debt_total != record.debt_calls + record.debt_puts:
            raise ValueError(f"invalid OCC debt total on {observation_date}")
        parsed.append(record)
    if not parsed:
        raise ValueError("OCC monthly file contains no daily rows")
    return parsed


def _month_requests(start: date, end: date) -> list[date]:
    if end < start:
        raise ValueError("end must be on or after start")
    requests: list[date] = []
    current = start.replace(day=1)
    while current <= end:
        next_month = (
            current.replace(year=current.year + 1, month=1)
            if current.month == 12
            else current.replace(month=current.month + 1)
        )
        month_end = next_month - timedelta(days=1)
        requests.append(min(month_end, end))
        current = next_month
    return requests


def download_month(report_date: date) -> bytes:
    query = urllib.parse.urlencode(
        {
            "reportDate": report_date.strftime("%m/%d/%Y"),
            "action": "download",
            "format": "csv",
        }
    )
    request = urllib.request.Request(
        f"{OCC_REPORT_URL}?{query}",
        headers={"User-Agent": "AXIO7-research-ingestor/1.0"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def ingest_range(
    database_url: str,
    schema_path: Path,
    raw_root: Path,
    start: date,
    end: date,
    minimum_interval_seconds: float = 0.5,
) -> dict[str, object]:
    import psycopg

    captured_at = datetime.now(UTC)
    raw_root.mkdir(parents=True, exist_ok=True)
    batches: list[tuple[str, Path, list[OccDailyOpenInterestTotal]]] = []
    last_request = 0.0
    for report_date in _month_requests(start, end):
        elapsed = time.monotonic() - last_request
        if elapsed < minimum_interval_seconds:
            time.sleep(minimum_interval_seconds - elapsed)
        raw = download_month(report_date)
        last_request = time.monotonic()
        rows = [
            row
            for row in parse_occ_month(raw)
            if start <= row.observation_date <= end
        ]
        if not rows:
            continue
        source_hash = hashlib.sha256(raw).hexdigest()
        path = raw_root / f"{report_date:%Y-%m}-{source_hash[:16]}.csv.gz"
        with gzip.open(path, "wb") as handle:
            handle.write(raw)
        batches.append((source_hash, path, rows))

    if not batches:
        raise RuntimeError("no OCC daily totals were downloaded for the interval")
    inserted_rows = 0
    with psycopg.connect(database_url) as connection:
        connection.execute(schema_path.read_text(encoding="utf-8"))
        for source_hash, path, rows in batches:
            batch_id = hashlib.sha256(
                f"OCC_DAILY_OPEN_INTEREST_TOTALS:{source_hash}".encode()
            ).hexdigest()
            connection.execute(
                """
                INSERT INTO market_data.batches (
                    batch_id, provider, dataset, source_file_sha256, source_path,
                    captured_at, availability_policy, availability_delay_seconds,
                    license_scope, license_reference, input_rows, accepted_rows,
                    duplicate_rows, rejected_rows
                ) VALUES (
                    %s, 'OCC', 'DAILY_OPEN_INTEREST_TOTALS', %s, %s, %s,
                    'CONSERVATIVE_NEXT_CALENDAR_DAY_NOON_ET', 0,
                    'RESEARCH_ONLY', %s, %s, %s, 0, 0
                )
                ON CONFLICT (batch_id) DO NOTHING
                """,
                (
                    batch_id,
                    source_hash,
                    str(path),
                    captured_at,
                    OCC_LICENSE_REFERENCE,
                    len(rows),
                    len(rows),
                ),
            )
            with connection.cursor() as cursor:
                cursor.executemany(
                    """
                    INSERT INTO market_data.occ_daily_open_interest_totals (
                        batch_id, observation_date, available_at, recorded_at,
                        equity_calls, equity_puts, equity_total,
                        index_other_calls, index_other_puts, index_other_total,
                        debt_calls, debt_puts, debt_total, futures_total, occ_total,
                        source, data_quality
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                        %s, %s, %s, 'OCC_DAILY_OPEN_INTEREST_TOTALS',
                        'OFFICIAL_MARKET_WIDE_TOTAL_NOT_CONTRACT_OI'
                    )
                    ON CONFLICT (batch_id, observation_date) DO NOTHING
                    """,
                    [
                        (
                            batch_id,
                            row.observation_date,
                            row.available_at,
                            captured_at,
                            row.equity_calls,
                            row.equity_puts,
                            row.equity_total,
                            row.index_other_calls,
                            row.index_other_puts,
                            row.index_other_total,
                            row.debt_calls,
                            row.debt_puts,
                            row.debt_total,
                            row.futures_total,
                            row.occ_total,
                        )
                        for row in rows
                    ],
                )
                inserted_rows += cursor.rowcount
        connection.commit()
    return {
        "status": "INGESTED_RESEARCH_ONLY",
        "dataset": "OCC_DAILY_OPEN_INTEREST_TOTALS",
        "requested_start": start.isoformat(),
        "requested_end": end.isoformat(),
        "monthly_files": len(batches),
        "downloaded_rows": sum(len(rows) for _, _, rows in batches),
        "newly_inserted": inserted_rows,
        "contract_level": False,
        "gamma_eligible": False,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Archive official OCC market-wide daily open-interest totals."
    )
    parser.add_argument("--start", type=date.fromisoformat, required=True)
    parser.add_argument("--end", type=date.fromisoformat, required=True)
    parser.add_argument(
        "--schema",
        type=Path,
        default=Path("../infra/market-data/postgres/schema.sql"),
    )
    parser.add_argument(
        "--raw-root",
        type=Path,
        default=Path("../quant_engine_rs/data/raw/occ/daily_open_interest_totals"),
    )
    parser.add_argument("--database-url-env", default="MARKET_DATABASE_URL")
    parser.add_argument("--minimum-interval-seconds", type=float, default=0.5)
    return parser


def main() -> int:
    arguments = _parser().parse_args()
    database_url = os.environ.get(arguments.database_url_env)
    if not database_url:
        raise SystemExit(f"{arguments.database_url_env} is not configured")
    result = ingest_range(
        database_url=database_url,
        schema_path=arguments.schema,
        raw_root=arguments.raw_root,
        start=arguments.start,
        end=arguments.end,
        minimum_interval_seconds=arguments.minimum_interval_seconds,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

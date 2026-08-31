from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass
from datetime import UTC, date, datetime, time as datetime_time, timedelta
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo


MASSIVE_API_ROOT = "https://api.massive.com"
MASSIVE_LICENSE_REFERENCE = (
    "https://massive.com/legal/market-data-terms-of-service;"
    "https://massive.com/pricing?product=options"
)


@dataclass(frozen=True)
class OptionContract:
    option_symbol: str
    underlying_symbol: str
    expiration_date: date
    strike: float
    option_right: str
    multiplier: int
    exercise_style: str | None
    listing_exchange: str | None


@dataclass(frozen=True)
class OptionMinuteBar:
    option_symbol: str
    event_at: datetime
    available_at: datetime
    open: float
    high: float
    low: float
    close: float
    volume: int
    transaction_count: int | None


def parse_contract(payload: dict[str, Any]) -> OptionContract:
    option_type = str(payload["contract_type"]).lower()
    if option_type not in {"call", "put"}:
        raise ValueError(f"unsupported contract type: {option_type}")
    option_symbol = str(payload["ticker"]).upper()
    if not option_symbol.startswith("O:"):
        raise ValueError(f"not an OCC-style Massive option ticker: {option_symbol}")
    return OptionContract(
        option_symbol=option_symbol,
        underlying_symbol=str(payload["underlying_ticker"]).upper(),
        expiration_date=date.fromisoformat(str(payload["expiration_date"])),
        strike=float(payload["strike_price"]),
        option_right="C" if option_type == "call" else "P",
        multiplier=int(payload.get("shares_per_contract") or 100),
        exercise_style=(
            str(payload["exercise_style"]) if payload.get("exercise_style") else None
        ),
        listing_exchange=(
            str(payload["primary_exchange"]) if payload.get("primary_exchange") else None
        ),
    )


def basic_eod_availability(event_at: datetime) -> datetime:
    """Conservative availability for the free end-of-day entitlement.

    Massive documents Basic as end-of-day and its flat files as available by
    approximately 11:00 ET on the next day. Noon ET on the next calendar day
    intentionally prevents these records from entering a same-day simulation.
    """

    eastern = ZoneInfo("America/New_York")
    local_date = event_at.astimezone(eastern).date() + timedelta(days=1)
    return datetime.combine(local_date, datetime_time(12, 0), eastern).astimezone(UTC)


def parse_bars(
    option_symbol: str, payload: dict[str, Any]
) -> list[OptionMinuteBar]:
    if payload.get("status") not in {"OK", "DELAYED"}:
        raise ValueError(f"Massive response status is not usable: {payload.get('status')}")
    bars: list[OptionMinuteBar] = []
    for row in payload.get("results") or []:
        event_at = datetime.fromtimestamp(float(row["t"]) / 1_000, UTC)
        bar = OptionMinuteBar(
            option_symbol=option_symbol,
            event_at=event_at,
            available_at=basic_eod_availability(event_at),
            open=float(row["o"]),
            high=float(row["h"]),
            low=float(row["l"]),
            close=float(row["c"]),
            volume=int(row["v"]),
            transaction_count=int(row["n"]) if row.get("n") is not None else None,
        )
        if bar.high < max(bar.open, bar.low, bar.close):
            raise ValueError(f"invalid high for {option_symbol} at {event_at}")
        if bar.low > min(bar.open, bar.high, bar.close):
            raise ValueError(f"invalid low for {option_symbol} at {event_at}")
        bars.append(bar)
    return bars


class MassiveClient:
    def __init__(self, api_key: str, minimum_interval_seconds: float = 12.1) -> None:
        if not api_key:
            raise ValueError("Massive API key is required")
        self.api_key = api_key
        self.minimum_interval_seconds = minimum_interval_seconds
        self._last_request = 0.0

    def get_json(
        self, path_or_url: str, parameters: dict[str, Any] | None = None
    ) -> tuple[dict[str, Any], bytes]:
        elapsed = time.monotonic() - self._last_request
        if elapsed < self.minimum_interval_seconds:
            time.sleep(self.minimum_interval_seconds - elapsed)
        if path_or_url.startswith("https://"):
            url = path_or_url
        else:
            query = urllib.parse.urlencode(parameters or {})
            url = f"{MASSIVE_API_ROOT}{path_or_url}"
            if query:
                url = f"{url}?{query}"
        request = urllib.request.Request(
            url, headers={"Authorization": f"Bearer {self.api_key}"}
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                raw = response.read()
        except urllib.error.HTTPError as error:
            body = error.read(500).decode("utf-8", errors="replace")
            raise RuntimeError(
                f"Massive request failed with HTTP {error.code}: {body}"
            ) from error
        finally:
            self._last_request = time.monotonic()
        return json.loads(raw), raw

    def contracts(
        self,
        underlying: str,
        expiration: date,
        strike_minimum: float,
        strike_maximum: float,
    ) -> tuple[list[OptionContract], list[bytes]]:
        contracts: list[OptionContract] = []
        raw_pages: list[bytes] = []
        next_url: str | None = "/v3/reference/options/contracts"
        parameters: dict[str, Any] | None = {
            "underlying_ticker": underlying.upper(),
            "expiration_date": expiration.isoformat(),
            "strike_price.gte": strike_minimum,
            "strike_price.lte": strike_maximum,
            "expired": "true",
            "limit": 1000,
            "sort": "ticker",
            "order": "asc",
        }
        while next_url:
            payload, raw = self.get_json(next_url, parameters)
            raw_pages.append(raw)
            contracts.extend(parse_contract(row) for row in payload.get("results") or [])
            next_url = payload.get("next_url")
            parameters = None
        return contracts, raw_pages

    def minute_bars(
        self, contract: OptionContract, start: date, end: date
    ) -> tuple[list[OptionMinuteBar], bytes]:
        symbol = urllib.parse.quote(contract.option_symbol, safe="")
        payload, raw = self.get_json(
            f"/v2/aggs/ticker/{symbol}/range/1/minute/{start}/{end}",
            {"adjusted": "true", "sort": "asc", "limit": 50_000},
        )
        return parse_bars(contract.option_symbol, payload), raw


def _month_floor(value: datetime) -> datetime:
    return value.astimezone(UTC).replace(
        day=1, hour=0, minute=0, second=0, microsecond=0
    )


def _next_month(value: datetime) -> datetime:
    if value.month == 12:
        return value.replace(year=value.year + 1, month=1)
    return value.replace(month=value.month + 1)


def _apply_schema_and_partitions(
    connection: Any, schema_path: Path, event_times: list[datetime]
) -> None:
    from psycopg import sql

    connection.execute(schema_path.read_text(encoding="utf-8"))
    months = sorted({_month_floor(value) for value in event_times})
    for start in months:
        end = _next_month(start)
        suffix = f"{start.year:04d}_{start.month:02d}"
        connection.execute(
            sql.SQL(
                "CREATE TABLE IF NOT EXISTS market_data.{} "
                "PARTITION OF market_data.option_minute_bars "
                "FOR VALUES FROM ({}) TO ({})"
            ).format(
                sql.Identifier(f"option_minute_bars_{suffix}"),
                sql.Literal(start),
                sql.Literal(end),
            )
        )
    connection.commit()


def ingest_expiration_slice(
    api_key: str,
    database_url: str,
    schema_path: Path,
    raw_root: Path,
    underlying: str,
    expiration: date,
    strike_minimum: float,
    strike_maximum: float,
    start: date,
    end: date,
    minimum_interval_seconds: float = 12.1,
) -> dict[str, Any]:
    import psycopg

    captured_at = datetime.now(UTC)
    client = MassiveClient(api_key, minimum_interval_seconds)
    contracts, contract_pages = client.contracts(
        underlying, expiration, strike_minimum, strike_maximum
    )
    if not contracts:
        raise RuntimeError("Massive returned no contracts for the requested slice")
    all_bars: list[OptionMinuteBar] = []
    raw_responses: list[tuple[str, bytes]] = [
        (f"contracts-{index:04d}.json", raw)
        for index, raw in enumerate(contract_pages)
    ]
    for contract in contracts:
        bars, raw = client.minute_bars(contract, start, end)
        all_bars.extend(bars)
        safe_symbol = contract.option_symbol.replace(":", "_")
        raw_responses.append((f"{safe_symbol}-{start}-{end}.json", raw))
    if not all_bars:
        raise RuntimeError("Massive returned contracts but no minute aggregate bars")

    raw_directory = (
        raw_root
        / underlying.upper()
        / expiration.isoformat()
        / f"{strike_minimum:g}-{strike_maximum:g}"
    )
    raw_directory.mkdir(parents=True, exist_ok=True)
    raw_hashes: list[dict[str, str]] = []
    for name, raw in raw_responses:
        path = raw_directory / f"{name}.gz"
        with gzip.open(path, "wb") as handle:
            handle.write(raw)
        raw_hashes.append(
            {"path": str(path), "sha256": hashlib.sha256(raw).hexdigest()}
        )
    source_manifest = {
        "provider": "MASSIVE",
        "dataset": "OPTIONS_MINUTE_AGGREGATES",
        "captured_at": captured_at.isoformat(),
        "request": {
            "underlying": underlying.upper(),
            "expiration": expiration.isoformat(),
            "strike_minimum": strike_minimum,
            "strike_maximum": strike_maximum,
            "start": start.isoformat(),
            "end": end.isoformat(),
        },
        "raw_files": raw_hashes,
    }
    manifest_bytes = json.dumps(
        source_manifest, sort_keys=True, separators=(",", ":")
    ).encode()
    source_sha256 = hashlib.sha256(manifest_bytes).hexdigest()
    manifest_path = raw_directory / f"manifest-{source_sha256[:16]}.json"
    manifest_path.write_bytes(manifest_bytes)
    batch_id = source_sha256

    with psycopg.connect(database_url) as connection:
        _apply_schema_and_partitions(
            connection, schema_path, [bar.event_at for bar in all_bars]
        )
        connection.execute(
            """
            INSERT INTO market_data.batches (
                batch_id, provider, dataset, source_file_sha256, source_path,
                captured_at, availability_policy, availability_delay_seconds,
                license_scope, license_reference, input_rows, accepted_rows,
                duplicate_rows, rejected_rows
            ) VALUES (
                %s, 'MASSIVE', 'OPTIONS_MINUTE_AGGREGATES', %s, %s, %s,
                'OPTIONS_BASIC_END_OF_DAY_NEXT_DAY_NOON_ET', 0,
                'RESEARCH_ONLY', %s, %s, %s, 0, 0
            )
            ON CONFLICT (batch_id) DO NOTHING
            """,
            (
                batch_id,
                source_sha256,
                str(manifest_path),
                captured_at,
                MASSIVE_LICENSE_REFERENCE,
                len(all_bars),
                len(all_bars),
            ),
        )
        with connection.cursor() as cursor:
            cursor.executemany(
                """
                INSERT INTO market_data.option_contracts (
                    option_symbol, underlying_symbol, expiration_date, strike,
                    option_right, multiplier, exercise_style, settlement_style,
                    listing_exchange, first_seen_at, last_seen_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, NULL, %s, %s, %s)
                ON CONFLICT (option_symbol) DO NOTHING
                """,
                [
                    (
                        contract.option_symbol,
                        contract.underlying_symbol,
                        contract.expiration_date,
                        contract.strike,
                        contract.option_right,
                        contract.multiplier,
                        contract.exercise_style,
                        contract.listing_exchange,
                        captured_at,
                        captured_at,
                    )
                    for contract in contracts
                ],
            )
        recorded_at = datetime.now(UTC)
        with connection.cursor() as cursor:
            cursor.execute(
                """
                CREATE TEMP TABLE option_minute_bars_stage
                (LIKE market_data.option_minute_bars INCLUDING DEFAULTS)
                ON COMMIT DROP
                """
            )
            with cursor.copy(
                """
                COPY option_minute_bars_stage (
                    batch_id, option_symbol, event_at, available_at, recorded_at,
                    open, high, low, close, volume, transaction_count,
                    source, data_quality
                ) FROM STDIN
                """
            ) as copy:
                for bar in all_bars:
                    copy.write_row(
                        (
                            batch_id,
                            bar.option_symbol,
                            bar.event_at,
                            bar.available_at,
                            recorded_at,
                            bar.open,
                            bar.high,
                            bar.low,
                            bar.close,
                            bar.volume,
                            bar.transaction_count,
                            "MASSIVE_OPTIONS_AGG_1M",
                            "END_OF_DAY_AGGREGATE_NO_NBBO_NO_OPEN_INTEREST",
                        )
                    )
            cursor.execute(
                """
                INSERT INTO market_data.option_minute_bars
                SELECT * FROM option_minute_bars_stage
                ON CONFLICT (batch_id, option_symbol, event_at) DO NOTHING
                """
            )
            newly_inserted = cursor.rowcount
        connection.execute(
            """
            INSERT INTO market_data.coverage_receipts (
                batch_id, dataset, symbol, minimum_event_at, maximum_event_at,
                row_count, vwap_row_count, bid_row_count, ask_row_count,
                trade_count_row_count
            )
            SELECT
                batch_id, 'OPTION_MINUTE_BARS', option_symbol, MIN(event_at),
                MAX(event_at), COUNT(*), 0, 0, 0, COUNT(transaction_count)
            FROM market_data.option_minute_bars
            WHERE batch_id = %s
            GROUP BY batch_id, option_symbol
            ON CONFLICT (batch_id, dataset, symbol) DO NOTHING
            """,
            (batch_id,),
        )
        receipt_payload = {
            "underlying": underlying.upper(),
            "expiration": expiration.isoformat(),
            "contracts": len(contracts),
            "bars": len(all_bars),
            "has_nbbo": False,
            "has_open_interest": False,
            "same_day_realtime_eligible": False,
            "source_manifest_sha256": source_sha256,
        }
        receipt_id = hashlib.sha256(
            json.dumps(receipt_payload, sort_keys=True).encode()
        ).hexdigest()
        connection.execute(
            """
            INSERT INTO market_data.readiness_receipts (
                receipt_id, observed_at, provider, dataset, symbols,
                entitlement_status, freshness_status, coverage_status,
                license_scope, details
            ) VALUES (
                %s, %s, 'MASSIVE', 'OPTIONS_MINUTE_AGGREGATES', %s,
                'OPTIONS_BASIC', 'END_OF_DAY_ONLY',
                'BOUNDED_EXPIRATION_STRIKE_SLICE', 'RESEARCH_ONLY', %s::jsonb
            )
            ON CONFLICT (receipt_id) DO NOTHING
            """,
            (
                receipt_id,
                captured_at,
                [contract.option_symbol for contract in contracts],
                json.dumps(receipt_payload),
            ),
        )
        connection.commit()
    return {
        "status": "INGESTED_RESEARCH_ONLY",
        "batch_id": batch_id,
        "underlying": underlying.upper(),
        "contracts": len(contracts),
        "bars": len(all_bars),
        "newly_inserted": newly_inserted,
        "minimum_event_at": min(bar.event_at for bar in all_bars).isoformat(),
        "maximum_event_at": max(bar.event_at for bar in all_bars).isoformat(),
        "has_nbbo": False,
        "has_open_interest": False,
        "realtime_eligible": False,
        "manifest": str(manifest_path),
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Ingest a bounded Massive options minute-aggregate slice."
    )
    parser.add_argument("--underlying", required=True)
    parser.add_argument("--expiration", type=date.fromisoformat, required=True)
    parser.add_argument("--strike-min", type=float, required=True)
    parser.add_argument("--strike-max", type=float, required=True)
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
        default=Path("../quant_engine_rs/data/raw/massive/options_minute_aggs"),
    )
    parser.add_argument("--api-key-env", default="MASSIVE_API_KEY")
    parser.add_argument("--database-url-env", default="MARKET_DATABASE_URL")
    parser.add_argument("--minimum-interval-seconds", type=float, default=12.1)
    return parser


def main() -> int:
    arguments = _parser().parse_args()
    api_key = os.environ.get(arguments.api_key_env)
    database_url = os.environ.get(arguments.database_url_env)
    if not api_key:
        raise SystemExit(f"{arguments.api_key_env} is not configured")
    if not database_url:
        raise SystemExit(f"{arguments.database_url_env} is not configured")
    result = ingest_expiration_slice(
        api_key=api_key,
        database_url=database_url,
        schema_path=arguments.schema,
        raw_root=arguments.raw_root,
        underlying=arguments.underlying,
        expiration=arguments.expiration,
        strike_minimum=arguments.strike_min,
        strike_maximum=arguments.strike_max,
        start=arguments.start,
        end=arguments.end,
        minimum_interval_seconds=arguments.minimum_interval_seconds,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

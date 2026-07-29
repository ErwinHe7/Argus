#!/usr/bin/env python3
"""Read-only Moomoo historical K_1M exporter for deterministic Rust replay.

This process creates only ``OpenQuoteContext`` and calls only
``request_history_kline``.  It never imports or creates a trade context and
accepts OpenD only on a loopback address.

The provider's US ``time_key`` is preserved as ``event_timestamp_et`` so the
wire format matches ``moomoo_quote_bridge.py`` and ``quantctl moomoo-replay``.
``api_response_received_at_utc`` is the local AXIO7 receipt time for the
historical API response.  It is deliberately *not* represented as the
historical bar's original point-in-time availability timestamp.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from datetime import date, datetime, timezone
from typing import Any, Mapping

from moomoo_quote_bridge import (
    EXPECTED_SDK_VERSION,
    JsonLineEmitter,
    _normalized_sdk_version,
    frame_records,
    log,
    map_kline_row,
    parse_symbols,
    validate_loopback_host,
    validate_port,
)

DEFAULT_PAGE_SIZE = 1000
DEFAULT_MAX_ROWS = 500_000
MAX_PAGE_SIZE = 1000
MAX_EXPORT_ROWS = 2_000_000
TIME_KEY_SEMANTICS = (
    "MOOMOO_US_EASTERN_K_1M_BUCKET_END_LABEL_AS_RETURNED_BY_OPEND"
)
AVAILABILITY_SEMANTICS = (
    "HISTORICAL_API_RESPONSE_RECEIPT_ONLY;"
    "ORIGINAL_POINT_IN_TIME_AVAILABILITY_UNKNOWN"
)


def validate_date(value: str) -> str:
    text = str(value).strip()
    try:
        parsed = date.fromisoformat(text)
    except ValueError as error:
        raise argparse.ArgumentTypeError("date must use YYYY-MM-DD") from error
    if parsed.isoformat() != text:
        raise argparse.ArgumentTypeError("date must use canonical YYYY-MM-DD")
    return text


def bounded_positive_int(
    value: str | int, *, name: str, maximum: int
) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError) as error:
        raise argparse.ArgumentTypeError(f"{name} must be an integer") from error
    if not 1 <= parsed <= maximum:
        raise argparse.ArgumentTypeError(
            f"{name} must be between 1 and {maximum}"
        )
    return parsed


def validate_page_size(value: str | int) -> int:
    return bounded_positive_int(
        value, name="page-size", maximum=MAX_PAGE_SIZE
    )


def validate_max_rows(value: str | int) -> int:
    return bounded_positive_int(
        value, name="max-rows", maximum=MAX_EXPORT_ROWS
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Export official Moomoo historical K_1M rows as replay JSONL "
            "without any trading capability"
        )
    )
    commands = parser.add_subparsers(dest="command", required=True)
    history = commands.add_parser(
        "HistoryKline",
        help="request paginated unadjusted historical one-minute quote bars",
    )
    history.add_argument("--host", required=True, type=validate_loopback_host)
    history.add_argument("--port", required=True, type=validate_port)
    history.add_argument("--symbols", required=True, type=parse_symbols)
    history.add_argument("--start", required=True, type=validate_date)
    history.add_argument("--end", required=True, type=validate_date)
    history.add_argument(
        "--page-size",
        type=validate_page_size,
        default=DEFAULT_PAGE_SIZE,
    )
    history.add_argument(
        "--max-rows",
        type=validate_max_rows,
        default=DEFAULT_MAX_ROWS,
        help="fail closed if the export would exceed this many rows",
    )
    history.add_argument(
        "--extended-time",
        action="store_true",
        help="include Moomoo-supported US extended-hours K_1M rows",
    )
    history.add_argument(
        "--dry-run",
        action="store_true",
        help="validate arguments and capability boundary without connecting",
    )
    return parser


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    args = build_parser().parse_args(argv)
    if date.fromisoformat(args.start) > date.fromisoformat(args.end):
        build_parser().error("--start must not be later than --end")
    return args


def utc_receipt_timestamp() -> str:
    return (
        datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )


def map_history_kline_row(
    row: Mapping[str, Any], api_response_received_at_utc: str
) -> dict[str, Any]:
    """Map one SDK history row to the Rust K_1M wire schema plus provenance."""

    raw_time_key = str(row.get("time_key", "")).strip()
    mapped = map_kline_row({**dict(row), "k_type": "K_1M"})
    if mapped["event_timestamp_et"] != raw_time_key:
        # ``map_kline_row`` may remove only a zero-valued fractional suffix.
        normalized_raw = raw_time_key.removesuffix(".000")
        if mapped["event_timestamp_et"] != normalized_raw:
            raise ValueError("history time_key normalization changed its value")
    mapped.update(
        {
            "provider_time_key_et": raw_time_key,
            "time_key_semantics": TIME_KEY_SEMANTICS,
            "api_response_received_at_utc": api_response_received_at_utc,
            "availability_semantics": AVAILABILITY_SEMANTICS,
            "original_point_in_time_available_at": None,
            "source_method": "OpenQuoteContext.request_history_kline",
            "historical_retrieval": True,
        }
    )
    return mapped


def _page_key_fingerprint(page_req_key: Any) -> str:
    """Create a local loop guard without logging or serializing SDK page keys."""

    if isinstance(page_req_key, bytes):
        encoded = page_req_key
    else:
        encoded = repr(page_req_key).encode("utf-8", errors="strict")
    return hashlib.sha256(encoded).hexdigest()


def run_history_export(
    host: str,
    port: int,
    symbols: tuple[str, ...],
    start: str,
    end: str,
    page_size: int,
    max_rows: int,
    extended_time: bool,
    emitter: JsonLineEmitter,
) -> int:
    """Fetch paginated quote history and emit deterministic replay JSONL."""

    # Exact imports make the runtime capability visibly quote-only. Importing
    # here keeps dry-run and schema tests independent of a running OpenD.
    try:
        from moomoo import (
            RET_OK,
            AuType,
            KLType,
            OpenQuoteContext,
            __version__ as sdk_version,
        )
    except ImportError as error:
        raise RuntimeError(
            "official moomoo-api==10.9.6908 is required for HistoryKline"
        ) from error

    if _normalized_sdk_version(sdk_version) != EXPECTED_SDK_VERSION:
        raise RuntimeError(
            f"Moomoo SDK {sdk_version} is not the pinned 10.09.6908 runtime"
        )

    quote_context = None
    total_rows = 0
    try:
        quote_context = OpenQuoteContext(host=host, port=port)
        for symbol in symbols:
            page_req_key = None
            seen_page_keys: set[str] = set()
            last_time_key: str | None = None
            symbol_rows = 0
            while True:
                ret_code, data, next_page_req_key = (
                    quote_context.request_history_kline(
                        code=symbol,
                        start=start,
                        end=end,
                        ktype=KLType.K_1M,
                        autype=AuType.NONE,
                        max_count=page_size,
                        page_req_key=page_req_key,
                        extended_time=extended_time,
                    )
                )
                response_received_at = utc_receipt_timestamp()
                if ret_code != RET_OK:
                    raise RuntimeError(
                        f"Moomoo history request failed for {symbol}: {data}"
                    )

                rows = frame_records(data)
                for row in rows:
                    event = map_history_kline_row(row, response_received_at)
                    if event["symbol"] != symbol:
                        raise RuntimeError(
                            "Moomoo history response symbol does not match request"
                        )
                    current_time_key = event["event_timestamp_et"]
                    if (
                        last_time_key is not None
                        and current_time_key <= last_time_key
                    ):
                        raise RuntimeError(
                            f"Moomoo history is not strictly chronological for {symbol}"
                        )
                    if total_rows >= max_rows:
                        raise RuntimeError(
                            f"Moomoo history export exceeded max-rows={max_rows}"
                        )
                    emitter.emit(event)
                    total_rows += 1
                    symbol_rows += 1
                    last_time_key = current_time_key

                if next_page_req_key is None:
                    break
                fingerprint = _page_key_fingerprint(next_page_req_key)
                if fingerprint in seen_page_keys:
                    raise RuntimeError(
                        f"Moomoo history pagination repeated for {symbol}"
                    )
                seen_page_keys.add(fingerprint)
                page_req_key = next_page_req_key

            log(
                "MOOMOO_HISTORY_SYMBOL_COMPLETE "
                f"symbol={symbol} rows={symbol_rows} start={start} end={end}"
            )
        log(
            "MOOMOO_HISTORY_EXPORT_COMPLETE "
            f"symbols={len(symbols)} rows={total_rows} quote_only=true "
            "trade_api=false original_availability=unknown"
        )
        return total_rows
    finally:
        if quote_context is not None:
            quote_context.close()


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.dry_run:
        log(
            "MOOMOO_HISTORY_BRIDGE_DRY_RUN_OK "
            f"host={args.host} port={args.port} "
            f"symbols={','.join(args.symbols)} start={args.start} end={args.end} "
            "quote_only=true trade_api=false emits_data=false"
        )
        return 0

    protocol_stdout = sys.stdout
    # Keep SDK prints and diagnostics away from the JSONL wire stream.
    sys.stdout = sys.stderr
    try:
        emitter = JsonLineEmitter(protocol_stdout)
        run_history_export(
            args.host,
            args.port,
            args.symbols,
            args.start,
            args.end,
            args.page_size,
            args.max_rows,
            args.extended_time,
            emitter,
        )
        return 0
    except (RuntimeError, OSError, ValueError) as error:
        log(f"MOOMOO_HISTORY_BRIDGE_FATAL error={error}")
        return 1
    finally:
        sys.stdout = protocol_stdout


if __name__ == "__main__":
    raise SystemExit(main())

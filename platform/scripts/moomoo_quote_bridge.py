#!/usr/bin/env python3
"""Official Moomoo quote-only JSONL bridge for the Rust live supervisor.

Only the quote context and the Basic, Ticker, and K_1M push handlers are used.
The process never creates or invokes a trading context.  OpenD is accepted only
on a loopback address.  During QuotePush, the original stdout handle is reserved
for compact JSON Lines; diagnostics and any SDK console output go to stderr.
"""

from __future__ import annotations

import argparse
import ipaddress
import json
import math
import re
import signal
import sys
import threading
from datetime import datetime
from typing import Any, Mapping, TextIO

EXPECTED_SDK_VERSION = (10, 9, 6908)
SOURCE_VERSION = "moomoo-opend-10.9.6908"
MAX_SYMBOLS = 128
SYMBOL_PATTERN = re.compile(r"^US\.[A-Z][A-Z0-9.-]{0,31}$")
EXCHANGE_TIMESTAMP_PATTERN = re.compile(
    r"^(?P<seconds>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"
    r"(?P<fraction>\.\d{1,9})?$"
)


def validate_loopback_host(value: str) -> str:
    """Return a normalized loopback host or reject it without DNS resolution."""

    host = str(value).strip()
    if host.lower() == "localhost":
        return "localhost"
    try:
        address = ipaddress.ip_address(host)
    except ValueError as error:
        raise argparse.ArgumentTypeError(
            "host must be localhost or a numeric loopback address"
        ) from error
    if not address.is_loopback:
        raise argparse.ArgumentTypeError("OpenD host must be loopback-only")
    return address.compressed


def validate_port(value: str | int) -> int:
    try:
        port = int(value)
    except (TypeError, ValueError) as error:
        raise argparse.ArgumentTypeError("port must be an integer") from error
    if not 1 <= port <= 65_535:
        raise argparse.ArgumentTypeError("port must be between 1 and 65535")
    return port


def parse_symbols(value: str) -> tuple[str, ...]:
    """Parse, normalize, validate, and de-duplicate a Moomoo symbol list."""

    raw_symbols = str(value).split(",")
    if not raw_symbols or any(not symbol.strip() for symbol in raw_symbols):
        raise argparse.ArgumentTypeError("symbols must be a non-empty comma-separated list")
    symbols: list[str] = []
    seen: set[str] = set()
    for raw_symbol in raw_symbols:
        symbol = raw_symbol.strip().upper()
        if not SYMBOL_PATTERN.fullmatch(symbol):
            raise argparse.ArgumentTypeError(
                f"invalid quote symbol {raw_symbol!r}; expected US.<ticker>"
            )
        if symbol not in seen:
            symbols.append(symbol)
            seen.add(symbol)
    if len(symbols) > MAX_SYMBOLS:
        raise argparse.ArgumentTypeError(
            f"at most {MAX_SYMBOLS} symbols may be subscribed"
        )
    return tuple(symbols)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Loopback-only official Moomoo quote push bridge"
    )
    commands = parser.add_subparsers(dest="command", required=True)
    quote_push = commands.add_parser(
        "QuotePush", help="stream Basic, Ticker, and K_1M callbacks as JSONL"
    )
    quote_push.add_argument("--host", required=True, type=validate_loopback_host)
    quote_push.add_argument("--port", required=True, type=validate_port)
    quote_push.add_argument("--symbols", required=True, type=parse_symbols)
    return parser


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    return build_parser().parse_args(argv)


def _clean_scalar(value: Any) -> Any:
    if value is None:
        return None
    if hasattr(value, "item"):
        try:
            value = value.item()
        except (TypeError, ValueError):
            pass
    if isinstance(value, float) and not math.isfinite(value):
        return None
    if isinstance(value, (str, int, float, bool)):
        return value
    enum_value = getattr(value, "value", None)
    if isinstance(enum_value, (str, int, float, bool)):
        return enum_value
    return str(value)


def frame_records(frame: Any) -> list[dict[str, Any]]:
    """Convert an SDK DataFrame-like callback payload to plain dictionaries."""

    if frame is None:
        return []
    if isinstance(frame, Mapping):
        rows = [frame]
    elif isinstance(frame, list):
        rows = frame
    elif hasattr(frame, "to_dict"):
        rows = frame.to_dict(orient="records")
    else:
        raise ValueError("unsupported Moomoo callback payload")
    output: list[dict[str, Any]] = []
    for row in rows:
        if not isinstance(row, Mapping):
            raise ValueError("Moomoo callback row is not a mapping")
        output.append(
            {str(key): _clean_scalar(value) for key, value in row.items()}
        )
    return output


def _required_text(row: Mapping[str, Any], name: str) -> str:
    value = row.get(name)
    text = "" if value is None else str(value).strip()
    if not text:
        raise ValueError(f"{name} is required")
    return text


def _required_number(
    row: Mapping[str, Any],
    name: str,
    *,
    positive: bool = False,
    nonnegative: bool = False,
) -> float:
    value = row.get(name)
    if isinstance(value, bool):
        raise ValueError(f"{name} must be numeric")
    try:
        number = float(value)
    except (TypeError, ValueError) as error:
        raise ValueError(f"{name} must be numeric") from error
    if not math.isfinite(number):
        raise ValueError(f"{name} must be finite")
    if positive and number <= 0:
        raise ValueError(f"{name} must be positive")
    if nonnegative and number < 0:
        raise ValueError(f"{name} must be nonnegative")
    return number


def _optional_number(
    row: Mapping[str, Any], name: str, *, nonnegative: bool = False
) -> float | None:
    value = row.get(name)
    if value is None or value == "":
        return None
    return _required_number(row, name, nonnegative=nonnegative)


def _required_integer(
    row: Mapping[str, Any], name: str, *, nonnegative: bool = False
) -> int:
    value = row.get(name)
    if isinstance(value, bool):
        raise ValueError(f"{name} must be an integer")
    if hasattr(value, "item"):
        try:
            value = value.item()
        except (TypeError, ValueError):
            pass
    try:
        integer = int(value)
    except (TypeError, ValueError, OverflowError) as error:
        raise ValueError(f"{name} must be an integer") from error
    if isinstance(value, float) and (not math.isfinite(value) or value != integer):
        raise ValueError(f"{name} must be an integer")
    if isinstance(value, str) and value.strip() != str(integer):
        raise ValueError(f"{name} must be an integer")
    if nonnegative and integer < 0:
        raise ValueError(f"{name} must be nonnegative")
    return integer


def normalize_exchange_timestamp(value: Any, *, seconds_only: bool) -> str:
    """Validate an exchange-local timestamp and optionally remove sub-seconds."""

    text = str(value).strip().replace("T", " ", 1)
    match = EXCHANGE_TIMESTAMP_PATTERN.fullmatch(text)
    if match is None:
        raise ValueError("exchange timestamp must be YYYY-MM-DD HH:MM:SS[.fraction]")
    seconds = match.group("seconds")
    datetime.strptime(seconds, "%Y-%m-%d %H:%M:%S")
    if seconds_only or match.group("fraction") is None:
        return seconds
    return seconds + match.group("fraction")


def _quote_timestamp(row: Mapping[str, Any]) -> str:
    date = _required_text(row, "data_date")
    time = _required_text(row, "data_time")
    if EXCHANGE_TIMESTAMP_PATTERN.fullmatch(time.replace("T", " ", 1)):
        combined = time
    else:
        combined = f"{date} {time}"
    return normalize_exchange_timestamp(combined, seconds_only=False)


def map_stock_quote_row(row: Mapping[str, Any]) -> dict[str, Any]:
    """Map StockQuoteHandlerBase output to the native bridge's Basic event."""

    return {
        "event": "basic",
        "symbol": _required_text(row, "code").upper(),
        "event_timestamp_et": _quote_timestamp(row),
        "price": _required_number(row, "last_price", positive=True),
        "open": _required_number(row, "open_price", positive=True),
        "high": _required_number(row, "high_price", positive=True),
        "low": _required_number(row, "low_price", positive=True),
        "volume": _required_number(row, "volume", nonnegative=True),
        "turnover": _optional_number(row, "turnover", nonnegative=True),
        "source_version": SOURCE_VERSION,
    }


def map_ticker_row(row: Mapping[str, Any]) -> dict[str, Any]:
    """Map TickerHandlerBase output to the native bridge's Ticker event."""

    sequence = _required_integer(row, "sequence", nonnegative=True)
    event = {
        "event": "ticker",
        "symbol": _required_text(row, "code").upper(),
        "event_timestamp_et": normalize_exchange_timestamp(
            _required_text(row, "time"), seconds_only=False
        ),
        "price": _required_number(row, "price", positive=True),
        "volume": _required_number(row, "volume", nonnegative=True),
        "turnover": _optional_number(row, "turnover", nonnegative=True),
        "direction": _clean_scalar(row.get("ticker_direction")),
        "sequence": sequence,
        "ticker_type": _clean_scalar(row.get("type")),
        "source_version": SOURCE_VERSION,
    }
    return event


def map_kline_row(row: Mapping[str, Any]) -> dict[str, Any]:
    """Map CurKlineHandlerBase output to live::parse_sdk_kline's schema."""

    k_type = row.get("k_type")
    if k_type not in (None, "", "K_1M"):
        raise ValueError(f"unexpected kline type {k_type!r}")
    open_price = _required_number(row, "open", positive=True)
    high_price = _required_number(row, "high", positive=True)
    low_price = _required_number(row, "low", positive=True)
    close_price = _required_number(row, "close", positive=True)
    if high_price < max(open_price, close_price, low_price):
        raise ValueError("high is below an OHLC component")
    if low_price > min(open_price, close_price, high_price):
        raise ValueError("low is above an OHLC component")
    return {
        "event": "k_1m",
        "symbol": _required_text(row, "code").upper(),
        "event_timestamp_et": normalize_exchange_timestamp(
            _required_text(row, "time_key"), seconds_only=True
        ),
        "open": open_price,
        "high": high_price,
        "low": low_price,
        "close": close_price,
        "volume": _required_number(row, "volume", nonnegative=True),
        "turnover": _optional_number(row, "turnover", nonnegative=True),
        "source_version": SOURCE_VERSION,
    }


class JsonLineEmitter:
    """Serialize callback events atomically so SDK worker threads cannot interleave."""

    def __init__(self, stream: TextIO):
        self._stream = stream
        self._lock = threading.Lock()

    def emit(self, event: Mapping[str, Any]) -> None:
        encoded = json.dumps(
            dict(event),
            ensure_ascii=True,
            allow_nan=False,
            separators=(",", ":"),
        )
        with self._lock:
            self._stream.write(encoded + "\n")
            self._stream.flush()


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def _emit_frame(
    frame: Any,
    mapper: Any,
    emitter: JsonLineEmitter,
    event_name: str,
) -> None:
    try:
        rows = frame_records(frame)
    except (TypeError, ValueError) as error:
        log(f"MOOMOO_{event_name}_PAYLOAD_REJECTED error={error}")
        return
    for row in rows:
        try:
            emitter.emit(mapper(row))
        except (TypeError, ValueError) as error:
            symbol = row.get("code", "US.UNKNOWN")
            log(
                f"MOOMOO_{event_name}_ROW_REJECTED "
                f"symbol={symbol} error={error}"
            )


def _normalized_sdk_version(value: Any) -> tuple[int, ...]:
    try:
        return tuple(int(part) for part in str(value).split("."))
    except ValueError as error:
        raise RuntimeError(f"unrecognized Moomoo SDK version {value!r}") from error


def run_quote_push(
    host: str,
    port: int,
    symbols: tuple[str, ...],
    emitter: JsonLineEmitter,
    stop_event: threading.Event | None = None,
) -> int:
    """Connect the official quote context and stream the three approved handlers."""

    # Exact imports keep the process capability visibly quote-only.  Importing
    # here also makes module import and pure mapping tests independent of OpenD.
    try:
        from moomoo import (
            RET_OK,
            CurKlineHandlerBase,
            OpenQuoteContext,
            StockQuoteHandlerBase,
            SubType,
            TickerHandlerBase,
            __version__ as sdk_version,
        )
    except ImportError as error:
        raise RuntimeError(
            "official moomoo-api==10.9.6908 is required for QuotePush"
        ) from error

    if _normalized_sdk_version(sdk_version) != EXPECTED_SDK_VERSION:
        raise RuntimeError(
            f"Moomoo SDK {sdk_version} is not the pinned 10.09.6908 runtime"
        )

    class StockQuoteHandler(StockQuoteHandlerBase):
        def on_recv_rsp(self, response: Any) -> tuple[int, Any]:
            ret_code, data = super().on_recv_rsp(response)
            if ret_code == RET_OK:
                _emit_frame(data, map_stock_quote_row, emitter, "BASIC")
            else:
                log(f"MOOMOO_BASIC_CALLBACK_ERROR detail={data}")
            return ret_code, data

    class TickerHandler(TickerHandlerBase):
        def on_recv_rsp(self, response: Any) -> tuple[int, Any]:
            ret_code, data = super().on_recv_rsp(response)
            if ret_code == RET_OK:
                _emit_frame(data, map_ticker_row, emitter, "TICKER")
            else:
                log(f"MOOMOO_TICKER_CALLBACK_ERROR detail={data}")
            return ret_code, data

    class KlineHandler(CurKlineHandlerBase):
        def on_recv_rsp(self, response: Any) -> tuple[int, Any]:
            ret_code, data = super().on_recv_rsp(response)
            if ret_code == RET_OK:
                _emit_frame(data, map_kline_row, emitter, "K_1M")
            else:
                log(f"MOOMOO_K_1M_CALLBACK_ERROR detail={data}")
            return ret_code, data

    shutdown = stop_event or threading.Event()

    def request_shutdown(_signum: int, _frame: Any) -> None:
        shutdown.set()

    if stop_event is None:
        signal.signal(signal.SIGINT, request_shutdown)
        signal.signal(signal.SIGTERM, request_shutdown)

    quote_context = None
    try:
        quote_context = OpenQuoteContext(host=host, port=port)
        quote_context.set_handler(StockQuoteHandler())
        quote_context.set_handler(TickerHandler())
        quote_context.set_handler(KlineHandler())
        ret_code, detail = quote_context.subscribe(
            list(symbols),
            [SubType.QUOTE, SubType.TICKER, SubType.K_1M],
            subscribe_push=True,
        )
        if ret_code != RET_OK:
            raise RuntimeError(f"Moomoo quote subscription failed: {detail}")
        log(
            "MOOMOO_QUOTE_BRIDGE_READY "
            f"host={host} port={port} symbols={','.join(symbols)} "
            "subscriptions=Basic,Ticker,K_1M quote_only=true"
        )
        shutdown.wait()
        return 0
    finally:
        if quote_context is not None:
            quote_context.close()


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    protocol_stdout = sys.stdout
    # Reserve the inherited stdout file descriptor for JSONL.  This also
    # captures incidental SDK prints without corrupting the Rust wire protocol.
    sys.stdout = sys.stderr
    try:
        emitter = JsonLineEmitter(protocol_stdout)
        return run_quote_push(args.host, args.port, args.symbols, emitter)
    except (RuntimeError, OSError, ValueError) as error:
        log(f"MOOMOO_QUOTE_BRIDGE_FATAL error={error}")
        return 1
    finally:
        sys.stdout = protocol_stdout


if __name__ == "__main__":
    raise SystemExit(main())

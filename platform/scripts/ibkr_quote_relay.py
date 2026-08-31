#!/usr/bin/env python3
"""Relay owner-authorized IBKR Level-1 quotes to AXIO7 over outbound HTTPS.

The Client Portal Gateway is accepted only on loopback. Its cookie jar stays in
this process and is never serialized or sent to AXIO7. The outbound payload has
an intentionally closed schema: symbol, conid, provider timestamp, IBKR field
6509, and Level-1 price/size fields. It has no account or trading fields.
"""

from __future__ import annotations

import argparse
import http.cookiejar
import ipaddress
import json
import math
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import UTC, datetime
from typing import Any, Iterable, Mapping

BRIDGE_VERSION = "axio7-ibkr-quote-relay/1.0"
SCHEMA_VERSION = "axio7.ibkr.quote-batch.v1"
DEFAULT_SYMBOLS = (
    "SPY",
    "QQQ",
    "NVDA",
    "AAPL",
    "MU",
    "SOXX",
    "NBIS",
    "BE",
    "IGV",
    "IWM",
    "HYG",
    "TLT",
    "UUP",
    "VXX",
)
SYMBOL_PATTERN = re.compile(r"^[A-Z][A-Z0-9.-]{0,15}$")
SNAPSHOT_FIELDS = "31,84,85,86,88,6509"
MAX_RESPONSE_BYTES = 1_048_576
MAX_RELAY_BODY_BYTES = 65_536


class RelayError(RuntimeError):
    """Expected fail-closed relay error."""


def iso_utc(value: datetime) -> str:
    return value.astimezone(UTC).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def validate_gateway_url(value: str) -> str:
    parsed = urllib.parse.urlsplit(value.strip())
    if parsed.scheme != "https" or not parsed.hostname:
        raise argparse.ArgumentTypeError("Gateway URL must be loopback HTTPS")
    host = parsed.hostname
    if host.lower() != "localhost":
        try:
            address = ipaddress.ip_address(host)
        except ValueError as error:
            raise argparse.ArgumentTypeError(
                "Gateway host must be localhost or a numeric loopback address"
            ) from error
        if not address.is_loopback:
            raise argparse.ArgumentTypeError("Gateway must remain loopback-only")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise argparse.ArgumentTypeError("Gateway URL must not contain credentials or query data")
    path = parsed.path.rstrip("/")
    if path not in ("", "/v1/api"):
        raise argparse.ArgumentTypeError("Gateway URL path must be /v1/api")
    return urllib.parse.urlunsplit(
        (parsed.scheme, parsed.netloc, "/v1/api", "", "")
    ).rstrip("/")


def validate_ingest_url(value: str) -> str:
    parsed = urllib.parse.urlsplit(value.strip())
    if parsed.scheme != "https" or not parsed.hostname:
        raise argparse.ArgumentTypeError("AXIO7 ingest URL must use HTTPS")
    if parsed.username or parsed.password or parsed.fragment:
        raise argparse.ArgumentTypeError("AXIO7 ingest URL must not contain credentials")
    if parsed.query:
        raise argparse.ArgumentTypeError("AXIO7 ingest URL must not contain query data")
    return urllib.parse.urlunsplit(parsed)


def parse_symbols(value: str) -> tuple[str, ...]:
    output: list[str] = []
    seen: set[str] = set()
    for raw in value.split(","):
        symbol = raw.strip().upper().removeprefix("US.")
        if not SYMBOL_PATTERN.fullmatch(symbol):
            raise argparse.ArgumentTypeError(f"invalid US equity symbol: {raw!r}")
        if symbol not in seen:
            output.append(symbol)
            seen.add(symbol)
    if not output or len(output) > 64:
        raise argparse.ArgumentTypeError("symbols must contain between 1 and 64 entries")
    return tuple(output)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Loopback-only IBKR quote client with outbound-only AXIO7 HTTPS relay"
    )
    parser.add_argument(
        "--gateway-url",
        type=validate_gateway_url,
        default="https://127.0.0.1:5000/v1/api",
    )
    parser.add_argument(
        "--ingest-url",
        type=validate_ingest_url,
        default="https://axio7.com/api/market/ibkr/relay",
    )
    parser.add_argument(
        "--symbols",
        type=parse_symbols,
        default=DEFAULT_SYMBOLS,
        help="comma-separated allow-listed US symbols",
    )
    parser.add_argument("--interval-seconds", type=float, default=2.0)
    parser.add_argument("--timeout-seconds", type=float, default=8.0)
    parser.add_argument(
        "--allow-insecure-loopback-gateway",
        action="store_true",
        help="accept the official Gateway's self-signed TLS certificate on loopback only",
    )
    parser.add_argument("--once", action="store_true")
    return parser


def parse_ibkr_number(value: Any) -> float | None:
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        number = float(value)
        return number if math.isfinite(number) else None
    if not isinstance(value, str):
        return None
    raw = value.strip()
    if not raw:
        return None
    multiplier = 1_000_000 if raw.endswith("M") else 1_000 if raw.endswith("K") else 1
    cleaned = re.sub(r"^[A-Z]", "", raw)
    cleaned = re.sub(r"[,%KM]", "", cleaned)
    try:
        number = float(cleaned) * multiplier
    except ValueError:
        return None
    return number if math.isfinite(number) else None


def updated_at(value: Any) -> str:
    if isinstance(value, bool):
        raise RelayError("IBKR _updated timestamp is invalid")
    try:
        milliseconds = int(value)
    except (TypeError, ValueError, OverflowError) as error:
        raise RelayError("IBKR _updated timestamp is absent") from error
    if milliseconds <= 0:
        raise RelayError("IBKR _updated timestamp is invalid")
    try:
        return iso_utc(datetime.fromtimestamp(milliseconds / 1000, tz=UTC))
    except (OSError, OverflowError, ValueError) as error:
        raise RelayError("IBKR _updated timestamp is outside its domain") from error


def require_bool(value: Any) -> bool:
    if value is True or value == 1 or str(value).lower() == "true":
        return True
    return False


class JsonHttpClient:
    def __init__(
        self,
        base_url: str,
        *,
        timeout_seconds: float,
        loopback_gateway: bool,
        allow_insecure_loopback: bool = False,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds
        self.loopback_gateway = loopback_gateway
        handlers: list[Any] = [urllib.request.ProxyHandler({})]
        if loopback_gateway:
            cookie_jar = http.cookiejar.CookieJar()
            handlers.append(urllib.request.HTTPCookieProcessor(cookie_jar))
        if allow_insecure_loopback:
            if not loopback_gateway:
                raise RelayError("insecure TLS is permitted only for the loopback Gateway")
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
            handlers.append(urllib.request.HTTPSHandler(context=context))
        self.opener = urllib.request.build_opener(*handlers)

    def request(
        self,
        path: str = "",
        *,
        method: str = "GET",
        body: Mapping[str, Any] | None = None,
        headers: Mapping[str, str] | None = None,
    ) -> Any:
        url = self.base_url + ("/" + path.lstrip("/") if path else "")
        encoded = None
        request_headers = {
            "Accept": "application/json",
            "User-Agent": BRIDGE_VERSION,
            **dict(headers or {}),
        }
        if body is not None:
            encoded = json.dumps(
                body, allow_nan=False, separators=(",", ":")
            ).encode("utf-8")
            if len(encoded) > MAX_RELAY_BODY_BYTES:
                raise RelayError("relay payload exceeds 64 KiB")
            request_headers["Content-Type"] = "application/json"
        request = urllib.request.Request(
            url,
            data=encoded,
            headers=request_headers,
            method=method,
        )
        try:
            with self.opener.open(request, timeout=self.timeout_seconds) as response:
                raw = response.read(MAX_RESPONSE_BYTES + 1)
                if len(raw) > MAX_RESPONSE_BYTES:
                    raise RelayError("HTTP response exceeds 1 MiB")
        except urllib.error.HTTPError as error:
            detail = error.read(512).decode("utf-8", errors="replace")
            raise RelayError(f"HTTP {error.code}: {detail}") from error
        except urllib.error.URLError as error:
            raise RelayError(f"HTTP connection failed: {error.reason}") from error
        try:
            return json.loads(raw or b"null")
        except json.JSONDecodeError as error:
            raise RelayError("HTTP endpoint returned invalid JSON") from error


class IbkrQuoteRelay:
    def __init__(
        self,
        gateway: JsonHttpClient,
        ingest: JsonHttpClient,
        symbols: Iterable[str],
        relay_token: str,
    ) -> None:
        self.gateway = gateway
        self.ingest = ingest
        self.symbols = tuple(symbols)
        self.relay_token = relay_token
        self.conids: dict[str, int] = {}
        self.last_tickle = 0.0

    def require_session(self) -> None:
        status = self.gateway.request(
            "iserver/auth/status",
            method="POST",
            body={},
        )
        if not isinstance(status, Mapping):
            raise RelayError("IBKR auth status has an invalid shape")
        if (
            not require_bool(status.get("authenticated"))
            or not require_bool(status.get("connected"))
            or require_bool(status.get("competing"))
        ):
            raise RelayError("IBKR Client Portal session is not ready")
        self.gateway.request("iserver/accounts")

    def resolve_conids(self) -> None:
        resolved: dict[str, int] = {}
        for symbol in self.symbols:
            query = urllib.parse.urlencode({"symbol": symbol})
            rows = self.gateway.request(f"iserver/secdef/search?{query}")
            if not isinstance(rows, list):
                raise RelayError(f"IBKR conid lookup failed for {symbol}")
            exact = next(
                (
                    row
                    for row in rows
                    if isinstance(row, Mapping)
                    and str(row.get("symbol", "")).upper() == symbol
                    and any(
                        isinstance(section, Mapping)
                        and section.get("secType") == "STK"
                        for section in row.get("sections", [])
                    )
                ),
                None,
            )
            if exact is None:
                exact = next(
                    (
                        row
                        for row in rows
                        if isinstance(row, Mapping)
                        and str(row.get("symbol", "")).upper() == symbol
                    ),
                    None,
                )
            try:
                conid = int(exact["conid"]) if exact is not None else 0
            except (KeyError, TypeError, ValueError, OverflowError):
                conid = 0
            if conid <= 0:
                raise RelayError(f"IBKR conid lookup failed for {symbol}")
            resolved[symbol] = conid
        self.conids = resolved

    def fetch_batch(self) -> dict[str, Any]:
        if set(self.conids) != set(self.symbols):
            self.resolve_conids()
        conids = ",".join(str(self.conids[symbol]) for symbol in self.symbols)
        query = urllib.parse.urlencode(
            {"conids": conids, "fields": SNAPSHOT_FIELDS}, safe=","
        )
        path = f"iserver/marketdata/snapshot?{query}"
        self.gateway.request(path)
        time.sleep(0.5)
        rows = self.gateway.request(path)
        if not isinstance(rows, list):
            raise RelayError("IBKR snapshot has an invalid shape")
        by_conid: dict[int, Mapping[str, Any]] = {}
        for row in rows:
            if not isinstance(row, Mapping):
                continue
            try:
                conid = int(row.get("conid", 0))
            except (TypeError, ValueError, OverflowError):
                continue
            by_conid[conid] = row

        quotes: list[dict[str, Any]] = []
        for symbol in self.symbols:
            conid = self.conids[symbol]
            row = by_conid.get(conid)
            if row is None:
                raise RelayError(f"IBKR snapshot is missing {symbol}")
            availability = str(row.get("6509", "")).strip()
            bid = parse_ibkr_number(row.get("84"))
            ask = parse_ibkr_number(row.get("86"))
            bid_size = parse_ibkr_number(row.get("88"))
            ask_size = parse_ibkr_number(row.get("85"))
            last = parse_ibkr_number(row.get("31"))
            if not availability.startswith("R"):
                raise RelayError(
                    f"IBKR realtime entitlement is unavailable for {symbol}"
                )
            if (
                bid is None
                or ask is None
                or bid <= 0
                or ask < bid
                or (bid_size is not None and bid_size < 0)
                or (ask_size is not None and ask_size < 0)
                or (last is not None and last <= 0)
            ):
                raise RelayError(f"IBKR Level-1 quote is incomplete for {symbol}")
            quotes.append(
                {
                    "symbol": symbol,
                    "conid": conid,
                    "provider_observed_at": updated_at(row.get("_updated")),
                    "market_data_availability": availability,
                    "bid": bid,
                    "ask": ask,
                    "bid_size": bid_size,
                    "ask_size": ask_size,
                    "last": last,
                }
            )
        return {
            "schema_version": SCHEMA_VERSION,
            "batch_id": str(uuid.uuid4()),
            "source": "ibkr_client_portal",
            "bridge_version": BRIDGE_VERSION,
            "captured_at": iso_utc(datetime.now(UTC)),
            "session_authenticated": True,
            "quotes": quotes,
        }

    def push_once(self) -> Mapping[str, Any]:
        now = time.monotonic()
        if now - self.last_tickle >= 55:
            self.require_session()
            self.gateway.request("tickle")
            self.last_tickle = now
        batch = self.fetch_batch()
        receipt = self.ingest.request(
            method="POST",
            body=batch,
            headers={"Authorization": f"Bearer {self.relay_token}"},
        )
        if not isinstance(receipt, Mapping):
            raise RelayError("AXIO7 ingest returned an invalid receipt")
        return receipt


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.interval_seconds < 1 or args.interval_seconds > 60:
        raise SystemExit("--interval-seconds must be between 1 and 60")
    if args.timeout_seconds < 1 or args.timeout_seconds > 30:
        raise SystemExit("--timeout-seconds must be between 1 and 30")
    relay_token = os.environ.get("IBKR_QUOTE_RELAY_TOKEN", "")
    if len(relay_token) < 32:
        raise SystemExit("IBKR_QUOTE_RELAY_TOKEN must contain at least 32 characters")
    gateway = JsonHttpClient(
        args.gateway_url,
        timeout_seconds=args.timeout_seconds,
        loopback_gateway=True,
        allow_insecure_loopback=args.allow_insecure_loopback_gateway,
    )
    ingest = JsonHttpClient(
        args.ingest_url,
        timeout_seconds=args.timeout_seconds,
        loopback_gateway=False,
    )
    relay = IbkrQuoteRelay(gateway, ingest, args.symbols, relay_token)
    backoff = args.interval_seconds
    while True:
        started = time.monotonic()
        try:
            receipt = relay.push_once()
            print(
                "IBKR_QUOTE_RELAY_ACCEPTED "
                f"batch_id={receipt.get('batch_id', 'unknown')} "
                f"quote_count={receipt.get('quote_count', 'unknown')}",
                flush=True,
            )
            backoff = args.interval_seconds
            if args.once:
                return 0
        except (RelayError, OSError, ValueError) as error:
            print(f"IBKR_QUOTE_RELAY_BLOCKED reason={error}", file=sys.stderr, flush=True)
            if args.once:
                return 1
            time.sleep(backoff)
            backoff = min(30.0, backoff * 2)
            continue
        remaining = args.interval_seconds - (time.monotonic() - started)
        if remaining > 0:
            time.sleep(remaining)


if __name__ == "__main__":
    raise SystemExit(main())

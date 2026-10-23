#!/usr/bin/env python3
"""Scan US small caps for momentum conditions using only the IBKR Client Portal Gateway.

Read-only: the script calls session, scanner and market-data endpoints on the
loopback Gateway and never touches order or account-trading endpoints. IBKR's
scanner only generates candidates; every criterion is re-checked here on a
realtime snapshot, and anything IBKR cannot verify is reported as unverified
instead of being guessed.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
import time
import urllib.parse
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Callable, Iterable, Mapping

RELAY_PATH = Path(__file__).resolve().parents[3] / "scripts" / "ibkr_quote_relay.py"
_spec = importlib.util.spec_from_file_location("axio7_ibkr_relay_for_scan", RELAY_PATH)
assert _spec and _spec.loader
relay = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(relay)
RelayError = relay.RelayError

SCANNER_VERSION = "axio7-ibkr-momentum-scan/1.0"
SCHEMA_VERSION = "axio7.ibkr.momentum-scan.v1"
INSTRUMENT = "STK"
LOCATION = "STK.US.MAJOR"
SCAN_TYPE = "TOP_PERC_GAIN"
PRICE_FILTERS = ("priceAbove", "priceBelow")
CHANGE_FILTER = "changePercAbove"
MAX_SCANNER_ROWS = 50
DEFAULT_BAND_EDGES = (3.0, 5.0, 10.0)
# last, symbol, availability, 90-day average volume, market cap, prior close, volume
SNAPSHOT_FIELDS = ("31", "55", "6509", "7282", "7289", "7741", "7762")
SNAPSHOT_BATCH = 50
SNAPSHOT_ATTEMPTS = 4
MAX_GATEWAY_RESPONSE_BYTES = 8 * 1_048_576
PASS, FAIL, UNVERIFIED = "pass", "fail", "unverified"
CAVEATS = (
    "IBKR scanner returns at most 50 rows per request; a band that hits the cap is marked truncated.",
    "relative_volume = today's volume (7762) / IBKR 90-day average daily volume (7282); "
    "it is not time-of-day adjusted, so early-session values are understated.",
    "float is never reported by IBKR Client Portal. shares_outstanding_max = market cap (7289) "
    "/ min(last, prior close) is an upper bound on float; below the limit it passes, otherwise "
    "float stays unverified. IBKR's share count can lag recent offerings.",
    "IBKR Client Portal has no news feed; the news criterion always needs a manual check.",
    "change_pct = last (31) / prior close (7741) - 1 and includes extended-hours trades.",
    "Research scan only. A matched condition is not a forecast or a recommendation.",
)


@dataclass(frozen=True)
class Criteria:
    min_price: float = 1.5
    max_price: float = 25.0
    min_change_pct: float = 10.0
    min_relative_volume: float = 5.0
    max_float_shares: float = 20_000_000


def price_bands(criteria: Criteria, edges: Iterable[float] = DEFAULT_BAND_EDGES) -> list[tuple[float, float]]:
    inner = sorted(edge for edge in set(edges) if criteria.min_price < edge < criteria.max_price)
    points = [criteria.min_price, *inner, criteria.max_price]
    return list(zip(points, points[1:]))


def codes(items: Any) -> set[str]:
    if not isinstance(items, list):
        return set()
    return {str(item.get("code")) for item in items if isinstance(item, Mapping) and item.get("code")}


def contract_conid(item: Mapping[str, Any]) -> int:
    try:
        conid = int(item.get("con_id", item.get("conid", 0)))
    except (TypeError, ValueError, OverflowError):
        return 0
    return conid if conid > 0 else 0


def observed_at(row: Mapping[str, Any]) -> datetime:
    return datetime.fromisoformat(relay.updated_at(row.get("_updated")).replace("Z", "+00:00"))


def evaluate(
    contract: Mapping[str, Any],
    row: Mapping[str, Any] | None,
    criteria: Criteria,
    *,
    now: datetime,
    max_age_seconds: float,
) -> dict[str, Any]:
    output: dict[str, Any] = {
        "symbol": contract["symbol"],
        "conid": contract["conid"],
        "company": contract.get("company"),
        "listing_exchange": contract.get("listing_exchange"),
    }

    def blocked(reason: str) -> dict[str, Any]:
        return {**output, "status": "blocked", "reason": reason}

    if row is None:
        return blocked("IBKR snapshot is missing this contract")
    try:
        observed = observed_at(row)
    except RelayError as error:
        return blocked(str(error))
    age = (now - observed).total_seconds()
    output["provider_observed_at"] = relay.iso_utc(observed)
    availability = str(row.get("6509", "")).strip()
    output["market_data_availability"] = availability
    if not availability.startswith("R"):
        return blocked(f"IBKR data is not realtime (6509={availability or 'absent'})")
    if age > max_age_seconds or age < -5:
        return blocked(f"IBKR snapshot is stale ({age:.0f}s old)")
    last = relay.parse_ibkr_number(row.get("31"))
    prior_close = relay.parse_ibkr_number(row.get("7741"))
    if last is None or prior_close is None or last <= 0 or prior_close <= 0:
        return blocked("IBKR last or prior close is incomplete")
    volume = relay.parse_ibkr_number(row.get("7762"))
    average_volume = relay.parse_ibkr_number(row.get("7282"))
    market_cap = relay.parse_ibkr_number(row.get("7289"))

    change_pct = (last / prior_close - 1) * 100
    relative_volume = (
        volume / average_volume
        if volume is not None and volume >= 0 and average_volume and average_volume > 0
        else None
    )
    shares_max = market_cap / min(last, prior_close) if market_cap and market_cap > 0 else None

    def threshold(ok: bool) -> str:
        return PASS if ok else FAIL

    checks = {
        "price": threshold(criteria.min_price <= last <= criteria.max_price),
        "change": threshold(change_pct >= criteria.min_change_pct),
        "relative_volume": UNVERIFIED
        if relative_volume is None
        else threshold(relative_volume >= criteria.min_relative_volume),
        "float": PASS
        if shares_max is not None and shares_max < criteria.max_float_shares
        else UNVERIFIED,
        "news": UNVERIFIED,
    }
    return {
        **output,
        "status": "fail" if FAIL in checks.values() else "eligible",
        "last": last,
        # IBKR prefixes the last price with H while trading is halted.
        "halted": str(row.get("31", "")).strip().startswith("H"),
        "prior_close": prior_close,
        "change_pct": round(change_pct, 2),
        "volume": volume,
        "average_volume_90d": average_volume,
        "relative_volume": None if relative_volume is None else round(relative_volume, 2),
        "market_cap": market_cap,
        "shares_outstanding_max": None if shares_max is None else round(shares_max),
        "checks": checks,
        "verified_pass_count": sum(value == PASS for value in checks.values()),
    }


def sort_key(row: Mapping[str, Any]) -> tuple[int, int, float]:
    rank = {"eligible": 0, "fail": 1, "blocked": 2}[row["status"]]
    return (rank, -row.get("verified_pass_count", 0), -row.get("change_pct", 0.0))


class MomentumScanner:
    def __init__(
        self,
        gateway: Any,
        criteria: Criteria,
        *,
        bands: list[tuple[float, float]],
        max_age_seconds: float,
        sleep: Callable[[float], None] = time.sleep,
        clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    ) -> None:
        self.gateway = gateway
        self.criteria = criteria
        self.bands = bands
        self.max_age_seconds = max_age_seconds
        self.sleep = sleep
        self.clock = clock
        self.use_change_filter: bool | None = None

    def require_session(self) -> None:
        status = self.gateway.request("iserver/auth/status", method="POST", body={})
        if not isinstance(status, Mapping):
            raise RelayError("IBKR auth status has an invalid shape")
        if (
            not relay.require_bool(status.get("authenticated"))
            or not relay.require_bool(status.get("connected"))
            or relay.require_bool(status.get("competing"))
        ):
            raise RelayError("IBKR Client Portal session is not ready; log in to the Gateway first")
        # IBKR requires this call before any market-data snapshot.
        self.gateway.request("iserver/accounts")

    def load_params(self) -> None:
        params = self.gateway.request("iserver/scanner/params")
        if not isinstance(params, Mapping):
            raise RelayError("IBKR scanner params have an invalid shape")
        if SCAN_TYPE not in codes(params.get("scan_type_list")):
            raise RelayError(f"IBKR scanner type {SCAN_TYPE} is unavailable; run with --list-params")
        filters = codes(params.get("filter_list"))
        missing = [code for code in PRICE_FILTERS if code not in filters]
        if missing:
            raise RelayError(f"IBKR scanner filters {missing} are unavailable; run with --list-params")
        self.use_change_filter = CHANGE_FILTER in filters

    def scan_band(self, low: float, high: float) -> list[dict[str, Any]]:
        # Bands overlap by one cent because IBKR does not document filter inclusivity.
        filters: list[dict[str, Any]] = [
            {"code": "priceAbove", "value": round(max(low - 0.01, 0.01), 2)},
            {"code": "priceBelow", "value": round(high + 0.01, 2)},
        ]
        if self.use_change_filter:
            filters.append({"code": CHANGE_FILTER, "value": self.criteria.min_change_pct})
        response = self.gateway.request(
            "iserver/scanner/run",
            method="POST",
            body={"instrument": INSTRUMENT, "type": SCAN_TYPE, "location": LOCATION, "filter": filters},
        )
        items = response.get("contracts") if isinstance(response, Mapping) else None
        if not isinstance(items, list):
            detail = response.get("error") if isinstance(response, Mapping) else None
            raise RelayError(f"IBKR scanner failed for ${low}-${high}: {detail or 'invalid response shape'}")
        contracts = []
        for item in items:
            if not isinstance(item, Mapping):
                continue
            conid = contract_conid(item)
            symbol = str(item.get("symbol", "")).strip().upper()
            if conid and symbol:
                contracts.append(
                    {
                        "symbol": symbol,
                        "conid": conid,
                        "company": item.get("company_name"),
                        "listing_exchange": item.get("listing_exchange"),
                    }
                )
        return contracts

    def snapshot(self, conids: list[int]) -> dict[int, Mapping[str, Any]]:
        latest: dict[int, Mapping[str, Any]] = {}
        for start in range(0, len(conids), SNAPSHOT_BATCH):
            batch = conids[start : start + SNAPSHOT_BATCH]
            query = urllib.parse.urlencode(
                {"conids": ",".join(map(str, batch)), "fields": ",".join(SNAPSHOT_FIELDS)},
                safe=",",
            )
            path = f"iserver/marketdata/snapshot?{query}"
            try:
                # The first request only opens the subscriptions; IBKR fills fields on later polls.
                for attempt in range(SNAPSHOT_ATTEMPTS):
                    rows = self.gateway.request(path)
                    if not isinstance(rows, list):
                        raise RelayError("IBKR snapshot has an invalid shape")
                    for row in rows:
                        if isinstance(row, Mapping) and contract_conid(row) in batch:
                            latest[contract_conid(row)] = row
                    if all(
                        all(field in latest.get(conid, {}) for field in SNAPSHOT_FIELDS)
                        for conid in batch
                    ):
                        break
                    if attempt + 1 < SNAPSHOT_ATTEMPTS:
                        self.sleep(1.0)
            finally:
                # Release market-data lines so the next batch does not exceed the account limit.
                self.gateway.request("iserver/marketdata/unsubscribeall")
        return latest

    def run(self) -> dict[str, Any]:
        self.require_session()
        if self.use_change_filter is None:
            self.load_params()
        captured_at = self.clock()
        contracts: dict[int, dict[str, Any]] = {}
        coverage = []
        for index, (low, high) in enumerate(self.bands):
            if index:
                self.sleep(1.1)  # IBKR paces scanner runs at one per second.
            found = self.scan_band(low, high)
            coverage.append(
                {
                    "min_price": low,
                    "max_price": high,
                    "returned": len(found),
                    "truncated": len(found) >= MAX_SCANNER_ROWS,
                }
            )
            for contract in found:
                contracts.setdefault(contract["conid"], contract)
        snapshots = self.snapshot(list(contracts))
        now = self.clock()
        rows = sorted(
            (
                evaluate(
                    contract,
                    snapshots.get(conid),
                    self.criteria,
                    now=now,
                    max_age_seconds=self.max_age_seconds,
                )
                for conid, contract in contracts.items()
            ),
            key=sort_key,
        )
        counts = {status: sum(row["status"] == status for row in rows) for status in ("eligible", "fail", "blocked")}
        return {
            "schema_version": SCHEMA_VERSION,
            "scanner_version": SCANNER_VERSION,
            "source": "ibkr_client_portal",
            "captured_at": relay.iso_utc(captured_at),
            "evaluated_at": relay.iso_utc(now),
            "max_snapshot_age_seconds": self.max_age_seconds,
            "criteria": asdict(self.criteria),
            "scanner": {
                "instrument": INSTRUMENT,
                "location": LOCATION,
                "scan_type": SCAN_TYPE,
                "change_filter_applied": bool(self.use_change_filter),
            },
            "coverage": {
                "bands": coverage,
                "candidates": len(contracts),
                **counts,
                "complete": not any(band["truncated"] for band in coverage) and counts["blocked"] == 0,
            },
            "rows": rows,
            "caveats": list(CAVEATS),
        }


def format_table(artifact: Mapping[str, Any]) -> str:
    mark = {PASS: "Y", FAIL: "N", UNVERIFIED: "?"}
    lines = [
        f"IBKR momentum scan {artifact['captured_at']}  "
        f"candidates={artifact['coverage']['candidates']} eligible={artifact['coverage']['eligible']} "
        f"fail={artifact['coverage']['fail']} blocked={artifact['coverage']['blocked']}",
        f"{'SYMBOL':<8}{'LAST':>9}{'CHG%':>9}{'RVOL':>8}{'SHARES<=':>12}  PRICE CHG RVOL FLOAT NEWS",
    ]
    for row in artifact["rows"]:
        if row["status"] != "eligible":
            continue
        rvol = "-" if row["relative_volume"] is None else f"{row['relative_volume']:.1f}x"
        shares = "-" if row["shares_outstanding_max"] is None else f"{row['shares_outstanding_max'] / 1e6:.1f}M"
        checks = row["checks"]
        lines.append(
            f"{row['symbol']:<8}{row['last']:>9.2f}{row['change_pct']:>9.2f}{rvol:>8}{shares:>12}  "
            f"{mark[checks['price']]:^5} {mark[checks['change']]:^3} {mark[checks['relative_volume']]:^4} "
            f"{mark[checks['float']]:^5} {mark[checks['news']]:^4}{'  HALTED' if row['halted'] else ''}"
        )
    if artifact["coverage"]["eligible"] == 0:
        lines.append("(no contract met every verifiable criterion)")
    for band in artifact["coverage"]["bands"]:
        if band["truncated"]:
            lines.append(
                f"WARNING ${band['min_price']}-${band['max_price']} hit IBKR's {MAX_SCANNER_ROWS}-row cap; "
                "more matches may exist (add --band-edges)"
            )
    blocked = [row for row in artifact["rows"] if row["status"] == "blocked"]
    for row in blocked[:10]:
        lines.append(f"BLOCKED {row['symbol']}: {row['reason']}")
    if len(blocked) > 10:
        lines.append(f"BLOCKED ... {len(blocked) - 10} more (see --json output)")
    lines.append("Y=pass N=fail ?=IBKR cannot verify (check news and float manually)")
    return "\n".join(lines)


def parse_edges(value: str) -> tuple[float, ...]:
    try:
        edges = tuple(float(part) for part in value.split(",") if part.strip())
    except ValueError as error:
        raise argparse.ArgumentTypeError("band edges must be comma-separated prices") from error
    if any(edge <= 0 for edge in edges):
        raise argparse.ArgumentTypeError("band edges must be positive")
    return edges


def build_parser() -> argparse.ArgumentParser:
    defaults = Criteria()
    parser = argparse.ArgumentParser(description="Read-only IBKR small-cap momentum scanner")
    parser.add_argument("--gateway-url", type=relay.validate_gateway_url, default="https://127.0.0.1:5000/v1/api")
    parser.add_argument(
        "--allow-insecure-loopback-gateway",
        action="store_true",
        help="accept the official Gateway's self-signed TLS certificate on loopback only",
    )
    parser.add_argument("--timeout-seconds", type=float, default=15.0)
    parser.add_argument("--min-price", type=float, default=defaults.min_price)
    parser.add_argument("--max-price", type=float, default=defaults.max_price)
    parser.add_argument("--min-change-pct", type=float, default=defaults.min_change_pct)
    parser.add_argument("--min-relative-volume", type=float, default=defaults.min_relative_volume)
    parser.add_argument("--max-float-shares", type=float, default=defaults.max_float_shares)
    parser.add_argument(
        "--band-edges",
        type=parse_edges,
        default=DEFAULT_BAND_EDGES,
        help="inner price edges that split the scan so each band stays under IBKR's 50-row cap",
    )
    parser.add_argument("--max-age-seconds", type=float, default=120.0)
    parser.add_argument("--json", type=Path, help="write the full scan artifact to this path")
    parser.add_argument("--every", type=float, default=0.0, help="repeat every N seconds (minimum 30)")
    parser.add_argument(
        "--list-params",
        action="store_true",
        help="print IBKR scanner types and filter codes, then exit",
    )
    return parser


def validate_args(args: argparse.Namespace) -> Criteria:
    if not 0 < args.min_price < args.max_price:
        raise SystemExit("--min-price must be positive and below --max-price")
    if args.min_relative_volume <= 0 or args.max_float_shares <= 0:
        raise SystemExit("--min-relative-volume and --max-float-shares must be positive")
    if not 1 <= args.timeout_seconds <= 60:
        raise SystemExit("--timeout-seconds must be between 1 and 60")
    if args.max_age_seconds <= 0:
        raise SystemExit("--max-age-seconds must be positive")
    if args.every and args.every < 30:
        raise SystemExit("--every must be at least 30 seconds")
    return Criteria(
        min_price=args.min_price,
        max_price=args.max_price,
        min_change_pct=args.min_change_pct,
        min_relative_volume=args.min_relative_volume,
        max_float_shares=args.max_float_shares,
    )


def print_params(gateway: Any) -> None:
    params = gateway.request("iserver/scanner/params")
    if not isinstance(params, Mapping):
        raise RelayError("IBKR scanner params have an invalid shape")
    for section in ("scan_type_list", "filter_list"):
        print(f"[{section}]")
        for item in params.get(section) or []:
            if isinstance(item, Mapping):
                print(f"{item.get('code')}\t{item.get('display_name', '')}")


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    criteria = validate_args(args)
    gateway = relay.JsonHttpClient(
        args.gateway_url,
        timeout_seconds=args.timeout_seconds,
        loopback_gateway=True,
        allow_insecure_loopback=args.allow_insecure_loopback_gateway,
        max_response_bytes=MAX_GATEWAY_RESPONSE_BYTES,
    )
    scanner = MomentumScanner(
        gateway,
        criteria,
        bands=price_bands(criteria, args.band_edges),
        max_age_seconds=args.max_age_seconds,
    )
    if args.list_params:
        try:
            scanner.require_session()
            print_params(gateway)
            return 0
        except (RelayError, OSError, ValueError) as error:
            print(f"IBKR_MOMENTUM_SCAN_BLOCKED reason={error}", file=sys.stderr, flush=True)
            return 1
    while True:
        started = time.monotonic()
        try:
            artifact = scanner.run()
            print(format_table(artifact), flush=True)
            if args.json:
                args.json.write_text(json.dumps(artifact, indent=2, allow_nan=False), encoding="utf-8")
        except (RelayError, OSError, ValueError) as error:
            print(f"IBKR_MOMENTUM_SCAN_BLOCKED reason={error}", file=sys.stderr, flush=True)
            if not args.every:
                return 1
        if not args.every:
            return 0
        time.sleep(max(0.0, args.every - (time.monotonic() - started)))


if __name__ == "__main__":
    raise SystemExit(main())

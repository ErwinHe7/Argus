"""Export retained, descriptive Research Desk observations; no network or signals.

Existing iv_lab supplies causal daily indicators and OHLC validation. SMA50 and
the observed 20-session high/low are calculated here, never in the frontend.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    from .iv_lab import _number, _rounded, _timestamp, _validated_bars, technical_indicators
except ImportError:  # Support direct, dependency-free invocation.
    from iv_lab import _number, _rounded, _timestamp, _validated_bars, technical_indicators

SCHEMA = "leo-research-desk.v1"
RETAINED = ("DXYZ", "ZM", "AVGO", "AMZN", "GOOGL", "NVDA")
PROXIES = {"SPY": "SPDR S&P 500 ETF Trust", "QQQ": "Invesco QQQ Trust"}


def daily_descriptors(bars: list[dict[str, Any]]) -> dict[str, Any]:
    """Prefix-causal descriptors. Warm-up values stay null; prices are unaltered."""
    validated = _validated_bars(bars)
    technical = technical_indicators(validated)
    series = []
    for index, (bar, point) in enumerate(zip(validated, technical["series"], strict=True)):
        sma50 = math.fsum(row["close"] for row in validated[index - 49:index + 1]) / 50 if index >= 49 else None
        series.append({"date": point["date"], "close": point["close"],
                       "high": bar["high"], "low": bar["low"], "sma20": point["sma20"],
                       "sma50": sma50, "rsi14": point["rsi14"]})
    latest = technical["latest"]
    return {"latest": {
        "rsi14": latest["rsi14"], "sma20": latest["sma20"], "sma50": series[-1]["sma50"],
        "atr14": latest["atr14"], "realizedVol20Percent": latest["realizedVol20Percent"],
        "priceVsSma20Percent": latest["priceVsSma20Percent"],
        "changePercent": latest["return1dPercent"],
        "high20": max(bar["high"] for bar in validated[-20:]) if len(validated) >= 20 else None,
        "low20": min(bar["low"] for bar in validated[-20:]) if len(validated) >= 20 else None,
    }, "series": series[-120:], "technicalLatest": latest}


def validated_suffix(bars: Any) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    observed = _validated_bars(bars, validate_ohlc_range=False)
    invalid = [index for index, bar in enumerate(observed)
               if not (bar["low"] <= bar["open"] <= bar["high"] and bar["low"] <= bar["close"] <= bar["high"])]
    excluded = invalid[-1] + 1 if invalid else 0
    valid = _validated_bars(observed[excluded:])
    return valid, {
        "state": "observed_sessions_only_calendar_unverified", "observedSessions": len(valid),
        "sourceSessions": len(observed), "validationExcludedPrefixSessions": excluded,
        "startDate": valid[0]["date"], "endDate": valid[-1]["date"], "expectedSessions": None,
        "invalidDates": [observed[index]["date"] for index in invalid],
        "validationNote": "Only the contiguous valid suffix after the last inconsistent OHLC bar is used. No prices are repaired, filled or bridged.",
        "adjustmentPolicy": "not specified by provider",
    }


def symbol_record(symbol: str, name: str, source: str, retrieved_at: str,
                  observed_at: str, spot: Any, iv_annual: Any, percentile: Any,
                  bars: list[dict[str, Any]], *, retained: dict[str, Any] | None = None) -> dict[str, Any]:
    retrieved = _timestamp(retrieved_at, "retrievedAt")
    observed = _timestamp(observed_at, "observedAt")
    if observed > retrieved:
        raise ValueError("observation cannot be later than retrieval")
    spot = _number(spot, "spot", strictly_positive=True)
    iv = None if iv_annual is None else _number(iv_annual, "ivAnnual", strictly_positive=True, maximum=5) * 100
    iv_percentile = None if percentile is None else _number(percentile, "ivPercentile", minimum=0, maximum=1) * 100
    suffix, coverage = validated_suffix(bars)
    if suffix[-1]["date"] > observed.date().isoformat():
        raise ValueError("daily bar cannot follow the retained price observation")
    calculated = daily_descriptors(suffix)
    if retained is not None:
        if retained["market"]["coverage"]["startDate"] != coverage["startDate"]:
            raise ValueError("retained IV Lab coverage does not match raw source")
        if _rounded(calculated["technicalLatest"]) != retained["technical"]["latest"]:
            raise ValueError("retained IV Lab indicators do not match source calculation")
    return {
        "symbol": symbol, "name": name, "assetType": "etf" if symbol in PROXIES else "closed_end_fund" if symbol == "DXYZ" else "stock",
        "role": "market_proxy" if symbol in PROXIES else "research_watchlist",
        "source": source, "retrievedAt": retrieved_at, "observedAt": observed_at,
        "dailyBarLastDate": suffix[-1]["date"], "dailyBarCloseObservedAt": None,
        "dailyBarTimestampMeaning": "Source daily timestamps identify the session start; close observation time was not supplied.",
        "spot": spot, "spotBasis": "last_trade_reference_may_be_after_hours", "currency": "USD",
        "iv": iv, "ivPercentile": iv_percentile, "ivObservedAt": None, "ivPercentileObservedAt": None,
        "ivBasis": "undated_provider_underlying_composite_field", "ivPercentileLookback": "52 weeks (provider field)",
        "freshness": "historical_snapshot_not_live", "coverage": coverage,
        "latest": calculated["latest"], "series": calculated["series"],
        "changeBasis": "completed_daily_close_to_previous_observed_daily_close",
        "rangeBasis": "past_20_observed_sessions_high_low_descriptive_not_price_targets",
        "executionEnabled": False,
    }


def tool_payload(result: dict[str, Any]) -> dict[str, Any]:
    if result.get("isError"):
        raise ValueError("IBKR returned an error")
    if isinstance(result.get("structuredContent"), dict):
        payload = result["structuredContent"]
    else:
        messages = [item.get("text", "") for item in result.get("content", []) if item.get("type") == "text"]
        if len(messages) != 1:
            raise ValueError("unrecognized retained IBKR response")
        payload = json.loads(messages[0])
    if not isinstance(payload, dict) or payload.get("error"):
        raise ValueError("invalid IBKR data payload")
    return payload


def proxy_record(item: dict[str, Any], retrieved_at: str) -> dict[str, Any]:
    symbol = item["symbol"]
    if symbol not in PROXIES:
        raise ValueError("unsupported market proxy")
    history, snapshot = tool_payload(item["history"]), tool_payload(item["snapshot"])
    columns = [history.get(key) for key in ("time", "open", "high", "low", "close", "volume")]
    if any(not isinstance(column, list) for column in columns) or len({len(column) for column in columns}) != 1:
        raise ValueError("incomplete parallel history arrays")
    bars = []
    for stamp, open_, high, low, close, volume in zip(*columns, strict=True):
        parsed = _timestamp(stamp, "daily source timestamp")
        bars.append({"date": parsed.date().isoformat(), "open": open_, "high": high, "low": low, "close": close, "volume": volume})
    last = snapshot.get("last", {})
    unix = _number(last.get("ts"), "last.ts", strictly_positive=True)
    observed_at = datetime.fromtimestamp(unix, timezone.utc).isoformat().replace("+00:00", "Z")
    iv = snapshot.get("implied-vol-underlying", {})
    annual = iv.get("annual_iv") if iv.get("is_valid") is True else None
    percentile = snapshot.get("implied-volatility-percentile", {}).get("high_52w")
    return symbol_record(symbol, PROXIES[symbol], "Interactive Brokers connector", retrieved_at,
                         observed_at, last.get("price"), annual, percentile, bars)


def build_desk(raw: dict[str, Any], retained: dict[str, Any], proxies: dict[str, Any] | None = None) -> dict[str, Any]:
    if retained.get("schemaVersion") != "leo-iv-lab.v1":
        raise ValueError("unsupported retained IV Lab schema")
    retained_by_symbol = {item["symbol"]: item for item in retained["symbols"]}
    input_by_symbol = {item["symbol"]: item for item in raw["symbols"]}
    if set(retained_by_symbol) != set(RETAINED) or set(input_by_symbol) != set(RETAINED):
        raise ValueError("exact retained six-symbol research universe required")
    symbols = []
    for symbol in RETAINED:
        item = input_by_symbol[symbol]
        snapshot = item["snapshot"]
        symbols.append(symbol_record(symbol, item["name"], raw["provider"], raw["retrievedAt"],
                                     snapshot["lastTradeTime"], snapshot["last"], snapshot.get("underlyingIvAnnual"),
                                     snapshot.get("ivPercentile52w"), item["history"]["bars"], retained=retained_by_symbol[symbol]))
    proxy_symbols, proxy_exclusions = [], []
    if proxies is not None:
        seen = set()
        for item in proxies.get("symbols", []):
            symbol = item.get("symbol")
            if symbol in seen:
                raise ValueError("duplicate proxy symbol")
            seen.add(symbol)
            try:
                result = proxy_record(item, proxies["retrievedAt"])
                symbols.append(result)
                proxy_symbols.append(symbol)
            except (ValueError, TypeError, KeyError) as error:
                proxy_exclusions.append({"symbol": symbol, "reason": str(error)})
    timestamps = [item["retrievedAt"] for item in symbols]
    latest_retrieval = max(timestamps, key=lambda value: _timestamp(value, "retrievedAt"))
    return _rounded({
        "schemaVersion": SCHEMA, "retrievedAt": latest_retrieval, "dataMode": "historical_snapshot_not_live",
        "sourceRetrievals": sorted(set(timestamps), key=lambda value: _timestamp(value, "retrievedAt")),
        "units": {"prices": "USD per share", "iv": "annualized percent", "ivPercentile": "percent, 0 to 100",
                  "changes": "percent", "atr14": "USD per share", "realizedVol20Percent": "annualized percent"},
        "methodology": {"featureVersion": "research-desk-daily-descriptors.v1", "baseIndicators": "iv_lab.technical_indicators",
                        "sma50": "Arithmetic mean of 50 completed observed daily closes; null before observation 50.",
                        "high20Low20": "Maximum observed daily high and minimum observed daily low over the last 20 valid observed sessions. Descriptive range, never price targets.",
                        "changePercent": "Completed daily close-to-close change; never a mixed-hours return calculated from the spot card.",
                        "projectionEnabled": False, "executionEnabled": False},
        "indexContext": {"state": "etf_proxies_only" if proxy_symbols else "unavailable",
                         "symbols": proxy_symbols, "indicesObserved": False, "exclusions": proxy_exclusions,
                         "note": "SPY and QQQ are tradable ETF proxies; their prices and changes are not S&P 500 or Nasdaq-100 index values." if proxy_symbols else "Index observations and ETF proxies are unavailable; the six-stock watchlist is not an index."},
        "symbols": symbols,
        "limitations": ["Original market and per-symbol retrieval timestamps are preserved. Retrieval does not make an old observation live.",
                        "Spot can be an after-hours last trade. Daily indicators and daily change use completed regular-session observations separately.",
                        "Independent IV and percentile observation times are unavailable; fields stay undated rather than receiving the price timestamp.",
                        "Exchange-calendar coverage and corporate-action adjustment are unverified. Invalid OHLC prefixes are disclosed and excluded, never repaired.",
                        "No predictions, target prices, trade results, win rates or executable instructions are included."],
    })


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--market-data", type=Path, required=True)
    parser.add_argument("--iv-artifact", type=Path, required=True)
    parser.add_argument("--proxies", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    raw_bytes = args.market_data.read_bytes()
    retained = json.loads(args.iv_artifact.read_text(encoding="utf8"))
    raw = json.loads(raw_bytes)
    canonical_source = json.dumps(raw, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()
    if retained.get("inputSha256") != hashlib.sha256(canonical_source).hexdigest():
        raise ValueError("retained IV Lab input hash does not match supplied market-data file")
    proxies = json.loads(args.proxies.read_text(encoding="utf8")) if args.proxies else None
    result = build_desk(raw, retained, proxies)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, allow_nan=False, separators=(",", ":")), encoding="utf8")
    print(f"Exported {len(result['symbols'])} historical research symbols to {args.output}")


if __name__ == "__main__":
    main()

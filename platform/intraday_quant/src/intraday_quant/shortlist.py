"""Export a transparent, dated technical shortlist from retained Desk observations.

This offline module ranks descriptive conditions, not expected returns. No
network, fundamentals, live signals, portfolio advice, or execution are supplied.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
from datetime import date, datetime, time, timedelta, timezone
from hashlib import sha256
import json
from pathlib import Path
import re
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

try:
    from .iv_lab import _number, _rounded, _timestamp
except ImportError:
    from iv_lab import _number, _rounded, _timestamp

PLATFORM = Path(__file__).resolve().parents[3]
DEFAULT_CALENDAR = PLATFORM / "workers/public-market-map/us-calendar.ts"
FRIENDLY_NAMES = {
    "NVDA": "NVIDIA", "AVGO": "Broadcom", "AMZN": "Amazon", "GOOGL": "Alphabet",
    "ZM": "Zoom Communications", "DXYZ": "Destiny Tech100",
    "SPY": "SPDR S&P 500 ETF Trust", "QQQ": "Invesco QQQ Trust",
}
CRITERIA = [
    {"id": "trend", "label": "Above 50-session average",
     "definition": "Completed daily close strictly exceeds SMA50."},
    {"id": "momentum", "label": "RSI in the selected band",
     "definition": "RSI14 is between 50 and 65, including both endpoints."},
    {"id": "price_discipline", "label": "Within 5% above 20-session average",
     "definition": "Completed daily close is at least SMA20 and at most 1.05 times SMA20, including both endpoints."},
]


def _text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{name} is missing")
    return value


def _iso(value: str) -> str:
    return _timestamp(value, "wire timestamp").astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def calendar_review(as_of: str, path: Path | None) -> tuple[str | None, str | None, str | None]:
    """Read the existing bounded schedule; do not infer observation availability.

    Its closed/early sets remain the single source of dates. Unrecognized or
    unavailable schedule metadata disables the deadline instead of guessing.
    """
    if path is None:
        return None, None, None
    try:
        raw = path.read_text(encoding="utf8")
        fields = {}
        for key in ("SOURCE", "VERIFIED_AT", "START", "END"):
            match = re.search(rf"export const US_CALENDAR_{key} = '([^']+)';", raw)
            if match is None:
                return None, None, None
            fields[key] = match.group(1)
        sets = {}
        for key in ("closed", "early"):
            match = re.search(rf"const {key} = new Set\(\[(.*?)\]\);", raw, re.DOTALL)
            if match is None:
                return None, None, None
            sets[key] = {date.fromisoformat(value) for value in re.findall(r"'(\d{4}-\d{2}-\d{2})'", match.group(1))}
        current = date.fromisoformat(as_of)
        first, last = date.fromisoformat(fields["START"]), date.fromisoformat(fields["END"])
        if not first <= current <= last:
            return None, fields["SOURCE"], _iso(fields["VERIFIED_AT"])
        # Bind the source version to a verified past timestamp, not arbitrary text.
        _timestamp(fields["VERIFIED_AT"], "calendar verified time")
        zone = ZoneInfo("America/New_York")
        for offset in range(1, 15):
            candidate = current + timedelta(days=offset)
            if candidate > last:
                break
            if candidate.weekday() >= 5 or candidate in sets["closed"]:
                continue
            close = datetime.combine(candidate, time(13 if candidate in sets["early"] else 16), zone)
            return close.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"), fields["SOURCE"], _iso(fields["VERIFIED_AT"])
    except (OSError, ValueError, ZoneInfoNotFoundError):
        pass
    return None, None, None


def shortlist_row(asset: dict[str, Any], as_of: str) -> dict[str, Any]:
    symbol = _text(asset.get("symbol"), "symbol")
    if asset.get("assetType") not in ("stock", "etf", "closed_end_fund"):
        raise ValueError("asset type is not a supported stock or fund")
    if asset.get("currency") != "USD":
        raise ValueError("this screen requires USD observations")
    if asset.get("dailyBarLastDate") != as_of:
        raise ValueError("daily cutoff differs from the shortlist cutoff")
    if asset.get("freshness") != "historical_snapshot_not_live":
        raise ValueError("expected an explicitly dated historical snapshot")
    source = _text(asset.get("source"), "source")
    retrieved_at = _text(asset.get("retrievedAt"), "source retrieval time")
    retrieved = _timestamp(retrieved_at, "source retrieval time")
    observed_at = _text(asset.get("observedAt"), "price observation time")
    observed = _timestamp(observed_at, "price observation time")
    if observed > retrieved or date.fromisoformat(as_of) > observed.date():
        raise ValueError("source observation and retrieval timestamps are inconsistent")
    if asset.get("dailyBarCloseObservedAt") is not None:
        raise ValueError("this retained schema expects the independent daily-close observation time to be unknown")
    coverage = asset.get("coverage")
    if not isinstance(coverage, dict) or coverage.get("state") != "observed_sessions_only_calendar_unverified":
        raise ValueError("retained observation coverage is missing")
    sessions = coverage.get("observedSessions")
    if isinstance(sessions, bool) or not isinstance(sessions, int) or sessions < 50:
        raise ValueError("at least 50 retained observed sessions are required")
    if coverage.get("endDate") != as_of:
        raise ValueError("coverage end does not match the daily cutoff")
    if not isinstance(coverage.get("adjustmentPolicy"), str):
        raise ValueError("adjustment policy disclosure is missing")
    series = asset.get("series")
    if not isinstance(series, list) or not series or series[-1].get("date") != as_of:
        raise ValueError("daily cutoff does not match the final series point")
    if len(series) != min(120, sessions):
        raise ValueError("retained series count does not match observed coverage and the 120-point export limit")
    previous_date = None
    for point in series:
        if not isinstance(point, dict):
            raise ValueError("invalid retained series point")
        point_date = date.fromisoformat(_text(point.get("date"), "retained series date"))
        if previous_date is not None and point_date <= previous_date:
            raise ValueError("retained series dates must be unique and strictly increasing")
        _number(point.get("close"), "retained series close", strictly_positive=True)
        previous_date = point_date
    latest = asset.get("latest")
    if not isinstance(latest, dict):
        raise ValueError("latest indicators are missing")
    close = _number(series[-1].get("close"), "completed daily close", strictly_positive=True)
    sma20 = _number(latest.get("sma20"), "SMA20", strictly_positive=True)
    sma50 = _number(latest.get("sma50"), "SMA50", strictly_positive=True)
    rsi = _number(latest.get("rsi14"), "RSI14", minimum=0, maximum=100)
    atr = _number(latest.get("atr14"), "ATR14", minimum=0)
    for key, expected in (("sma20", sma20), ("sma50", sma50), ("rsi14", rsi)):
        if series[-1].get(key) != expected:
            raise ValueError(f"latest {key} differs from the final series observation")
    change = latest.get("changePercent")
    if change is not None:
        change = _number(change, "completed daily change")
    conditions = [close > sma50, 50 <= rsi <= 65, sma20 <= close <= 1.05 * sma20]
    relative = (close / sma20 - 1) * 100
    atr_percent = atr / close * 100
    details = [
        f"Close ${close:,.2f}; SMA50 ${sma50:,.2f}.",
        f"RSI14 {rsi:.1f}; selected band 50–65.",
        f"Close {relative:+.2f}% versus SMA20 ${sma20:,.2f}; selected band 0% to +5%.",
    ]
    checks = [{"id": rule["id"], "label": rule["label"], "passed": passed, "detail": detail}
              for rule, passed, detail in zip(CRITERIA, conditions, details, strict=True)]
    passed_count = sum(conditions)
    if all(conditions):
        summary = "The trend and momentum conditions line up, and price is still inside the selected band."
    elif conditions[0] and rsi < 50:
        summary = "Price is above its longer-term average; short-term momentum is still soft."
    elif conditions[0] and rsi > 65:
        summary = "Price is above its longer-term average, but momentum is above the screen’s selected band."
    elif conditions[0] and close < sma20:
        summary = "Price is above its longer-term average, but it has yet to regain its short-term average."
    elif conditions[0]:
        summary = "The trend condition is met, but price has stretched beyond the selected band."
    elif conditions[1]:
        summary = "Momentum is in the selected band, but price has not cleared its longer-term average."
    else:
        summary = "Price has not cleared its longer-term average, and momentum is outside the selected band."
    hesitation = []
    if not conditions[0]:
        hesitation.append("The longer-term trend condition is still missing.")
    if close < sma20:
        hesitation.append("Price remains below its short-term average.")
    elif relative > 5:
        hesitation.append("Price is already above the screen’s price band.")
    elif relative >= 4:
        hesitation.append("Price is near the upper edge of the band; a small rise could change the result.")
    if rsi < 50:
        hesitation.append("Momentum has not reached the selected band.")
    elif rsi > 65:
        hesitation.append("Momentum is above the selected band.")
    hesitation.append(f"The observed daily range measure, ATR14, is {atr_percent:.2f}% of the close.")
    if coverage.get("validationExcludedPrefixSessions", 0) > 0:
        hesitation.append(f"Only {sessions} valid observations remain after inconsistent earlier bars were excluded.")
    counterpoint = " ".join(hesitation)
    return {
        "rank": 0, "symbol": symbol, "name": FRIENDLY_NAMES.get(symbol, _text(asset.get("name"), "name")),
        "assetType": asset["assetType"], "criteriaMet": passed_count, "criteriaTotal": 3,
        "summary": summary, "counterpoint": counterpoint,
        "watch": f"Recheck the next completed daily close against an updated short-term average. This snapshot’s 20-session reference is ${sma20:,.2f}.",
        "close": close, "changePercent": change, "rsi14": rsi, "sma20": sma20, "sma50": sma50,
        "atr14": atr, "atrPercent": atr_percent, "priceVsSma20Percent": relative,
        "asOf": as_of, "source": source, "sourceRetrievedAt": _iso(retrieved_at),
        "priceObservedAt": _iso(observed_at), "dailyCloseObservedAt": None,
        "coverage": deepcopy(coverage), "criteria": checks,
    }


def build_shortlist(data: dict[str, Any], calendar_path: Path | None = DEFAULT_CALENDAR,
                    input_bytes: bytes | None = None) -> dict[str, Any]:
    """CLI artifacts hash exact input bytes; in-memory callers hash canonical JSON.

    Supplied bytes must decode to the same input object. This binds the published
    artifact to its retained file without confusing formatting with new evidence.
    """
    if data.get("schemaVersion") != "leo-research-desk.v1" or data.get("dataMode") != "historical_snapshot_not_live":
        raise ValueError("expected the retained historical Desk artifact")
    assets = data.get("symbols")
    if not isinstance(assets, list) or not assets or any(not isinstance(asset, dict) for asset in assets):
        raise ValueError("a nonempty array of source assets is required")
    symbols = [_text(asset.get("symbol"), "symbol") for asset in assets]
    if len(set(symbols)) != len(symbols):
        raise ValueError("duplicate source symbols")
    cutoffs = {date.fromisoformat(_text(asset.get("dailyBarLastDate"), "daily cutoff")).isoformat() for asset in assets}
    as_of = max(cutoffs)
    source_times = [_text(asset.get("retrievedAt"), "source retrieval time") for asset in assets]
    latest_retrieval = max(source_times, key=lambda value: _timestamp(value, "source retrieval time"))
    if date.fromisoformat(as_of) > _timestamp(latest_retrieval, "source retrieval time").date():
        raise ValueError("daily cutoff cannot follow source retrieval")
    canonical = json.dumps(data, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf8")
    if input_bytes is not None:
        if json.loads(input_bytes.decode("utf8")) != data:
            raise ValueError("supplied source bytes do not match the input object")
        canonical = input_bytes
    groups: dict[str, list[dict[str, Any]]] = {"stocks": [], "funds": []}
    exclusions = []
    for asset in assets:
        try:
            row = shortlist_row(asset, as_of)
            groups["stocks" if row["assetType"] == "stock" else "funds"].append(row)
        except (ValueError, TypeError, KeyError) as error:
            exclusions.append({"symbol": asset["symbol"], "reason": str(error)})
    for rows in groups.values():
        rows.sort(key=lambda row: (-row["criteriaMet"], row["atrPercent"], row["symbol"]))
        for rank, row in enumerate(rows, start=1):
            row["rank"] = rank
    review_after, calendar_source, calendar_verified = calendar_review(as_of, calendar_path)
    return _rounded({
        "schemaVersion": "astra-shortlist.v1", "featureVersion": "astra-technical-shortlist.v1",
        "dataMode": "historical_snapshot_not_live", "asOf": as_of,
        "sourceRetrievedAt": _iso(latest_retrieval), "inputSha256": sha256(canonical).hexdigest(),
        "reviewAfter": review_after,
        "universe": {"observedAssets": len(assets),
                     "companyStocks": sum(asset.get("assetType") == "stock" for asset in assets),
                     "funds": sum(asset.get("assetType") in ("etf", "closed_end_fund") for asset in assets),
                     "eligibleCompanyStocks": len(groups["stocks"]), "eligibleFunds": len(groups["funds"])},
        "methodology": {"criteria": deepcopy(CRITERIA),
                        "ranking": "Within company stocks and funds separately: more conditions met first; ties use lower ATR14 / completed close, then symbol alphabetically.",
                        "scoreMeaning": "A count of three chosen descriptive conditions, not a probability, investment grade, expected return, or validated edge. Thresholds are fixed research choices, not fitted performance claims.",
                        "sourceCutoffMeaning": "Completed source daily-session date. Spot may be after hours; independent daily-close availability, full calendar coverage, and corporate-action adjustments are unverified.",
                        "reviewAfterMeaning": "Next scheduled U.S. core-session close after this snapshot, from the retained bounded NYSE calendar. A review deadline only; it does not certify new data availability or full historical coverage. Null means no verified deadline was available.",
                        "calendarSource": calendar_source, "calendarVerifiedAt": calendar_verified},
        **groups, "exclusions": exclusions,
        "limitations": [
            "Ranks cover this small retained universe, not all U.S. stocks. Company stocks and funds are ranked separately.",
            "Recorded daily observations only. Retrieval time does not make a historical price live.",
            "Exchange-calendar completeness, corporate-action adjustment, and independent daily-close availability are unverified. Invalid source prefixes remain excluded and disclosed.",
            "The screen uses price, moving averages, RSI, and ATR only. It does not establish fundamental value, earnings quality, probabilities, future returns, or a buy recommendation.",
            "Undated IV fields, live chart widgets, synthetic grid demonstrations, and brokerage account data are not ranking inputs.",
        ], "predictionEnabled": False, "executionEnabled": False,
    })


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=PLATFORM / "features/research-desk/data/desk-data.json")
    parser.add_argument("--output", type=Path, default=PLATFORM / "features/research-desk/data/shortlist.json")
    parser.add_argument("--calendar", type=Path, default=DEFAULT_CALENDAR)
    args = parser.parse_args()
    input_bytes = args.input.read_bytes()
    result = build_shortlist(json.loads(input_bytes.decode("utf8")), args.calendar, input_bytes)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, allow_nan=False, indent=2) + "\n", encoding="utf8")
    print(f"Exported {len(result['stocks'])} company-stock and {len(result['funds'])} fund rows; cutoff {result['asOf']}.")


if __name__ == "__main__":
    main()

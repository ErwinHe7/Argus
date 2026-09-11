"""Reproducible, offline IV scenario export. This module never emits trade signals.

Only Python's standard library is required. Observed daily bars and last trades
remain distinct from assumed, constant IV European-option scenarios. Unknown
quote timestamps, split adjustment and contract multipliers are not inferred.

SMA20, population Bollinger20 and Wilder RSI14/ATR14 match the definitions in
``quant_engine_rs/src/market_map.rs::features``. KDJ matches the old 9/3/3 station's
50 seeds and flat-range convention, moving that calculation out of TypeScript.
Those implementations cannot be imported into a dependency-free Python export;
their definitions are explicitly retained here, not presented as a promoted
production prediction model.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any


VERSION = "leo-iv-lab.v1"
AXES = {
    "tenorDays": [14, 30, 60, 90],
    "rights": ["call", "put"],
    "strikeOffsetPercent": [-10, 0, 10],
    "elapsedDays": [0, 3, 7],
    "spotMovePercent": [-10, -5, 0, 5, 10, 20],
    "ivShiftPp": [-20, -10, 0, 10, 20],
}
DEFAULTS = {
    "symbol": "AVGO", "tenorDays": 30, "right": "call",
    "strikeOffsetPercent": 0, "elapsedDays": 7,
}
DEFINITIONS = {
    "sma20": "Arithmetic mean of 20 completed daily closes; null before bar 20.",
    "bollinger20": "SMA20 +/- 2 population standard deviations of 20 closes (ddof=0).",
    "rsi14": "Wilder RSI: seed mean of first 14 price changes, then (13*previous+change)/14; flat=50; no losses=100.",
    "atr14": "Wilder ATR: first 14 true ranges after the first close seed the mean; same smoothing as RSI.",
    "kdj9_3_3": "9-bar high/low RSV; flat range RSV=50; initial K=D=50; K=(2*previousK+RSV)/3, D=(2*previousD+K)/3, J=3*K-2*D. Null before bar 9.",
    "macd": "EMA12 minus EMA26, each seeded with its period SMA; signal=EMA9 of available MACD, histogram=MACD-signal (not doubled).",
    "realizedVol20Percent": "Sample standard deviation (ddof=1) of 20 daily log returns * sqrt(252) * 100; null before 21 closes. This is historical realized volatility, not option IV.",
    "relativeVolume20": "Current daily volume divided by mean volume over current and prior 19 observed sessions; null for zero denominator or incomplete/unknown volume.",
    "trend": "Descriptive: bullish when close>SMA20 and RSI14>55; bearish when close<SMA20 and RSI14<45; otherwise neutral. Not a forecast or recommendation.",
    "return1dPercent": "(Current close / prior close - 1) * 100, based only on completed daily bars.",
    "return5dPercent": "(Current close / close five observed sessions earlier - 1) * 100.",
    "priceVsSma20Percent": "(Current close / SMA20 - 1) * 100.",
}
LIMITATIONS = [
    "Offline, historical observation snapshot with hypothetical scenarios; no live signal, forecast probability or execution permission.",
    "Underlying composite IV and IV percentile have no independent observation timestamps. They are user-selected research assumptions anchored to a provider field, not observed contract IV or a volatility surface.",
    "Scenario spot is a timestamped last trade, possibly after hours; technical indicators use separate completed regular-session daily bars. They are not synchronized executable quotes.",
    "European Black-Scholes with constant rates and volatility does not model American early exercise, discrete cash dividends, jumps, volatility skew/smile or event term structure.",
    "Continuous risk-free rate and dividend yield are explicit research assumptions in methodology, not verified current market observations. Hypothetical multiplier=100, unverified for quoted contracts.",
    "Calendar-day ACT/365 option time and 252-session historical-volatility annualization use different clocks. Tenors and strikes are theoretical, not listed contract specifications.",
    "No bid/ask execution, commission, slippage, financing or taxes in scenario P&L. A theoretical premium is not an available purchase or liquidation price.",
    "Historical daily-bar corporate-action adjustment and exchange-calendar completeness are not attested by the source. Indicators are descriptive research on supplied observations, not validated strategy performance.",
    "A low IV percentile is not a probability of a price increase, nor proof that an option is underpriced. IV and spot shocks are independent assumptions, not forecasts.",
    "Price-only, IV-only and time-only effects each reprice from the same baseline. Their sum need not equal the full reprice; the residual records nonlinear interactions, not an extra source of profit.",
    "Observed option bid/ask, IV and open-interest fields lacking independent timestamps remain read-only incomplete evidence; no execution eligibility or synchronization is inferred.",
]


def _number(value: Any, name: str, *, minimum: float | None = None,
            maximum: float | None = None, strictly_positive: bool = False) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError(f"{name}: finite numeric value required")
    result = float(value)
    if strictly_positive and result <= 0:
        raise ValueError(f"{name}: positive value required")
    if minimum is not None and result < minimum:
        raise ValueError(f"{name}: below supported minimum {minimum}")
    if maximum is not None and result > maximum:
        raise ValueError(f"{name}: above supported maximum {maximum}")
    return result


def _timestamp(value: Any, name: str) -> datetime:
    if not isinstance(value, str) or not value:
        raise ValueError(f"{name}: timezone-aware timestamp required")
    try:
        result = datetime.fromisoformat(value.replace(" UTC", "+00:00").replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError(f"{name}: invalid timestamp") from exc
    if result.tzinfo is None:
        raise ValueError(f"{name}: timezone-aware timestamp required")
    return result.astimezone(timezone.utc)


def _cdf(value: float) -> float:
    return 0.5 * math.erfc(-value / math.sqrt(2.0))


def black_scholes(spot: float, strike: float, days: float, sigma: float,
                  right: str = "call", rate: float = 0.04,
                  dividend_yield: float = 0.0) -> dict[str, float | None]:
    """European theoretical value per share; vega / 1 IV pp, theta / calendar day.

    Rates and sigma are annual decimals (0.35 means 35%). Supported numerical
    domain is explicitly bounded, including positive sigma even at expiry.
    At expiration, payoff is exact; theta is undefined and ATM delta/gamma are
    undefined. No positive volatility floor silently alters an input.
    """
    spot = _number(spot, "spot", minimum=1e-8, maximum=1e9)
    strike = _number(strike, "strike", minimum=1e-8, maximum=1e9)
    days = _number(days, "days", minimum=0, maximum=36500)
    sigma = _number(sigma, "sigma", strictly_positive=True, maximum=5)
    rate = _number(rate, "rate", minimum=-1, maximum=1)
    dividend_yield = _number(dividend_yield, "dividend_yield", minimum=-1, maximum=1)
    if right not in ("call", "put"):
        raise ValueError("right: expected call or put")
    if days == 0:
        itm = spot > strike if right == "call" else spot < strike
        return {
            "premium": max(0.0, spot - strike if right == "call" else strike - spot),
            "delta": None if spot == strike else (1.0 if right == "call" else -1.0) if itm else 0.0,
            "gamma": None if spot == strike else 0.0,
            "vegaPerPp": 0.0, "thetaPerDay": None,
        }
    time = days / 365.0
    root_time = math.sqrt(time)
    discount_r = math.exp(-rate * time)
    discount_q = math.exp(-dividend_yield * time)
    d1 = (math.log(spot / strike) + (rate - dividend_yield + 0.5 * sigma * sigma) * time) / (sigma * root_time)
    d2 = d1 - sigma * root_time
    density = math.exp(-0.5 * d1 * d1) / math.sqrt(2.0 * math.pi)
    common_theta = -spot * discount_q * density * sigma / (2.0 * root_time)
    if right == "call":
        premium = spot * discount_q * _cdf(d1) - strike * discount_r * _cdf(d2)
        delta = discount_q * _cdf(d1)
        theta = common_theta - rate * strike * discount_r * _cdf(d2) + dividend_yield * spot * discount_q * _cdf(d1)
    else:
        premium = strike * discount_r * _cdf(-d2) - spot * discount_q * _cdf(-d1)
        delta = discount_q * (_cdf(d1) - 1.0)
        theta = common_theta + rate * strike * discount_r * _cdf(-d2) - dividend_yield * spot * discount_q * _cdf(-d1)
    # Floating-point subtraction can produce a tiny negative value at a tail.
    if -1e-10 < premium < 0:
        premium = 0.0
    result = {
        "premium": premium, "delta": delta,
        "gamma": discount_q * density / (spot * sigma * root_time),
        "vegaPerPp": spot * discount_q * density * root_time / 100.0,
        "thetaPerDay": theta / 365.0,
    }
    if premium < 0 or not all(math.isfinite(value) for value in result.values()):
        raise ValueError("Black-Scholes result outside finite nonnegative pricing domain")
    return result


def scenario_cell(spot: float, strike: float, tenor_days: float, sigma: float,
                  right: str, elapsed_days: float, spot_move_percent: float,
                  iv_shift_pp: float, rate: float = 0.04,
                  dividend_yield: float = 0.0) -> dict[str, Any]:
    """Reprice one cell from baseline. IV shifts are additive percentage points."""
    base = black_scholes(spot, strike, tenor_days, sigma, right, rate, dividend_yield)["premium"]
    elapsed_days = _number(elapsed_days, "elapsed_days", minimum=0, maximum=tenor_days)
    spot_move_percent = _number(spot_move_percent, "spot_move_percent", minimum=-99.999, maximum=1000)
    iv_shift_pp = _number(iv_shift_pp, "iv_shift_pp", minimum=-500, maximum=500)
    changed_sigma = sigma + iv_shift_pp / 100.0
    changed_spot = spot * (1.0 + spot_move_percent / 100.0)
    remaining = tenor_days - elapsed_days
    cell: dict[str, Any] = {"spotMovePercent": spot_move_percent, "ivShiftPp": iv_shift_pp,
                            "newSpot": changed_spot, "newIvPercent": changed_sigma * 100,
                            "daysRemaining": remaining}
    if changed_sigma <= 0 or changed_sigma > 5:
        return {**cell, "status": "invalid_iv", **{key: None for key in (
            "price", "pnl", "pnlPercent", "premiumPerContract", "pnlPerContract",
            "priceOnlyPnl", "ivOnlyPnl", "timeOnlyPnl", "interactionPnl"
        )}}
    def price(s: float, d: float, iv: float) -> float:
        return black_scholes(s, strike, d, iv, right, rate, dividend_yield)["premium"]  # type: ignore[return-value]
    price_only = price(changed_spot, tenor_days, sigma) - base
    iv_only = price(spot, tenor_days, changed_sigma) - base
    time_only = price(spot, remaining, sigma) - base
    full_price = price(changed_spot, remaining, changed_sigma)
    full_pnl = full_price - base
    return {
        **cell, "status": "valid", "price": full_price, "pnl": full_pnl,
        "premiumPerContract": full_price * 100, "pnlPerContract": full_pnl * 100,
        "pnlPercent": full_pnl / base * 100.0 if base > 1e-12 else None,
        "priceOnlyPnl": price_only, "ivOnlyPnl": iv_only, "timeOnlyPnl": time_only,
        "interactionPnl": full_pnl - price_only - iv_only - time_only,
    }


def _validated_bars(bars: Any, *, validate_ohlc_range: bool = True) -> list[dict[str, Any]]:
    if not isinstance(bars, list) or not bars:
        raise ValueError("bars: nonempty chronological daily-bar list required")
    result = []
    previous = None
    for row in bars:
        if not isinstance(row, dict):
            raise ValueError("bar: object required")
        try:
            day = date.fromisoformat(row["date"])
        except (KeyError, TypeError, ValueError) as exc:
            raise ValueError("bar date: ISO date required") from exc
        if previous is not None and day <= previous:
            raise ValueError("bars: dates must be strictly increasing, with no duplicates")
        previous = day
        prices = {key: _number(row.get(key), f"bar.{key}", minimum=1e-8, maximum=1e9)
                  for key in ("open", "high", "low", "close")}
        if validate_ohlc_range and not (prices["low"] <= prices["open"] <= prices["high"] and
                                       prices["low"] <= prices["close"] <= prices["high"]):
            raise ValueError("bar: OHLC range inconsistent")
        volume = None if row.get("volume") is None else _number(row["volume"], "volume", minimum=0, maximum=1e18)
        result.append({"date": day.isoformat(), **prices, "volume": volume})
    return result


def technical_indicators(bars: list[dict[str, Any]]) -> dict[str, Any]:
    """Causal, prefix-stable daily descriptors with explicit warm-up nulls."""
    bars = _validated_bars(bars)
    closes = [row["close"] for row in bars]
    series: list[dict[str, Any]] = []
    gain = loss = atr = 0.0
    previous_k = previous_d = 50.0
    ema12 = ema26 = signal = None
    macds: list[float] = []
    returns: list[float] = []
    for index, row in enumerate(bars):
        close = row["close"]
        current = {"date": row["date"], "close": close, "volume": row["volume"],
                   **{key: None for key in (
                       "sma20", "bollingerUpper", "bollingerLower", "rsi14", "atr14",
                       "k", "d", "j", "macd", "macdSignal", "macdHistogram",
                       "realizedVol20Percent", "relativeVolume20", "return1dPercent",
                       "return5dPercent", "priceVsSma20Percent",
                   )}}
        if index >= 19:
            window = closes[index - 19:index + 1]
            average = math.fsum(window) / 20.0
            deviation = math.sqrt(math.fsum((item - average) ** 2 for item in window) / 20.0)
            current.update(sma20=average, bollingerUpper=average + 2 * deviation,
                           bollingerLower=average - 2 * deviation,
                           priceVsSma20Percent=(close / average - 1) * 100)
            volumes = [item["volume"] for item in bars[index - 19:index + 1]]
            if all(item is not None for item in volumes):
                volume_average = math.fsum(volumes) / 20.0
                current["relativeVolume20"] = row["volume"] / volume_average if volume_average else None
        if index:
            change = close - closes[index - 1]
            current_gain, current_loss = max(change, 0), max(-change, 0)
            true_range = max(row["high"] - row["low"], abs(row["high"] - closes[index - 1]), abs(row["low"] - closes[index - 1]))
            if index <= 14:
                gain += current_gain / 14
                loss += current_loss / 14
                atr += true_range / 14
            else:
                gain, loss, atr = ((gain * 13 + current_gain) / 14,
                                   (loss * 13 + current_loss) / 14,
                                   (atr * 13 + true_range) / 14)
            if index >= 14:
                current["rsi14"] = 50.0 if gain == loss == 0 else 100.0 if loss == 0 else 100 - 100 / (1 + gain / loss)
                current["atr14"] = atr
            returns.append(math.log(close / closes[index - 1]))
            current["return1dPercent"] = (close / closes[index - 1] - 1) * 100
        if index >= 20:
            recent = returns[-20:]
            mean_return = math.fsum(recent) / 20
            current["realizedVol20Percent"] = math.sqrt(math.fsum((r - mean_return) ** 2 for r in recent) / 19) * math.sqrt(252) * 100
        if index >= 5:
            current["return5dPercent"] = (close / closes[index - 5] - 1) * 100
        if index >= 8:
            recent_bars = bars[index - 8:index + 1]
            high, low = max(item["high"] for item in recent_bars), min(item["low"] for item in recent_bars)
            rsv = 50.0 if high == low else (close - low) / (high - low) * 100
            k = (2 * previous_k + rsv) / 3
            d = (2 * previous_d + k) / 3
            current.update(k=k, d=d, j=3 * k - 2 * d)
            previous_k, previous_d = k, d
        if index == 11:
            ema12 = math.fsum(closes[:12]) / 12
        elif index > 11:
            ema12 += (close - ema12) * 2 / 13
        if index == 25:
            ema26 = math.fsum(closes[:26]) / 26
        elif index > 25:
            ema26 += (close - ema26) * 2 / 27
        if ema12 is not None and ema26 is not None:
            current["macd"] = ema12 - ema26
            macds.append(current["macd"])
            if len(macds) == 9:
                signal = math.fsum(macds) / 9
            elif len(macds) > 9:
                signal += (current["macd"] - signal) * 2 / 10
            current["macdSignal"] = signal
            current["macdHistogram"] = None if signal is None else current["macd"] - signal
        current["trend"] = "neutral"
        if current["sma20"] is not None and current["rsi14"] is not None:
            if close > current["sma20"] and current["rsi14"] > 55:
                current["trend"] = "bullish"
            elif close < current["sma20"] and current["rsi14"] < 45:
                current["trend"] = "bearish"
        series.append(current)
    return {"latest": series[-1], "series": series, "definitions": DEFINITIONS,
            "featureVersion": "iv-lab-daily-descriptors.v1",
            "predictionModelApplied": False}


def _rounded(value: Any) -> Any:
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ValueError("nonfinite artifact value")
        return round(value, 6)
    if isinstance(value, list):
        return [_rounded(item) for item in value]
    if isinstance(value, dict):
        return {key: _rounded(item) for key, item in value.items()}
    return value


def build_artifact(raw: dict[str, Any], *, rate: float = 0.04,
                   dividend_yield: float = 0.0) -> dict[str, Any]:
    """Adapt the retained IBKR evidence schema without network or fallback data."""
    rate = _number(rate, "rate", minimum=-1, maximum=1)
    dividend_yield = _number(dividend_yield, "dividend_yield", minimum=-1, maximum=1)
    available = _timestamp(raw.get("retrievedAt"), "retrievedAt")
    source = raw.get("provider")
    if not isinstance(source, str) or not source:
        raise ValueError("provider: source required")
    if not isinstance(raw.get("symbols"), list) or not raw["symbols"]:
        raise ValueError("symbols: nonempty list required")
    symbols = []
    seen: set[str] = set()
    for item in raw["symbols"]:
        symbol = item.get("symbol")
        if not isinstance(symbol, str) or not symbol or symbol in seen:
            raise ValueError("symbol: unique nonempty identifier required")
        if item.get("currency") != "USD":
            raise ValueError(f"{symbol}: USD source required")
        seen.add(symbol)
        snapshot, history = item["snapshot"], item["history"]
        observed = _timestamp(snapshot.get("lastTradeTime"), "lastTradeTime")
        if observed > available:
            raise ValueError(f"{symbol}: observation later than availability")
        spot = _number(snapshot.get("last"), "snapshot.last", minimum=1e-8, maximum=1e9)
        iv = _number(snapshot.get("underlyingIvAnnual"), "underlyingIvAnnual", strictly_positive=True, maximum=5)
        percentile = snapshot.get("ivPercentile52w")
        if percentile is not None:
            percentile = _number(percentile, "ivPercentile52w", minimum=0, maximum=1) * 100
        source_bars = _validated_bars(history.get("bars"), validate_ohlc_range=False)
        invalid_indices = [index for index, bar in enumerate(source_bars)
                           if not (bar["low"] <= bar["open"] <= bar["high"] and
                                   bar["low"] <= bar["close"] <= bar["high"])]
        excluded = invalid_indices[-1] + 1 if invalid_indices else 0
        # Do not repair highs/lows, discard isolated days then bridge returns,
        # or reset RSI invisibly. Start a disclosed, strictly valid suffix.
        bars = _validated_bars(source_bars[excluded:])
        if date.fromisoformat(bars[-1]["date"]) > observed.date():
            raise ValueError(f"{symbol}: daily bar later than spot observation cutoff")
        technical = technical_indicators(bars)
        configurations = []
        for tenor in AXES["tenorDays"]:
            for right in AXES["rights"]:
                for offset in AXES["strikeOffsetPercent"]:
                    strike = spot * (1 + offset / 100)
                    baseline = black_scholes(spot, strike, tenor, iv, right, rate, dividend_yield)
                    baseline.update(
                        premiumPerContract=baseline["premium"] * 100,
                        breakevenAtExpiry=strike + baseline["premium"] if right == "call" else strike - baseline["premium"],
                        fullPremiumLossPerContract=baseline["premium"] * 100,
                    )
                    scenarios = [{"elapsedDays": elapsed, "cells": [
                        scenario_cell(spot, strike, tenor, iv, right, elapsed, move, shift, rate, dividend_yield)
                        for move in AXES["spotMovePercent"] for shift in AXES["ivShiftPp"]
                    ]} for elapsed in AXES["elapsedDays"]]
                    configurations.append({"id": f"{tenor}:{right}:{offset}", "tenorDays": tenor,
                                           "right": right, "strikeOffsetPercent": offset,
                                           "strike": strike, "baseline": baseline, "scenarios": scenarios})
        symbols.append({
            "symbol": symbol, "label": item.get("name", symbol),
            "market": {
                "spot": spot, "currency": "USD", "observedAt": snapshot["lastTradeTime"],
                "availableAt": available.isoformat().replace("+00:00", "Z"), "source": source,
                "basis": "last_trade_reference_may_be_after_hours",
                "dailyBarLastDate": bars[-1]["date"], "dailyBarCloseObservedAt": None,
                "dailyBarTimestampMeaning": history.get("barTimestampMeaning", "unknown"),
                "freshness": "historical_snapshot_not_live",
                "coverage": {"state": "observed_sessions_only_calendar_unverified", "observedSessions": len(bars),
                             "startDate": bars[0]["date"], "endDate": bars[-1]["date"], "expectedSessions": None,
                             "sourceSessions": len(source_bars), "validationExcludedPrefixSessions": excluded,
                             "invalidDates": [source_bars[index]["date"] for index in invalid_indices],
                             "validationNote": "Use only the contiguous observed suffix after the last OHLC inconsistency; discarded prefix is not repaired or bridged." if excluded else "All supplied OHLC ranges passed; calendar completeness remains unverified.",
                             "adjustmentPolicy": history.get("adjustmentPolicy", "unknown")},
                "executionEligible": False,
            },
            "ivAssumption": {
                "annualIv": iv, "ivPercentilePercent": percentile,
                "classification": "user_scenario_assumption", "observedAt": None,
                "source": f"User-selected research baseline from {source} underlyingIvAnnual; not contract IV",
                "retrievedAt": available.isoformat().replace("+00:00", "Z"),
                "percentileObservedAt": None, "percentileLookback": "52 weeks (provider field)",
                "units": "annualIv decimal; ivPercentilePercent percent; IV shocks additive percentage points",
            },
            "technical": technical, "configurations": configurations,
            "optionEvidence": [dict({key: value for key, value in option.items() if key != "sourceContractId"}, executionEligible=False, evidenceStatus="incomplete_independent_field_timestamps")
                               for option in raw.get("options", []) if option.get("symbol") == symbol],
        })
    digest = hashlib.sha256(json.dumps(raw, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()
    return _rounded({
        "schemaVersion": VERSION, "generatedAt": available.isoformat().replace("+00:00", "Z"),
        "inputSha256": digest,
        "methodology": {
            "model": "European Black-Scholes offline constant-volatility scenario",
            "modelVersion": "bs-european-scenario.v1", "rateAnnual": rate,
            "dividendYieldAnnual": dividend_yield, "rateAndDividendSource": "explicit user research assumptions, not observed rates",
            "optionCalendarDaysPerYear": 365, "realizedVolSessionsPerYear": 252,
            "assumedContractMultiplier": 100, "premiumAndPnlUnits": "USD per share",
            "vegaUnits": "USD per share per +1 IV percentage point", "thetaUnits": "USD per share per elapsed calendar day",
            "strikeDefinition": "spot * (1 + strikeOffsetPercent / 100); theoretical, not an exchange-listed strike",
            "pnlPercentDefinition": "(scenario theoretical premium - baseline theoretical premium) / baseline theoretical premium * 100",
            "invalidIvPolicy": "IV <= 0 or > 500% annual is invalid; no clamp or substitute",
            "decomposition": "Each single-factor change reprices from the original baseline; interactionPnl = total - spot-only - IV-only - time-only",
            "executionEnabled": False, "predictionModelPromoted": False,
            "limitations": LIMITATIONS,
        },
        "axes": AXES, "defaults": DEFAULTS, "symbols": symbols,
    })


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="Retained IBKR market-data.json evidence")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--rate", type=float, default=0.04, help="Assumed continuously compounded annual decimal rate")
    parser.add_argument("--dividend-yield", type=float, default=0.0, help="Assumed continuous annual decimal dividend yield")
    args = parser.parse_args()
    raw = json.loads(args.input.read_text(encoding="utf-8-sig"))
    artifact = build_artifact(raw, rate=args.rate, dividend_yield=args.dividend_yield)
    serialized = json.dumps(artifact, ensure_ascii=False, separators=(",", ":"), allow_nan=False)
    if len(serialized.encode("utf-8")) >= 5_000_000:
        raise ValueError("Artifact exceeds 5 MB UI budget")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(serialized, encoding="utf-8")
    print(json.dumps({"output": str(args.output), "symbols": len(artifact["symbols"]),
                      "bytes": len(serialized.encode("utf-8")), "inputSha256": artifact["inputSha256"]}))


if __name__ == "__main__":
    main()

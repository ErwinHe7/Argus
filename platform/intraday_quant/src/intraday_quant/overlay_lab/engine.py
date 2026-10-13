"""Offline options-overlay backtest on an existing long stock position. No orders.

A covered call, protective put or collar on a fixed share count is replayed
against buy-and-hold on XNYS-verified, unadjusted daily bars. Every decision
uses the session-close snapshot: a quote or IV mark counts on its session only
when observed in the final 30 minutes and available by the next session open.
Missing, stale, non-causal, split-affected or unverified inputs fail closed.
"""
from __future__ import annotations

import csv
import hashlib
import importlib.metadata
import io
import math
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from decimal import ROUND_CEILING, ROUND_FLOOR, ROUND_HALF_UP, Decimal
from pathlib import Path
from statistics import NormalDist
from typing import Any, Literal

from pydantic import field_validator, model_validator

from ..iv_lab import black_scholes
from ..strategy_lab import research
from ..strategy_lab.continuous import _read_bytes
from . import report

SOURCE_VERSION = "leo-overlay-source.v1"
CONFIG_VERSION = "leo-overlay-config.v1"
ARTIFACT_VERSION = report.ARTIFACT_VERSION
ENGINE_VERSION = "leo-overlay-engine.v1"
FILL_TIMING = "session_close_snapshot"
MODEL_LABEL = "MODEL_PRICED_NOT_EXECUTABLE"
SNAPSHOT_WINDOW = timedelta(minutes=30)
CONTRACT_MULTIPLIER = 100
MAX_QUOTE_BYTES = 256 * 1024 * 1024
QUOTE_COLUMNS = ("session_date", "observed_at", "available_at", "contract", "expiry", "strike", "right",
                 "bid", "ask", "multiplier", "delta", "source")
LEGS = {"covered_call": (("call", "short"),), "protective_put": (("put", "long"),),
        "collar": (("call", "short"), ("put", "long"))}


def _decimal(value: str, field_name: str, *, positive: bool = False) -> Decimal:
    parsed = Decimal(research.money(value))
    if parsed < 0 or (positive and parsed == 0):
        raise ValueError(f"{field_name}: {'positive' if positive else 'nonnegative'} decimal required")
    return parsed


def _finite(value: float, field_name: str, low: float, high: float, *, low_open: bool = False, high_open: bool = False) -> float:
    if not math.isfinite(value) or value < low or value > high or (low_open and value == low) or (high_open and value == high):
        raise ValueError(f"{field_name} outside supported range")
    return value


class CorporateActions(research.StrictModel):
    splits: list[dict[str, Any]]

    @model_validator(mode="after")
    def no_splits(self) -> "CorporateActions":
        if self.splits:
            raise ValueError("split in the source window; unadjusted option and share history fails closed")
        return self


class Dividend(research.StrictModel):
    ex_date: date
    amount: str
    available_at: datetime

    @field_validator("amount")
    @classmethod
    def positive_amount(cls, value: str) -> str:
        return format(_decimal(value, "dividend amount", positive=True), ".6f")

    @model_validator(mode="after")
    def aware(self) -> "Dividend":
        research.utc(self.available_at)
        return self


class QuoteFile(research.StrictModel):
    path: str
    sha256: str

    @model_validator(mode="after")
    def bound(self) -> "QuoteFile":
        if not self.path.strip() or len(self.sha256) != 64 or any(c not in "0123456789abcdef" for c in self.sha256.lower()):
            raise ValueError("option quote file path and sha256 required")
        return self


class IvMark(research.StrictModel):
    session_date: date
    observed_at: datetime
    available_at: datetime
    iv: float
    source: str

    @model_validator(mode="after")
    def valid(self) -> "IvMark":
        research.utc(self.observed_at)
        research.utc(self.available_at)
        _finite(self.iv, "iv", 0, 5, low_open=True)
        if not self.source.strip():
            raise ValueError("IV mark source required")
        return self


class OverlaySource(research.StrictModel):
    schema_version: Literal["leo-overlay-source.v1"]
    symbol: str
    evidence: research.Evidence
    bars: list[research.RawBar]
    code_revision: str
    corporate_actions: CorporateActions
    dividend_policy: Literal["included_verified", "excluded_price_only"]
    dividends: list[Dividend]
    option_quotes: QuoteFile | None
    iv_marks: list[IvMark] | None

    @model_validator(mode="after")
    def consistent(self) -> "OverlaySource":
        if not self.symbol.strip() or not self.code_revision.strip():
            raise ValueError("symbol and code revision required")
        if self.dividend_policy == "excluded_price_only" and self.dividends:
            raise ValueError("excluded_price_only cannot carry dividend records")
        if len({dividend.ex_date for dividend in self.dividends}) != len(self.dividends):
            raise ValueError("duplicate dividend ex-dates")
        return self


class StrikeRule(research.StrictModel):
    kind: Literal["otm_pct", "delta"]
    value: float

    @model_validator(mode="after")
    def bounded(self) -> "StrikeRule":
        if self.kind == "otm_pct":
            _finite(self.value, "otm_pct", 0, 0.5)
        else:
            _finite(self.value, "delta", 0, 1, low_open=True, high_open=True)
        return self


class ModelSettings(research.StrictModel):
    iv_source: Literal["iv_marks", "realized_vol"]
    realized_vol_window: int
    iv_premium_multiplier: float
    rate: float
    dividend_yield: float
    strike_increment: str
    half_spread_fraction: float
    max_iv_mark_age_sessions: int

    @model_validator(mode="after")
    def bounded(self) -> "ModelSettings":
        if not 5 <= self.realized_vol_window <= 252 or not 0 <= self.max_iv_mark_age_sessions <= 20:
            raise ValueError("realized-vol window or IV mark age outside supported range")
        _finite(self.iv_premium_multiplier, "iv_premium_multiplier", 0, 5, low_open=True)
        _finite(self.rate, "rate", -0.05, 0.25)
        _finite(self.dividend_yield, "dividend_yield", 0, 0.25)
        _finite(self.half_spread_fraction, "half_spread_fraction", 0, 0.5, high_open=True)
        self.strike_increment = format(_decimal(self.strike_increment, "strike_increment", positive=True), ".6f")
        return self


class Costs(research.StrictModel):
    commission_per_contract: str
    share_slippage_bps: float

    @model_validator(mode="after")
    def bounded(self) -> "Costs":
        self.commission_per_contract = format(_decimal(self.commission_per_contract, "commission_per_contract"), ".6f")
        _finite(self.share_slippage_bps, "share_slippage_bps", 0, 1000)
        return self


class OverlayConfig(research.StrictModel):
    schema_version: Literal["leo-overlay-config.v1"]
    structure: Literal["covered_call", "collar", "protective_put"]
    shares: int
    pricing_mode: Literal["EXECUTABLE_QUOTES", "MODEL_PRICED"]
    call_rule: StrikeRule | None = None
    put_rule: StrikeRule | None = None
    target_dte: int
    min_dte: int
    max_dte: int
    max_spread_fraction: float
    model: ModelSettings | None = None
    costs: Costs

    @model_validator(mode="after")
    def consistent(self) -> "OverlayConfig":
        if not 0 < self.shares <= 10_000_000 or self.shares % CONTRACT_MULTIPLIER:
            raise ValueError("shares must be a positive multiple of 100")
        rights = {right for right, _ in LEGS[self.structure]}
        if (self.call_rule is not None) != ("call" in rights) or (self.put_rule is not None) != ("put" in rights):
            raise ValueError("strike rules must match the structure's legs exactly")
        if not 1 <= self.min_dte <= self.target_dte <= self.max_dte <= 400:
            raise ValueError("require 1 <= min_dte <= target_dte <= max_dte <= 400")
        _finite(self.max_spread_fraction, "max_spread_fraction", 0, 2, low_open=True)
        if (self.model is not None) != (self.pricing_mode == "MODEL_PRICED"):
            raise ValueError("model settings are required for, and only for, MODEL_PRICED")
        return self


@dataclass(frozen=True)
class _Session:
    day: date
    open_at: datetime
    close_at: datetime
    next_open: datetime
    close: float
    available_at: datetime


@dataclass
class _Cycle:
    cycle_id: str
    open_index: int
    expiry: date
    legs: list[dict[str, Any]]
    nav_open: float
    baseline_open: float
    net_premium: float
    commissions: float
    cap_hit: bool = False
    ex_dividend_events: int = 0
    slippage: float = 0.0


def _quote_row(row: dict[str | None, Any]) -> dict[str, Any]:
    if None in row or any(value is None for value in row.values()):
        raise ValueError("ragged CSV row")
    if Decimal(row["multiplier"].strip()) != CONTRACT_MULTIPLIER:
        raise ValueError("non-100 contract multiplier; adjusted contracts fail closed")
    right = row["right"].strip()
    if right not in ("call", "put"):
        raise ValueError("right must be call or put")
    bid = _decimal(row["bid"].strip(), "bid")
    ask = _decimal(row["ask"].strip(), "ask", positive=True)
    if bid > ask:
        raise ValueError("crossed bid/ask; no repair")
    raw_delta = (row.get("delta") or "").strip()
    delta = None
    if raw_delta:
        delta = float(raw_delta)
        if not math.isfinite(delta) or not (0 <= delta <= 1 if right == "call" else -1 <= delta <= 0):
            raise ValueError("delta outside the right's range")
    contract, source = row["contract"].strip(), row["source"].strip()
    if not contract or not source:
        raise ValueError("contract and source required")
    return {"session_date": date.fromisoformat(row["session_date"].strip()), "observed_at": research.utc(row["observed_at"].strip()),
            "available_at": research.utc(row["available_at"].strip()), "contract": contract,
            "expiry": date.fromisoformat(row["expiry"].strip()), "strike": float(_decimal(row["strike"].strip(), "strike", positive=True)),
            "right": right, "bid": float(bid), "ask": float(ask), "delta": delta, "source": source}


def load_quotes(spec: QuoteFile, base_dir: Path | None) -> tuple[list[dict[str, Any]], str]:
    """Read the hash-bound quote CSV. Every row must be well formed; none is repaired."""
    path = Path(spec.path)
    if not path.is_absolute():
        if base_dir is None:
            raise ValueError("relative option quote path needs the source file directory")
        path = base_dir / path
    payload = _read_bytes(path, MAX_QUOTE_BYTES)
    actual = hashlib.sha256(payload).hexdigest()
    if actual != spec.sha256.lower():
        raise ValueError("option quote file sha256 mismatch")
    reader = csv.DictReader(io.StringIO(payload.decode("utf-8-sig"), newline=""))
    header = reader.fieldnames or []
    if len(set(header)) != len(header) or set(header) - set(QUOTE_COLUMNS) or set(QUOTE_COLUMNS) - {"delta"} - set(header):
        raise ValueError("option quote columns must be " + ", ".join(QUOTE_COLUMNS) + " (delta optional)")
    rows: list[dict[str, Any]] = []
    terms: dict[str, tuple[date, float, str]] = {}
    for number, raw in enumerate(reader, start=2):
        try:
            row = _quote_row(raw)
        except (ArithmeticError, AttributeError, KeyError, TypeError, ValueError) as error:
            raise ValueError(f"option quote row {number}: {error}") from error
        if terms.setdefault(row["contract"], (row["expiry"], row["strike"], row["right"])) != (row["expiry"], row["strike"], row["right"]):
            raise ValueError(f"option quote row {number}: contract identifier maps to different terms")
        rows.append(row)
    if not rows:
        raise ValueError("option quote file has no rows")
    return rows, actual


def _usable(row: dict[str, Any], session: _Session) -> bool:
    return (session.close_at - SNAPSHOT_WINDOW <= row["observed_at"] <= session.close_at
            and row["observed_at"] <= row["available_at"] <= session.next_open)


def _snapshots(rows: list[dict[str, Any]], sessions: list[_Session], key: str | None) -> tuple[dict[date, dict[str, dict[str, Any]]], dict[str, int]]:
    """Index causal close snapshots by session; keep the latest observation per contract."""
    by_day = {session.day: session for session in sessions}
    usable: dict[date, dict[str, dict[str, Any]]] = {}
    outside = rejected = 0
    for row in rows:
        session = by_day.get(row["session_date"])
        if session is None:
            outside += 1
            continue
        if not _usable(row, session):
            rejected += 1
            continue
        bucket = usable.setdefault(session.day, {})
        name = row[key] if key else "iv"
        current = bucket.get(name)
        if current is not None and current["observed_at"] == row["observed_at"]:
            raise ValueError(f"duplicate snapshot for {name} on {session.day}")
        if current is None or row["observed_at"] > current["observed_at"]:
            bucket[name] = row
    return usable, {"rows": len(rows), "usable_rows": len(rows) - outside - rejected,
                    "rejected_non_causal_rows": rejected, "outside_coverage_rows": outside}


def _round_strike(value: float, increment: Decimal, rounding: str = ROUND_HALF_UP) -> float:
    strike = (Decimal(repr(value)) / increment).to_integral_value(rounding) * increment
    if strike <= 0:
        raise ValueError("model strike rounds to zero")
    return float(strike)


def _iso(value: datetime) -> str:
    return value.isoformat()


class _Replay:
    def __init__(self, source: OverlaySource, config: OverlayConfig, sessions: list[_Session], calendar: Any,
                 quotes: dict[date, dict[str, dict[str, Any]]], marks: dict[date, dict[str, dict[str, Any]]]) -> None:
        self.source, self.config, self.sessions, self.calendar = source, config, sessions, calendar
        self.quotes, self.marks = quotes, marks
        self.shares = config.shares
        self.contracts = config.shares // CONTRACT_MULTIPLIER
        self.commission = float(config.costs.commission_per_contract)
        self.slippage = config.costs.share_slippage_bps / 10_000
        self.days = {session.day for session in sessions}
        self.model = config.model
        self.used_quote_sources: set[str] = set()
        self.used_iv_sources: set[str] = set()
        self.latest_input = max(session.available_at for session in sessions)

    # -- inputs ---------------------------------------------------------
    def sigma(self, index: int) -> tuple[float, dict[str, Any]]:
        model = self.model
        assert model is not None
        if model.iv_source == "realized_vol":
            window = model.realized_vol_window
            closes = [session.close for session in self.sessions[index - window:index + 1]]
            logs = [math.log(closes[i] / closes[i - 1]) for i in range(1, len(closes))]
            mean = math.fsum(logs) / len(logs)
            realized = math.sqrt(math.fsum((value - mean) ** 2 for value in logs) / (len(logs) - 1)) * math.sqrt(252)
            sigma = realized * model.iv_premium_multiplier
            if not 0 < sigma <= 5:
                raise ValueError(f"realized volatility unusable on {self.sessions[index].day}; no floor or substitute")
            label = f"trailing_realized_vol_{window}_sessions_x{model.iv_premium_multiplier:g}"
            self.used_iv_sources.add(label)
            return sigma, {"iv_source": label, "iv_through": self.sessions[index].day.isoformat()}
        for age in range(model.max_iv_mark_age_sessions + 1):
            if index - age < 0:
                break
            mark = self.marks.get(self.sessions[index - age].day, {}).get("iv")
            if mark is not None:
                self.used_iv_sources.add(mark["source"])
                self.latest_input = max(self.latest_input, mark["available_at"])
                return mark["iv"], {"iv_source": mark["source"], "iv_session": mark["session_date"].isoformat(),
                                    "iv_observed_at": _iso(mark["observed_at"]), "iv_available_at": _iso(mark["available_at"]),
                                    "iv_age_sessions": age}
        raise ValueError(f"stale or missing point-in-time IV mark on {self.sessions[index].day}; "
                         f"maximum age {model.max_iv_mark_age_sessions} sessions")

    def _model_value(self, spot: float, leg: dict[str, Any], day: date, sigma: float) -> float:
        assert self.model is not None
        days = (leg["expiry"] - day).days
        return float(black_scholes(spot, leg["strike"], days, sigma, leg["right"], self.model.rate,  # type: ignore[arg-type]
                                   self.model.dividend_yield)["premium"])

    def _valid_expiry(self, expiry: date) -> bool:
        if expiry <= self.sessions[-1].day:
            return expiry in self.days
        return bool(self.calendar.is_session(expiry))

    # -- roll selection -------------------------------------------------
    def _rule(self, right: str) -> Any:
        return self.config.call_rule if right == "call" else self.config.put_rule

    def _pick_quote(self, rows: list[dict[str, Any]], right: str, spot: float) -> dict[str, Any] | None:
        rule = self._rule(right)
        if rule.kind == "delta":
            rows = [row for row in rows if row["delta"] is not None]
            distance = lambda row: abs(abs(row["delta"]) - rule.value)  # noqa: E731
        else:
            target = spot * (1 + rule.value if right == "call" else 1 - rule.value)
            distance = lambda row: abs(row["strike"] - target)  # noqa: E731
        if not rows:
            return None
        # Ties go further out of the money, then to the contract identifier.
        return min(rows, key=lambda row: (distance(row), -row["strike"] if right == "call" else row["strike"], row["contract"]))

    def _select_quotes(self, index: int) -> list[dict[str, Any]] | None:
        session = self.sessions[index]
        config = self.config
        snapshot = self.quotes.get(session.day, {})
        candidates: dict[str, dict[date, list[dict[str, Any]]]] = {}
        for right, _side in LEGS[config.structure]:
            by_expiry: dict[date, list[dict[str, Any]]] = {}
            for row in snapshot.values():
                dte = (row["expiry"] - session.day).days
                mid = (row["bid"] + row["ask"]) / 2
                if (row["right"] == right and config.min_dte <= dte <= config.max_dte and row["bid"] > 0
                        and (row["ask"] - row["bid"]) / mid <= config.max_spread_fraction and self._valid_expiry(row["expiry"])):
                    by_expiry.setdefault(row["expiry"], []).append(row)
            candidates[right] = by_expiry
        shared = set.intersection(*(set(by_expiry) for by_expiry in candidates.values()))
        for expiry in sorted(shared, key=lambda day: (abs((day - session.day).days - config.target_dte), day)):
            picks = {right: self._pick_quote(candidates[right][expiry], right, session.close) for right in candidates}
            if any(pick is None for pick in picks.values()):
                continue
            if "call" in picks and "put" in picks and picks["call"]["strike"] < picks["put"]["strike"]:  # type: ignore[index]
                continue
            legs = []
            for right, side in LEGS[config.structure]:
                row = picks[right]
                assert row is not None
                self.used_quote_sources.add(row["source"])
                self.latest_input = max(self.latest_input, row["available_at"])
                fill_side = "bid" if side == "short" else "ask"
                legs.append({"right": right, "side": side, "contract": row["contract"], "strike": row["strike"],
                             "expiry": row["expiry"], "dte": (row["expiry"] - session.day).days, "fill_side": fill_side,
                             "fill_price": row[fill_side], "delta_at_open": row["delta"],
                             "strike_moneyness": row["strike"] / session.close - 1,
                             "provenance": {"quote_session": row["session_date"].isoformat(), "observed_at": _iso(row["observed_at"]),
                                            "available_at": _iso(row["available_at"]), "source": row["source"]}})
            return legs
        return None

    def _model_strike(self, right: str, spot: float, days: int, sigma: float) -> float:
        model = self.model
        assert model is not None
        rule = self._rule(right)
        increment = Decimal(model.strike_increment)
        if rule.kind == "otm_pct":
            return _round_strike(spot * (1 + rule.value if right == "call" else 1 - rule.value), increment)
        time = days / 365
        scaled = rule.value * math.exp(model.dividend_yield * time)
        probability = scaled if right == "call" else 1 - scaled
        if not 0 < probability < 1:
            raise ValueError("target delta unreachable under the model dividend yield")
        d1 = NormalDist().inv_cdf(probability)
        raw = spot * math.exp(-(d1 * sigma * math.sqrt(time) - (model.rate - model.dividend_yield + 0.5 * sigma * sigma) * time))
        options = {_round_strike(raw, increment, ROUND_FLOOR), _round_strike(raw, increment, ROUND_CEILING)}

        def distance(strike: float) -> tuple[float, float]:
            delta = black_scholes(spot, strike, days, sigma, right, model.rate, model.dividend_yield)["delta"]
            return abs(abs(delta) - rule.value), -strike if right == "call" else strike  # type: ignore[arg-type]
        return min(options, key=distance)

    def _select_model(self, index: int) -> list[dict[str, Any]] | None:
        session = self.sessions[index]
        config = self.config
        model = self.model
        assert model is not None
        target = session.day + timedelta(days=config.target_dte)
        expiry = self.calendar.date_to_session(target, direction="previous").date()
        dte = (expiry - session.day).days
        if not config.min_dte <= dte <= config.max_dte:
            return None
        sigma, provenance = self.sigma(index)
        legs = []
        for right, side in LEGS[config.structure]:
            strike = self._model_strike(right, session.close, dte, sigma)
            leg = {"right": right, "side": side, "contract": f"model:{right}:{expiry.isoformat()}:{strike:g}", "strike": strike,
                   "expiry": expiry, "dte": dte, "fill_side": "model"}
            value = self._model_value(session.close, leg, session.day, sigma)
            spread = model.half_spread_fraction
            delta = black_scholes(session.close, strike, dte, sigma, right, model.rate, model.dividend_yield)["delta"]
            legs.append({**leg, "fill_price": value * (1 - spread if side == "short" else 1 + spread), "delta_at_open": delta,
                         "strike_moneyness": strike / session.close - 1,
                         "provenance": {"pricing": "black_scholes_european", "label": MODEL_LABEL, "sigma": sigma,
                                        "model_value": value, **provenance}})
        if len(legs) == 2 and legs[0]["strike"] < legs[1]["strike"]:
            return None
        return legs

    # -- marks and settlement -------------------------------------------
    def mark(self, legs: list[dict[str, Any]], index: int) -> float:
        """Conservative liquidation value of open legs per share: shorts at ask, longs at bid."""
        session = self.sessions[index]
        total = 0.0
        if self.config.pricing_mode == "EXECUTABLE_QUOTES":
            snapshot = self.quotes.get(session.day, {})
            for leg in legs:
                row = snapshot.get(leg["contract"])
                if row is None:
                    raise ValueError(f"missing executable quote for held contract on {session.day}; no stale or model mark")
                self.latest_input = max(self.latest_input, row["available_at"])
                total += -row["ask"] if leg["side"] == "short" else row["bid"]
            return total
        assert self.model is not None
        sigma, _ = self.sigma(index)
        spread = self.model.half_spread_fraction
        for leg in legs:
            value = self._model_value(session.close, leg, session.day, sigma)
            total += -value * (1 + spread) if leg["side"] == "short" else value * (1 - spread)
        return total

    def run(self, start: int) -> dict[str, Any]:
        sessions, shares = self.sessions, self.shares
        dividends = {dividend.ex_date: dividend for dividend in self.source.dividends} if self.source.dividend_policy == "included_verified" else {}
        base = shares * sessions[start].close
        cash = baseline_cash = 0.0
        cycle: _Cycle | None = None
        cycles: list[dict[str, Any]] = []
        daily: list[dict[str, Any]] = []
        counts = {"cycles": 0, "assignments": 0, "cap_hits": 0, "put_exercises": 0, "deferred_rolls": 0,
                  "ex_dividend_itm_short_call_events": 0, "dividends_credited": 0}
        commissions = slippage = 0.0
        premium_yield = 0.0
        previous_overlay = previous_baseline = base
        for index in range(start, len(sessions)):
            session = sessions[index]
            spot = session.close
            held_cycle = cycle
            if index > start and session.day in dividends:
                dividend = dividends[session.day]
                cash += shares * float(dividend.amount)
                baseline_cash += shares * float(dividend.amount)
                counts["dividends_credited"] += 1
                self.latest_input = max(self.latest_input, research.utc(dividend.available_at))
                if cycle is not None:
                    prior = sessions[index - 1].close
                    if any(leg["right"] == "call" and leg["side"] == "short" and prior > leg["strike"] for leg in cycle.legs):
                        cycle.ex_dividend_events += 1
                        counts["ex_dividend_itm_short_call_events"] += 1
            if cycle is not None and index > cycle.open_index:
                if any(leg["right"] == "call" and leg["side"] == "short" and spot > leg["strike"] for leg in cycle.legs):
                    cycle.cap_hit = True
            if cycle is not None and cycle.expiry == session.day:
                outcome = "expired_worthless"
                for leg in cycle.legs:
                    exercised = spot > leg["strike"] if leg["right"] == "call" else spot < leg["strike"]
                    if not exercised:
                        continue
                    if leg["side"] == "short":
                        outcome = "call_assigned"
                        counts["assignments"] += 1
                    else:
                        outcome = "put_exercised"
                        counts["put_exercises"] += 1
                    # Physical delivery at the strike, then repurchase at the close so the share count is constant.
                    repurchase_slippage = shares * spot * self.slippage
                    fee = self.contracts * self.commission
                    cash += shares * leg["strike"] - shares * spot - repurchase_slippage - fee
                    cycle.commissions += fee
                    cycle.slippage += repurchase_slippage
                    commissions += fee
                    slippage += repurchase_slippage
                cycles.append(self._close(cycle, outcome, session, shares * spot + cash, shares * spot + baseline_cash))
                counts["cap_hits"] += int(cycle.cap_hit)
                cycle = None
            if cycle is None:
                legs = self._select_quotes(index) if self.config.pricing_mode == "EXECUTABLE_QUOTES" else self._select_model(index)
                if legs is None:
                    counts["deferred_rolls"] += 1
                else:
                    counts["cycles"] += 1
                    nav_open = shares * spot + cash
                    fee = self.contracts * self.commission * len(legs)
                    net_premium = sum(leg["fill_price"] if leg["side"] == "short" else -leg["fill_price"] for leg in legs)
                    cash += shares * net_premium - fee
                    commissions += fee
                    premium_yield += net_premium / spot
                    cycle = _Cycle(f"cycle-{counts['cycles']:03d}", index, legs[0]["expiry"], legs, nav_open,
                                   shares * spot + baseline_cash, net_premium, fee)
            overlay_nav = shares * spot + cash + (shares * self.mark(cycle.legs, index) if cycle is not None else 0.0)
            baseline_nav = shares * spot + baseline_cash
            if overlay_nav <= 0:
                raise ValueError("overlay account value non-positive; replay fails closed")
            overlay_return = overlay_nav / previous_overlay - 1
            baseline_return = baseline_nav / previous_baseline - 1
            responsible = held_cycle or (cycle if cycle is not None and cycle.open_index == index else None)
            cluster = sessions[responsible.open_index].day if responsible is not None else session.day
            daily.append({"session_date": session.day.isoformat(), "overlay_nav_index": overlay_nav / base,
                          "baseline_nav_index": baseline_nav / base, "overlay_return": overlay_return,
                          "baseline_return": baseline_return, "active_return": overlay_return - baseline_return,
                          "cluster_date": cluster.isoformat(), "cycle_id": cycle.cycle_id if cycle is not None else None})
            previous_overlay, previous_baseline = overlay_nav, baseline_nav
        if cycle is not None:
            counts["cap_hits"] += int(cycle.cap_hit)
            cycles.append(self._close(cycle, "open_at_end", None, previous_overlay, previous_baseline))
        return {"daily": daily, "cycles": cycles, "counts": counts, "commissions": commissions, "slippage": slippage,
                "premium_yield_sum": premium_yield, "base": base}

    def _close(self, cycle: _Cycle, outcome: str, session: _Session | None, overlay_nav: float, baseline_nav: float) -> dict[str, Any]:
        opened = self.sessions[cycle.open_index]
        return {"cycle_id": cycle.cycle_id, "opened": opened.day.isoformat(), "expiry": cycle.expiry.isoformat(),
                "closed": session.day.isoformat() if session is not None else None, "outcome": outcome,
                "shares": self.shares, "contracts": self.contracts, "open_close": opened.close,
                "settlement_close": session.close if session is not None else None,
                "net_premium_per_share": cycle.net_premium, "commissions": cycle.commissions,
                "repurchase_slippage": cycle.slippage, "overlay_return": overlay_nav / cycle.nav_open - 1,
                "baseline_return": baseline_nav / cycle.baseline_open - 1, "cap_hit": cycle.cap_hit,
                "ex_dividend_itm_short_call_events": cycle.ex_dividend_events,
                "legs": [{**leg, "expiry": leg["expiry"].isoformat()} for leg in cycle.legs]}


def _calendar(first: date, last: date, max_dte: int) -> Any:
    import exchange_calendars as calendars

    return calendars.get_calendar("XNYS", start=str(first), end=str(last + timedelta(days=max_dte + 14)))


def _sessions(verified: list[dict[str, Any]], calendar: Any) -> list[_Session]:
    sessions = []
    for index, bar in enumerate(verified):
        day = date.fromisoformat(bar["session_date"])
        if index + 1 < len(verified):
            next_open = research.utc(verified[index + 1]["open_at"])
        else:
            next_open = research.utc(calendar.session_open(calendar.next_session(day)).to_pydatetime())
        sessions.append(_Session(day, research.utc(bar["open_at"]), research.utc(bar["close_at"]), next_open,
                                 float(bar["close"]), research.utc(bar["available_at"])))
    return sessions


def _evidence_status(config: OverlayConfig, source: OverlaySource) -> str:
    if config.pricing_mode == "MODEL_PRICED":
        return MODEL_LABEL
    if source.evidence.classification != "observed":
        return "SYNTHETIC_FIXTURE_NOT_MARKET_EVIDENCE"
    return "EXECUTABLE_QUOTES_OBSERVED"


def run_overlay(source_raw: dict[str, Any], config_raw: dict[str, Any], *, base_dir: Path | None = None,
                seed: int = 7, resamples: int = 2000) -> dict[str, Any]:
    """Replay one overlay against buy-and-hold and return a ``leo-overlay-lab.v1`` artifact."""
    source = OverlaySource.model_validate(source_raw)
    config = OverlayConfig.model_validate(config_raw)
    if config.pricing_mode == "EXECUTABLE_QUOTES" and source.option_quotes is None:
        raise ValueError("EXECUTABLE_QUOTES requires a hash-bound option quote file")
    if config.model is not None and config.model.iv_source == "iv_marks" and not source.iv_marks:
        raise ValueError("iv_marks pricing requires point-in-time IV marks")
    verified, calendar_source = research.verified_xnys_bars(source.bars)
    first, last = date.fromisoformat(verified[0]["session_date"]), date.fromisoformat(verified[-1]["session_date"])
    calendar = _calendar(first, last, config.max_dte)
    sessions = _sessions(verified, calendar)
    days = {session.day for session in sessions}
    by_day = {session.day: session for session in sessions}
    for dividend in source.dividends:
        if first <= dividend.ex_date <= last:
            if dividend.ex_date not in days:
                raise ValueError("dividend ex-date is not a covered XNYS session")
            if research.utc(dividend.available_at) > by_day[dividend.ex_date].open_at:
                raise ValueError("dividend not known before its ex-date open")
    quote_rows: list[dict[str, Any]] = []
    quote_sha = None
    if source.option_quotes is not None:
        quote_rows, quote_sha = load_quotes(source.option_quotes, base_dir)
    quotes, quote_counts = _snapshots(quote_rows, sessions, "contract")
    mark_rows = [mark.model_dump() for mark in source.iv_marks or []]
    for mark in mark_rows:
        mark.update(observed_at=research.utc(mark["observed_at"]), available_at=research.utc(mark["available_at"]))
    marks, mark_counts = _snapshots(mark_rows, sessions, None)
    start = config.model.realized_vol_window if config.model is not None and config.model.iv_source == "realized_vol" else 0
    if len(sessions) - start < 3:
        raise ValueError("fewer than three evaluable sessions after warm-up")
    replay = _Replay(source, config, sessions, calendar, quotes, marks)
    result = replay.run(start)
    daily = result["daily"]
    metrics = report.slice_metrics(daily, daily[0]["session_date"], daily[-1]["session_date"], seed=seed, resamples=resamples)
    overlay = metrics["overlay"]
    overlay["premium_yield_annualized"] = (result["premium_yield_sum"] * report.SESSIONS_PER_YEAR / len(daily)
                                           if result["counts"]["cycles"] else None)
    total_costs = result["commissions"] + result["slippage"]
    metrics.update(counts=result["counts"], total_costs=total_costs, total_commissions=result["commissions"],
                   total_repurchase_slippage=result["slippage"], total_costs_fraction_of_initial_nav=total_costs / result["base"])
    status = _evidence_status(config, source)
    evidence = source.evidence.model_dump(mode="json")
    evidence.update(calendar_source=calendar_source, coverage_verified=True)
    evaluated = sessions[start:]
    caveats = [
        "Historical backtest, not live. No orders, options execution or promotion are authorized.",
        "Early exercise and early assignment are not modelled; ex-dividend in-the-money short calls are only counted as a risk flag.",
        "Cash earns and pays zero interest; margin, borrow, taxes and financing are excluded.",
        "Expiry settles physically at the official close with immediate share repurchase at that close plus slippage; pin risk and after-hours moves are not modelled.",
        "Bootstrap interval and sign-flip p-value are descriptive diagnostics, not promotion evidence.",
    ]
    if config.pricing_mode == "MODEL_PRICED":
        caveats.insert(0, f"{MODEL_LABEL}: European Black-Scholes values with an assumed half spread, not observed executable quotes.")
    if source.evidence.classification != "observed":
        caveats.insert(0, "SYNTHETIC_FIXTURE_NOT_MARKET_EVIDENCE: inputs are a synthetic fixture, not market performance.")
    if source.dividend_policy == "excluded_price_only":
        caveats.append("Dividends excluded: a price-only comparison omits income for both sides and ex-dividend assignment risk.")
    assumptions = [
        "Decisions use the session-close snapshot; quotes and IV marks must be observed within 30 minutes before the close and available by the next session open.",
        "Executable quotes sell at the bid and buy at the ask; model prices are Black-Scholes value minus or plus the half spread.",
        "Daily marks are conservative: short legs at the ask (or model value plus half spread), long legs at the bid (or minus).",
        "Expiry is the eligible date nearest the target calendar-day DTE; strikes are nearest the rule, ties further out of the money.",
        "Assignment and exercise are physical at the expiry close; shares are repurchased so the share count stays constant.",
        "Dividends are credited equally to the overlay and buy-and-hold on the ex-date when the policy includes verified dividends.",
        "Commissions apply per contract at opening and at assignment or exercise; repurchased shares pay the configured slippage.",
        report.RETURN_CONVENTION,
    ]
    return {
        "schema_version": ARTIFACT_VERSION, "engine_version": ENGINE_VERSION, "symbol": source.symbol,
        "structure": config.structure, "pricing_mode": config.pricing_mode, "evidence_status": status,
        "fill_timing": FILL_TIMING,
        "source": {"name": source.evidence.source, "license_scope": source.evidence.license_scope, "evidence": evidence,
                   "dividend_policy": source.dividend_policy, "corporate_actions": {"splits": []},
                   "option_quotes": None if source.option_quotes is None else {"file_name": Path(source.option_quotes.path).name, "sha256": quote_sha},
                   "quote_sources": sorted(replay.used_quote_sources), "iv_sources": sorted(replay.used_iv_sources)},
        "observation_cutoff": _iso(evaluated[-1].close_at), "availability_cutoff": _iso(replay.latest_input),
        "freshness": "historical_backtest_not_live",
        "coverage": {"sessions": len(daily), "start": daily[0]["session_date"], "end": daily[-1]["session_date"],
                     "calendar_source": calendar_source, "cycles": result["counts"]["cycles"],
                     "deferred_rolls": result["counts"]["deferred_rolls"], "source_sessions": len(sessions), "warmup_sessions": start,
                     "option_quotes": quote_counts, "iv_marks": mark_counts},
        "input_sha256": research.digest(source_raw), "config_sha256": research.digest(config_raw),
        "code_identity": {"code_revision": source.code_revision, "engine_version": ENGINE_VERSION,
                          "module": "intraday_quant.overlay_lab.engine",
                          "dependency_versions": {name: importlib.metadata.version(name) for name in ("pydantic", "exchange-calendars", "numpy", "pandas")}},
        "config": config.model_dump(mode="json"),
        "inference_settings": {"seed": seed, "resamples": resamples, "bootstrap_block_length": report.BOOTSTRAP_BLOCK_LENGTH,
                               "sign_flip_cluster": "roll_cycle_start", "sign_flip_minimum_clusters": report.SIGN_FLIP_MIN_CLUSTERS},
        "metrics": metrics, "cycles": result["cycles"], "daily": daily,
        "assumptions": assumptions, "caveats": caveats,
        "execution_authorized": False, "options_execution_enabled": False, "promotion_eligible": False,
    }

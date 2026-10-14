"""No network, broker, fabricated prices, or Python copy of strategy execution."""
from __future__ import annotations

import hashlib
import importlib.metadata
import json
import math
import random
import subprocess
from datetime import date, datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, field_validator, model_validator

VERSION = "leo-strategy-research.v1"


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


def money(value: Any) -> str:
    if not isinstance(value, str):
        raise ValueError("monetary source values must be decimal strings")
    try:
        parsed = Decimal(value)
    except InvalidOperation as error:
        raise ValueError("invalid decimal") from error
    if not parsed.is_finite() or parsed != parsed.quantize(Decimal("0.000001")):
        raise ValueError("finite monetary values with at most six decimal places required")
    return format(parsed, ".6f")


def utc(value: str | datetime) -> datetime:
    parsed = value if isinstance(value, datetime) else datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("timestamp needs a timezone")
    return parsed.astimezone(timezone.utc)


def digest(value: Any) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()


class Evidence(StrictModel):
    source: str
    dataset_sha256: str
    calendar_source: str
    adjustment_verified: bool
    coverage_verified: bool
    availability_verified: bool
    classification: Literal["observed", "synthetic_fixture"]
    license_scope: str

    @model_validator(mode="after")
    def provenance(self) -> "Evidence":
        if not self.source.strip() or not self.license_scope.strip():
            raise ValueError("source and use rights required")
        if len(self.dataset_sha256) != 64 or any(c not in "0123456789abcdefABCDEF" for c in self.dataset_sha256):
            raise ValueError("source dataset hash required")
        if not self.adjustment_verified or not self.availability_verified:
            raise ValueError("unverified split adjustments or historical availability")
        return self


class RawBar(StrictModel):
    session_date: date
    available_at: datetime
    open: str
    high: str
    low: str
    close: str
    volume: int

    @field_validator("open", "high", "low", "close")
    @classmethod
    def prices(cls, value: str) -> str:
        return money(value)

    @model_validator(mode="after")
    def ranges(self) -> "RawBar":
        if self.volume < 0 or not Decimal("0") < Decimal(self.low) <= Decimal(self.open) <= Decimal(self.high) or not Decimal(self.low) <= Decimal(self.close) <= Decimal(self.high):
            raise ValueError("invalid OHLCV; no repair or filling")
        utc(self.available_at)
        return self


class RawDataset(StrictModel):
    schema_version: Literal["leo-strategy-source.v1"]
    symbol: str
    strategy: Literal["MR-v1", "MOM-v1"]
    bars: list[RawBar]
    evidence: Evidence
    code_revision: str
    starting_capital: str = "10000"
    commission_per_order: str = "1"
    slippage_bps: int = 10


def verified_xnys_bars(bars: list[RawBar]) -> tuple[list[dict[str, Any]], str]:
    """Verify observed sessions against XNYS. Never infer historical availability."""
    import exchange_calendars as calendars

    if not bars or len(bars) > 20_000:
        raise ValueError("empty or oversized source history")
    dates = [bar.session_date for bar in bars]
    if dates != sorted(set(dates)):
        raise ValueError("duplicate or unordered source dates")
    calendar = calendars.get_calendar("XNYS", start=str(dates[0]), end=str(dates[-1]))
    schedule = calendar.schedule.loc[str(dates[0]):str(dates[-1])]
    expected = [timestamp.date() for timestamp in schedule.index]
    if dates != expected:
        raise ValueError("official XNYS session coverage incomplete; do not bridge missing sessions")
    verified = []
    for bar, (_, session) in zip(bars, schedule.iterrows(), strict=True):
        closed = session["close"].to_pydatetime()
        if utc(bar.available_at) < utc(closed):
            raise ValueError("daily bar allegedly available before its session close")
        verified.append({**bar.model_dump(mode="json"), "open_at": session["open"].isoformat(), "close_at": session["close"].isoformat()})
    return verified, f"exchange_calendars/{importlib.metadata.version('exchange-calendars')}/XNYS"


def prepare(raw: dict[str, Any]) -> dict[str, Any]:
    """Verify observed sessions against XNYS. Never infer historical availability."""
    source = RawDataset.model_validate(raw)
    bars, calendar_source = verified_xnys_bars(source.bars)
    evidence = source.evidence.model_dump(mode="json")
    evidence.update(calendar_source=calendar_source, coverage_verified=True)
    if not source.code_revision.strip() or not 0 <= source.slippage_bps <= 1000:
        raise ValueError("code revision and bounded costs required")
    return {
        "symbol": source.symbol, "strategy": source.strategy, "bars": bars, "evidence": evidence,
        "starting_capital": money(source.starting_capital), "commission_per_order": money(source.commission_per_order),
        "slippage_bps": source.slippage_bps, "cash_flows": [], "code_revision": source.code_revision,
        "dependency_versions": {name: importlib.metadata.version(name) for name in ("pydantic", "exchange-calendars")},
    }


class Registration(StrictModel):
    schema_version: Literal["leo-strategy-registration.v1"]
    experiment_id: str
    strategy: Literal["MR-v1", "MOM-v1"]
    symbol: str
    frozen_at: datetime
    development_end: date
    holdout_start: date
    holdout_end: date
    minimum_sessions: int
    minimum_net_return: float
    maximum_drawdown: float
    trial_count: int
    prior_history_inspected: bool

    @model_validator(mode="after")
    def chronological(self) -> "Registration":
        if not self.development_end < self.holdout_start <= self.holdout_end:
            raise ValueError("development and holdout must be disjoint chronological intervals")
        if utc(self.frozen_at).date() >= self.holdout_start:
            raise ValueError("registration must precede the future holdout")
        if self.minimum_sessions < 1 or self.trial_count < 1 or not 0 < self.maximum_drawdown <= 1:
            raise ValueError("invalid preregistered evidence criteria")
        if not math.isfinite(self.minimum_net_return):
            raise ValueError("invalid return objective")
        return self


def run_engine(engine: Path, request: dict[str, Any]) -> dict[str, Any]:
    result = subprocess.run([str(engine.resolve())], input=json.dumps({"operation": "replay", **request}, allow_nan=False),
                            text=True, capture_output=True, timeout=180, check=False)
    response = json.loads(result.stdout)
    if result.returncode or "error" in response:
        raise ValueError(f"Rust replay rejected input: {response.get('error', 'unknown failure')}")
    if response.get("schema_version") != "leo-strategy-lab.v1" or response.get("execution_authorized") is not False or response.get("promotion_eligible") is not False:
        raise ValueError("unexpected engine contract or execution authority")
    return response


def _compound(returns: list[float]) -> float:
    result = 1.0
    for value in returns:
        if not math.isfinite(value) or value <= -1:
            raise ValueError("invalid net account return")
        result *= 1 + value
    return result - 1


def _quantile(values: list[float], percentile: float) -> float:
    values = sorted(values)
    position = (len(values) - 1) * percentile
    left = int(position)
    return values[left] + (values[min(left + 1, len(values) - 1)] - values[left]) * (position - left)


def block_interval(returns: list[float], *, seed: int = 7, resamples: int = 2000, block_length: int = 5) -> dict[str, Any]:
    if resamples < 100 or block_length < 1:
        raise ValueError("invalid bootstrap settings")
    if len(returns) < max(20, 2 * block_length):
        return {"status": "insufficient_sessions", "session_count": len(returns), "minimum_diagnostic_sessions": max(20, 2 * block_length)}
    rng = random.Random(seed)
    samples = []
    for _ in range(resamples):
        sampled: list[float] = []
        while len(sampled) < len(returns):
            start = rng.randrange(len(returns) - block_length + 1)
            sampled.extend(returns[start:start + block_length])
        samples.append(_compound(sampled[:len(returns)]))
    return {"status": "descriptive_block_bootstrap_not_promotion", "session_count": len(returns), "seed": seed,
            "resamples": resamples, "block_length": block_length, "lower_95": _quantile(samples, .025), "upper_95": _quantile(samples, .975),
            "caveat": "Fixed-length moving blocks preserve short dependence, not every regime or all long-horizon trade dependence. The session threshold is diagnostic, not proof of an edge."}


def evaluate_result(result: dict[str, Any], registration: dict[str, Any] | None = None,
                    *, seed: int = 7, resamples: int = 2000, block_length: int = 5) -> dict[str, Any]:
    if result.get("schema_version") != "leo-strategy-lab.v1" or result.get("promotion_eligible") is not False:
        raise ValueError("invalid research artifact contract")
    if result["input_manifest"]["evidence"]["classification"] != "observed":
        raise ValueError("synthetic fixtures cannot enter performance reports")
    points = result["equity"][220:]
    returns = [float(point["net_return"]) for point in points]
    annual_vol = None
    if len(returns) > 1:
        average = sum(returns) / len(returns)
        annual_vol = math.sqrt(sum((r - average) ** 2 for r in returns) / (len(returns) - 1)) * math.sqrt(252)
    holdout: dict[str, Any] = {"status": "no_preregistration", "promotable": False}
    if registration is not None:
        frozen = Registration.model_validate(registration)
        if frozen.strategy != result["strategy"] or frozen.symbol != result["symbol"]:
            raise ValueError("registration does not bind this strategy and symbol")
        selected = [point for point in points if frozen.holdout_start <= date.fromisoformat(point["session_date"]) <= frozen.holdout_end]
        # A position opened before the holdout contaminates its initial exposure.
        overlap = any(date.fromisoformat(trade["entry_session"]) < frozen.holdout_start <= date.fromisoformat(trade["exit_session"]) for trade in result["trades"])
        if result.get("open_position") and date.fromisoformat(result["open_position"]["entry_session"]) < frozen.holdout_start:
            overlap = True
        selected_return = _compound([float(p["net_return"]) for p in selected])
        nav = peak = 1.0
        drawdown = 0.0
        for point in selected:
            nav *= 1 + float(point["net_return"])
            peak = max(peak, nav)
            drawdown = min(drawdown, nav / peak - 1)
        complete = bool(selected) and date.fromisoformat(selected[-1]["session_date"]) >= frozen.holdout_end
        enough = len(selected) >= frozen.minimum_sessions
        criteria = enough and complete and not overlap and selected_return >= frozen.minimum_net_return and drawdown >= -frozen.maximum_drawdown
        holdout = {"status": "descriptive_objectives_met" if criteria else "objectives_not_met_or_incomplete", "promotable": False,
                   "registration_sha256": digest(registration), "registration": frozen.model_dump(mode="json"), "session_count": len(selected),
                   "net_return": selected_return, "max_drawdown": drawdown, "cross_boundary_position": overlap,
                   "future_window_complete": complete, "objective_checks_passed": criteria,
                   "caveat": "A signed-off registration and separate custody/inspection audit are required; this file cannot prove the interval was unseen. No automatic promotion."}
    manifest = result["input_manifest"]
    last_bar = manifest["bars"][-1]
    return {"schema_version": VERSION, "run_id": result["run_id"], "artifact_sha256": digest(result),
            "strategy": result["strategy"], "symbol": result["symbol"], "evidence_status": "EXPLORATORY_NOT_PROMOTED",
            "source_evidence": manifest["evidence"], "observation_cutoff": last_bar["close_at"],
            "research_variant": bool(manifest.get("research_parameters")), "research_parameters": manifest.get("research_parameters"),
            "availability_cutoff": last_bar["available_at"], "code_revision": manifest["code_revision"],
            "cost_assumptions": {"commission_per_order": manifest["commission_per_order"], "slippage_bps": manifest["slippage_bps"]},
            "execution_authorized": False, "promotion_eligible": False,
            "metrics": {**result["metrics"], "annualized_account_volatility": annual_vol},
            "benchmarks": price_only_benchmarks(manifest),
            "uncertainty": block_interval(returns, seed=seed, resamples=resamples, block_length=block_length),
            "holdout": holdout, "fill_model": result["fill_model"], "quote_window_experiment_available": False,
            "limitations": result["caveats"] + ["No statistical multiple-testing correction is inferred from a missing experiment registry. Trial counts must include discarded and failed experiments."]}


def price_only_benchmarks(manifest: dict[str, Any]) -> dict[str, Any]:
    bars = manifest["bars"][220:]
    if not bars or manifest.get("cash_flows"):
        return {"status": "unavailable", "reason": "No post-warmup observations, or external cash flows require matched benchmark cash-flow boundaries."}
    capital = Decimal(manifest["starting_capital"])
    fees = Decimal(manifest["commission_per_order"]) * 2
    slip = Decimal(manifest["slippage_bps"]) / 10000
    entry = Decimal(bars[0]["open"]) * (1 + slip)
    exit_price = Decimal(bars[-1]["close"]) * (1 - slip)
    rows = []
    for allocation in (Decimal(".05"), Decimal("1")):
        quantity = max(0, int(min(capital * allocation, capital - fees) / entry))
        net_pnl = (exit_price - entry) * quantity - (fees if quantity else 0)
        rows.append({"name": f"buy_hold_{allocation * 100:g}_percent_initial_notional", "quantity": quantity,
                     "net_price_return_on_account": float(net_pnl / capital), "idle_cash_included": True})
    return {"status": "descriptive_price_only", "cash_zero_yield_return": 0.0, "buy_and_hold": rows,
            "caveat": "Fixed initial notional benchmarks with a final liquidation assumption. No dividends, tax, interest or identical stop risk; 5% notional is not proof of matched risk."}


def sensitivity_requests(request: dict[str, Any]) -> list[tuple[str, dict[str, Any]]]:
    """The single predeclared cost/parameter grid, shared by offline runners."""
    if request.get("research_parameters"):
        raise ValueError("sensitivity must start from the fixed baseline")
    experiments: list[tuple[str, dict[str, Any]]] = []
    for multiplier in (1, 2, 3):
        experiments.append((f"cost_x{multiplier}", {**request, "commission_per_order": money(str(Decimal(request["commission_per_order"]) * multiplier)),
                            "slippage_bps": request["slippage_bps"] * multiplier}))
    neighbors = ({"mr_z_abs": value} for value in (1.8, 2.2)) if request["strategy"] == "MR-v1" else ({"momentum_lookback": value} for value in (50, 60))
    parameters = list(neighbors)
    if request["strategy"] == "MR-v1":
        parameters += [{"mr_rsi_max": value} for value in (28, 32)] + [{"stop_multiple": value} for value in (1.5, 2.5)]
    else:
        parameters += [{"stop_multiple": value} for value in (2.5, 3.5)]
    for parameter in parameters:
        experiments.append(("parameter:" + json.dumps(parameter, sort_keys=True), {**request, "research_parameters": parameter}))
    return experiments


def sensitivity(engine: Path, request: dict[str, Any]) -> dict[str, Any]:
    """Predeclared cost/parameter neighbors; all execution stays in Rust."""
    rows = []
    for experiment_id, variant in sensitivity_requests(request):
        answer = run_engine(engine, variant)
        if answer["input_manifest"]["evidence"]["classification"] != "observed":
            raise ValueError("synthetic fixtures cannot enter sensitivity performance reports")
        rows.append({"experiment_id": experiment_id, "research_parameters": variant.get("research_parameters"), "run_id": answer["run_id"], "metrics": answer["metrics"]})
    return {"schema_version": VERSION, "kind": "predeclared_cost_and_parameter_sensitivity", "experiments": rows, "selection_performed": False,
            "parameter_sensitivity_status": "research_only_neighbors_not_deployable_versions", "promotion_eligible": False,
            "caveat": "Stops, affordable size and fills may change with costs; these are complete replay experiments, not a subtraction from a fixed equity curve."}


def assess_retained_source(raw: dict[str, Any]) -> dict[str, Any]:
    """Metadata-only receipt for the retained IBKR research schema, never prices."""
    if not isinstance(raw.get("provider"), str) or not isinstance(raw.get("symbols"), list):
        raise ValueError("expected the retained IBKR research evidence schema")
    symbols = []
    for item in raw["symbols"]:
        history = item.get("history", {})
        bars = history.get("bars", [])
        dates = [str(bar.get("date", "")) for bar in bars]
        symbols.append({
            "symbol": item.get("symbol"), "observed_sessions": len(bars),
            "first_session": min(dates) if dates else None, "last_session": max(dates) if dates else None,
            "has_220_observations": len(bars) >= 220, "adjustment_policy": history.get("adjustmentPolicy", "unknown"),
            "strategy_evaluation_available": False,
            "blockers": [
                *([] if len(bars) >= 220 else ["fewer_than_220_completed_sessions"]),
                "split_adjustment_attestation_missing", "official_session_coverage_unverified",
                "per_bar_historical_availability_receipt_missing",
            ],
            "options_only_limitations": ["historical_executable_option_chain_missing"],
        })
    return {"schema_version": "leo-strategy-source-capability.v1", "source": raw["provider"],
            "source_sha256": digest(raw), "retrieved_at": raw.get("retrievedAt"), "symbols": symbols,
            "observed_data_retained": True, "strategy_evaluation_available": False,
            "execution_authorized": False, "promotion_eligible": False,
            "reason": "Actual observed research evidence exists, but its known data gaps cannot be converted into valid MR/MOM/IV strategy performance.",
            "raw_market_values_included": False}


def write_new(path: Path, value: Any) -> None:
    payload = json.dumps(value, indent=2, allow_nan=False)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8") as handle:
        handle.write(payload + "\n")

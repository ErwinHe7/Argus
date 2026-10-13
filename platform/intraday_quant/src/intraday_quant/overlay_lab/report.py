"""Overlay metrics and the redacted public projection. Python owns every number.

``slice_metrics`` recomputes the same path statistics for any date window of an
artifact's ``daily`` rows, so development and holdout windows share one
definition. ``public_projection`` strips quotes, fills, closes and share counts.
"""
from __future__ import annotations

import math
from datetime import date
from typing import Any

import pandas as pd

from ..backtest.validation import _session_sign_flip_placebo
from ..strategy_lab import research

ARTIFACT_VERSION = "leo-overlay-lab.v1"
SESSIONS_PER_YEAR = 252
BOOTSTRAP_BLOCK_LENGTH = 21
SIGN_FLIP_MIN_CLUSTERS = 6
RETURN_CONVENTION = (
    "Close-to-close returns realized on each listed session; the first evaluated session measures the "
    "opening trade against pre-trade capital at the same close, so buy-and-hold is 0 on that row."
)


def _day(value: str | date) -> date:
    return value if isinstance(value, date) else date.fromisoformat(value)


def _finite(values: list[float]) -> list[float]:
    if not all(isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value) for value in values):
        raise ValueError("non-finite daily return; metrics fail closed")
    return [float(value) for value in values]


def path_metrics(returns: list[float]) -> dict[str, Any]:
    """Compounded total, annualized return (null below 252 sessions), sample volatility and drawdown."""
    returns = _finite(returns)
    if not returns:
        raise ValueError("no returns in metric window")
    nav = peak = 1.0
    drawdown = 0.0
    for value in returns:
        if value <= -1:
            raise ValueError("return at or below -100%; metrics fail closed")
        nav *= 1 + value
        peak = max(peak, nav)
        drawdown = min(drawdown, nav / peak - 1)
    volatility = None
    if len(returns) > 1:
        mean = math.fsum(returns) / len(returns)
        volatility = math.sqrt(math.fsum((value - mean) ** 2 for value in returns) / (len(returns) - 1)) * math.sqrt(SESSIONS_PER_YEAR)
    annualized = nav ** (SESSIONS_PER_YEAR / len(returns)) - 1 if len(returns) >= SESSIONS_PER_YEAR else None
    return {"total_return": nav - 1, "annualized_return": annualized, "annualized_volatility": volatility, "max_drawdown": drawdown}


def _capture(overlay: list[float], baseline: list[float], *, downside: bool) -> float | None:
    pairs = [(o, b) for o, b in zip(overlay, baseline, strict=True) if (b < 0 if downside else b > 0)]
    if not pairs:
        return None
    return math.fsum(o for o, _ in pairs) / math.fsum(b for _, b in pairs)


def _difference(left: float | None, right: float | None) -> float | None:
    return None if left is None or right is None else left - right


def active_inference(active: list[float], clusters: list[str], *, seed: int = 7, resamples: int = 2000) -> dict[str, Any]:
    """Moving-block bootstrap and roll-cycle-clustered sign flip of daily active returns."""
    active = _finite(active)
    if len(active) != len(clusters):
        raise ValueError("every active return needs a roll-cycle cluster")
    bootstrap = research.block_interval(active, seed=seed, resamples=resamples, block_length=BOOTSTRAP_BLOCK_LENGTH)
    bootstrap["point_estimate"] = research._compound(active)
    bootstrap["statistic"] = "compounded daily active return (overlay minus buy-and-hold)"
    frame = pd.DataFrame({"date": clusters, "gross_return": active, "net_return": active})
    sign_flip = _session_sign_flip_placebo(frame, resamples=resamples, random_seed=seed, minimum_sessions=SIGN_FLIP_MIN_CLUSTERS)
    sign_flip.update(cluster_definition="roll_cycle_start",
                     statistic_note="Rows are daily active returns; gross_return and net_return both equal the after-cost active return.")
    return {"active_return_bootstrap": bootstrap, "active_return_sign_flip": sign_flip}


def slice_metrics(daily: list[dict[str, Any]], start: str | date, end: str | date,
                  *, seed: int = 7, resamples: int = 2000) -> dict[str, Any]:
    """Metrics for daily rows with ``start <= session_date <= end``; contiguous windows partition returns."""
    first, last = _day(start), _day(end)
    if first > last:
        raise ValueError("metric window start after end")
    rows = [row for row in daily if first <= _day(row["session_date"]) <= last]
    if not rows:
        raise ValueError("empty metric window")
    overlay = _finite([row["overlay_return"] for row in rows])
    baseline = _finite([row["baseline_return"] for row in rows])
    active = _finite([row["active_return"] for row in rows])
    overlay_metrics = path_metrics(overlay)
    baseline_metrics = path_metrics(baseline)
    overlay_metrics.update(downside_capture=_capture(overlay, baseline, downside=True),
                           upside_capture=_capture(overlay, baseline, downside=False))
    return {
        "sessions": len(rows), "start": rows[0]["session_date"], "end": rows[-1]["session_date"],
        "return_convention": RETURN_CONVENTION,
        "overlay": overlay_metrics, "buy_and_hold": baseline_metrics,
        "difference": {key: _difference(overlay_metrics[key], baseline_metrics[key])
                       for key in ("total_return", "annualized_return", "annualized_volatility", "max_drawdown")},
        **active_inference(active, [row["cluster_date"] for row in rows], seed=seed, resamples=resamples),
    }


def _pct(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError("non-finite public percentage")
    return round(float(value) * 100, 2) + 0.0


def public_projection(artifact: dict[str, Any], *, public_symbol: bool = False) -> dict[str, Any]:
    """camelCase ``OverlayPublic``: no bid, ask, fill price, close, share count or contract identifier."""
    if artifact.get("schema_version") != ARTIFACT_VERSION:
        raise ValueError("expected a leo-overlay-lab.v1 artifact")
    if any(artifact.get(flag) is not False for flag in ("execution_authorized", "options_execution_enabled", "promotion_eligible")):
        raise ValueError("overlay artifacts never authorize execution or promotion")
    if artifact["pricing_mode"] == "MODEL_PRICED" and artifact["evidence_status"] != "MODEL_PRICED_NOT_EXECUTABLE":
        raise ValueError("model-priced artifacts must stay labelled MODEL_PRICED_NOT_EXECUTABLE")
    metrics, coverage, source = artifact["metrics"], artifact["coverage"], artifact["source"]
    overlay, baseline, counts = metrics["overlay"], metrics["buy_and_hold"], metrics["counts"]
    bootstrap, sign_flip = metrics["active_return_bootstrap"], metrics["active_return_sign_flip"]
    p_value = sign_flip.get("two_sided_plus_one_p_value")
    return {
        "symbolLabel": artifact["symbol"] if public_symbol else "Redacted holding",
        "structure": artifact["structure"], "pricingMode": artifact["pricing_mode"],
        "evidenceStatus": artifact["evidence_status"], "engineVersion": artifact["engine_version"],
        "inputSha256": artifact["input_sha256"], "configSha256": artifact["config_sha256"],
        "observationCutoff": artifact["observation_cutoff"], "availabilityCutoff": artifact["availability_cutoff"],
        "freshness": artifact["freshness"],
        "coverage": {"sessions": coverage["sessions"], "start": coverage["start"], "end": coverage["end"],
                     "calendarSource": coverage["calendar_source"], "cycles": coverage["cycles"],
                     "deferredRolls": coverage["deferred_rolls"]},
        "source": {"name": source["name"], "licenseScope": source["license_scope"],
                   "quoteSources": list(source["quote_sources"]), "ivSources": list(source["iv_sources"])},
        "metrics": {
            "overlay": {"totalReturnPct": _pct(overlay["total_return"]), "annualizedReturnPct": _pct(overlay["annualized_return"]),
                        "annualizedVolatilityPct": _pct(overlay["annualized_volatility"]), "maxDrawdownPct": _pct(overlay["max_drawdown"]),
                        "downsideCapturePct": _pct(overlay["downside_capture"]), "upsideCapturePct": _pct(overlay["upside_capture"]),
                        "premiumYieldAnnualizedPct": _pct(overlay["premium_yield_annualized"])},
            "buyAndHold": {"totalReturnPct": _pct(baseline["total_return"]), "annualizedReturnPct": _pct(baseline["annualized_return"]),
                           "annualizedVolatilityPct": _pct(baseline["annualized_volatility"]), "maxDrawdownPct": _pct(baseline["max_drawdown"])},
            "difference": {"totalReturnPct": _pct(metrics["difference"]["total_return"]),
                           "maxDrawdownPct": _pct(metrics["difference"]["max_drawdown"])},
            "counts": {"assignments": counts["assignments"], "capHits": counts["cap_hits"], "putExercises": counts["put_exercises"],
                       "deferredRolls": counts["deferred_rolls"], "exDividendItmShortCallEvents": counts["ex_dividend_itm_short_call_events"]},
            "activeReturnBootstrap": {"status": bootstrap["status"], "lower95Pct": _pct(bootstrap.get("lower_95")),
                                      "upper95Pct": _pct(bootstrap.get("upper_95")), "resamples": bootstrap.get("resamples"),
                                      "blockLength": bootstrap.get("block_length")},
            "activeReturnSignFlipP": None if p_value is None else round(float(p_value), 4),
        },
        "cycles": [{"cycleId": cycle["cycle_id"], "opened": cycle["opened"], "expiry": cycle["expiry"], "outcome": cycle["outcome"],
                    "overlayReturnPct": _pct(cycle["overlay_return"]), "baselineReturnPct": _pct(cycle["baseline_return"]),
                    "legs": [{"right": leg["right"], "side": leg["side"], "strikeMoneynessPct": _pct(leg["strike_moneyness"]),
                              "dte": leg["dte"], "fillSide": leg["fill_side"]} for leg in cycle["legs"]]}
                   for cycle in artifact["cycles"]],
        "assumptions": list(artifact["assumptions"]), "caveats": list(artifact["caveats"]),
        "executionAuthorized": False, "optionsExecutionEnabled": False, "promotionEligible": False,
    }

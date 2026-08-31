from __future__ import annotations

import math

import numpy as np
import pandas as pd


THEORY_MAP = pd.DataFrame([
    {"book_idea": "Mine many weak recurring anomalies", "testable_implementation": "Four rule families + calibrated ensemble + daily top-N gate", "status": "implemented"},
    {"book_idea": "Use granular intraday data", "testable_implementation": "One-minute SPX state with SPY/ES/QQQ/SOXX/IWM/VIX context", "status": "implemented; data-source quality varies"},
    {"book_idea": "Exploit persistence from minutes to days", "testable_implementation": "15/30/60m labels, opening trend and closing-cover features", "status": "implemented for intraday horizons"},
    {"book_idea": "Use reliable trends in related markets", "testable_implementation": "Cross-asset breadth, confirmation and ES-SPX basis", "status": "implemented"},
    {"book_idea": "Win rate below 50% can still work", "testable_implementation": "Net expectancy, payoff ratio, profit factor and break-even win rate", "status": "implemented"},
    {"book_idea": "Replace discretion with preset algorithms", "testable_implementation": "Deterministic candidates, t+1 fills, costs, cooldown and max trades", "status": "implemented"},
    {"book_idea": "Option mispricing and hedging", "testable_implementation": "Historical NBBO ask/bid engine with IV and Greeks", "status": "engine implemented; real OPRA/NBBO required"},
    {"book_idea": "Scientific testing over chart folklore", "testable_implementation": "Purged walk-forward OOS tests and confidence intervals", "status": "implemented; long history still required"},
])


def _wilson_interval(wins: int, n: int, z: float = 1.96) -> tuple[float, float]:
    if n == 0:
        return 0.0, 0.0
    p = wins / n
    denominator = 1 + z * z / n
    center = (p + z * z / (2 * n)) / denominator
    margin = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denominator
    return max(0.0, center - margin), min(1.0, center + margin)


def theory_performance_audit(trades: pd.DataFrame) -> pd.DataFrame:
    columns = ["setup", "trades", "wins", "win_rate", "win_rate_ci_low", "win_rate_ci_high",
               "average_win", "average_loss", "payoff_ratio", "break_even_win_rate",
               "expectancy", "profit_factor", "verdict"]
    if trades.empty:
        return pd.DataFrame(columns=columns)
    groups = [("ALL", trades)] + list(trades.groupby("setup"))
    rows: list[dict[str, object]] = []
    for name, group in groups:
        returns = group["net_return"].astype(float)
        wins = returns[returns > 0]
        losses = returns[returns <= 0]
        n = len(returns)
        win_count = len(wins)
        low, high = _wilson_interval(win_count, n)
        average_win = float(wins.mean()) if len(wins) else 0.0
        average_loss = float(losses.mean()) if len(losses) else 0.0
        payoff = average_win / abs(average_loss) if average_loss < 0 else np.inf if average_win > 0 else 0.0
        break_even = 1 / (1 + payoff) if np.isfinite(payoff) and payoff > 0 else 0.0
        gross_profit, gross_loss = float(wins.sum()), abs(float(losses.sum()))
        profit_factor = gross_profit / gross_loss if gross_loss else np.inf if gross_profit else 0.0
        expectancy = float(returns.mean())
        if n < 30:
            verdict = "insufficient_sample"
        elif expectancy > 0 and profit_factor > 1:
            verdict = "promising_requires_more_oos"
        else:
            verdict = "no_positive_net_edge_observed"
        rows.append({
            "setup": name, "trades": n, "wins": win_count, "win_rate": win_count / n,
            "win_rate_ci_low": low, "win_rate_ci_high": high, "average_win": average_win,
            "average_loss": average_loss, "payoff_ratio": payoff, "break_even_win_rate": break_even,
            "expectancy": expectancy, "profit_factor": profit_factor, "verdict": verdict,
        })
    return pd.DataFrame(rows, columns=columns)


def hypothesis_event_audit(labels: pd.DataFrame) -> pd.DataFrame:
    """Descriptive first-event-per-day stats; explicitly not walk-forward OOS."""
    columns = ["setup", "event_days", "wins_after_cost", "win_rate_after_cost",
               "average_net_return", "median_net_return", "profit_factor", "scope"]
    if labels.empty:
        return pd.DataFrame(columns=columns)
    independent = labels.sort_values("timestamp").groupby(["setup_type", "session_date"], as_index=False).head(1)
    rows: list[dict[str, object]] = []
    for setup, group in independent.groupby("setup_type"):
        returns = group["net_return_after_cost"].dropna().astype(float)
        wins = returns[returns > 0]
        losses = returns[returns <= 0]
        rows.append({
            "setup": setup, "event_days": len(returns), "wins_after_cost": len(wins),
            "win_rate_after_cost": float((returns > 0).mean()) if len(returns) else 0.0,
            "average_net_return": float(returns.mean()) if len(returns) else 0.0,
            "median_net_return": float(returns.median()) if len(returns) else 0.0,
            "profit_factor": float(wins.sum() / abs(losses.sum())) if len(losses) and losses.sum() else 0.0,
            "scope": "hypothesis_formation_not_oos",
        })
    return pd.DataFrame(rows, columns=columns)

from __future__ import annotations

import numpy as np
import pandas as pd

from intraday_quant.config import AppConfig


def cost_audit(trades: pd.DataFrame, config: AppConfig) -> dict[str, object]:
    """Stress realized costs with fixed fills; never reselect or tune on test P&L."""
    report: dict[str, object] = {
        "status": "RESEARCH_ASSUMPTIONS_NOT_CALIBRATED",
        "scope": "underlying_test_fold_trades",
        "capacity_status": "prior_bar_proxy_checked" if config.execution_costs.require_volume_capacity else "not_checked",
        "assumptions": config.execution_costs.model_dump(),
        "legacy_cost_assumptions": config.costs.model_dump(),
        "stress_method": "fixed_trade_and_fill_sample_cost_multiplier_only; no reselection or retuning",
        "number_of_trades": len(trades),
    }
    if trades.empty:
        return {**report, "gross_pnl": 0.0, "cost": 0.0, "net_pnl": 0.0,
                "break_even_cost_multiplier": None, "cost_scenarios": []}
    components = ["commission_cost", "spread_cost", "slippage_cost", "impact_cost"]
    required = ["gross_pnl", "cost", "net_pnl", "trade_notional", *components]
    if not set(required).issubset(trades):
        raise ValueError("cost audit requires a new cost-decomposed blotter; rerun the backtest")
    values = trades[required].astype(float)
    if not np.isfinite(values.to_numpy()).all() or (values[["cost", *components]] < 0).any().any():
        raise ValueError("cost audit rejects nonfinite or negative transaction costs")
    if (values["trade_notional"] <= 0).any():
        raise ValueError("cost audit requires positive trade notional")
    if not np.allclose(values[components].sum(axis=1), values["cost"], rtol=1e-10, atol=1e-8):
        raise ValueError("cost components must reconcile to total cost")
    if not np.allclose(values["gross_pnl"] - values["cost"], values["net_pnl"], rtol=1e-10, atol=1e-8):
        raise ValueError("gross minus costs must reconcile to net P&L")
    gross, cost = float(values["gross_pnl"].sum()), float(values["cost"].sum())
    scenarios = []
    for multiplier in (1.0, 2.0, 3.0):
        net = values["gross_pnl"] - multiplier * values["cost"]
        scenarios.append({
            "cost_multiplier": multiplier, "gross_pnl": gross, "cost": cost * multiplier,
            "net_pnl": float(net.sum()), "net_positive_trade_fraction": float((net > 0).mean()),
            "mean_break_even_return_bps": float((multiplier * values["cost"] / values["trade_notional"] * 10_000).mean()),
        })
    return {
        **report, "gross_pnl": gross, "cost": cost, "net_pnl": gross - cost,
        **{name: float(values[name].sum()) for name in components},
        "break_even_cost_multiplier": gross / cost if cost else None,
        "mean_break_even_return_bps": float((values["cost"] / values["trade_notional"] * 10_000).mean()),
        "cost_scenarios": scenarios,
    }

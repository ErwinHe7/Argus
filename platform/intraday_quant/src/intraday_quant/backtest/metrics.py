from __future__ import annotations

import math

import numpy as np
import pandas as pd


def performance_metrics(trades: pd.DataFrame, candidate_dates: list[object] | None = None) -> dict[str, object]:
    if trades.empty:
        total_days = len(set(candidate_dates or []))
        return {"total_return": 0.0, "annualized_return": None, "sharpe": None, "sortino": None,
                "maximum_drawdown": 0.0, "calmar": 0.0, "win_rate": 0.0, "average_win": 0.0,
                "average_loss": 0.0, "profit_factor": 0.0, "expectancy_per_trade": 0.0,
                "median_return_per_trade": 0.0, "number_of_trades": 0, "trades_per_day": 0.0,
                "percentage_no_trade_days": 100.0 if total_days else 0.0, "average_holding_period": 0.0,
                "average_mfe": 0.0, "average_mae": 0.0, "mfe_capture_ratio": 0.0,
                "observed_sessions": total_days, "annualization_status": "insufficient_history"}
    returns = trades["net_return"].astype(float)
    daily = trades.groupby("date")["net_return"].sum()
    all_date_values = sorted(set(candidate_dates or trades["date"].tolist()))
    daily = daily.reindex(all_date_values, fill_value=0.0)
    equity = (1 + daily).cumprod()
    peak = equity.cummax()
    drawdown = equity / peak - 1
    total_return = float(equity.iloc[-1] - 1)
    years = max(len(daily) / 252, 1 / 252)
    raw_annualized = float((equity.iloc[-1] ** (1 / years) - 1) if equity.iloc[-1] > 0 else -1)
    std = daily.std(ddof=1)
    downside = daily[daily < 0].std(ddof=1)
    raw_sharpe = float(daily.mean() / std * math.sqrt(252)) if std and np.isfinite(std) else 0.0
    raw_sortino = float(daily.mean() / downside * math.sqrt(252)) if downside and np.isfinite(downside) else 0.0
    max_dd = float(drawdown.min())
    wins, losses = returns[returns > 0], returns[returns <= 0]
    all_days = len(all_date_values)
    traded_days = trades["date"].nunique()
    gross_profit, gross_loss = wins.sum(), abs(losses.sum())
    captured = np.where(trades["MFE"] > 0, trades["net_return"] / trades["MFE"], np.nan)
    return {
        "total_return": total_return,
        "annualized_return": raw_annualized if all_days >= 60 else None,
        "sharpe": raw_sharpe if all_days >= 60 else None,
        "sortino": raw_sortino if all_days >= 60 else None,
        "maximum_drawdown": max_dd,
        "calmar": raw_annualized / abs(max_dd) if all_days >= 60 and max_dd < 0 else None,
        "win_rate": float((returns > 0).mean()), "average_win": float(wins.mean()) if len(wins) else 0.0,
        "average_loss": float(losses.mean()) if len(losses) else 0.0,
        "profit_factor": float(gross_profit / gross_loss) if gross_loss else 0.0,
        "expectancy_per_trade": float(returns.mean()), "median_return_per_trade": float(returns.median()),
        "number_of_trades": int(len(trades)), "trades_per_day": float(len(trades) / max(all_days, 1)),
        "percentage_no_trade_days": float(100 * (1 - traded_days / max(all_days, 1))),
        "average_holding_period": float(trades["holding_minutes"].mean()),
        "average_mfe": float(trades["MFE"].mean()), "average_mae": float(trades["MAE"].mean()),
        "mfe_capture_ratio": float(np.nanmean(captured)) if np.isfinite(captured).any() else 0.0,
        "observed_sessions": all_days,
        "annualization_status": "reported" if all_days >= 60 else "suppressed_insufficient_history_lt_60_sessions",
    }

from __future__ import annotations

import uuid

import numpy as np
import pandas as pd

from intraday_quant.config import AppConfig


def run_underlying_backtest(selected: pd.DataFrame, features: pd.DataFrame, config: AppConfig) -> pd.DataFrame:
    columns = ["trade_id", "date", "setup", "direction", "signal_time", "entry_time", "exit_time",
               "underlying_entry", "underlying_exit", "gross_pnl", "cost", "net_pnl", "MFE", "MAE",
               "exit_reason", "model_probability", "score", "fold", "gross_return", "net_return", "holding_minutes"]
    if selected.empty:
        return pd.DataFrame(columns=columns)
    bars = features.set_index("timestamp").sort_index()
    notional = 100_000.0
    trades: list[dict[str, object]] = []
    for signal in selected.sort_values("timestamp").itertuples(index=False):
        pos = bars.index.searchsorted(signal.timestamp, side="right")
        if pos >= len(bars) or bars.index[pos].date() != signal.timestamp.date():
            continue
        entry_bar = bars.iloc[pos]
        raw_entry = float(entry_bar["open"])
        direction = int(signal.direction)
        slippage = config.costs.underlying_slippage_bps / 10_000
        entry = raw_entry * (1 + direction * slippage)
        atr = float(entry_bar.get("rolling_atr", np.nan))
        if not np.isfinite(atr):
            atr = entry * 0.001
        stop_distance = config.risk.stop_value * atr
        target_distance = config.risk.take_profit_value * atr
        window = bars.iloc[pos:pos + config.risk.max_holding_minutes]
        exit_price = float(window.iloc[-1]["close"])
        exit_time = window.index[-1]
        exit_reason = "time_exit"
        favorable_max = 0.0
        adverse_min = 0.0
        for timestamp, bar in window.iterrows():
            favorable_price = float(bar["high"] if direction == 1 else bar["low"])
            adverse_price = float(bar["low"] if direction == 1 else bar["high"])
            favorable = direction * (favorable_price / entry - 1)
            adverse = direction * (adverse_price / entry - 1)
            favorable_max = max(favorable_max, favorable)
            adverse_min = min(adverse_min, adverse)
            stop_hit = adverse_price <= entry - stop_distance if direction == 1 else adverse_price >= entry + stop_distance
            target_hit = favorable_price >= entry + target_distance if direction == 1 else favorable_price <= entry - target_distance
            if stop_hit:  # conservative same-minute ordering
                exit_price = entry - direction * stop_distance
                exit_time, exit_reason = timestamp, "stop_loss"
                break
            if target_hit:
                exit_price = entry + direction * target_distance
                exit_time, exit_reason = timestamp, "take_profit"
                break
        exit_fill = exit_price * (1 - direction * slippage)
        gross_return = direction * (exit_price / raw_entry - 1)
        net_price_return = direction * (exit_fill / entry - 1)
        commission_return = 2 * config.costs.commission_per_trade / notional
        net_return = net_price_return - commission_return
        trades.append({
            "trade_id": str(uuid.uuid4()), "date": signal.timestamp.date(), "setup": signal.setup_type,
            "direction": direction, "signal_time": signal.timestamp, "entry_time": bars.index[pos],
            "exit_time": exit_time, "underlying_entry": entry, "underlying_exit": exit_fill,
            "gross_pnl": gross_return * notional, "cost": (gross_return - net_return) * notional,
            "net_pnl": net_return * notional, "MFE": favorable_max, "MAE": abs(adverse_min),
            "exit_reason": exit_reason, "model_probability": float(signal.win_probability),
            "score": float(signal.score), "fold": int(signal.fold), "gross_return": gross_return, "net_return": net_return,
            "holding_minutes": max(1, int((exit_time - bars.index[pos]).total_seconds() / 60) + 1),
        })
    return pd.DataFrame(trades, columns=columns)

from __future__ import annotations

import pandas as pd

from intraday_quant.backtest.execution import option_entry_fill, option_exit_fill
from intraday_quant.config import AppConfig
from intraday_quant.schemas import OPTION_COLUMNS


def load_option_quotes(path: str) -> pd.DataFrame:
    quotes = pd.read_parquet(path) if path.lower().endswith(".parquet") else pd.read_csv(path)
    missing = [c for c in OPTION_COLUMNS if c not in quotes]
    if missing:
        raise ValueError(f"option data missing columns: {missing}")
    quotes["timestamp"] = pd.to_datetime(quotes["timestamp"], utc=True).dt.tz_convert("America/New_York")
    return quotes.sort_values("timestamp")


def run_options_backtest(underlying_trades: pd.DataFrame, config: AppConfig) -> tuple[pd.DataFrame, str]:
    if not config.option_execution.enabled or not config.option_execution.quotes_path:
        return pd.DataFrame(), "期权回测未执行：未启用或未提供真实期权 NBBO 数据"
    quotes = load_option_quotes(config.option_execution.quotes_path)
    rows: list[dict[str, object]] = []
    for trade in underlying_trades.itertuples(index=False):
        entry_after = trade.signal_time + pd.Timedelta(milliseconds=config.execution_costs.latency_ms)
        entry = option_entry_fill(quotes, entry_after, trade.direction, config.option_execution, config.costs.option_slippage)
        if not entry.accepted:
            rows.append({"trade_id": trade.trade_id, "status": "rejected", "reason": entry.reason})
            continue
        option_symbol = str(entry.quote["option_symbol"])
        exit_after = max(trade.exit_time, entry.quote["timestamp"])
        exit_ = option_exit_fill(quotes, option_symbol, exit_after, config.option_execution, config.costs.option_slippage)
        if not exit_.accepted:
            rows.append({"trade_id": trade.trade_id, "status": "unliquidated", "reason": exit_.reason,
                         "option_symbol": option_symbol, "option_fill": entry.fill,
                         "entry_time": entry.quote["timestamp"], "net_pnl": None})
            continue
        multiplier = 100
        gross = (float(exit_.quote["bid"]) - float(entry.quote["ask"])) * multiplier
        net = (exit_.fill - entry.fill) * multiplier - 2 * config.costs.commission_per_trade
        mid_entry = (float(entry.quote["bid"]) + float(entry.quote["ask"])) / 2
        mid_exit = (float(exit_.quote["bid"]) + float(exit_.quote["ask"])) / 2
        mid_gross = (mid_exit - mid_entry) * multiplier
        spread_cost = ((float(entry.quote["ask"]) - mid_entry) + (mid_exit - float(exit_.quote["bid"]))) * multiplier
        rows.append({
            "trade_id": trade.trade_id, "status": "filled", "option_symbol": option_symbol,
            "option_entry_bid": entry.quote["bid"], "option_entry_ask": entry.quote["ask"], "option_fill": entry.fill,
            "option_exit_bid": exit_.quote["bid"], "option_exit_ask": exit_.quote["ask"], "option_exit_fill": exit_.fill,
            "iv_entry": entry.quote["iv"], "iv_exit": exit_.quote["iv"], "delta_entry": entry.quote["delta"],
            "gamma_entry": entry.quote["gamma"], "theta_entry": entry.quote["theta"],
            "gross_pnl": gross, "cost": gross - net, "net_pnl": net,
            "mid_gross_pnl": mid_gross, "all_in_cost": mid_gross - net,
            "spread_cost": spread_cost, "slippage_cost": 2 * config.costs.option_slippage * multiplier,
            "commission_cost": 2 * config.costs.commission_per_trade,
            "entry_time": entry.quote["timestamp"], "exit_time": exit_.quote["timestamp"],
            "cost_model_status": "RESEARCH_ASSUMPTIONS_NOT_CALIBRATED",
        })
    result = pd.DataFrame(rows)
    if not result.empty and result["status"].eq("unliquidated").any():
        return result, "期权回测存在未清算头寸：净收益不可完整评估；请检查真实 NBBO 覆盖"
    return result, "期权回测已使用提供的真实 NBBO 文件执行"


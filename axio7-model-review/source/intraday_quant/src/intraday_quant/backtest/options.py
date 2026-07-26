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
        entry = option_entry_fill(quotes, trade.signal_time, trade.direction, config.option_execution, config.costs.option_slippage)
        if not entry.accepted:
            rows.append({"trade_id": trade.trade_id, "status": "rejected", "reason": entry.reason})
            continue
        option_symbol = str(entry.quote["option_symbol"])
        exit_ = option_exit_fill(quotes, option_symbol, trade.exit_time, config.option_execution, config.costs.option_slippage)
        if not exit_.accepted:
            rows.append({"trade_id": trade.trade_id, "status": "rejected", "reason": exit_.reason, "option_symbol": option_symbol})
            continue
        multiplier = 100
        gross = (float(exit_.quote["bid"]) - float(entry.quote["ask"])) * multiplier
        net = (exit_.fill - entry.fill) * multiplier - 2 * config.costs.commission_per_trade
        rows.append({
            "trade_id": trade.trade_id, "status": "filled", "option_symbol": option_symbol,
            "option_entry_bid": entry.quote["bid"], "option_entry_ask": entry.quote["ask"], "option_fill": entry.fill,
            "option_exit_bid": exit_.quote["bid"], "option_exit_ask": exit_.quote["ask"], "option_exit_fill": exit_.fill,
            "iv_entry": entry.quote["iv"], "iv_exit": exit_.quote["iv"], "delta_entry": entry.quote["delta"],
            "gamma_entry": entry.quote["gamma"], "theta_entry": entry.quote["theta"],
            "gross_pnl": gross, "cost": gross - net, "net_pnl": net,
        })
    return pd.DataFrame(rows), "期权回测已使用提供的真实 NBBO 文件执行"


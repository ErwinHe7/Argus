from __future__ import annotations

from datetime import timedelta

import pandas as pd

from intraday_quant.config import OptionExecutionConfig
from intraday_quant.schemas import OptionFill


def validate_option_quote(row: pd.Series, config: OptionExecutionConfig, signal_time: pd.Timestamp) -> tuple[bool, str]:
    if row["timestamp"] <= signal_time:
        return False, "quote_not_after_signal"
    if (row["timestamp"] - signal_time).total_seconds() > config.max_quote_age_seconds:
        return False, "stale_quote"
    if row["bid"] <= 0 or row["ask"] <= row["bid"]:
        return False, "invalid_nbbo"
    if row.get("bid_size", 0) < config.min_bid_size or row.get("ask_size", 0) < config.min_bid_size:
        return False, "insufficient_size"
    spread_pct = (row["ask"] - row["bid"]) / ((row["ask"] + row["bid"]) / 2)
    if spread_pct > config.max_spread_pct:
        return False, "spread_too_wide"
    if abs(float(row["delta"])) < config.delta_min or abs(float(row["delta"])) > config.delta_max:
        return False, "delta_out_of_range"
    if int(row["dte"]) not in config.dte:
        return False, "dte_out_of_range"
    return True, "accepted"


def option_entry_fill(quotes: pd.DataFrame, signal_time: pd.Timestamp, direction: int, config: OptionExecutionConfig, slippage: float) -> OptionFill:
    side = "C" if direction == 1 else "P"
    eligible = quotes[(quotes["timestamp"] > signal_time) & (quotes["call_put"].str.upper().str[0] == side)].sort_values("timestamp")
    for _, row in eligible.iterrows():
        valid, reason = validate_option_quote(row, config, signal_time)
        if valid:
            return OptionFill(True, "accepted", float(row["ask"] + slippage), row.to_dict())
    return OptionFill(False, "no_valid_nbbo", None, None)


def option_exit_fill(quotes: pd.DataFrame, option_symbol: str, after: pd.Timestamp, config: OptionExecutionConfig, slippage: float) -> OptionFill:
    eligible = quotes[(quotes["option_symbol"] == option_symbol) & (quotes["timestamp"] >= after)].sort_values("timestamp")
    for _, row in eligible.iterrows():
        if (row["timestamp"] - after).total_seconds() > config.max_quote_age_seconds:
            break
        if row["bid"] > 0 and row["ask"] > row["bid"]:
            spread_pct = (row["ask"] - row["bid"]) / ((row["ask"] + row["bid"]) / 2)
            if spread_pct <= config.max_spread_pct:
                return OptionFill(True, "accepted", max(0.0, float(row["bid"] - slippage)), row.to_dict())
    return OptionFill(False, "no_valid_exit_nbbo", None, None)

from __future__ import annotations

import math

import pandas as pd

from intraday_quant.config import OptionExecutionConfig
from intraday_quant.schemas import OptionFill


def _validate_slippage(slippage: float) -> None:
    if not math.isfinite(slippage) or slippage < 0:
        raise ValueError("option slippage must be finite and non-negative")


def _valid_nbbo(row: pd.Series, config: OptionExecutionConfig) -> tuple[bool, str]:
    for key in ("bid", "ask", "bid_size", "ask_size"):
        try:
            if not math.isfinite(float(row.get(key, float("nan")))):
                return False, "nonfinite_nbbo"
        except (TypeError, ValueError):
            return False, "nonfinite_nbbo"
    if row["bid"] <= 0 or row["ask"] <= row["bid"]:
        return False, "invalid_nbbo"
    if row["bid_size"] < config.min_bid_size or row["ask_size"] < config.min_bid_size:
        return False, "insufficient_size"
    spread_pct = (row["ask"] - row["bid"]) / ((row["ask"] + row["bid"]) / 2)
    if spread_pct > config.max_spread_pct:
        return False, "spread_too_wide"
    return True, "accepted"


def validate_option_quote(row: pd.Series, config: OptionExecutionConfig, signal_time: pd.Timestamp) -> tuple[bool, str]:
    if pd.isna(row["timestamp"]):
        return False, "invalid_quote_time"
    if row["timestamp"] <= signal_time:
        return False, "quote_not_after_signal"
    if (row["timestamp"] - signal_time).total_seconds() > config.max_quote_age_seconds:
        return False, "stale_quote"
    valid, reason = _valid_nbbo(row, config)
    if not valid:
        return valid, reason
    try:
        delta, dte = float(row["delta"]), float(row["dte"])
    except (ValueError, TypeError):
        return False, "nonfinite_contract_fields"
    if not math.isfinite(delta) or not math.isfinite(dte):
        return False, "nonfinite_contract_fields"
    if abs(delta) < config.delta_min or abs(delta) > config.delta_max:
        return False, "delta_out_of_range"
    if not dte.is_integer() or int(dte) not in config.dte:
        return False, "dte_out_of_range"
    return True, "accepted"


def option_entry_fill(quotes: pd.DataFrame, signal_time: pd.Timestamp, direction: int, config: OptionExecutionConfig, slippage: float) -> OptionFill:
    _validate_slippage(slippage)
    if direction not in {-1, 1} or pd.isna(signal_time) or signal_time.tzinfo is None:
        raise ValueError("option entry requires direction -1/1 and timezone-aware signal time")
    side = "C" if direction == 1 else "P"
    eligible = quotes[(quotes["timestamp"] > signal_time) & (quotes["call_put"].str.upper().str[0] == side)].sort_values("timestamp")
    for _, row in eligible.iterrows():
        valid, reason = validate_option_quote(row, config, signal_time)
        if valid:
            return OptionFill(True, "accepted", float(row["ask"] + slippage), row.to_dict())
    return OptionFill(False, "no_valid_nbbo", None, None)


def option_exit_fill(quotes: pd.DataFrame, option_symbol: str, after: pd.Timestamp, config: OptionExecutionConfig, slippage: float) -> OptionFill:
    _validate_slippage(slippage)
    if pd.isna(after) or after.tzinfo is None:
        raise ValueError("option exit requires a timezone-aware cutoff")
    eligible = quotes[(quotes["option_symbol"] == option_symbol) & (quotes["timestamp"] > after)].sort_values("timestamp")
    for _, row in eligible.iterrows():
        if (row["timestamp"] - after).total_seconds() > config.max_quote_age_seconds:
            break
        valid, _ = _valid_nbbo(row, config)
        if valid and row["bid"] > slippage:
            return OptionFill(True, "accepted", float(row["bid"] - slippage), row.to_dict())
    return OptionFill(False, "no_valid_exit_nbbo", None, None)


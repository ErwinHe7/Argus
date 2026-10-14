from __future__ import annotations

import uuid

import numpy as np
import pandas as pd

from intraday_quant.backtest.costs import CapacityUnavailable, fill_costs
from intraday_quant.calendar import filter_regular_session, market_schedule
from intraday_quant.config import AppConfig


TRADE_COLUMNS = [
    "trade_id", "date", "setup", "direction", "signal_time", "entry_time", "exit_time",
    "underlying_entry", "underlying_exit", "gross_pnl", "cost", "net_pnl", "MFE", "MAE",
    "exit_reason", "model_probability", "score", "fold", "gross_return", "net_return", "holding_minutes",
    "raw_entry", "raw_exit", "quantity", "trade_notional", "commission_cost", "spread_cost",
    "slippage_cost", "impact_cost", "break_even_return_bps", "entry_participation_rate",
    "exit_participation_rate", "capacity_status", "cost_model_status", "latency_ms", "signal_bar_time",
]


def _validated_bars(features: pd.DataFrame, config: AppConfig) -> pd.DataFrame:
    required = {"timestamp", "open", "high", "low", "close"}
    if not required.issubset(features):
        raise ValueError(f"backtest bars missing: {sorted(required - set(features.columns))}")
    if features["timestamp"].isna().any() or features["timestamp"].duplicated().any():
        raise ValueError("backtest timestamps must be present and unique")
    if features["timestamp"].dt.tz is None:
        raise ValueError("backtest timestamps must be timezone-aware")
    prices = features[["open", "high", "low", "close"]].astype(float)
    if not np.isfinite(prices.to_numpy()).all() or (prices <= 0).any().any():
        raise ValueError("backtest OHLC must be finite and positive")
    if ((prices["high"] < prices[["open", "close", "low"]].max(axis=1))
            | (prices["low"] > prices[["open", "close", "high"]].min(axis=1))).any():
        raise ValueError("backtest OHLC ranges are inconsistent")
    if "symbol" in features and not features["symbol"].eq(config.target).all():
        raise ValueError("backtest bars must contain the target symbol only")
    if config.execution_costs.require_volume_capacity:
        if config.target in {"SPX", "VIX", "VIX1D"}:
            raise ValueError("cash index/proxy volume cannot establish executable capacity")
        if "symbol" not in features or "volume" not in features:
            raise ValueError("capacity requires explicitly identified same-symbol share volume")
    if features.empty:
        return features.set_index("timestamp")
    dates = features["timestamp"].dt.tz_convert(config.timezone).dt.date
    schedule = market_schedule(str(dates.min()), str(dates.max()), config.timezone)
    regular = filter_regular_session(features, schedule)
    if len(regular) != len(features):
        raise ValueError("backtest bars must belong to official XNYS regular sessions")
    ordered = regular.sort_values("timestamp")
    cadence = ordered.groupby(ordered["timestamp"].dt.tz_convert(config.timezone).dt.date)["timestamp"].diff().dropna()
    if not cadence.eq(pd.Timedelta(minutes=1)).all():
        raise ValueError("missing minute bars within a session; no delayed substitute entry or imputed fills")
    result = regular.set_index("timestamp").sort_index()
    result.attrs["session_closes"] = schedule["close"].to_dict()
    return result


def run_underlying_backtest(selected: pd.DataFrame, features: pd.DataFrame, config: AppConfig) -> pd.DataFrame:
    """Fixed-quantity research simulation. Any unpriceable exit aborts the run.

    Entry rejections are retained in ``execution_rejections`` attrs for the CLI.
    A failed exit is never silently removed from the performance sample.
    """
    if selected.empty:
        return pd.DataFrame(columns=TRADE_COLUMNS)
    bars = _validated_bars(features, config)
    notional = config.execution_costs.trade_notional
    trades: list[dict[str, object]] = []
    rejections: list[dict[str, object]] = []
    active_exits: list[pd.Timestamp] = []
    for signal in selected.sort_values("timestamp").itertuples(index=False):
        signal_bar_time = pd.Timestamp(signal.timestamp)
        if pd.isna(signal_bar_time) or signal_bar_time.tzinfo is None or signal.direction not in {-1, 1}:
            raise ValueError("signals require timezone-aware timestamps and direction -1/1")
        probability, score = float(signal.win_probability), float(signal.score)
        if not np.isfinite([probability, score]).all() or not 0 <= probability <= 1:
            raise ValueError("selected signals require finite probability/score and probability in [0,1]")
        signal_bar_time = signal_bar_time.tz_convert(config.timezone)
        # Archived minute bars are labeled at interval start. Closing features
        # of this bar become available one minute later, never at its label.
        cutoff = signal_bar_time + pd.Timedelta(minutes=1)

        def reject(reason: str) -> None:
            rejections.append({**signal._asdict(), "rejection_reason": reason})

        eligible_after = cutoff + pd.Timedelta(milliseconds=config.execution_costs.latency_ms)
        pos = bars.index.searchsorted(eligible_after, side="left")
        if pos >= len(bars) or bars.index[pos].tz_convert(config.timezone).date() != cutoff.date():
            reject("no_post_latency_same_session_entry")
            continue
        active_exits = [value for value in active_exits if value > bars.index[pos]]
        if len(active_exits) >= config.portfolio.max_open_positions:
            reject("open_position_limit")
            continue
        # ATR is frozen at the signal information cutoff, never at the future fill bar.
        state_pos = bars.index.searchsorted(signal_bar_time, side="right") - 1
        if state_pos < 0 or bars.index[state_pos].tz_convert(config.timezone).date() != cutoff.date():
            reject("missing_causal_signal_state")
            continue
        atr = float(bars.iloc[state_pos].get("rolling_atr", np.nan))
        if not np.isfinite(atr) or atr <= 0:
            reject("missing_positive_causal_atr")
            continue
        if signal_bar_time - bars.index[state_pos] >= pd.Timedelta(minutes=1):
            reject("stale_causal_signal_state")
            continue
        raw_entry = float(bars.iloc[pos]["open"])
        quantity = notional / raw_entry
        direction = int(signal.direction)
        entry_volume = bars.iloc[pos - 1].get("volume") if pos else None
        if pos == 0 or bars.index[pos] - bars.index[pos - 1] != pd.Timedelta(minutes=1):
            entry_volume = None
        try:
            entry_costs = fill_costs(raw_entry, quantity, direction, config, entry_volume)
        except CapacityUnavailable as exc:
            reject(str(exc))
            continue
        stop_distance = config.risk.stop_value * atr
        target_distance = config.risk.take_profit_value * atr
        horizon_end = bars.index[pos] + pd.Timedelta(minutes=config.risk.max_holding_minutes)
        session_dates = bars.index.tz_convert(config.timezone).date
        window = bars.iloc[pos:].loc[(bars.index[pos:] < horizon_end) & (session_dates[pos:] == cutoff.date())]
        if window.empty:
            reject("no_same_session_exit_bar")
            continue
        if len(window) > 1 and not window.index.to_series().diff().iloc[1:].eq(pd.Timedelta(minutes=1)).all():
            raise ValueError("missing minute bars in trade holding window; no imputed fills")
        raw_exit = float(window.iloc[-1]["close"])
        exit_bar_time = window.index[-1]
        exit_reason = "time_exit" if len(window) == config.risk.max_holding_minutes else "session_close"
        favorable_max = 0.0
        adverse_min = 0.0
        for timestamp, bar in window.iterrows():
            favorable_price = float(bar["high"] if direction == 1 else bar["low"])
            adverse_price = float(bar["low"] if direction == 1 else bar["high"])
            favorable_max = max(favorable_max, direction * (favorable_price / raw_entry - 1))
            adverse_min = min(adverse_min, direction * (adverse_price / raw_entry - 1))
            stop_price = raw_entry - direction * stop_distance
            target_price = raw_entry + direction * target_distance
            stop_hit = adverse_price <= stop_price if direction == 1 else adverse_price >= stop_price
            target_hit = favorable_price >= target_price if direction == 1 else favorable_price <= target_price
            if stop_hit:  # conservative same-minute ordering and adverse opening gaps
                opening = float(bar["open"])
                raw_exit = min(stop_price, opening) if direction == 1 else max(stop_price, opening)
                exit_bar_time, exit_reason = timestamp, "stop_loss"
                break
            if target_hit:
                raw_exit = target_price
                exit_bar_time, exit_reason = timestamp, "take_profit"
                break
        exit_pos = bars.index.get_loc(exit_bar_time)
        if exit_reason == "session_close" and exit_bar_time + pd.Timedelta(minutes=1) != bars.attrs["session_closes"][cutoff.date()]:
            raise ValueError("incomplete holding-window data before official session close")
        exit_volume = bars.iloc[exit_pos - 1].get("volume") if exit_pos else None
        try:
            exit_costs = fill_costs(raw_exit, quantity, -direction, config, exit_volume)
        except CapacityUnavailable as exc:
            raise ValueError(f"unpriceable exit ({exc}); performance cannot discard an entered trade") from exc
        gross_pnl = direction * quantity * (raw_exit - raw_entry)
        components = {
            name: getattr(entry_costs, name) + getattr(exit_costs, name)
            for name in ("commission_cost", "spread_cost", "slippage_cost", "impact_cost")
        }
        cost = sum(components.values())
        net_pnl = gross_pnl - cost
        if not np.isfinite([gross_pnl, cost, net_pnl, *components.values()]).all():
            raise ValueError("nonfinite trade economics; cannot publish P&L")
        # Bar extrema/close are only observed when this minute has finished.
        exit_time = exit_bar_time + pd.Timedelta(minutes=1)
        active_exits.append(exit_time)
        trades.append({
            "trade_id": str(uuid.uuid5(uuid.NAMESPACE_URL, f"quant-research:{getattr(signal, 'candidate_id', '')}:{cutoff}:{signal.setup_type}:{direction}:{bars.index[pos]}")),
            "date": cutoff.date(), "setup": signal.setup_type,
            "direction": direction, "signal_time": cutoff, "signal_bar_time": signal_bar_time,
            "entry_time": bars.index[pos],
            "exit_time": exit_time, "underlying_entry": entry_costs.fill_price,
            "underlying_exit": exit_costs.fill_price, "raw_entry": raw_entry, "raw_exit": raw_exit,
            "quantity": quantity, "trade_notional": notional, "gross_pnl": gross_pnl, "cost": cost,
            "net_pnl": net_pnl, **components, "break_even_return_bps": cost / notional * 10_000,
            "MFE": favorable_max, "MAE": abs(adverse_min), "exit_reason": exit_reason,
            "model_probability": probability, "score": score, "fold": int(signal.fold),
            "gross_return": gross_pnl / notional, "net_return": net_pnl / notional,
            "holding_minutes": int((exit_time - bars.index[pos]).total_seconds() / 60),
            "entry_participation_rate": entry_costs.participation_rate,
            "exit_participation_rate": exit_costs.participation_rate,
            "capacity_status": "prior_bar_proxy_checked" if config.execution_costs.require_volume_capacity else "not_checked",
            "cost_model_status": "RESEARCH_ASSUMPTIONS_NOT_CALIBRATED",
            "latency_ms": config.execution_costs.latency_ms,
        })
    result = pd.DataFrame(trades, columns=TRADE_COLUMNS)
    result.attrs["execution_rejections"] = rejections
    return result

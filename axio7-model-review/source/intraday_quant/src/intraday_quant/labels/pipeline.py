from __future__ import annotations

import numpy as np
import pandas as pd

from intraday_quant.config import AppConfig
from intraday_quant.backtest.costs import minimum_round_trip_cost_return
from intraday_quant.calendar import market_schedule


def _valid_window(window: pd.DataFrame) -> bool:
    if window.empty:
        return False
    prices = window[["open", "high", "low", "close"]].astype(float)
    if not np.isfinite(prices.to_numpy()).all() or (prices <= 0).any().any():
        return False
    if ((prices["high"] < prices[["open", "close", "low"]].max(axis=1))
            | (prices["low"] > prices[["open", "close", "high"]].min(axis=1))).any():
        return False
    return window.index.to_series().diff().iloc[1:].eq(pd.Timedelta(minutes=1)).all()


def build_labels(candidates: pd.DataFrame, features: pd.DataFrame, config: AppConfig) -> pd.DataFrame:
    if candidates.empty:
        return candidates.copy()
    bars = features.set_index("timestamp").sort_index()
    if bars.empty:
        return pd.DataFrame()
    session_closes = market_schedule(str(bars.index.min().date()), str(bars.index.max().date()), config.timezone)["close"].to_dict()
    rows: list[dict[str, object]] = []
    max_h = max(config.forecast_horizons)
    for candidate in candidates.itertuples(index=False):
        decision_as_of = candidate.timestamp + pd.Timedelta(minutes=1)
        earliest_after = decision_as_of + pd.Timedelta(milliseconds=config.execution_costs.latency_ms)
        pos = bars.index.searchsorted(earliest_after, side="left")
        if pos >= len(bars):
            continue
        entry_time = bars.index[pos]
        if entry_time.date() != candidate.timestamp.date():
            continue
        entry = float(bars.iloc[pos]["open"])
        if not np.isfinite(entry) or entry <= 0:
            continue
        row = candidate._asdict()
        row.update({"signal_time": decision_as_of, "signal_bar_time": candidate.timestamp,
                    "earliest_entry": entry_time, "label_entry_price": entry})
        direction = int(candidate.direction)
        for horizon in config.forecast_horizons:
            window = bars.iloc[pos:pos + horizon]
            if (len(window) < horizon or window.index[-1].date() != candidate.timestamp.date()
                    or not _valid_window(window)):
                row[f"forward_return_{horizon}m"] = np.nan
                row[f"MFE_{horizon}m"] = np.nan
                row[f"MAE_{horizon}m"] = np.nan
                row[f"forward_available_at_{horizon}m"] = pd.NaT
                row[f"label_rejection_reason_{horizon}m"] = "incomplete_discontinuous_or_invalid_price_window"
                continue
            signed_close = direction * (float(window.iloc[-1]["close"]) / entry - 1)
            favorable = direction * (window["high" if direction == 1 else "low"] / entry - 1)
            adverse = direction * (window["low" if direction == 1 else "high"] / entry - 1)
            row[f"forward_return_{horizon}m"] = signed_close
            row[f"forward_available_at_{horizon}m"] = window.index[-1] + pd.Timedelta(minutes=1)
            row[f"MFE_{horizon}m"] = max(0.0, float(favorable.max()))
            row[f"MAE_{horizon}m"] = abs(min(0.0, float(adverse.min())))
            row[f"time_to_MFE_{horizon}m"] = int(np.argmax(favorable.to_numpy())) + 1
            row[f"time_to_MAE_{horizon}m"] = int(np.argmin(adverse.to_numpy())) + 1
        state_pos = bars.index.searchsorted(candidate.timestamp, side="right") - 1
        atr = float(bars.iloc[state_pos].get("rolling_atr", np.nan)) if state_pos >= 0 else np.nan
        if not np.isfinite(atr) or atr <= 0:
            # An unavailable state must not create invented barriers or targets.
            continue
        tp = config.risk.take_profit_value * atr / entry
        sl = config.risk.stop_value * atr / entry
        barrier_window = bars.iloc[pos:pos + min(config.risk.max_holding_minutes, max_h)]
        barrier_window = barrier_window.loc[barrier_window.index.date == candidate.timestamp.date()]
        close_time = session_closes.get(candidate.timestamp.date())
        expected_barrier_count = min(config.risk.max_holding_minutes, max_h)
        if close_time is not None:
            expected_barrier_count = min(expected_barrier_count, max(0, int((close_time - entry_time).total_seconds() / 60)))
        barrier_valid = (close_time is not None and len(barrier_window) == expected_barrier_count
                         and _valid_window(barrier_window))
        if not barrier_valid:
            barrier_window = barrier_window.iloc[0:0]
        hit_tp = False
        hit_sl = False
        barrier_return = np.nan
        barrier_mfe = 0.0
        barrier_mae = 0.0
        for quote in barrier_window.itertuples():
            high_ret = direction * (getattr(quote, "high" if direction == 1 else "low") / entry - 1)
            low_ret = direction * (getattr(quote, "low" if direction == 1 else "high") / entry - 1)
            barrier_mfe = max(barrier_mfe, high_ret)
            barrier_mae = max(barrier_mae, -low_ret)
            this_tp = high_ret >= tp
            this_sl = low_ret <= -sl
            if this_sl:  # conservative ordering when both occur in one minute
                stop_price = entry - direction * config.risk.stop_value * atr
                opening = float(quote.open)
                stopped_price = min(stop_price, opening) if direction == 1 else max(stop_price, opening)
                hit_sl, barrier_return = True, direction * (stopped_price / entry - 1)
                break
            if this_tp:
                hit_tp, barrier_return = True, tp
                break
        if not hit_tp and not hit_sl and len(barrier_window):
            barrier_return = direction * (float(barrier_window.iloc[-1]["close"]) / entry - 1)
        cost_return = minimum_round_trip_cost_return(config)
        row.update({
            "hit_take_profit_first": hit_tp, "hit_stop_loss_first": hit_sl,
            "triple_barrier_return": barrier_return,
            "triple_barrier_mfe": max(0.0, barrier_mfe),
            "triple_barrier_mae": max(0.0, barrier_mae),
            "net_return_after_cost": barrier_return - cost_return if np.isfinite(barrier_return) else np.nan,
            "profitable_after_cost": bool(np.isfinite(barrier_return) and barrier_return > cost_return),
            "label_cost_basis": "pre_trade_baseline_excludes_size_impact",
            "barrier_label_status": "available" if barrier_valid else "withheld_incomplete_discontinuous_or_invalid_price_window",
        })
        rows.append(row)
    return pd.DataFrame(rows)


def save_labels(labels: pd.DataFrame, config: AppConfig) -> None:
    path = config.output_dir / "features" / "labels.parquet"
    path.parent.mkdir(parents=True, exist_ok=True)
    labels.to_parquet(path, index=False)

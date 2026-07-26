from __future__ import annotations

import numpy as np
import pandas as pd

from intraday_quant.config import AppConfig


def build_labels(candidates: pd.DataFrame, features: pd.DataFrame, config: AppConfig) -> pd.DataFrame:
    if candidates.empty:
        return candidates.copy()
    bars = features.set_index("timestamp").sort_index()
    rows: list[dict[str, object]] = []
    max_h = max(config.forecast_horizons)
    for candidate in candidates.itertuples(index=False):
        pos = bars.index.searchsorted(candidate.timestamp, side="right")
        if pos >= len(bars):
            continue
        entry_time = bars.index[pos]
        if entry_time.date() != candidate.timestamp.date():
            continue
        entry = float(bars.iloc[pos]["open"])
        row = candidate._asdict()
        row.update({"signal_time": candidate.timestamp, "earliest_entry": entry_time, "label_entry_price": entry})
        direction = int(candidate.direction)
        for horizon in config.forecast_horizons:
            window = bars.iloc[pos:pos + horizon]
            if len(window) < horizon or window.index[-1].date() != candidate.timestamp.date():
                row[f"forward_return_{horizon}m"] = np.nan
                row[f"MFE_{horizon}m"] = np.nan
                row[f"MAE_{horizon}m"] = np.nan
                continue
            signed_close = direction * (float(window.iloc[-1]["close"]) / entry - 1)
            favorable = direction * (window["high" if direction == 1 else "low"] / entry - 1)
            adverse = direction * (window["low" if direction == 1 else "high"] / entry - 1)
            row[f"forward_return_{horizon}m"] = signed_close
            row[f"MFE_{horizon}m"] = max(0.0, float(favorable.max()))
            row[f"MAE_{horizon}m"] = abs(min(0.0, float(adverse.min())))
            row[f"time_to_MFE_{horizon}m"] = int(np.argmax(favorable.to_numpy())) + 1
            row[f"time_to_MAE_{horizon}m"] = int(np.argmin(adverse.to_numpy())) + 1
        atr = float(bars.iloc[pos].get("rolling_atr", np.nan))
        if not np.isfinite(atr):
            atr = entry * 0.001
        tp = config.risk.take_profit_value * atr / entry
        sl = config.risk.stop_value * atr / entry
        barrier_window = bars.iloc[pos:pos + min(config.risk.max_holding_minutes, max_h)]
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
                hit_sl, barrier_return = True, -sl
                break
            if this_tp:
                hit_tp, barrier_return = True, tp
                break
        if not hit_tp and not hit_sl and len(barrier_window):
            barrier_return = direction * (float(barrier_window.iloc[-1]["close"]) / entry - 1)
        cost_return = (2 * (config.costs.underlying_slippage_bps + config.costs.estimated_spread_bps)) / 10_000
        row.update({
            "hit_take_profit_first": hit_tp, "hit_stop_loss_first": hit_sl,
            "triple_barrier_return": barrier_return,
            "triple_barrier_mfe": max(0.0, barrier_mfe),
            "triple_barrier_mae": max(0.0, barrier_mae),
            "net_return_after_cost": barrier_return - cost_return if np.isfinite(barrier_return) else np.nan,
            "profitable_after_cost": bool(np.isfinite(barrier_return) and barrier_return > cost_return),
        })
        rows.append(row)
    return pd.DataFrame(rows)


def save_labels(labels: pd.DataFrame, config: AppConfig) -> None:
    path = config.output_dir / "features" / "labels.parquet"
    path.parent.mkdir(parents=True, exist_ok=True)
    labels.to_parquet(path, index=False)

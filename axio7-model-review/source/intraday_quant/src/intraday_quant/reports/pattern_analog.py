from __future__ import annotations

import numpy as np
import pandas as pd


ANALOG_FEATURES = [
    "ret_1m", "ret_3m", "ret_5m", "ret_15m", "ret_30m", "dist_vwap",
    "session_range_position", "rolling_realized_vol", "high_low_range_zscore",
    "rvol_same_minute", "volume_zscore", "volume_acceleration", "buy_pressure_proxy",
    "cross_asset_breadth_score", "market_confirmation_score", "vix_change_5m", "vix_change_15m",
]


def closing_state_analogs(features: pd.DataFrame, target_date: str, minute_of_day: int = 950, k: int = 10) -> pd.DataFrame:
    """Compare a 15:50 state only with earlier 15:50 states; no target-day future enters distance."""
    frame = features.copy().sort_values("timestamp")
    frame["date_string"] = frame["timestamp"].dt.strftime("%Y-%m-%d")
    states = frame[frame["minute_of_day"] == minute_of_day].drop_duplicates("date_string", keep="last")
    target_rows = states[states["date_string"] == target_date]
    if target_rows.empty:
        raise ValueError(f"no {minute_of_day} state for {target_date}")
    history = states[states["date_string"] < target_date].copy()
    if history.empty:
        raise ValueError("no earlier sessions available for analog search")
    columns = [column for column in ANALOG_FEATURES if column in history]
    train = history[columns].apply(pd.to_numeric, errors="coerce").astype(float).replace([np.inf, -np.inf], np.nan)
    medians = train.median()
    train = train.fillna(medians).fillna(0.0)
    scale = train.std(ddof=0).replace(0, 1.0)
    target = pd.to_numeric(target_rows.iloc[0][columns], errors="coerce").astype(float)
    target = target.replace([np.inf, -np.inf], np.nan).fillna(medians).fillna(0.0)
    distances = np.sqrt((((train - target) / scale) ** 2).mean(axis=1))
    history["distance"] = distances.to_numpy()
    history["similarity"] = 1 / (1 + history["distance"])

    closes = frame.pivot_table(index="date_string", columns="minute_of_day", values="close", aggfunc="last")
    close_minute = max([column for column in closes.columns if column < 960], default=959)
    history["return_1550_to_close"] = history["date_string"].map(closes[close_minute] / closes.get(minute_of_day) - 1)
    target_actual = float(closes.loc[target_date, close_minute] / closes.loc[target_date, minute_of_day] - 1)
    output = history.sort_values("distance").head(k).copy()
    output.insert(0, "rank", range(1, len(output) + 1))
    output["target_date"] = target_date
    output["target_actual_return_1550_to_close"] = target_actual
    return output[[
        "rank", "target_date", "date_string", "distance", "similarity",
        "return_1550_to_close", "target_actual_return_1550_to_close",
        "ret_5m", "ret_15m", "volume_zscore", "buy_pressure_proxy",
        "cross_asset_breadth_score", "closing_short_cover_score",
    ]]

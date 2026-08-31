from __future__ import annotations

import numpy as np
import pandas as pd

from intraday_quant.config import AppConfig
from intraday_quant.models.specification import score_candidates


def _promotion_eligible_predictions(predictions: pd.DataFrame) -> pd.DataFrame:
    """Exclude explicitly non-promotion estimators before any ensemble or trade."""

    if "promotion_eligible" not in predictions.columns:
        return predictions
    eligible = predictions["promotion_eligible"].astype("boolean").fillna(True)
    return predictions.loc[eligible].copy()


def score_and_select(predictions: pd.DataFrame, candidates: pd.DataFrame, config: AppConfig) -> tuple[pd.DataFrame, pd.DataFrame]:
    if predictions.empty:
        empty = candidates.copy()
        empty["rejection_reason"] = "no_out_of_sample_prediction"
        return pd.DataFrame(), empty
    predictions = _promotion_eligible_predictions(predictions)
    if predictions.empty:
        empty = candidates.copy()
        empty["rejection_reason"] = "no_promotion_eligible_out_of_sample_prediction"
        return pd.DataFrame(), empty
    numeric = ["expected_return", "median_return", "win_probability", "predicted_mfe", "predicted_mae", "uncertainty", "similarity_score"]
    if "horizon_minutes" not in predictions.columns:
        raise ValueError("predictions must identify horizon_minutes")
    ensemble = predictions.groupby(
        ["candidate_id", "timestamp", "fold", "horizon_minutes"], as_index=False
    )[numeric + ["validation_return_threshold"]].mean()
    merged = ensemble.merge(candidates.drop(columns=["timestamp"], errors="ignore"), on="candidate_id", how="left")
    cost_return = 2 * (config.costs.underlying_slippage_bps + config.costs.estimated_spread_bps) / 10_000
    merged = score_candidates(merged, config)
    merged["rejection_reason"] = ""
    threshold_fail = merged["expected_return"] <= np.maximum(merged["validation_return_threshold"], cost_return)
    merged.loc[threshold_fail, "rejection_reason"] = "below_validation_threshold_or_cost"
    selected_idx: list[int] = []
    for _, daily in merged.sort_values("score", ascending=False).groupby("session_date"):
        selected_directions: dict[int, int] = {}
        selected_times: list[pd.Timestamp] = []
        for idx, row in daily.iterrows():
            if row["rejection_reason"]:
                continue
            if len(selected_idx) and len([i for i in selected_idx if merged.loc[i, "session_date"] == row["session_date"]]) >= config.portfolio.max_trades_per_day:
                merged.loc[idx, "rejection_reason"] = "daily_trade_limit"
                continue
            direction = int(row["direction"])
            if selected_directions.get(direction, 0) >= config.portfolio.max_same_direction_per_day:
                merged.loc[idx, "rejection_reason"] = "same_direction_limit"
                continue
            if any(abs((row["timestamp"] - t).total_seconds()) < config.portfolio.cooldown_minutes * 60 for t in selected_times):
                merged.loc[idx, "rejection_reason"] = "cooldown_or_correlated_signal"
                continue
            selected_idx.append(idx)
            selected_directions[direction] = selected_directions.get(direction, 0) + 1
            selected_times.append(row["timestamp"])
    selected = merged.loc[selected_idx].copy().sort_values("timestamp")
    rejected = merged.drop(index=selected_idx).copy().sort_values("timestamp")
    if config.portfolio.max_trades_per_day == 0:
        selected = selected.iloc[0:0]
        merged["rejection_reason"] = "daily_trade_limit_zero"
        rejected = merged
    return selected.reset_index(drop=True), rejected.reset_index(drop=True)

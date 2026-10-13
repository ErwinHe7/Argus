from __future__ import annotations

import numpy as np
import pandas as pd

from intraday_quant.config import AppConfig
from intraday_quant.backtest.costs import minimum_round_trip_cost_return
from intraday_quant.models.specification import score_candidates


def score_and_select(predictions: pd.DataFrame, candidates: pd.DataFrame, config: AppConfig) -> tuple[pd.DataFrame, pd.DataFrame]:
    if predictions.empty:
        empty = candidates.copy()
        empty["rejection_reason"] = "no_out_of_sample_prediction"
        return pd.DataFrame(), empty
    # The quantctl analog bridge emits raw zero-return directional frequencies,
    # not calibrated profitability under this strategy's explicit cost labels.
    # Keep those rows in prediction/report artifacts, but never average them
    # into the calibrated strategy probabilities.
    raw_analog = predictions.get("model", pd.Series("", index=predictions.index)).eq("analog_kernel")
    unsupported_ids = set(predictions.loc[raw_analog, "candidate_id"])
    predictions = predictions.loc[~raw_analog].copy()
    unsupported_ids -= set(predictions["candidate_id"])
    unsupported_rejections = candidates.loc[candidates["candidate_id"].isin(unsupported_ids)].copy()
    unsupported_rejections["rejection_reason"] = "unsupported_probability_semantics"
    if predictions.empty:
        rejected = candidates.copy()
        rejected["rejection_reason"] = np.where(
            rejected["candidate_id"].isin(unsupported_ids), "unsupported_probability_semantics", "no_out_of_sample_prediction"
        )
        return pd.DataFrame(), rejected
    numeric = ["expected_return", "median_return", "win_probability", "predicted_mfe", "predicted_mae", "uncertainty", "similarity_score"]
    if "horizon_minutes" not in predictions.columns:
        raise ValueError("predictions must identify horizon_minutes")
    ensemble = predictions.groupby(
        ["candidate_id", "timestamp", "fold", "horizon_minutes"], as_index=False
    )[numeric + ["validation_return_threshold"]].mean()
    merged = ensemble.merge(candidates.drop(columns=["timestamp"], errors="ignore"), on="candidate_id", how="left")
    cost_return = minimum_round_trip_cost_return(config)
    merged = score_candidates(merged, config)
    merged["rejection_reason"] = ""
    nonfinite = ~np.isfinite(merged[numeric + ["validation_return_threshold", "score"]].to_numpy(dtype=float)).all(axis=1)
    merged.loc[nonfinite, "rejection_reason"] = "nonfinite_prediction"
    threshold_fail = merged["expected_return"] <= np.maximum(merged["validation_return_threshold"], cost_return)
    merged.loc[threshold_fail & ~nonfinite, "rejection_reason"] = "below_validation_threshold_or_cost"
    selected_idx: list[int] = []
    ordered = merged.sort_values(
        ["timestamp", "score", "candidate_id", "horizon_minutes"], ascending=[True, False, True, True], kind="stable"
    )
    for _, daily in ordered.groupby("session_date", sort=False):
        selected_directions: dict[int, int] = {}
        selected_times: list[pd.Timestamp] = []
        selected_candidates: set[str] = set()
        for idx, row in daily.iterrows():
            if row["rejection_reason"]:
                continue
            if len(selected_times) >= config.portfolio.max_trades_per_day:
                merged.loc[idx, "rejection_reason"] = "daily_trade_limit"
                continue
            if row["candidate_id"] in selected_candidates:
                merged.loc[idx, "rejection_reason"] = "candidate_already_selected_at_another_horizon"
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
            selected_candidates.add(row["candidate_id"])
    selected = merged.loc[selected_idx].copy().sort_values("timestamp")
    rejected = merged.drop(index=selected_idx).copy().sort_values("timestamp")
    if config.portfolio.max_trades_per_day == 0:
        selected = selected.iloc[0:0]
        merged["rejection_reason"] = "daily_trade_limit_zero"
        rejected = merged
    if not unsupported_rejections.empty:
        rejected = pd.concat([rejected, unsupported_rejections], ignore_index=True).sort_values("timestamp")
    return selected.reset_index(drop=True), rejected.reset_index(drop=True)

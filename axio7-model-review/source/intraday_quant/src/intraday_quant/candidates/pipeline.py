from __future__ import annotations

import json

import numpy as np
import pandas as pd

from intraday_quant.config import AppConfig


def generate_candidates(features: pd.DataFrame, config: AppConfig) -> pd.DataFrame:
    df = features.copy().sort_values("timestamp")
    candidates: list[dict[str, object]] = []
    previous = df.groupby("session_date").shift(1)

    def add(mask: pd.Series, setup: str, direction: pd.Series, reasons: list[str]) -> None:
        for idx in df.index[mask.fillna(False)]:
            row = df.loc[idx]
            snapshot_cols = ["ret_5m", "ret_15m", "dist_vwap", "rvol_same_minute", "volume_acceleration", "market_confirmation_score", "rolling_atr"]
            snapshot = {c: (None if pd.isna(row.get(c)) else float(row.get(c))) for c in snapshot_cols}
            candidates.append({
                "candidate_id": f"{row['timestamp'].strftime('%Y%m%dT%H%M')}-{setup}-{int(direction.loc[idx]):+d}",
                "timestamp": row["timestamp"], "session_date": row["session_date"],
                "setup_type": setup, "direction": int(direction.loc[idx]),
                "entry_reference": float(row["close"]), "feature_snapshot": json.dumps(snapshot, sort_keys=True),
                "reason_codes": "|".join(reasons),
            })

    if "opening_range_breakout" in config.setups:
        up = (df["close"] > df["opening_range_high"]) & (previous["close"] <= previous["opening_range_high"])
        down = (df["close"] < df["opening_range_low"]) & (previous["close"] >= previous["opening_range_low"])
        confirmation = (df["market_confirmation_score"].abs() > 0.05) | (df["rvol_same_minute"] > 0.8)
        add((up | down) & confirmation, "opening_range_breakout", pd.Series(np.where(up, 1, -1), index=df.index), ["opening_range_cross", "market_or_volume_confirmation"])
    if "vwap_pullback" in config.setups:
        trend = df["ret_15m"].abs() > df["rolling_realized_vol"].fillna(0) * 2
        reclaim_up = (df["close"] > df["session_vwap"]) & (previous["close"] <= previous["session_vwap"])
        reclaim_down = (df["close"] < df["session_vwap"]) & (previous["close"] >= previous["session_vwap"])
        volume_ok = df["volume_acceleration"].fillna(0) > -0.25
        add(trend & volume_ok & (reclaim_up | reclaim_down), "vwap_pullback", pd.Series(np.where(reclaim_up, 1, -1), index=df.index), ["vwap_cross", "prior_trend", "volume_not_collapsing"])
    if "mean_reversion" in config.setups:
        extreme = df["ret_15m"].abs() > (df["rolling_realized_vol"].fillna(np.inf) * 3.0)
        far = df["dist_vwap"].abs() > 0.0008
        decel = df["volume_acceleration"].fillna(0) < 0.35
        direction = pd.Series(np.where(df["ret_15m"] < 0, 1, -1), index=df.index)
        add(extreme & far & decel, "mean_reversion", direction, ["extreme_return", "vwap_extension", "volume_deceleration"])
    if "closing_short_cover" in config.setups:
        closing = df["closing_10m"].fillna(False)
        acceleration = (df["ret_5m"] > 0.0005) & (df["ret_1m"] > 0)
        pressure = (df["buy_pressure_proxy"] > 0.5) | (df["volume_zscore"] > 1.0)
        confirmed = df["cross_asset_breadth_score"].fillna(0) > 0.2
        # Covering can begin after an outright decline (7/16-like) or while
        # price is still below session VWAP despite a recent rebound (7/2-like).
        prior_weakness = (df["ret_30m"].fillna(0) < 0.001) | (df["dist_vwap"].fillna(0) < 0)
        add(closing & acceleration & pressure & confirmed & prior_weakness,
            "closing_short_cover", pd.Series(1, index=df.index),
            ["closing_10m", "upside_acceleration", "below_vwap_or_prior_weakness", "buy_pressure_proxy", "cross_asset_confirmation"])
    result = pd.DataFrame(candidates)
    if result.empty:
        return pd.DataFrame(columns=["candidate_id", "timestamp", "session_date", "setup_type", "direction", "entry_reference", "feature_snapshot", "reason_codes"])
    result = result.drop_duplicates(["timestamp", "setup_type", "direction"])
    context_cols = ["timestamp", "ret_15m", "dist_vwap", "volume_zscore", "market_confirmation_score"]
    for column in context_cols[1:]:
        if column not in df:
            df[column] = 0.0
    context = df[context_cols].drop_duplicates("timestamp")
    result = result.merge(context, on="timestamp", how="left")
    result["candidate_strength"] = (
        result["ret_15m"].abs().fillna(0) * 1_000
        + result["dist_vwap"].abs().fillna(0) * 500
        + result["volume_zscore"].abs().fillna(0)
        + result["market_confirmation_score"].abs().clip(upper=5).fillna(0)
        + np.where(result["setup_type"] == "closing_short_cover", 5.0, 0.0)
    )
    # Consume the existing ten research slots online. Strength only breaks
    # same-timestamp ties; an afternoon anomaly cannot replace a morning state.
    result = result.sort_values(
        ["timestamp", "candidate_strength", "candidate_id"], ascending=[True, False, True], kind="stable"
    ).groupby("session_date", sort=False).head(10)
    return result.drop(columns=["ret_15m", "dist_vwap", "volume_zscore", "market_confirmation_score"]).sort_values("timestamp").reset_index(drop=True)


def save_candidates(candidates: pd.DataFrame, config: AppConfig) -> None:
    path = config.output_dir / "features" / "candidates.parquet"
    path.parent.mkdir(parents=True, exist_ok=True)
    candidates.to_parquet(path, index=False)

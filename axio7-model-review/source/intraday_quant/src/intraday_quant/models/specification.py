from __future__ import annotations

from typing import Any

import numpy as np
import pandas as pd

from intraday_quant.config import AppConfig


MODEL_SPECIFICATION: dict[str, Any] = {
    "version": "1.0.0",
    "signal_timing": {
        "information_set": "F_t = sigma(all observations timestamped at or before minute t close)",
        "signal_time": "minute t close",
        "earliest_fill": "minute t+1 open or first later valid executable quote",
    },
    "targets": {
        "direction": "P(r_net(t,t+h) > 0 | F_t), h in {5,15,30,60}",
        "return": "E[r_net(t,t+h) | F_t]",
        "excursions": "E[MFE_h | F_t], E[MAE_h | F_t]",
        "triple_barrier": "first passage of upper/lower ATR barrier, otherwise time barrier",
    },
    "analog_kernel": {
        "distance": "d_i(x)=sqrt(mean_j(((x_j-mu_j_train)/sigma_j_train - z_ij)^2))",
        "eligibility": "timestamp_i < timestamp_query; training-fold observations only",
        "weight": "w_i=exp(-0.5*(d_i/bandwidth)^2)/sum_k exp(-0.5*(d_k/bandwidth)^2)",
        "outputs": [
            "sum(w_i*r_i)",
            "weighted win probability",
            "weighted MFE/MAE",
            "weighted return dispersion",
        ],
    },
    "ensemble": {
        "families": ["logistic_regression", "gaussian_kernel_analog", "hist_gradient_boosting"],
        "aggregation": "arithmetic mean across available out-of-sample family predictions",
        "calibration": "Platt or isotonic fit on validation only; Brier score reported",
    },
    "execution": {
        "underlying_entry": "next bar open adjusted against the trader by configured slippage",
        "option_entry": "first valid NBBO after signal, ask + option slippage",
        "option_exit": "valid NBBO bid - option slippage",
        "collision": "if stop and target are both inside one bar, stop is assumed first",
    },
    "selection": {
        "expected_net_return": "mu_hat - 2*(spread_bps+slippage_bps)/10000",
        "score": "(wr*mu_net*(p0+p_win)+wmfe*MFE_hat) / max(MAE_hat+wunc*uncertainty,risk_floor)",
        "threshold": "expected return must exceed a validation-derived quantile and modeled costs",
        "constraints": [
            "0..max_trades_per_day",
            "max one open position",
            "cooldown",
            "same-direction cap",
            "no-trade is valid",
        ],
    },
    "validation": {
        "split": "purged walk-forward train/validation/test; never shuffled",
        "normalization": "fit on training fold only",
        "model_and_threshold_selection": "validation only",
        "reported_strategy_performance": "test folds only",
    },
}


def score_candidates(frame: pd.DataFrame, config: AppConfig) -> pd.DataFrame:
    """Apply the documented utility equation without inspecting realized outcomes."""

    result = frame.copy()
    round_trip_market_cost = 2 * (
        config.costs.underlying_slippage_bps + config.costs.estimated_spread_bps
    ) / 10_000
    result["expected_net_return"] = result["expected_return"] - round_trip_market_cost
    floor = config.portfolio.risk_floor_bps / 10_000
    coefficients = config.scoring
    numerator = (
        coefficients.return_weight
        * result["expected_net_return"]
        * (coefficients.probability_base + result["win_probability"])
        + coefficients.mfe_weight * result["predicted_mfe"]
    )
    denominator = np.maximum(
        result["predicted_mae"] + coefficients.uncertainty_weight * result["uncertainty"],
        floor,
    )
    result["score"] = numerator / denominator
    return result


def model_specification(config: AppConfig | None = None) -> dict[str, Any]:
    spec = {**MODEL_SPECIFICATION}
    if config is not None:
        spec = {
            **spec,
            "active_parameters": {
                "forecast_horizons": config.forecast_horizons,
                "models": config.models,
                "setups": config.setups,
                "analog_neighbors": config.model.analog_neighbors,
                "analog_bandwidth": config.model.analog_bandwidth,
                "calibration": config.model.calibration,
                "validation_quantile": config.model.score_threshold_quantile,
                "score_coefficients": config.scoring.model_dump(),
                "risk_floor_bps": config.portfolio.risk_floor_bps,
                "max_trades_per_day": config.portfolio.max_trades_per_day,
            },
        }
    return spec

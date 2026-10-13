from __future__ import annotations

from typing import Any

import numpy as np
import pandas as pd

from intraday_quant.config import AppConfig
from intraday_quant.backtest.costs import minimum_round_trip_cost_return


MODEL_SPECIFICATION: dict[str, Any] = {
    "version": "1.2.0",
    "signal_timing": {
        "bar_timestamp": "one-minute interval start; its closing features become available at timestamp + 1 minute",
        "information_set": "F_t includes only observations available at the actual minute close cutoff",
        "signal_time": "bar timestamp + 1 minute",
        "earliest_fill": "first bar start >= actual close cutoff + latency; zero latency permits an explicitly idealized boundary fill",
    },
    "targets": {
        "direction": "P(r_gross(t,t+h) > pre_trade_cost_baseline | F_t), h in {5,15,30,60}; future size impact excluded",
        "return": "E[r_gross(t,t+h) | F_t]; scoring separately subtracts the pre-trade cost baseline",
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
        "families": ["logistic_regression", "hist_gradient_boosting"],
        "research_only": ["production_hmm_kernel_raw_up_frequency"],
        "aggregation": "arithmetic mean across available classical out-of-sample predictions; raw analog probabilities excluded",
        "calibration": "Platt or isotonic fit on validation only; Brier score reported",
    },
    "execution": {
        "underlying_entry": "post-latency open plus adverse half-spread, slippage and optional size impact",
        "option_entry": "first valid NBBO after signal, ask + option slippage",
        "option_exit": "valid NBBO bid - option slippage",
        "collision": "if stop and target are both inside one bar, stop is assumed first",
    },
    "selection": {
        "expected_net_return": "mu_hat - (full_spread_bps+2*slippage_bps)/10000 - 2*commission_per_side/trade_notional; excludes unknown size impact",
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
    round_trip_market_cost = minimum_round_trip_cost_return(config)
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
                "costs": config.costs.model_dump(),
                "execution_costs": config.execution_costs.model_dump(),
                "risk_floor_bps": config.portfolio.risk_floor_bps,
                "max_trades_per_day": config.portfolio.max_trades_per_day,
            },
        }
    return spec

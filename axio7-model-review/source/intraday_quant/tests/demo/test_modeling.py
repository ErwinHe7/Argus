from __future__ import annotations

import numpy as np
import pandas as pd
import pytest
from sklearn.metrics import accuracy_score, mean_absolute_error, mean_squared_error

from intraday_quant.demo.features import FEATURE_COLUMNS
from intraday_quant.demo.modeling import (
    fit_models,
    fit_residual_interval,
    predict_examples,
    evaluate_predictions,
)


def model_frame(rows: int, seed: int) -> pd.DataFrame:
    """Build finite, non-degenerate causal-example-shaped rows for model tests."""
    rng = np.random.default_rng(seed)
    frame = pd.DataFrame(rng.normal(size=(rows, len(FEATURE_COLUMNS))), columns=FEATURE_COLUMNS)
    signal = frame["ret_5m"] + 0.25 * frame["dist_session_vwap"]
    frame["target_return"] = signal * 0.001
    frame["target_up"] = (frame["target_return"] > 0).astype(int)
    frame["close"] = 700.0
    frame["outcome_close"] = frame["close"] * (1.0 + frame["target_return"])
    frame["timestamp"] = pd.date_range(
        "2026-01-05 10:00", periods=rows, freq="1min", tz="UTC"
    )
    return frame


@pytest.fixture
def train_examples() -> pd.DataFrame:
    return model_frame(240, 7)


@pytest.fixture
def validation_examples() -> pd.DataFrame:
    return model_frame(120, 8)


def test_scalers_fit_training_rows_only(
    train_examples: pd.DataFrame, validation_examples: pd.DataFrame
) -> None:
    """Fails if either pipeline learns its scaling statistics from non-training rows."""
    bundle = fit_models(train_examples)

    expected = train_examples.loc[:, FEATURE_COLUMNS].mean().to_numpy()

    np.testing.assert_allclose(bundle.direction.named_steps["scale"].mean_, expected)
    np.testing.assert_allclose(bundle.return_model.named_steps["scale"].mean_, expected)
    assert bundle.feature_columns == FEATURE_COLUMNS
    assert bundle.training_up_rate == pytest.approx(train_examples.target_up.mean())
    assert bundle.direction_parameters == {
        "C": 1.0,
        "max_iter": 1000,
        "solver": "lbfgs",
        "random_state": 7,
    }
    assert bundle.return_parameters == {"alpha": 1.0}


def test_fit_models_rejects_non_finite_features(train_examples: pd.DataFrame) -> None:
    """Fails if the model layer silently imputes an unavailable feature."""
    invalid = train_examples.copy()
    invalid.loc[0, "ret_1m"] = np.nan

    with pytest.raises(ValueError, match="non-finite"):
        fit_models(invalid)


def test_residual_interval_uses_only_validation_return_errors(
    train_examples: pd.DataFrame, validation_examples: pd.DataFrame
) -> None:
    """Fails if residual bounds use another split or predicted returns instead of errors."""
    bundle = fit_models(train_examples)

    interval = fit_residual_interval(bundle, validation_examples)
    residuals = validation_examples.target_return.to_numpy() - bundle.return_model.predict(
        validation_examples.loc[:, FEATURE_COLUMNS]
    )

    assert interval.lower_return == pytest.approx(np.quantile(residuals, 0.10))
    assert interval.upper_return == pytest.approx(np.quantile(residuals, 0.90))
    assert interval.lower_quantile == 0.10
    assert interval.upper_quantile == 0.90
    assert interval.validation_examples == len(validation_examples)


def test_prediction_fields_are_precomputed(
    train_examples: pd.DataFrame, validation_examples: pd.DataFrame
) -> None:
    """Fails if browser-owned forecast arithmetic leaks out of the Python artifact layer."""
    bundle = fit_models(train_examples)
    interval = fit_residual_interval(bundle, validation_examples)

    predictions = predict_examples(bundle, validation_examples, interval)

    assert predictions.probability_up.between(0.0, 1.0).all()
    assert (predictions.interval_low <= predictions.scenario_price).all()
    assert (predictions.scenario_price <= predictions.interval_high).all()
    assert set(predictions.probability_status) == {"RAW_EXPERIMENTAL_PROBABILITY"}
    assert set(predictions.interval_status) == {"EXPLORATORY_VALIDATION_RESIDUAL_INTERVAL"}
    assert set(predictions.direction).issubset({"UP", "DOWN", "FLAT"})
    np.testing.assert_allclose(
        predictions.scenario_price,
        predictions.close * (1.0 + predictions.expected_return_bps / 10_000.0),
    )
    np.testing.assert_allclose(
        predictions.outcome_close,
        predictions.close * (1.0 + predictions.outcome_return_bps / 10_000.0),
    )


def test_metrics_include_approved_baselines_and_no_trading_metrics(
    train_examples: pd.DataFrame, validation_examples: pd.DataFrame
) -> None:
    """Fails if metrics omit required baselines or introduce strategy-performance outputs."""
    bundle = fit_models(train_examples)
    interval = fit_residual_interval(bundle, validation_examples)
    predictions = predict_examples(bundle, validation_examples, interval)

    metrics = evaluate_predictions(predictions, bundle.training_up_rate)
    majority_class = int(bundle.training_up_rate >= 0.5)
    expected_accuracy_baseline = accuracy_score(
        predictions.target_up, np.full(len(predictions), majority_class)
    )
    expected_zero_return_mae = mean_absolute_error(
        predictions.target_return, np.zeros(len(predictions))
    )
    expected_momentum_rmse = np.sqrt(
        mean_squared_error(predictions.target_return, predictions.ret_5m)
    )

    assert metrics["direction_accuracy_baseline"] == pytest.approx(expected_accuracy_baseline)
    assert metrics["return_mae_zero_return_baseline"] == pytest.approx(expected_zero_return_mae)
    assert metrics["return_rmse_momentum_baseline"] == pytest.approx(expected_momentum_rmse)
    assert metrics["direction_coverage_count"] == float(len(predictions))
    assert metrics["return_coverage_count"] == float(len(predictions))
    for key in (
        "direction_roc_auc",
        "direction_brier_score",
        "direction_log_loss",
        "return_mae",
        "return_rmse",
    ):
        assert np.isfinite(metrics[key])
    assert all("pnl" not in key.lower() and "sharpe" not in key.lower() for key in metrics)

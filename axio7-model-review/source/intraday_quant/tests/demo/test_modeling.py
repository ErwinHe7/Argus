from __future__ import annotations

import numpy as np
import pandas as pd
import pytest
from sklearn.metrics import (
    accuracy_score,
    brier_score_loss,
    log_loss,
    mean_absolute_error,
    mean_squared_error,
    roc_auc_score,
)

from intraday_quant.demo.features import FEATURE_COLUMNS
from intraday_quant.demo.modeling import (
    ValidationResidualInterval,
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


def test_one_sided_validation_residual_interval_remains_unclamped(
    train_examples: pd.DataFrame, validation_examples: pd.DataFrame
) -> None:
    """Fails if one-sided validation residual quantiles reject or alter predictions."""
    bundle = fit_models(train_examples)
    one_sided_validation = validation_examples.copy()
    predicted_return = bundle.return_model.predict(
        one_sided_validation.loc[:, FEATURE_COLUMNS]
    )
    residuals = np.linspace(0.0001, 0.0012, len(one_sided_validation))
    one_sided_validation["target_return"] = predicted_return + residuals
    one_sided_validation["target_up"] = (one_sided_validation.target_return > 0.0).astype(int)

    interval = fit_residual_interval(bundle, one_sided_validation)
    predictions = predict_examples(bundle, one_sided_validation, interval)

    assert interval.lower_return == pytest.approx(np.quantile(residuals, 0.10))
    assert interval.upper_return == pytest.approx(np.quantile(residuals, 0.90))
    assert interval.lower_return > 0.0
    assert (predictions.scenario_price < predictions.interval_low).all()


def test_reversed_validation_residual_interval_is_rejected(
    train_examples: pd.DataFrame, validation_examples: pd.DataFrame
) -> None:
    """Fails if modeling can emit a forecast whose interval bounds are reversed."""
    bundle = fit_models(train_examples)
    reversed_interval = ValidationResidualInterval(
        lower_return=0.001,
        upper_return=-0.001,
        lower_quantile=0.10,
        upper_quantile=0.90,
        validation_examples=len(validation_examples),
    )

    with pytest.raises(ValueError, match="ordered"):
        predict_examples(bundle, validation_examples, reversed_interval)


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
    target_up = predictions.target_up.to_numpy()
    probability_up = predictions.probability_up.to_numpy()
    baseline_probability = np.full(len(predictions), bundle.training_up_rate)
    majority_class = np.full(len(predictions), int(bundle.training_up_rate >= 0.5))
    safe = np.clip(probability_up, np.finfo(float).eps, 1.0 - np.finfo(float).eps)
    safe_baseline = np.clip(
        baseline_probability,
        np.finfo(float).eps,
        1.0 - np.finfo(float).eps,
    )

    def equal_count_ece(probabilities: np.ndarray) -> float:
        order = np.argsort(probabilities, kind="stable")
        return float(
            sum(
                (len(indices) / len(order))
                * abs(probabilities[indices].mean() - target_up[indices].mean())
                for indices in np.array_split(order, min(10, len(order)))
                if len(indices) > 0
            )
        )

    direction_cases = {
        "roc_auc": (
            roc_auc_score(target_up, probability_up),
            roc_auc_score(target_up, baseline_probability),
        ),
        "brier_score": (
            brier_score_loss(target_up, probability_up),
            brier_score_loss(target_up, baseline_probability),
        ),
        "log_loss": (
            log_loss(target_up, safe, labels=(0, 1)),
            log_loss(target_up, safe_baseline, labels=(0, 1)),
        ),
        "calibration_error": (
            equal_count_ece(probability_up),
            equal_count_ece(baseline_probability),
        ),
        "accuracy": (
            accuracy_score(target_up, probability_up >= 0.5),
            accuracy_score(target_up, majority_class),
        ),
    }
    for name, (value, baseline) in direction_cases.items():
        assert metrics[f"direction_{name}"] == pytest.approx(value)
        assert metrics[f"direction_{name}_baseline"] == pytest.approx(baseline)
        assert metrics[f"direction_{name}_delta"] == pytest.approx(value - baseline)

    target_return = predictions.target_return.to_numpy()
    expected_return = predictions.expected_return_bps.to_numpy() / 10_000.0
    zero_return = np.zeros(len(predictions))
    momentum = predictions.ret_5m.to_numpy()
    return_cases = {
        "mae": (
            mean_absolute_error(target_return, expected_return),
            mean_absolute_error(target_return, zero_return),
            mean_absolute_error(target_return, momentum),
        ),
        "rmse": (
            np.sqrt(mean_squared_error(target_return, expected_return)),
            np.sqrt(mean_squared_error(target_return, zero_return)),
            np.sqrt(mean_squared_error(target_return, momentum)),
        ),
    }
    for name, (value, zero_baseline, momentum_baseline) in return_cases.items():
        assert metrics[f"return_{name}"] == pytest.approx(value)
        assert metrics[f"return_{name}_zero_return_baseline"] == pytest.approx(
            zero_baseline
        )
        assert metrics[f"return_{name}_zero_return_delta"] == pytest.approx(
            value - zero_baseline
        )
        assert metrics[f"return_{name}_momentum_baseline"] == pytest.approx(
            momentum_baseline
        )
        assert metrics[f"return_{name}_momentum_delta"] == pytest.approx(
            value - momentum_baseline
        )

    assert metrics["direction_coverage_count"] == float(len(predictions))
    assert metrics["return_coverage_count"] == float(len(predictions))
    assert all(np.isfinite(value) for value in metrics.values())
    assert all("pnl" not in key.lower() and "sharpe" not in key.lower() for key in metrics)

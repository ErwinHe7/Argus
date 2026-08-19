"""Fixed, train-only baseline models for the causal SPY replay examples."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd
import sklearn
from sklearn.linear_model import LogisticRegression, Ridge
from sklearn.metrics import (
    accuracy_score,
    brier_score_loss,
    log_loss,
    mean_absolute_error,
    mean_squared_error,
    roc_auc_score,
)
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from intraday_quant.demo.features import FEATURE_COLUMNS


RAW_PROBABILITY_STATUS = "RAW_EXPERIMENTAL_PROBABILITY"
VALIDATION_RESIDUAL_INTERVAL_STATUS = "EXPLORATORY_VALIDATION_RESIDUAL_INTERVAL"
_TARGET_COLUMNS = ("target_return", "target_up")


@dataclass(frozen=True)
class ModelBundle:
    """Fitted fixed baselines and the immutable metadata needed to describe them."""

    direction: Pipeline
    return_model: Pipeline
    feature_columns: tuple[str, ...]
    training_up_rate: float
    sklearn_version: str
    direction_parameters: dict[str, float | int | str]
    return_parameters: dict[str, float | int | str]


@dataclass(frozen=True)
class ValidationResidualInterval:
    """Validation-only residual return quantiles for exploratory forecast bounds."""

    lower_return: float
    upper_return: float
    lower_quantile: float
    upper_quantile: float
    validation_examples: int


def _require_columns(frame: pd.DataFrame, columns: tuple[str, ...]) -> None:
    missing = [column for column in columns if column not in frame.columns]
    if missing:
        raise ValueError(f"examples are missing required columns: {missing}")


def _feature_matrix(frame: pd.DataFrame) -> pd.DataFrame:
    _require_columns(frame, FEATURE_COLUMNS)
    try:
        values = frame.loc[:, FEATURE_COLUMNS].to_numpy(dtype=float)
    except (TypeError, ValueError) as error:
        raise ValueError("examples contain non-numeric feature values") from error
    if not np.isfinite(values).all():
        raise ValueError("examples contain non-finite features")
    return pd.DataFrame(values, columns=FEATURE_COLUMNS, index=frame.index)


def _targets(frame: pd.DataFrame) -> tuple[np.ndarray, np.ndarray]:
    _require_columns(frame, _TARGET_COLUMNS)
    try:
        target_return = pd.to_numeric(frame["target_return"], errors="raise").to_numpy(dtype=float)
        target_up = pd.to_numeric(frame["target_up"], errors="raise").to_numpy(dtype=float)
    except (TypeError, ValueError) as error:
        raise ValueError("examples contain non-numeric targets") from error
    if not np.isfinite(target_return).all() or not np.isfinite(target_up).all():
        raise ValueError("examples contain non-finite targets")
    if not np.isin(target_up, (0.0, 1.0)).all():
        raise ValueError("target_up must contain only zero or one")
    return target_return, target_up.astype(int)


def _positive_close(frame: pd.DataFrame) -> np.ndarray:
    _require_columns(frame, ("close",))
    try:
        close = pd.to_numeric(frame["close"], errors="raise").to_numpy(dtype=float)
    except (TypeError, ValueError) as error:
        raise ValueError("examples contain non-numeric close values") from error
    if not np.isfinite(close).all() or not (close > 0.0).all():
        raise ValueError("examples must contain finite positive close values")
    return close


def fit_models(train: pd.DataFrame) -> ModelBundle:
    """Fit the fixed direction and return models using only supplied training rows."""
    features = _feature_matrix(train)
    target_return, target_up = _targets(train)
    if len(features) == 0:
        raise ValueError("at least one training example is required")
    if np.unique(target_up).size != 2:
        raise ValueError("training target_up must contain both classes")

    direction = Pipeline(
        [
            ("scale", StandardScaler()),
            (
                "model",
                LogisticRegression(C=1.0, max_iter=1000, solver="lbfgs", random_state=7),
            ),
        ]
    )
    return_model = Pipeline([("scale", StandardScaler()), ("model", Ridge(alpha=1.0))])
    direction.fit(features, target_up)
    return_model.fit(features, target_return)

    return ModelBundle(
        direction=direction,
        return_model=return_model,
        feature_columns=FEATURE_COLUMNS,
        training_up_rate=float(target_up.mean()),
        sklearn_version=sklearn.__version__,
        direction_parameters={
            "C": 1.0,
            "max_iter": 1000,
            "solver": "lbfgs",
            "random_state": 7,
        },
        return_parameters={"alpha": 1.0},
    )


def fit_residual_interval(
    bundle: ModelBundle, validation: pd.DataFrame
) -> ValidationResidualInterval:
    """Derive 10th/90th residual-return bounds from validation examples only."""
    features = _feature_matrix(validation)
    target_return, _ = _targets(validation)
    if len(features) == 0:
        raise ValueError("at least one validation example is required")

    residuals = target_return - bundle.return_model.predict(features)
    if not np.isfinite(residuals).all():
        raise ValueError("validation residuals must be finite")
    return ValidationResidualInterval(
        lower_return=float(np.quantile(residuals, 0.10)),
        upper_return=float(np.quantile(residuals, 0.90)),
        lower_quantile=0.10,
        upper_quantile=0.90,
        validation_examples=len(validation),
    )


def _outcome_timestamps(frame: pd.DataFrame) -> pd.Series:
    _require_columns(frame, ("timestamp",))
    timestamps = pd.to_datetime(frame["timestamp"], utc=True, errors="coerce")
    if timestamps.isna().any():
        raise ValueError("examples contain invalid timestamps")
    return timestamps + pd.Timedelta(minutes=5)


def predict_examples(
    bundle: ModelBundle,
    frame: pd.DataFrame,
    interval: ValidationResidualInterval,
) -> pd.DataFrame:
    """Precompute all replay forecast and five-minute-outcome values in Python."""
    features = _feature_matrix(frame)
    target_return, _ = _targets(frame)
    close = _positive_close(frame)
    outcome_timestamps = _outcome_timestamps(frame)
    if len(features) == 0:
        raise ValueError("at least one example is required for prediction")

    class_labels = bundle.direction.named_steps["model"].classes_
    positive_index = np.flatnonzero(class_labels == 1)
    if len(positive_index) != 1:
        raise ValueError("direction model must expose a positive class probability")
    probability_up = bundle.direction.predict_proba(features)[:, positive_index[0]]
    expected_return = bundle.return_model.predict(features)
    if not np.isfinite(probability_up).all() or not np.isfinite(expected_return).all():
        raise ValueError("model predictions must be finite")

    scenario_price = close * (1.0 + expected_return)
    interval_low = close * (1.0 + expected_return + interval.lower_return)
    interval_high = close * (1.0 + expected_return + interval.upper_return)
    if not np.isfinite(interval_low).all() or not np.isfinite(interval_high).all():
        raise ValueError("forecast prices must be finite")
    if interval.lower_return > interval.upper_return:
        raise ValueError("validation residual interval bounds must be ordered")
    if not (scenario_price > 0.0).all() or not (interval_low > 0.0).all() or not (
        interval_high > 0.0
    ).all():
        raise ValueError("forecast prices must be positive")

    outcome_close = close * (1.0 + target_return)
    result = frame.copy()
    result["probability_up"] = probability_up
    result["probability_status"] = RAW_PROBABILITY_STATUS
    result["expected_return_bps"] = expected_return * 10_000.0
    result["scenario_price"] = scenario_price
    result["interval_low"] = interval_low
    result["interval_high"] = interval_high
    result["interval_status"] = VALIDATION_RESIDUAL_INTERVAL_STATUS
    result["direction"] = np.select(
        (expected_return > 0.0, expected_return < 0.0), ("UP", "DOWN"), default="FLAT"
    )
    result["outcome_timestamp"] = outcome_timestamps
    result["outcome_close"] = outcome_close
    result["outcome_return_bps"] = target_return * 10_000.0
    result["realized_close"] = outcome_close
    result["realized_return_bps"] = target_return * 10_000.0
    return result


def _expected_calibration_error(target_up: np.ndarray, probabilities: np.ndarray) -> float:
    """Compute ten equal-count-bin expected calibration error."""
    order = np.argsort(probabilities, kind="stable")
    bin_indices = np.array_split(order, min(10, len(order)))
    error = 0.0
    for indices in bin_indices:
        if len(indices) == 0:
            continue
        error += (len(indices) / len(order)) * abs(
            probabilities[indices].mean() - target_up[indices].mean()
        )
    return float(error)


def _add_direction_metric(
    metrics: dict[str, float],
    name: str,
    value: float,
    baseline: float,
) -> None:
    metrics[f"direction_{name}"] = value
    metrics[f"direction_{name}_baseline"] = baseline
    metrics[f"direction_{name}_delta"] = value - baseline


def _add_return_metric(
    metrics: dict[str, float],
    name: str,
    value: float,
    zero_return_baseline: float,
    momentum_baseline: float,
) -> None:
    metrics[f"return_{name}"] = value
    metrics[f"return_{name}_zero_return_baseline"] = zero_return_baseline
    metrics[f"return_{name}_zero_return_delta"] = value - zero_return_baseline
    metrics[f"return_{name}_momentum_baseline"] = momentum_baseline
    metrics[f"return_{name}_momentum_delta"] = value - momentum_baseline


def evaluate_predictions(predictions: pd.DataFrame, train_up_rate: float) -> dict[str, float]:
    """Report untouched-example model metrics, approved baselines, deltas, and coverage."""
    required = (
        "target_up",
        "target_return",
        "probability_up",
        "expected_return_bps",
        "ret_5m",
    )
    _require_columns(predictions, required)
    if len(predictions) == 0:
        raise ValueError("at least one prediction is required for evaluation")
    if not np.isfinite(train_up_rate) or not 0.0 <= train_up_rate <= 1.0:
        raise ValueError("training up rate must be between zero and one")

    target_return, target_up = _targets(predictions)
    probability_up = pd.to_numeric(predictions["probability_up"], errors="raise").to_numpy(dtype=float)
    expected_return = (
        pd.to_numeric(predictions["expected_return_bps"], errors="raise").to_numpy(dtype=float)
        / 10_000.0
    )
    momentum_return = pd.to_numeric(predictions["ret_5m"], errors="raise").to_numpy(dtype=float)
    if (
        not np.isfinite(probability_up).all()
        or not np.isfinite(expected_return).all()
        or not np.isfinite(momentum_return).all()
    ):
        raise ValueError("prediction metrics require finite values")
    if not ((0.0 <= probability_up) & (probability_up <= 1.0)).all():
        raise ValueError("probability_up must be between zero and one")
    if np.unique(target_up).size != 2:
        raise ValueError("direction metrics require both target_up classes")

    safe_probability = np.clip(probability_up, np.finfo(float).eps, 1.0 - np.finfo(float).eps)
    baseline_probability = np.full(len(predictions), train_up_rate, dtype=float)
    safe_baseline_probability = np.clip(
        baseline_probability, np.finfo(float).eps, 1.0 - np.finfo(float).eps
    )
    majority_class = int(train_up_rate >= 0.5)
    zero_return = np.zeros(len(predictions), dtype=float)

    metrics: dict[str, float] = {}
    _add_direction_metric(
        metrics,
        "roc_auc",
        float(roc_auc_score(target_up, probability_up)),
        float(roc_auc_score(target_up, baseline_probability)),
    )
    _add_direction_metric(
        metrics,
        "brier_score",
        float(brier_score_loss(target_up, probability_up)),
        float(brier_score_loss(target_up, baseline_probability)),
    )
    _add_direction_metric(
        metrics,
        "log_loss",
        float(log_loss(target_up, safe_probability, labels=(0, 1))),
        float(log_loss(target_up, safe_baseline_probability, labels=(0, 1))),
    )
    _add_direction_metric(
        metrics,
        "calibration_error",
        _expected_calibration_error(target_up, probability_up),
        _expected_calibration_error(target_up, baseline_probability),
    )
    _add_direction_metric(
        metrics,
        "accuracy",
        float(accuracy_score(target_up, probability_up >= 0.5)),
        float(accuracy_score(target_up, np.full(len(predictions), majority_class))),
    )

    _add_return_metric(
        metrics,
        "mae",
        float(mean_absolute_error(target_return, expected_return)),
        float(mean_absolute_error(target_return, zero_return)),
        float(mean_absolute_error(target_return, momentum_return)),
    )
    _add_return_metric(
        metrics,
        "rmse",
        float(np.sqrt(mean_squared_error(target_return, expected_return))),
        float(np.sqrt(mean_squared_error(target_return, zero_return))),
        float(np.sqrt(mean_squared_error(target_return, momentum_return))),
    )
    metrics["direction_coverage_count"] = float(len(predictions))
    metrics["return_coverage_count"] = float(len(predictions))
    return metrics


__all__ = [
    "ModelBundle",
    "RAW_PROBABILITY_STATUS",
    "VALIDATION_RESIDUAL_INTERVAL_STATUS",
    "ValidationResidualInterval",
    "evaluate_predictions",
    "fit_models",
    "fit_residual_interval",
    "predict_examples",
]

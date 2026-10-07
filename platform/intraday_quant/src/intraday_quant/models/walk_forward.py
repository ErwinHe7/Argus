from __future__ import annotations

from dataclasses import dataclass

import joblib
import numpy as np
import pandas as pd
from sklearn.compose import TransformedTargetRegressor
from sklearn.ensemble import HistGradientBoostingClassifier, HistGradientBoostingRegressor
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import brier_score_loss, log_loss
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from intraday_quant.config import AppConfig, WalkForwardConfig
from intraday_quant.data.integrity import DataIntegrityError
from intraday_quant.models.analog_kernel import LegacyExploratoryEuclideanAnalogModel
from intraday_quant.models.calibration import ProbabilityCalibrator
from intraday_quant.models.return_interval import SplitConformalReturnInterval
from intraday_quant.models.constants import (
    LEGACY_EXPLORATORY_ANALOG_EVIDENCE_KIND,
    LEGACY_EXPLORATORY_ANALOG_MODEL_NAME,
    LEGACY_EXPLORATORY_ANALOG_PROMOTION_BLOCKER,
)


@dataclass(slots=True)
class Fold:
    fold: int
    train_dates: list[object]
    validation_dates: list[object]
    test_dates: list[object]


FEATURE_COLUMNS = [
    "ret_1m", "ret_3m", "ret_5m", "ret_15m", "ret_30m", "overnight_gap",
    "gap_from_prev_close", "dist_vwap", "dist_session_open", "dist_opening_range_high",
    "dist_opening_range_low", "dist_prev_day_high", "dist_prev_day_low",
    "session_range_position", "rolling_realized_vol", "rolling_atr", "high_low_range_zscore",
    "consecutive_up_bars", "consecutive_down_bars", "volume_1m", "cumulative_volume",
    "rvol_same_minute", "volume_zscore", "volume_acceleration", "up_volume_ratio",
    "down_volume_ratio", "price_volume_divergence", "spy_ret_5m", "qqq_ret_5m",
    "soxx_ret_5m", "iwm_ret_5m", "es_ret_5m", "vix_change_5m", "vix_change_15m",
    "spx_minus_qqq", "spx_minus_soxx", "qqq_minus_soxx", "es_spx_basis",
    "cross_asset_breadth_score", "market_confirmation_score", "minutes_from_open",
    "minutes_to_close", "day_of_week", "time_sin", "time_cos", "closing_10m", "ret_from_1550",
    "close_location_value", "buy_pressure_proxy", "closing_short_cover_score", "direction",
]


def make_folds(dates: list[object], config: AppConfig) -> list[Fold]:
    wf = WalkForwardConfig.model_validate(config.walk_forward.model_dump())
    if any(pd.isna(date) for date in dates) or any(left >= right for left, right in zip(dates, dates[1:])):
        raise DataIntegrityError("fold dates must be strictly increasing and unique")
    folds: list[Fold] = []
    start = wf.train_sessions
    fold_id = 0
    while start + wf.validation_sessions + wf.test_sessions <= len(dates):
        train_start = 0 if wf.expanding else max(0, start - wf.train_sessions)
        validation_end = start + wf.validation_sessions
        test_end = validation_end + wf.test_sessions
        folds.append(Fold(fold_id, dates[train_start:start], dates[start:validation_end], dates[validation_end:test_end]))
        fold_id += 1
        start += wf.step_sessions
    return folds


def _dataset(labels: pd.DataFrame, features: pd.DataFrame, horizon: int, round_trip_cost: float) -> pd.DataFrame:
    feature_frame = features[
        ["timestamp"]
        + [
            column
            for column in FEATURE_COLUMNS
            if column != "direction" and column in features.columns
        ]
    ].copy()
    data = labels.merge(feature_frame, on="timestamp", how="left", suffixes=("", "_feature"))
    return_column = f"forward_return_{horizon}m"
    mfe_column = f"MFE_{horizon}m"
    mae_column = f"MAE_{horizon}m"
    required = [return_column, mfe_column, mae_column]
    missing = [column for column in required if column not in data]
    if missing:
        raise ValueError(f"horizon {horizon}m labels are missing: {missing}")
    data["target_return"] = data[return_column]
    data["target_mfe"] = data[mfe_column]
    data["target_mae"] = data[mae_column]
    data["target_win"] = (data["target_return"] > round_trip_cost).astype(int)
    data["horizon_minutes"] = horizon
    status_column = f"forward_label_status_{horizon}m"
    if status_column not in data:
        raise DataIntegrityError(
            f"horizon {horizon}m is missing explicit label eligibility; "
            "rebuild labels with the current causal timestamp contract"
        )
    inconsistent = data[status_column].ne("eligible") & data[
        ["target_return", "target_mfe", "target_mae"]
    ].notna().any(axis=1)
    if inconsistent.any():
        raise DataIntegrityError(
            f"horizon {horizon}m contains values marked as ineligible"
        )
    data = data.loc[data[status_column].eq("eligible")].copy()
    return data.dropna(subset=["target_return", "target_mfe", "target_mae"]).sort_values("timestamp")


def _linear_classifier() -> Pipeline:
    return Pipeline([("imputer", SimpleImputer(strategy="median")), ("scale", StandardScaler()), ("model", LogisticRegression(max_iter=1000, class_weight="balanced"))])


def _linear_regressor() -> TransformedTargetRegressor:
    from sklearn.linear_model import Ridge
    pipe = Pipeline([("imputer", SimpleImputer(strategy="median")), ("scale", StandardScaler()), ("model", Ridge(alpha=1.0))])
    return TransformedTargetRegressor(regressor=pipe, transformer=StandardScaler())


def _tree_classifier() -> Pipeline:
    return Pipeline([("imputer", SimpleImputer(strategy="median")), ("model", HistGradientBoostingClassifier(max_iter=100, max_depth=5, learning_rate=0.06, random_state=7))])


def _tree_regressor() -> Pipeline:
    return Pipeline([("imputer", SimpleImputer(strategy="median")), ("model", HistGradientBoostingRegressor(max_iter=100, max_depth=5, learning_rate=0.06, random_state=7))])


def _observation_times(frame: pd.DataFrame) -> pd.Series:
    times = frame["timestamp"]
    if times.empty or not isinstance(times.dtype, pd.DatetimeTZDtype) or times.isna().any():
        raise DataIntegrityError("forecast partitions require nonempty timezone-aware timestamps")
    return times


def _calibration_partitions(
    validation: pd.DataFrame, *, horizon_minutes: int, purge_minutes: int, embargo_minutes: int,
) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Reserve early sessions for fitting and later sessions for assessment."""
    if horizon_minutes <= 0 or purge_minutes < 0 or embargo_minutes < 0:
        raise DataIntegrityError("invalid forecast horizon, purge, or embargo")
    times = _observation_times(validation)
    if not validation["session_date"].eq(times.dt.date).all():
        raise DataIntegrityError("session dates must match observation timestamps")
    dates = sorted(validation["session_date"].unique())
    if len(dates) < 2:
        raise DataIntegrityError("calibration and assessment require at least two observed sessions")
    split = len(dates) // 2
    calibration = validation[validation["session_date"].isin(dates[:split])].copy()
    assessment = validation[validation["session_date"].isin(dates[split:])].copy()
    boundary = assessment["timestamp"].min()
    # Start-stamped minute bars: the forward label's last close arrives at t+h+1.
    gap = pd.Timedelta(minutes=max(purge_minutes, horizon_minutes + 1))
    calibration = calibration[calibration["timestamp"] < boundary - gap]
    assessment = assessment[assessment["timestamp"] >= boundary + pd.Timedelta(minutes=embargo_minutes)]
    if calibration.empty or assessment.empty:
        raise DataIntegrityError("insufficient rows after calibration purge/embargo")
    return calibration, assessment


def predict_from_artifact(artifact: dict[str, object], observations: pd.DataFrame) -> pd.DataFrame:
    """Predict later candidate observations without requiring any future labels.

    The caller remains responsible for causal feature construction and source
    integrity. This research artifact does not authorize production publication.
    """
    times = _observation_times(observations)
    available_after = pd.Timestamp(artifact["forecast_available_after"])
    if times.min() <= available_after:
        raise DataIntegrityError("observations must follow the artifact's matured evidence cutoff")
    columns = artifact["feature_columns"]
    x = observations[columns]
    if np.isinf(x.to_numpy(dtype=float)).any():
        raise DataIntegrityError("forecast features must not contain infinity")
    point = artifact["regressor"].predict(x)
    interval = artifact["return_interval"]
    lower, upper = interval.predict(point)
    return pd.DataFrame({
        "candidate_id": observations["candidate_id"].to_numpy(), "timestamp": times.to_numpy(),
        "model": artifact["model"], "expected_return": point, "median_return": point,
        "win_probability": artifact["calibrator"].predict(artifact["classifier"].predict_proba(x)[:, 1]),
        "predicted_mfe": np.maximum(0, artifact["mfe"].predict(x)),
        "predicted_mae": np.maximum(0, artifact["mae"].predict(x)),
        "return_lower": lower, "return_upper": upper,
        "return_interval_nominal_coverage": interval.coverage, "return_interval_method": interval.method,
        "horizon_minutes": artifact["horizon_minutes"],
        "neighbor_count": 0, "similarity_score": 0.0,
        "uncertainty": artifact["calibration_return_rmse"], "neighbor_dates": "",
        "forecast_available_after": available_after.isoformat(),
        "forecast_status": "CANDIDATE_NOT_PROMOTED", "promotion_eligible": False,
    })


def _fit_family(
    name: str, train: pd.DataFrame, validation: pd.DataFrame, test: pd.DataFrame,
    columns: list[str], calibration: str, *, horizon_minutes: int = 60,
    purge_minutes: int = 60, embargo_minutes: int = 15, return_interval_coverage: float = 0.90,
) -> tuple[pd.DataFrame, dict[str, object]]:
    if name not in {"logistic", "gradient_boosting"}:
        raise ValueError("unknown forecast model family")
    if not columns or len(set(columns)) != len(columns) or not set(columns).issubset(FEATURE_COLUMNS):
        raise DataIntegrityError("forecast inputs must use the allowed causal feature columns")
    calibration_frame, assessment = _calibration_partitions(
        validation, horizon_minutes=horizon_minutes, purge_minutes=purge_minutes,
        embargo_minutes=embargo_minutes,
    )
    gap = pd.Timedelta(minutes=max(purge_minutes, horizon_minutes + 1))
    for earlier, later in ((train, validation), (validation, test)):
        if _observation_times(earlier).max() + gap >= _observation_times(later).min():
            raise DataIntegrityError("model partitions must be chronological with matured labels")
    for frame in (train, validation):
        if not np.isfinite(frame[["target_return", "target_mfe", "target_mae"]].to_numpy(dtype=float)).all():
            raise DataIntegrityError("training and calibration return labels must be finite")
        if not frame["target_win"].isin([0, 1]).all():
            raise DataIntegrityError("training and calibration win labels must be binary")
    x_train, x_cal, x_val = train[columns], calibration_frame[columns], assessment[columns]
    classifier = _linear_classifier() if name == "logistic" else _tree_classifier()
    regressor = _linear_regressor() if name == "logistic" else _tree_regressor()
    mfe_model = _linear_regressor() if name == "logistic" else _tree_regressor()
    mae_model = _linear_regressor() if name == "logistic" else _tree_regressor()
    classifier.fit(x_train, train["target_win"])
    regressor.fit(x_train, train["target_return"])
    mfe_model.fit(x_train, train["target_mfe"])
    mae_model.fit(x_train, train["target_mae"])
    raw_cal = classifier.predict_proba(x_cal)[:, 1]
    calibrator = ProbabilityCalibrator(calibration).fit(raw_cal, calibration_frame["target_win"].to_numpy())
    calibrated_val = calibrator.predict(classifier.predict_proba(x_val)[:, 1])
    calibration_return_prediction = regressor.predict(x_cal)
    calibration_residual_scale = float(
        np.sqrt(np.mean(np.square(calibration_frame["target_return"].to_numpy() - calibration_return_prediction)))
    )
    interval = SplitConformalReturnInterval(return_interval_coverage).fit(
        calibration_return_prediction, calibration_frame["target_return"].to_numpy(),
    )
    validation_return_prediction = regressor.predict(x_val)
    lower, upper = interval.predict(validation_return_prediction)
    outcomes = assessment["target_return"].to_numpy()
    baseline_probability = float(calibration_frame["target_win"].mean())
    baseline_brier = float(brier_score_loss(assessment["target_win"], np.full(len(assessment), baseline_probability)))
    validation_brier = float(brier_score_loss(assessment["target_win"], calibrated_val))
    diagnostics = {
        "model": name,
        "validation_brier": validation_brier,
        "validation_baseline_brier": baseline_brier,
        "validation_brier_skill": 1 - validation_brier / baseline_brier if baseline_brier > 0 else None,
        "validation_log_loss": float(log_loss(assessment["target_win"], calibrated_val, labels=[0, 1])),
        "validation_return_rmse": float(np.sqrt(np.mean(np.square(outcomes - validation_return_prediction)))),
        "validation_zero_return_rmse": float(np.sqrt(np.mean(np.square(outcomes)))),
        "calibration_return_rmse": calibration_residual_scale,
        "return_interval_nominal_coverage": interval.coverage,
        "return_interval_radius": interval.radius,
        "validation_interval_coverage": float(np.mean((outcomes >= lower) & (outcomes <= upper))),
        "validation_interval_mean_width": float(np.mean(upper - lower)),
        "calibration_rows": len(calibration_frame), "assessment_rows": len(assessment),
        "calibration_end": calibration_frame["timestamp"].max().isoformat(),
        "assessment_start": assessment["timestamp"].min().isoformat(),
        "validation_score_scope": "chronological_post_calibration_assessment",
        "evidence_kind": "OFFLINE_CHALLENGER_DIAGNOSTIC_NOT_PROMOTION_EVIDENCE",
    }
    artifact = {
        "classifier": classifier, "regressor": regressor, "mfe": mfe_model, "mae": mae_model,
        "calibrator": calibrator, "return_interval": interval, "feature_columns": list(columns),
        "model": name, "horizon_minutes": horizon_minutes,
        "calibration_return_rmse": calibration_residual_scale,
        "forecast_available_after": (validation["timestamp"].max() + gap).isoformat(),
        "validation_contract": dict(diagnostics), "diagnostics": diagnostics,
    }
    return predict_from_artifact(artifact, test), artifact


def train_walk_forward(labels: pd.DataFrame, features: pd.DataFrame, config: AppConfig) -> tuple[pd.DataFrame, pd.DataFrame]:
    predictions: list[pd.DataFrame] = []
    diagnostics: list[dict[str, object]] = []
    models_dir = config.output_dir / "models"
    models_dir.mkdir(parents=True, exist_ok=True)
    round_trip_cost = (
        2 * (config.costs.underlying_slippage_bps + config.costs.estimated_spread_bps)
    ) / 10_000
    for horizon in config.forecast_horizons:
        data = _dataset(labels, features, horizon, round_trip_cost)
        dates = sorted(data["session_date"].unique())
        folds = make_folds(dates, config)
        columns = [column for column in FEATURE_COLUMNS if column in data.columns]
        for fold in folds:
            train = data[data["session_date"].isin(fold.train_dates)].copy()
            validation = data[data["session_date"].isin(fold.validation_dates)].copy()
            test = data[data["session_date"].isin(fold.test_dates)].copy()
            if train.empty or validation.empty or test.empty or train["target_win"].nunique() < 2:
                continue
            validation_start = validation["timestamp"].min()
            test_start = test["timestamp"].min()
            purge = pd.Timedelta(minutes=max(config.walk_forward.purge_minutes, horizon + 1))
            train = train[train["timestamp"] < validation_start - purge]
            validation = validation[(validation["timestamp"] >= validation_start + pd.Timedelta(minutes=config.walk_forward.embargo_minutes)) & (validation["timestamp"] < test_start - purge)]
            test = test[test["timestamp"] >= test_start + pd.Timedelta(minutes=config.walk_forward.embargo_minutes)]
            if train.empty or validation.empty or test.empty or train["target_win"].nunique() < 2:
                continue
            family_outputs: list[pd.DataFrame] = []
            for name in [model for model in config.models if model in {"logistic", "gradient_boosting"}]:
                output, artifact = _fit_family(
                    name, train, validation, test, columns, config.model.calibration,
                    horizon_minutes=horizon, purge_minutes=config.walk_forward.purge_minutes,
                    embargo_minutes=config.walk_forward.embargo_minutes,
                    return_interval_coverage=config.model.return_interval_coverage,
                )
                output["fold"] = fold.fold
                output["horizon_minutes"] = horizon
                family_outputs.append(output)
                diag = artifact.pop("diagnostics")
                diagnostics.append({"fold": fold.fold, "horizon_minutes": horizon, "train_rows": len(train), "validation_rows": len(validation), "test_rows": len(test), **diag})
                joblib.dump(artifact, models_dir / f"horizon_{horizon}m_fold_{fold.fold}_{name}.joblib")
            if LEGACY_EXPLORATORY_ANALOG_MODEL_NAME in config.models:
                analog = LegacyExploratoryEuclideanAnalogModel(
                    config.model.analog_neighbors, config.model.analog_bandwidth
                )
                y_train = pd.DataFrame({"return": train["target_return"], "mfe": train["target_mfe"], "mae": train["target_mae"]})
                analog.fit(train[columns], y_train, train["timestamp"])
                analog_output = analog.predict(test[columns], test["timestamp"])
                analog_output.insert(0, "timestamp", test["timestamp"].to_numpy())
                analog_output.insert(0, "candidate_id", test["candidate_id"].to_numpy())
                analog_output["model"] = LEGACY_EXPLORATORY_ANALOG_MODEL_NAME
                analog_output["fold"] = fold.fold
                analog_output["horizon_minutes"] = horizon
                analog_output["evidence_kind"] = LEGACY_EXPLORATORY_ANALOG_EVIDENCE_KIND
                analog_output["promotion_eligible"] = False
                analog_output["production_parity"] = False
                analog_output["promotion_blocker"] = LEGACY_EXPLORATORY_ANALOG_PROMOTION_BLOCKER
                family_outputs.append(analog_output)
                diagnostics.append({
                    "fold": fold.fold,
                    "horizon_minutes": horizon,
                    "model": LEGACY_EXPLORATORY_ANALOG_MODEL_NAME,
                    "train_rows": len(train),
                    "validation_rows": len(validation),
                    "test_rows": len(test),
                    "validation_brier": np.nan,
                    "evidence_kind": LEGACY_EXPLORATORY_ANALOG_EVIDENCE_KIND,
                    "promotion_eligible": False,
                    "production_parity": False,
                    "promotion_blocker": LEGACY_EXPLORATORY_ANALOG_PROMOTION_BLOCKER,
                })
                joblib.dump(
                    analog,
                    models_dir
                    / f"horizon_{horizon}m_fold_{fold.fold}_{LEGACY_EXPLORATORY_ANALOG_MODEL_NAME}.joblib",
                )
            if family_outputs:
                fold_predictions = pd.concat(family_outputs, ignore_index=True)
                # Validation-derived threshold only; test outcomes remain untouched.
                threshold = float(validation["target_return"].quantile(config.model.score_threshold_quantile))
                fold_predictions["validation_return_threshold"] = threshold
                predictions.append(fold_predictions)
    pred = pd.concat(predictions, ignore_index=True) if predictions else pd.DataFrame()
    diag = pd.DataFrame(diagnostics)
    pred.to_parquet(models_dir / "predictions.parquet", index=False)
    diag.to_csv(models_dir / "fold_diagnostics.csv", index=False)
    return pred, diag

from __future__ import annotations

from dataclasses import dataclass

import joblib
import numpy as np
import pandas as pd
from sklearn.compose import TransformedTargetRegressor
from sklearn.ensemble import HistGradientBoostingClassifier, HistGradientBoostingRegressor
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import brier_score_loss
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from intraday_quant.config import AppConfig
from intraday_quant.data.integrity import DataIntegrityError
from intraday_quant.models.analog_kernel import LegacyExploratoryEuclideanAnalogModel
from intraday_quant.models.calibration import ProbabilityCalibrator
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
    wf = config.walk_forward
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


def _fit_family(name: str, train: pd.DataFrame, validation: pd.DataFrame, test: pd.DataFrame, columns: list[str], calibration: str) -> tuple[pd.DataFrame, dict[str, object]]:
    x_train, x_val, x_test = train[columns], validation[columns], test[columns]
    classifier = _linear_classifier() if name == "logistic" else _tree_classifier()
    regressor = _linear_regressor() if name == "logistic" else _tree_regressor()
    mfe_model = _linear_regressor() if name == "logistic" else _tree_regressor()
    mae_model = _linear_regressor() if name == "logistic" else _tree_regressor()
    classifier.fit(x_train, train["target_win"])
    regressor.fit(x_train, train["target_return"])
    mfe_model.fit(x_train, train["target_mfe"])
    mae_model.fit(x_train, train["target_mae"])
    raw_val = classifier.predict_proba(x_val)[:, 1]
    calibrator = ProbabilityCalibrator(calibration).fit(raw_val, validation["target_win"].to_numpy())
    raw_test = classifier.predict_proba(x_test)[:, 1]
    validation_return_prediction = regressor.predict(x_val)
    validation_residual_scale = float(
        np.sqrt(np.mean(np.square(validation["target_return"].to_numpy() - validation_return_prediction)))
    )
    test_return_prediction = regressor.predict(x_test)
    output = pd.DataFrame({
        "candidate_id": test["candidate_id"].to_numpy(), "timestamp": test["timestamp"].to_numpy(),
        "model": name, "expected_return": test_return_prediction,
        "median_return": test_return_prediction, "win_probability": calibrator.predict(raw_test),
        "predicted_mfe": np.maximum(0, mfe_model.predict(x_test)),
        "predicted_mae": np.maximum(0, mae_model.predict(x_test)),
        "neighbor_count": 0, "similarity_score": 0.0,
        # Frozen validation residual scale; test outcomes are never referenced
        # while constructing a prediction.
        "uncertainty": validation_residual_scale, "neighbor_dates": "",
    })
    diagnostics = {
        "model": name,
        "validation_brier": float(brier_score_loss(validation["target_win"], calibrator.predict(raw_val))),
        "validation_return_rmse": validation_residual_scale,
    }
    return output, {"classifier": classifier, "regressor": regressor, "mfe": mfe_model, "mae": mae_model, "calibrator": calibrator, "diagnostics": diagnostics}


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
            train = train[train["timestamp"] < validation_start - pd.Timedelta(minutes=config.walk_forward.purge_minutes)]
            validation = validation[(validation["timestamp"] >= validation_start + pd.Timedelta(minutes=config.walk_forward.embargo_minutes)) & (validation["timestamp"] < test_start - pd.Timedelta(minutes=config.walk_forward.purge_minutes))]
            test = test[test["timestamp"] >= test_start + pd.Timedelta(minutes=config.walk_forward.embargo_minutes)]
            if train.empty or validation.empty or test.empty or train["target_win"].nunique() < 2:
                continue
            family_outputs: list[pd.DataFrame] = []
            for name in [model for model in config.models if model in {"logistic", "gradient_boosting"}]:
                output, artifact = _fit_family(name, train, validation, test, columns, config.model.calibration)
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

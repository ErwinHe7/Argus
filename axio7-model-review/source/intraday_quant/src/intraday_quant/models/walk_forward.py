from __future__ import annotations

import json
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

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
from intraday_quant.backtest.costs import minimum_round_trip_cost_return
from intraday_quant.models.calibration import ProbabilityCalibrator


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


class AnalogBacktestUnavailable(RuntimeError):
    """The quantctl analog-backtest bridge could not run.

    M3 intentionally does NOT fall back to the retired in-Python
    approximation (models/analog_kernel.py) when this happens -- silently
    substituting a different estimator on failure would recreate exactly the
    train-serve skew M3 exists to remove. A backtest number for
    analog_kernel must come from the real production kernel or be visibly
    absent, never a quiet stand-in.
    """


def _run_analog_backtest(
    test_dates: list[object],
    horizon: int,
    target: str,
    config: AppConfig,
) -> pd.DataFrame:
    """Query the real production HMM + AnalogEngine kernel via `quantctl`.

    Returns one row per state `quantctl` queried, keyed by `timestamp`
    (`decision_as_of`) -- NOT guaranteed to align 1:1 with any particular
    `test` DataFrame's rows or row count (quantctl queries every state in the
    test session-date range; the caller's purge/embargo trimming is a
    row-level subset of that). Callers must join on `timestamp`, not assume
    positional alignment.
    """
    bars_path = Path(
        config.model.analog_backtest_bars_path
        or (config.output_dir / "normalized" / "market_bars.csv")
    )
    if not bars_path.exists():
        raise AnalogBacktestUnavailable(
            f"analog_kernel backtest bridge requires normalized bars at {bars_path}; "
            "set model.analog_backtest_bars_path to the file quantctl should import, "
            "or run ingestion first."
        )
    # Rust's own train/query separation is by session date -- every session
    # strictly before the query's own session is eligible train data (see
    # predictor::hmm_context / fit_analog_engine). Passing the first test
    # date as the train cutoff preserves that policy. Unlike the Python
    # challengers' train-only fit, it may include validation sessions; these
    # raw research rows are not a comparable calibrated strategy ensemble.
    train_before = pd.Timestamp(min(test_dates))
    query_start = pd.Timestamp(min(test_dates))
    query_end = pd.Timestamp(max(test_dates))
    with tempfile.TemporaryDirectory() as tmp:
        output_path = Path(tmp) / "analog_backtest.json"
        command = [config.model.analog_backtest_quantctl_binary]
        if config.model.analog_backtest_config_path:
            command += ["--config", config.model.analog_backtest_config_path]
        command += [
            "research",
            "analog-backtest",
            "--bars", str(bars_path),
            "--target", target,
            "--horizon", str(horizon),
            "--train-before", train_before.strftime("%Y-%m-%d"),
            "--query-start", query_start.strftime("%Y-%m-%d"),
            "--query-end", query_end.strftime("%Y-%m-%d"),
            "--output", str(output_path),
        ]
        try:
            # Force UTF-8 regardless of the host's default locale codepage
            # (e.g. GBK on zh-CN Windows) -- quantctl's output is UTF-8 and a
            # codepage mismatch here throws inside subprocess's own reader
            # thread, which masks whatever quantctl actually said on stderr.
            subprocess.run(
                command,
                check=True,
                capture_output=True,
                encoding="utf-8",
                errors="replace",
                timeout=1800,
            )
        except FileNotFoundError as error:
            raise AnalogBacktestUnavailable(
                f"quantctl binary not found ({config.model.analog_backtest_quantctl_binary!r}); "
                "set model.analog_backtest_quantctl_binary to its full path."
            ) from error
        except subprocess.CalledProcessError as error:
            raise AnalogBacktestUnavailable(
                f"quantctl research analog-backtest failed (exit {error.returncode}): "
                f"{error.stderr}"
            ) from error
        except subprocess.TimeoutExpired as error:
            raise AnalogBacktestUnavailable(
                "quantctl research analog-backtest exceeded its 1800s budget"
            ) from error
        forecasts = json.loads(output_path.read_text(encoding="utf-8"))
    rows = []
    for forecast in forecasts:
        distribution = forecast.get("distribution") or {}
        diagnostics = forecast.get("diagnostics") or {}
        analogs = forecast.get("top_analogs") or []
        nearest_neighbor_distance = diagnostics.get("nearest_neighbor_distance")
        rows.append({
            "timestamp": forecast["decision_as_of"],
            "decision_as_of": forecast["decision_as_of"],
            "expected_return": distribution.get("kernel_weighted_mean", 0.0),
            "median_return": distribution.get("kernel_weighted_mean", 0.0),
            "win_probability": distribution.get("probability_up", 0.5),
            "predicted_mfe": distribution.get("average_mfe", 0.0),
            "predicted_mae": distribution.get("average_mae", 0.0),
            "neighbor_count": len(analogs),
            "similarity_score": (
                1.0 / (1.0 + nearest_neighbor_distance)
                if nearest_neighbor_distance is not None
                else 0.0
            ),
            "uncertainty": distribution.get("dispersion", 1.0),
            "neighbor_dates": "|".join(str(analog["session_date"]) for analog in analogs),
            "analog_backtest_status": forecast["status"],
        })
    result = pd.DataFrame(rows, columns=[
        "timestamp", "decision_as_of", "expected_return", "median_return", "win_probability",
        "predicted_mfe", "predicted_mae", "neighbor_count", "similarity_score", "uncertainty",
        "neighbor_dates", "analog_backtest_status",
    ])
    result["decision_as_of"] = pd.to_datetime(result["decision_as_of"], utc=True).dt.tz_convert(config.timezone)
    # The research export now identifies real completed-bar availability. Keep
    # it visible while joining Python candidates by their interval-start label.
    result["timestamp"] = result["decision_as_of"] - pd.Timedelta(minutes=1)
    return result


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
    data["decision_as_of"] = data.get("signal_time", data["timestamp"] + pd.Timedelta(minutes=1))
    available_column = f"forward_available_at_{horizon}m"
    fallback_entry = data.get("earliest_entry", data["decision_as_of"])
    data["target_available_at"] = data.get(available_column, fallback_entry + pd.Timedelta(minutes=horizon))
    data["horizon_minutes"] = horizon
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
        "decision_as_of": test["decision_as_of"].to_numpy(),
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


def directional_analog_predictions(test: pd.DataFrame, kernel_predictions: pd.DataFrame) -> pd.DataFrame:
    """Orient raw upward kernel outputs without claiming cost-aware calibration."""
    result = test[["candidate_id", "timestamp", "direction"]].merge(
        kernel_predictions, on="timestamp", how="inner"
    )
    if not result["direction"].isin([-1, 1]).all():
        raise ValueError("analog candidates require direction -1/1")
    short = result["direction"].eq(-1)
    result["expected_return"] = result["expected_return"] * result["direction"]
    result["median_return"] = result["median_return"] * result["direction"]
    raw_mfe, raw_mae = result["predicted_mfe"].copy(), result["predicted_mae"].copy()
    result["predicted_mfe"] = np.where(short, raw_mae, raw_mfe)
    result["predicted_mae"] = np.where(short, raw_mfe, raw_mae)
    result["raw_up_probability"] = result["win_probability"]
    # Cost-aware profitability is not derivable from a single zero-return
    # upward frequency (its complement also includes zero-return observations).
    result["win_probability"] = np.nan
    result["probability_semantics"] = "raw_up_frequency_not_cost_aware_calibration"
    result["strategy_eligibility"] = "unsupported_probability_semantics"
    return result


def mature_fold_partitions(
    train: pd.DataFrame, validation: pd.DataFrame, test: pd.DataFrame, config: AppConfig,
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Purge on real feature availability and exclude labels not yet mature."""
    validation_start = validation["decision_as_of"].min()
    test_start = test["decision_as_of"].min()
    purge = pd.Timedelta(minutes=config.walk_forward.purge_minutes)
    embargo = pd.Timedelta(minutes=config.walk_forward.embargo_minutes)
    train = train[(train["decision_as_of"] < validation_start - purge)
                  & (train["target_available_at"] <= validation_start)]
    validation = validation[(validation["decision_as_of"] >= validation_start + embargo)
                            & (validation["decision_as_of"] < test_start - purge)
                            & (validation["target_available_at"] <= test_start)]
    test = test[test["decision_as_of"] >= test_start + embargo]
    return train, validation, test


def train_walk_forward(labels: pd.DataFrame, features: pd.DataFrame, config: AppConfig) -> tuple[pd.DataFrame, pd.DataFrame]:
    predictions: list[pd.DataFrame] = []
    diagnostics: list[dict[str, object]] = []
    models_dir = config.output_dir / "models"
    models_dir.mkdir(parents=True, exist_ok=True)
    round_trip_cost = minimum_round_trip_cost_return(config)
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
            train, validation, test = mature_fold_partitions(train, validation, test, config)
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
            if "analog_kernel" in config.models:
                # M3: query the real production kernel via quantctl instead of
                # models/analog_kernel.py's separate approximation. Row count
                # from quantctl need not match `test` (it queries the whole
                # test session-date range; purge/embargo trimming above is a
                # row-level subset of that), so join on timestamp rather than
                # assuming positional alignment the way the old in-process
                # call could.
                kernel_predictions = _run_analog_backtest(
                    test_dates=sorted(test["session_date"].unique()),
                    horizon=horizon,
                    target=config.target,
                    config=config,
                )
                analog_output = directional_analog_predictions(test, kernel_predictions)
                analog_output["model"] = "analog_kernel"
                analog_output["fold"] = fold.fold
                analog_output["horizon_minutes"] = horizon
                family_outputs.append(analog_output)
                ok_rate = float((kernel_predictions["analog_backtest_status"] == "OK").mean()) if not kernel_predictions.empty else 0.0
                diagnostics.append({
                    "fold": fold.fold, "horizon_minutes": horizon, "model": "analog_kernel",
                    "train_rows": len(train), "validation_rows": len(validation), "test_rows": len(test),
                    "validation_brier": np.nan,
                    "quantctl_query_states": len(kernel_predictions),
                    "quantctl_matched_test_rows": len(analog_output),
                    "quantctl_ok_rate": ok_rate,
                    "strategy_eligibility": "unsupported_probability_semantics",
                })
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

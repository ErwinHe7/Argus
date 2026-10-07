"""Synthetic software checks; these fixtures do not establish trading alpha."""

import joblib
import numpy as np
import pandas as pd
import pytest
from sklearn.metrics import brier_score_loss

from intraday_quant.config import ModelConfig, WalkForwardConfig
from intraday_quant.models.calibration import ProbabilityCalibrator
from intraday_quant.models.return_interval import SplitConformalReturnInterval
from intraday_quant.models.walk_forward import (
    _calibration_partitions,
    _fit_family,
    make_folds,
    predict_from_artifact,
)


def test_interval_uses_corrected_order_statistic_without_interpolation():
    interval = SplitConformalReturnInterval(.8).fit(np.zeros(9), np.arange(9))
    # ceil((9+1)*.8) = 8; the eighth sorted absolute residual is 7.
    assert interval.radius == 7
    lower, upper = interval.predict(np.array([-2, 3]))
    np.testing.assert_array_equal(lower, [-9, -4])
    np.testing.assert_array_equal(upper, [5, 10])
    assert interval.sample_count == 9


@pytest.mark.parametrize("coverage", [0, 1, -.1, 1.1, np.nan, np.inf])
def test_interval_rejects_invalid_coverage(coverage):
    with pytest.raises(ValueError):
        ModelConfig(return_interval_coverage=coverage)
    with pytest.raises(ValueError):
        SplitConformalReturnInterval(coverage).fit(np.zeros(20), np.zeros(20))


@pytest.mark.parametrize("predictions,outcomes", [
    ([], []), ([0], [0, 1]), ([np.nan] * 20, [0] * 20),
    ([0] * 20, [np.inf] * 20), ([[0]] * 20, [0] * 20),
    ([0] * 2, [0] * 2), ([-1e308] * 20, [1e308] * 20),
])
def test_interval_failed_refit_cannot_reuse_old_radius(predictions, outcomes):
    interval = SplitConformalReturnInterval().fit(np.zeros(20), np.ones(20))
    with pytest.raises(ValueError):
        interval.fit(predictions, outcomes)
    with pytest.raises(ValueError, match="fit"):
        interval.predict(np.array([0]))


def test_interval_predict_rejects_nonfinite_values_and_allows_empty_queries():
    interval = SplitConformalReturnInterval().fit(np.zeros(20), np.ones(20))
    assert all(len(bound) == 0 for bound in interval.predict(np.array([])))
    for values in ([np.nan], [np.inf], [[0]]):
        with pytest.raises(ValueError):
            interval.predict(values)


def test_probability_calibration_refit_drops_stale_constant_and_failed_fit():
    probabilities = np.linspace(.01, .99, 40)
    labels = (probabilities > .5).astype(int)
    reused = ProbabilityCalibrator().fit(probabilities, np.zeros(40))
    reused.fit(probabilities, labels)
    fresh = ProbabilityCalibrator().fit(probabilities, labels)
    np.testing.assert_allclose(reused.predict(probabilities), fresh.predict(probabilities))
    with pytest.raises(ValueError):
        reused.fit([], [])
    with pytest.raises(ValueError, match="fit"):
        reused.predict(probabilities)


@pytest.mark.parametrize("probabilities,labels", [
    ([np.nan, .5], [0, 1]), ([-.1, .8], [0, 1]), ([.2, 1.1], [0, 1]),
    ([.2], [0, 1]), ([.2, .8], [0, 2]), ([.2, .8], [0, np.nan]),
])
def test_probability_calibration_rejects_bad_evidence(probabilities, labels):
    with pytest.raises(ValueError):
        ProbabilityCalibrator().fit(probabilities, labels)


@pytest.mark.parametrize("values", [
    {"train_sessions": 0}, {"validation_sessions": 1}, {"test_sessions": 0},
    {"step_sessions": 0}, {"step_sessions": 5, "test_sessions": 10},
    {"purge_minutes": -1}, {"embargo_minutes": -1},
])
def test_invalid_fold_config_is_rejected(values):
    with pytest.raises(ValueError):
        WalkForwardConfig(**values)


def test_make_folds_rejects_duplicate_dates_and_bypassed_validation(config):
    with pytest.raises(ValueError):
        make_folds([0, 1, 1], config)
    with pytest.raises(ValueError):
        make_folds([0, 2, 1], config)
    broken = config.model_copy(update={
        "walk_forward": config.walk_forward.model_copy(update={"step_sessions": 0}),
    })
    with pytest.raises(ValueError):
        make_folds(list(range(100)), broken)
    tests = [date for fold in make_folds(list(range(100)), config) for date in fold.test_dates]
    assert len(tests) == len(set(tests))


def _frame(start, sessions):
    times = pd.DatetimeIndex([
        day + pd.Timedelta(hours=15, minutes=i)
        for day in pd.date_range(start, periods=sessions, freq="D", tz="UTC")
        for i in range(40)
    ])
    signal = np.tile(np.linspace(-2, 2, 40), sessions)
    returns = signal * .003 + np.tile(np.sin(np.arange(40)) * .001, sessions)
    return pd.DataFrame({
        "timestamp": times, "session_date": times.date, "candidate_id": times.astype(str),
        "ret_1m": signal, "target_win": (returns > 0).astype(int),
        "target_return": returns, "target_mfe": np.maximum(0, returns),
        "target_mae": np.maximum(0, -returns),
    })


@pytest.mark.parametrize("family", ["logistic", "gradient_boosting"])
def test_future_labels_cannot_change_predictions_or_intervals(family):
    train, validation, test = _frame("2026-01-01", 3), _frame("2026-01-04", 4), _frame("2026-01-08", 2)
    output, artifact = _fit_family(family, train, validation, test, ["ret_1m"], "isotonic")
    unlabeled = test.drop(columns=["target_win", "target_return", "target_mfe", "target_mae"])
    changed, other = _fit_family(family, train, validation, unlabeled, ["ret_1m"], "isotonic")
    pd.testing.assert_frame_equal(output, changed)
    assert artifact["diagnostics"] == other["diagnostics"]
    assert output.return_lower.le(output.expected_return).all()
    assert output.return_upper.ge(output.expected_return).all()
    assert not output.promotion_eligible.any()
    assert output.forecast_status.eq("CANDIDATE_NOT_PROMOTED").all()


def test_assessment_scores_are_separate_from_calibration_and_do_not_refit():
    train, validation, test = _frame("2026-01-01", 3), _frame("2026-01-04", 4), _frame("2026-01-08", 1)
    output, _ = _fit_family("logistic", train, validation, test, ["ret_1m"], "isotonic")
    later = validation.session_date >= pd.Timestamp("2026-01-06").date()
    validation.loc[later, "target_win"] = 1 - validation.loc[later, "target_win"]
    validation.loc[later, "target_return"] = .5
    changed, artifact = _fit_family("logistic", train, validation, test, ["ret_1m"], "isotonic")
    pd.testing.assert_frame_equal(output, changed)
    _, assessment = _calibration_partitions(validation, horizon_minutes=60, purge_minutes=60, embargo_minutes=15)
    diag = artifact["diagnostics"]
    probabilities = artifact["calibrator"].predict(artifact["classifier"].predict_proba(assessment[["ret_1m"]])[:, 1])
    assert diag["validation_brier"] == pytest.approx(brier_score_loss(assessment.target_win, probabilities))
    assert diag["validation_brier"] > .5
    assert diag["validation_interval_coverage"] == 0
    assert diag["validation_interval_mean_width"] == pytest.approx(2 * artifact["return_interval"].radius)
    assert diag["calibration_end"] < diag["assessment_start"]


def test_saved_model_predicts_new_unlabeled_observations_and_rejects_past(tmp_path):
    train, validation, test = _frame("2026-01-01", 3), _frame("2026-01-04", 4), _frame("2026-01-08", 1)
    expected, artifact = _fit_family("logistic", train, validation, test, ["ret_1m"], "isotonic")
    path = tmp_path / "forecast.joblib"
    joblib.dump(artifact, path)
    restored = joblib.load(path)
    observations = test[["timestamp", "candidate_id", "ret_1m"]]
    pd.testing.assert_frame_equal(expected, predict_from_artifact(restored, observations))
    for past in (train, validation):
        with pytest.raises(ValueError, match="cutoff"):
            predict_from_artifact(restored, past)
    boundary = observations.copy()
    boundary["timestamp"] = pd.Timestamp(restored["forecast_available_after"])
    with pytest.raises(ValueError, match="cutoff"):
        predict_from_artifact(restored, boundary)
    with pytest.raises(KeyError):
        predict_from_artifact(restored, observations.drop(columns="ret_1m"))


def test_calibration_purges_labels_that_have_not_matured_and_embargoes_rows():
    times = pd.to_datetime([
        "2026-01-05 22:00Z", "2026-01-05 22:59Z", "2026-01-05 23:00Z",
        "2026-01-06 00:00Z", "2026-01-06 00:14Z", "2026-01-06 00:15Z",
    ])
    frame = pd.DataFrame({"timestamp": times, "session_date": times.date})
    calibration, assessment = _calibration_partitions(frame, horizon_minutes=60, purge_minutes=0, embargo_minutes=15)
    assert calibration.timestamp.tolist() == [times[0]]
    assert assessment.timestamp.tolist() == [times[-1]]


@pytest.mark.parametrize("problem", ["single_session", "naive", "wrong_session", "embargo"])
def test_calibration_fails_closed_for_insufficient_or_invalid_time_evidence(problem):
    frame = _frame("2026-01-04", 1 if problem == "single_session" else 2)
    if problem == "naive":
        frame["timestamp"] = frame.timestamp.dt.tz_localize(None)
    if problem == "wrong_session":
        frame["session_date"] = pd.Timestamp("2026-01-01").date()
    with pytest.raises(ValueError):
        _calibration_partitions(frame, horizon_minutes=60, purge_minutes=60, embargo_minutes=60 if problem == "embargo" else 15)


def test_fit_rejects_overlapping_partitions_or_target_features():
    train, validation = _frame("2026-01-01", 3), _frame("2026-01-04", 4)
    with pytest.raises(ValueError, match="chronological"):
        _fit_family("logistic", train, validation, validation, ["ret_1m"], "isotonic")
    with pytest.raises(ValueError, match="feature"):
        _fit_family("logistic", train, validation, _frame("2026-01-08", 1), ["target_return"], "isotonic")

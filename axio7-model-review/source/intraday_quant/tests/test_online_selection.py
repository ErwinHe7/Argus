import numpy as np
import pandas as pd

from intraday_quant.candidates.pipeline import generate_candidates
from intraday_quant.portfolio.selector import score_and_select
from intraday_quant.models.walk_forward import directional_analog_predictions


def _candidate_features(periods):
    times = pd.date_range("2026-01-05 10:00", periods=periods, freq="1min", tz="America/New_York")
    return pd.DataFrame({
        "timestamp": times, "session_date": times.date, "close": 100.0, "ret_15m": .01,
        "rolling_realized_vol": .001, "dist_vwap": .002, "volume_acceleration": .1,
        "ret_5m": .01, "rvol_same_minute": 1.0, "market_confirmation_score": 1.0,
        "rolling_atr": 1.0, "volume_zscore": 1.0,
    })


def test_future_stronger_candidate_cannot_replace_past_capped_candidates(config):
    cfg = config.model_copy(update={"setups": ["mean_reversion"]})
    past = _candidate_features(12)
    baseline = generate_candidates(past, cfg)
    future = _candidate_features(13)
    future.loc[12, "ret_15m"] = 100.0
    result = generate_candidates(future, cfg)
    assert len(baseline) == 10
    assert baseline.timestamp.tolist() == past.timestamp.iloc[:10].tolist()
    pd.testing.assert_frame_equal(baseline, result)


def _inputs(times, returns=None):
    n = len(times)
    ids = [f"candidate-{i}" for i in range(n)]
    candidates = pd.DataFrame({
        "candidate_id": ids, "timestamp": times, "session_date": [stamp.date() for stamp in times],
        "setup_type": "test", "direction": [1 if i % 2 == 0 else -1 for i in range(n)],
        "entry_reference": 100, "feature_snapshot": "{}", "reason_codes": "test",
    })
    predictions = pd.DataFrame({
        "candidate_id": ids, "timestamp": times, "fold": 0, "horizon_minutes": 15,
        "expected_return": returns if returns is not None else [.01] * n,
        "median_return": .01, "win_probability": .8, "predicted_mfe": .02,
        "predicted_mae": .005, "uncertainty": .001, "similarity_score": .8,
        "validation_return_threshold": .001,
    })
    return predictions, candidates


def test_stronger_afternoon_signal_does_not_change_morning_quota(config):
    times = pd.date_range("2026-01-05 10:00", periods=3, freq="2h", tz="America/New_York")
    predictions, candidates = _inputs(times, [.01, .02, 100.0])
    before, _ = score_and_select(predictions.iloc[:2], candidates.iloc[:2], config)
    after, rejected = score_and_select(predictions, candidates, config)
    pd.testing.assert_frame_equal(before, after)
    assert rejected.iloc[0].rejection_reason == "daily_trade_limit"


def test_same_timestamp_orders_by_score_and_cooldown_is_consumed_online(config):
    time = pd.Timestamp("2026-01-05 10:00", tz="America/New_York")
    times = [time, time, time + pd.Timedelta(minutes=29), time + pd.Timedelta(minutes=30)]
    predictions, candidates = _inputs(times, [.01, .02, 100.0, .03])
    candidates.loc[2, "direction"] = 1
    candidates.loc[3, "direction"] = 1
    selected, rejected = score_and_select(predictions, candidates, config)
    assert selected.candidate_id.tolist() == ["candidate-1", "candidate-3"]
    assert set(rejected.rejection_reason) == {"cooldown_or_correlated_signal"}


def test_nonfinite_predictions_fail_closed_and_same_candidate_is_not_repeated(config):
    time = pd.Timestamp("2026-01-05 10:00", tz="America/New_York")
    predictions, candidates = _inputs([time])
    predictions["expected_return"] = np.inf
    selected, rejected = score_and_select(predictions, candidates, config)
    assert selected.empty and rejected.iloc[0].rejection_reason == "nonfinite_prediction"
    predictions["expected_return"] = .01
    another = predictions.copy()
    another["horizon_minutes"] = 30
    cfg = config.model_copy(update={"portfolio": config.portfolio.model_copy(update={"cooldown_minutes": 0, "max_same_direction_per_day": 2})})
    selected, rejected = score_and_select(pd.concat([predictions, another]), candidates, cfg)
    assert len(selected) == 1
    assert rejected.iloc[0].rejection_reason == "candidate_already_selected_at_another_horizon"


def test_raw_analog_returns_and_excursions_follow_long_short_direction():
    time = pd.Timestamp("2026-01-05 10:00", tz="America/New_York")
    test = pd.DataFrame({"candidate_id": ["long", "short"], "timestamp": [time, time], "direction": [1, -1]})
    kernel = pd.DataFrame({"timestamp": [time], "expected_return": [.02], "median_return": [.01],
                           "predicted_mfe": [.03], "predicted_mae": [.01], "win_probability": [.7]})
    result = directional_analog_predictions(test, kernel)
    assert result.expected_return.tolist() == [.02, -.02]
    assert result.median_return.tolist() == [.01, -.01]
    assert result.predicted_mfe.tolist() == [.03, .01]
    assert result.predicted_mae.tolist() == [.01, .03]
    assert result.raw_up_probability.tolist() == [.7, .7]
    assert result.win_probability.isna().all()
    assert result.strategy_eligibility.eq("unsupported_probability_semantics").all()


def test_raw_analog_is_visible_but_cannot_pollute_classical_ensemble(config):
    time = pd.Timestamp("2026-01-05 10:00", tz="America/New_York")
    predictions, candidates = _inputs([time])
    predictions["model"] = "logistic"
    analog = predictions.copy()
    analog["model"] = "analog_kernel"
    analog["expected_return"] = -100
    analog["win_probability"] = np.nan
    selected, rejected = score_and_select(pd.concat([predictions, analog]), candidates, config)
    assert len(selected) == 1 and rejected.empty
    assert selected.iloc[0].expected_return == .01
    only_raw, rejection = score_and_select(analog, candidates, config)
    assert only_raw.empty
    assert rejection.iloc[0].rejection_reason == "unsupported_probability_semantics"

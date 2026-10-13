import numpy as np
import pandas as pd
import pytest

from intraday_quant.backtest.execution import option_entry_fill, option_exit_fill
from intraday_quant.calendar import filter_regular_session, market_schedule
from intraday_quant.candidates.pipeline import generate_candidates
from intraday_quant.data.clean import clean_bars
from intraday_quant.features.pipeline import same_minute_rvol, session_vwap
from intraday_quant.labels.pipeline import build_labels
from intraday_quant.models.walk_forward import _dataset, make_folds
from intraday_quant.portfolio.selector import score_and_select


def _bar(timestamp, close=100.0, volume=10):
    return {"timestamp": timestamp, "symbol": "SPX", "open": close, "high": close + 1,
            "low": close - 1, "close": close, "volume": volume, "vwap": close,
            "bid": close - .1, "ask": close + .1, "trade_count": 1,
            "source": "test", "data_quality": "ok"}


def test_timezone_dedup_and_invalid_volume():
    raw = pd.DataFrame([_bar("2026-03-09 09:30"), _bar("2026-03-09 09:30")])
    clean, stats = clean_bars(raw, "America/New_York")
    assert len(clean) == 1 and clean.iloc[0].close == 100
    assert str(clean.timestamp.dt.tz) == "America/New_York"
    assert stats["duplicates_removed"] == 1
    conflicting = pd.DataFrame([_bar("2026-03-09 09:30"), _bar("2026-03-09 09:30", 101)])
    rejected, conflict_stats = clean_bars(conflicting, "America/New_York")
    assert rejected.empty
    assert conflict_stats["ambiguous_duplicate_keys"] == 1
    assert conflict_stats["ambiguous_duplicate_rows_removed"] == 2
    bad, stats = clean_bars(pd.DataFrame([_bar("2026-03-09 09:30", volume=-1)]), "America/New_York")
    assert bad.empty and stats["invalid_rows_removed"] == 1


def test_official_session_excludes_1600_tick():
    timestamps = pd.to_datetime(["2026-07-02 15:59", "2026-07-02 16:00"]).tz_localize("America/New_York")
    frame = pd.DataFrame({"timestamp": timestamps})
    result = filter_regular_session(frame, market_schedule("2026-07-02", "2026-07-02"))
    assert result["timestamp"].dt.strftime("%H:%M").tolist() == ["15:59"]


def test_vwap_and_same_minute_rvol_are_past_only():
    frame = pd.DataFrame({
        "timestamp": pd.to_datetime(["2026-01-05 09:30", "2026-01-05 09:31"]).tz_localize("America/New_York"),
        "high": [11, 13], "low": [9, 11], "close": [10, 12], "volume": [100, 300],
    })
    np.testing.assert_allclose(session_vwap(frame), [10, 11.5])
    rows = []
    for day, multiplier in zip(pd.date_range("2026-01-05", periods=5, freq="B"), [1, 1, 1, 2, 99]):
        for minute, volume in [("09:30", 10), ("09:31", 20)]:
            rows.append((pd.Timestamp(f"{day.date()} {minute}", tz="America/New_York"), volume * multiplier))
    volume_frame = pd.DataFrame(rows, columns=["timestamp", "volume"])
    baseline = same_minute_rvol(volume_frame.iloc[:-2], lookback_days=3)
    future = same_minute_rvol(volume_frame, lookback_days=3)
    np.testing.assert_allclose(baseline, future.iloc[:-2], equal_nan=True)
    assert future.iloc[7] == 2.0


def test_opening_range_candidate_is_after_completed_range(config):
    times = pd.date_range("2026-01-05 09:30", periods=17, freq="1min", tz="America/New_York")
    frame = pd.DataFrame({
        "timestamp": times, "session_date": [t.date() for t in times], "close": [100] * 15 + [100.5, 101.5],
        "opening_range_high": [np.nan] * 15 + [101, 101], "opening_range_low": [np.nan] * 15 + [99, 99],
        "market_confirmation_score": 1.0, "rvol_same_minute": 1.2, "ret_5m": .001,
        "ret_15m": .002, "dist_vwap": .001, "volume_acceleration": .1, "rolling_atr": .2,
        "session_vwap": 100.0, "rolling_realized_vol": .0002,
    })
    out = generate_candidates(frame, config.model_copy(update={"setups": ["opening_range_breakout"]}))
    assert len(out) == 1 and out.iloc[0].timestamp == times[-1]


def test_labels_enter_next_minute(config):
    times = pd.date_range("2026-01-05 09:30", periods=70, freq="1min", tz="America/New_York")
    features = pd.DataFrame({"timestamp": times, "open": range(100, 170), "high": range(101, 171),
                             "low": range(99, 169), "close": range(100, 170), "rolling_atr": 1.0})
    candidate = pd.DataFrame([{"candidate_id": "x", "timestamp": times[0], "session_date": times[0].date(),
                               "setup_type": "test", "direction": 1, "entry_reference": 999,
                               "feature_snapshot": "{}", "reason_codes": "test"}])
    labels = build_labels(candidate, features, config)
    assert labels.iloc[0].earliest_entry == times[1]
    assert labels.iloc[0].label_entry_price == 101


def test_walk_forward_has_no_overlap(config):
    for fold in make_folds(list(range(60)), config):
        assert not set(fold.train_dates) & set(fold.validation_dates)
        assert not set(fold.validation_dates) & set(fold.test_dates)
        assert max(fold.train_dates) < min(fold.validation_dates) < min(fold.test_dates)


def _quotes(signal, bid=1.0, ask=1.1):
    return pd.DataFrame([{"timestamp": signal + pd.Timedelta(minutes=1), "option_symbol": "SPX-C",
                          "call_put": "C", "bid": bid, "ask": ask, "bid_size": 5, "ask_size": 5,
                          "delta": .5, "dte": 0}])


def test_options_use_ask_and_bid_and_reject_wide(config):
    signal = pd.Timestamp("2026-01-05 10:00", tz="America/New_York")
    quotes = _quotes(signal)
    assert option_entry_fill(quotes, signal, 1, config.option_execution, .05).fill == pytest.approx(1.15)
    assert option_exit_fill(quotes, "SPX-C", signal, config.option_execution, .05).fill == pytest.approx(.95)
    assert not option_entry_fill(_quotes(signal, .1, 1), signal, 1, config.option_execution, 0).accepted


def test_selector_limits_and_allows_zero(config):
    times = pd.date_range("2026-01-05 10:00", periods=4, freq="60min", tz="America/New_York")
    candidates = pd.DataFrame({"candidate_id": list("abcd"), "timestamp": times,
        "session_date": [t.date() for t in times], "setup_type": "x", "direction": [1, -1, 1, -1],
        "entry_reference": 100, "feature_snapshot": "{}", "reason_codes": "x"})
    predictions = pd.DataFrame({"candidate_id": list("abcd"), "timestamp": times, "fold": 0,
        "horizon_minutes": 15,
        "expected_return": .01, "median_return": .01, "win_probability": .8, "predicted_mfe": .02,
        "predicted_mae": .005, "uncertainty": .001, "similarity_score": .8,
        "validation_return_threshold": .001})
    assert len(score_and_select(predictions, candidates, config)[0]) <= 2
    zero = config.model_copy(update={"portfolio": config.portfolio.model_copy(update={"max_trades_per_day": 0})})
    selected, rejected = score_and_select(predictions, candidates, zero)
    assert selected.empty and len(rejected) == 4


def test_each_forecast_horizon_uses_its_own_forward_label():
    timestamp = pd.Timestamp("2026-01-05 10:00", tz="America/New_York")
    labels = pd.DataFrame([{
        "candidate_id": "x",
        "timestamp": timestamp,
        "session_date": timestamp.date(),
        "direction": 1,
        "forward_return_5m": 0.005,
        "MFE_5m": 0.007,
        "MAE_5m": 0.002,
        "forward_return_60m": -0.03,
        "MFE_60m": 0.01,
        "MAE_60m": 0.04,
    }])
    features = pd.DataFrame([{"timestamp": timestamp, "ret_1m": 0.001}])
    five = _dataset(labels, features, 5, 0.001).iloc[0]
    sixty = _dataset(labels, features, 60, 0.001).iloc[0]
    assert five["target_return"] == pytest.approx(0.005)
    assert five["target_win"] == 1
    assert five["horizon_minutes"] == 5
    assert sixty["target_return"] == pytest.approx(-0.03)
    assert sixty["target_win"] == 0
    assert sixty["horizon_minutes"] == 60



def test_closing_short_cover_setup_is_identified(config):
    times = pd.date_range("2026-07-16 15:50", periods=10, freq="1min", tz="America/New_York")
    frame = pd.DataFrame({
        "timestamp": times, "session_date": [t.date() for t in times], "close": np.linspace(100, 101, 10),
        "closing_10m": True, "ret_1m": .001, "ret_5m": .001, "ret_15m": .001,
        "ret_30m": -.001, "buy_pressure_proxy": 1.2, "volume_zscore": 2.0,
        "cross_asset_breadth_score": .8, "market_confirmation_score": 1.0,
        "rvol_same_minute": 1.5, "dist_vwap": .001, "volume_acceleration": .5,
        "rolling_atr": .2, "session_vwap": 100.0, "rolling_realized_vol": .0002,
        "opening_range_high": 100.0, "opening_range_low": 99.0,
    })
    cfg = config.model_copy(update={"setups": ["closing_short_cover"]})
    result = generate_candidates(frame, cfg)
    assert not result.empty
    assert set(result["setup_type"]) == {"closing_short_cover"}
    assert result["timestamp"].dt.hour.eq(15).all()

def test_stale_option_quote_is_rejected(config):
    signal = pd.Timestamp("2026-01-05 10:00", tz="America/New_York")
    stale = _quotes(signal)
    stale["timestamp"] = signal + pd.Timedelta(minutes=5)
    assert not option_entry_fill(stale, signal, 1, config.option_execution, 0).accepted


def test_closing_candidate_keeps_to_close_barrier_label(config):
    times = pd.date_range("2026-07-16 15:50", periods=10, freq="1min", tz="America/New_York")
    features = pd.DataFrame({
        "timestamp": times, "open": np.linspace(100, 100.9, 10),
        "high": np.linspace(100.1, 101.0, 10), "low": np.linspace(99.9, 100.8, 10),
        "close": np.linspace(100, 100.9, 10), "rolling_atr": 0.1,
    })
    candidate = pd.DataFrame([{
        "candidate_id": "closing", "timestamp": times[4], "session_date": times[4].date(),
        "setup_type": "closing_short_cover", "direction": 1, "entry_reference": 100.4,
        "feature_snapshot": "{}", "reason_codes": "closing_10m",
    }])
    label = build_labels(candidate, features, config).iloc[0]
    assert pd.isna(label["forward_return_15m"])
    assert pd.notna(label["triple_barrier_return"])
    assert label["triple_barrier_mfe"] >= 0

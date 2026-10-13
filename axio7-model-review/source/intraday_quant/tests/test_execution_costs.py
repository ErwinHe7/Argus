import json

import numpy as np
import pandas as pd
import pytest
from pydantic import ValidationError

from intraday_quant.backtest.costs import CapacityUnavailable, FillCosts, fill_costs, minimum_round_trip_cost_return
from intraday_quant.backtest.execution import option_entry_fill, option_exit_fill
from intraday_quant.backtest.options import run_options_backtest
from intraday_quant.backtest.underlying import run_underlying_backtest
from intraday_quant.config import CostConfig, ExecutionCostConfig, OptionExecutionConfig
from intraday_quant.labels.pipeline import build_labels
from intraday_quant.models.specification import score_candidates
from intraday_quant.models.walk_forward import _dataset, mature_fold_partitions
from intraday_quant.reports.cost_audit import cost_audit


def _config(config, **execution):
    return config.model_copy(update={
        "target": "SPY", "symbols": ["SPY"],
        "execution_costs": ExecutionCostConfig(**execution),
        "risk": config.risk.model_copy(update={"max_holding_minutes": 2, "stop_value": 10, "take_profit_value": 10}),
    })


def _bars(start="2026-01-05 10:00", periods=5):
    times = pd.date_range(start, periods=periods, freq="1min", tz="America/New_York")
    return pd.DataFrame({
        "timestamp": times, "symbol": "SPY", "open": 100.0, "high": 101.0,
        "low": 99.0, "close": 100.0, "rolling_atr": 10.0, "volume": 10_000.0,
    })


def _signal(bars, direction=1):
    stamp = bars.iloc[0]["timestamp"]
    return pd.DataFrame([{
        "candidate_id": "x", "timestamp": stamp, "session_date": stamp.date(), "setup_type": "test",
        "direction": direction, "win_probability": .6, "score": 1.0, "fold": 0,
    }])


@pytest.mark.parametrize("field", ["commission_per_trade", "underlying_slippage_bps", "estimated_spread_bps", "option_slippage"])
@pytest.mark.parametrize("value", [-1.0, float("nan"), float("inf")])
def test_legacy_cost_inputs_reject_negative_and_nonfinite(field, value):
    with pytest.raises(ValidationError):
        CostConfig(**{field: value})


@pytest.mark.parametrize("field", ["trade_notional", "full_spread_bps", "commission_per_side", "impact_bps_at_full_participation"])
@pytest.mark.parametrize("value", [-1.0, float("nan"), float("inf")])
def test_execution_assumptions_reject_negative_and_nonfinite(field, value):
    with pytest.raises(ValidationError):
        ExecutionCostConfig(**{field: value})


@pytest.mark.parametrize("value", [0, -1, 1.01, float("nan"), float("inf")])
def test_participation_rate_is_finite_and_bounded(value):
    with pytest.raises(ValidationError):
        ExecutionCostConfig(max_participation_rate=value)


def test_impact_needs_capacity_and_latency_needs_nonnegative():
    with pytest.raises(ValidationError, match="positive impact requires"):
        ExecutionCostConfig(impact_bps_at_full_participation=1)
    with pytest.raises(ValidationError):
        ExecutionCostConfig(latency_ms=-1)


def test_same_quantity_long_and_short_reconcile_all_costs(config):
    cfg = _config(config, full_spread_bps=2, commission_per_side=3, require_volume_capacity=True,
                  impact_bps_at_full_participation=10)
    cfg.costs.underlying_slippage_bps = 2
    bars = _bars()
    for direction, exit_price in [(1, 101.0), (-1, 99.0)]:
        bars.loc[2, "close"] = exit_price
        row = run_underlying_backtest(_signal(bars, direction), bars, cfg).iloc[0]
        assert row.quantity == 1000
        assert row.gross_pnl == pytest.approx(1000)
        assert row.commission_cost == 6
        assert row.spread_cost == pytest.approx((100 + exit_price) * .1)
        assert row.slippage_cost == pytest.approx((100 + exit_price) * .2)
        assert row.impact_cost == pytest.approx((100 + exit_price) * .1)
        assert row.cost == pytest.approx(row.commission_cost + row.spread_cost + row.slippage_cost + row.impact_cost)
        assert row.net_pnl == pytest.approx(row.gross_pnl - row.cost)
        assert direction * row.quantity * (row.underlying_exit - row.underlying_entry) - row.commission_cost == pytest.approx(row.net_pnl)
        assert row.net_return == pytest.approx(row.net_pnl / row.trade_notional)
        assert row.break_even_return_bps == pytest.approx(row.cost / row.trade_notional * 10_000)
        assert row.entry_participation_rate == pytest.approx(.1)


def test_legacy_spread_semantics_and_commission_remain_per_side(config):
    config.costs.estimated_spread_bps = 3
    config.costs.underlying_slippage_bps = 2
    config.costs.commission_per_trade = 4
    one = fill_costs(100, 10, 1, config)
    assert one.spread_cost == pytest.approx(.3)
    assert one.commission_cost == 4
    assert one.fill_price == pytest.approx(100.05)
    assert minimum_round_trip_cost_return(config) == pytest.approx(.00108)


def test_scale_increases_impact_and_participation_rejects(config):
    cfg = _config(config, require_volume_capacity=True, impact_bps_at_full_participation=20)
    small = fill_costs(100, 100, 1, cfg, 10_000)
    large = fill_costs(100, 200, 1, cfg, 10_000)
    assert large.impact_cost == pytest.approx(4 * small.impact_cost)
    with pytest.raises(CapacityUnavailable, match="participation_limit_exceeded"):
        fill_costs(100, 1001, 1, cfg, 10_000)


@pytest.mark.parametrize("volume", [None, 0, -1, float("nan"), float("inf")])
def test_capacity_needs_positive_finite_observed_volume(config, volume):
    cfg = _config(config, require_volume_capacity=True)
    with pytest.raises(CapacityUnavailable, match="missing_positive"):
        fill_costs(100, 10, 1, cfg, volume)


def test_spx_cash_index_cannot_use_spy_proxy_volume(config):
    cfg = config.model_copy(update={"execution_costs": ExecutionCostConfig(require_volume_capacity=True)})
    bars = _bars()
    bars["symbol"] = "SPX"
    with pytest.raises(ValueError, match="cash index/proxy"):
        run_underlying_backtest(_signal(bars), bars, cfg)


def test_capacity_rejection_retains_machine_readable_entry_reason(config):
    cfg = _config(config, trade_notional=100_100, require_volume_capacity=True)
    bars = _bars()
    result = run_underlying_backtest(_signal(bars), bars, cfg)
    assert result.empty
    assert result.attrs["execution_rejections"][0]["rejection_reason"] == "participation_limit_exceeded"


def test_unpriceable_exit_aborts_instead_of_dropping_losing_trade(config):
    cfg = _config(config, require_volume_capacity=True)
    bars = _bars()
    bars.loc[1, "volume"] = 10
    bars.loc[2, "close"] = 99
    with pytest.raises(ValueError, match="unpriceable exit.*cannot discard"):
        run_underlying_backtest(_signal(bars), bars, cfg)


def test_entry_atr_and_volume_use_completed_state_not_entry_bar(config):
    cfg = _config(config, require_volume_capacity=True, impact_bps_at_full_participation=10)
    cfg.risk.max_holding_minutes = 1
    bars = _bars()
    baseline = run_underlying_backtest(_signal(bars), bars, cfg)
    changed = bars.copy()
    changed.loc[1, "rolling_atr"] = .0001
    changed.loc[1, "volume"] = 1
    mutated = run_underlying_backtest(_signal(changed), changed, cfg)
    pd.testing.assert_frame_equal(baseline, mutated)
    assert baseline.iloc[0].exit_reason == "time_exit"


def test_missing_atr_fails_closed_without_synthetic_barriers(config):
    cfg = _config(config)
    bars = _bars()
    bars.loc[0, "rolling_atr"] = np.nan
    result = run_underlying_backtest(_signal(bars), bars, cfg)
    assert result.empty
    assert result.attrs["execution_rejections"][0]["rejection_reason"] == "missing_positive_causal_atr"


def test_latency_is_strict_and_matches_training_labels(config):
    cfg = _config(config, latency_ms=60_000)
    bars = _bars(periods=10)
    signal = _signal(bars)
    trade = run_underlying_backtest(signal, bars, cfg).iloc[0]
    label = build_labels(signal, bars, cfg).iloc[0]
    assert trade.entry_time == bars.iloc[2].timestamp
    assert label.earliest_entry == trade.entry_time
    assert trade.exit_time > trade.entry_time >= trade.signal_time + pd.Timedelta(milliseconds=60_000)


@pytest.mark.parametrize("latency, entry_index", [(0, 1), (250, 2), (60_000, 2)])
def test_bar_start_availability_precedes_fill_and_matches_label_maturity(config, latency, entry_index):
    cfg = _config(config, latency_ms=latency)
    bars = _bars(periods=10)
    signal = _signal(bars)
    trade = run_underlying_backtest(signal, bars, cfg).iloc[0]
    labels = build_labels(signal, bars, cfg)
    label = labels.iloc[0]
    assert trade.signal_bar_time == bars.iloc[0].timestamp
    assert trade.signal_time == bars.iloc[0].timestamp + pd.Timedelta(minutes=1)
    assert trade.entry_time == bars.iloc[entry_index].timestamp == label.earliest_entry
    assert label.forward_available_at_5m == trade.entry_time + pd.Timedelta(minutes=5)
    data = _dataset(labels, bars, 5, minimum_round_trip_cost_return(cfg)).iloc[0]
    assert data.decision_as_of == trade.signal_time
    assert data.target_available_at == label.forward_available_at_5m


def test_purge_cannot_fit_future_unmatured_labels_even_with_zero_purge(config):
    cfg = config.model_copy(update={"walk_forward": config.walk_forward.model_copy(update={"purge_minutes": 0, "embargo_minutes": 0})})
    base = pd.Timestamp("2026-01-05 10:00", tz="America/New_York")
    train = pd.DataFrame({"id": ["mature", "future_label"], "decision_as_of": [base, base],
                          "target_available_at": [base + pd.Timedelta(minutes=5), base + pd.Timedelta(minutes=20)]})
    validation = pd.DataFrame({"id": ["validation_mature", "validation_future_label"],
                               "decision_as_of": [base + pd.Timedelta(minutes=10)] * 2,
                               "target_available_at": [base + pd.Timedelta(minutes=15), base + pd.Timedelta(minutes=40)]})
    test = pd.DataFrame({"id": ["test"], "decision_as_of": [base + pd.Timedelta(minutes=30)],
                         "target_available_at": [base + pd.Timedelta(minutes=35)]})
    kept_train, kept_validation, kept_test = mature_fold_partitions(train, validation, test, cfg)
    assert kept_train.id.tolist() == ["mature"]
    assert kept_validation.id.tolist() == ["validation_mature"]
    assert kept_test.id.tolist() == ["test"]


def test_missing_forward_minute_is_withheld_instead_of_replaced_by_later_bar(config):
    cfg = _config(config)
    bars = _bars(periods=10).drop(index=3)
    label = build_labels(_signal(bars), bars, cfg).iloc[0]
    assert pd.isna(label.forward_return_5m)
    assert pd.isna(label.forward_available_at_5m)
    assert label.label_rejection_reason_5m == "incomplete_discontinuous_or_invalid_price_window"
    cfg.risk.max_holding_minutes = 5
    barrier = build_labels(_signal(bars), bars, cfg).iloc[0]
    assert pd.isna(barrier.triple_barrier_return)
    assert pd.isna(barrier.net_return_after_cost)
    assert barrier.barrier_label_status.startswith("withheld")


def test_missing_pre_entry_minute_cannot_jump_to_later_session_price(config):
    cfg = _config(config)
    bars = _bars().drop(index=1)
    with pytest.raises(ValueError, match="missing minute bars"):
        run_underlying_backtest(_signal(bars), bars, cfg)


def test_session_exit_never_crosses_day_even_when_future_data_added(config):
    cfg = _config(config)
    cfg.risk.max_holding_minutes = 60
    bars = _bars("2026-01-05 15:57", 3)
    baseline = run_underlying_backtest(_signal(bars), bars, cfg)
    appended = pd.concat([bars, _bars("2026-01-06 09:30", 60)], ignore_index=True)
    future = run_underlying_backtest(_signal(bars), appended, cfg)
    pd.testing.assert_frame_equal(baseline, future)
    assert baseline.iloc[0].exit_reason == "session_close"
    assert baseline.iloc[0].exit_time == pd.Timestamp("2026-01-05 16:00", tz="America/New_York")


def test_incomplete_window_or_missing_minute_cannot_publish_pnl(config):
    cfg = _config(config)
    with pytest.raises(ValueError, match="incomplete holding-window"):
        run_underlying_backtest(_signal(_bars()), _bars(periods=2), cfg)
    cfg.risk.max_holding_minutes = 3
    bars = _bars().drop(index=2)
    with pytest.raises(ValueError, match="missing minute"):
        run_underlying_backtest(_signal(bars), bars, cfg)


def test_official_early_close_and_holiday_are_enforced(config):
    cfg = _config(config)
    cfg.risk.max_holding_minutes = 60
    bars = _bars("2026-11-27 12:57", 3)
    result = run_underlying_backtest(_signal(bars), bars, cfg)
    assert result.iloc[0].exit_time.hour == 13
    bars = _bars("2026-07-03 10:00")
    with pytest.raises(ValueError, match="official XNYS"):
        run_underlying_backtest(_signal(bars), bars, cfg)


def test_overlapping_position_is_rejected_online(config):
    cfg = _config(config)
    bars = _bars()
    first = _signal(bars)
    second = first.copy()
    second["candidate_id"] = "y"
    second["timestamp"] = bars.iloc[1].timestamp
    result = run_underlying_backtest(pd.concat([first, second]), bars, cfg)
    assert len(result) == 1
    assert result.attrs["execution_rejections"][0]["rejection_reason"] == "open_position_limit"


def test_opening_gap_stop_uses_adverse_open_not_unavailable_stop_price(config):
    cfg = _config(config)
    cfg.risk.stop_value = 1
    bars = _bars()
    bars.loc[2, ["open", "high", "low", "close"]] = [80, 81, 79, 80]
    result = run_underlying_backtest(_signal(bars), bars, cfg).iloc[0]
    assert result.exit_reason == "stop_loss"
    assert result.raw_exit == 80
    label = build_labels(_signal(bars), bars, cfg).iloc[0]
    assert label.triple_barrier_return == pytest.approx(result.gross_return)


def test_cost_audit_stress_break_even_and_json_contract(config):
    cfg = _config(config)
    bars = _bars()
    bars.loc[2, "close"] = 101
    trades = run_underlying_backtest(_signal(bars), bars, cfg)
    audit = cost_audit(trades, cfg)
    assert json.loads(json.dumps(audit, allow_nan=False))["status"] == "RESEARCH_ASSUMPTIONS_NOT_CALIBRATED"
    assert audit["break_even_cost_multiplier"] == pytest.approx(audit["gross_pnl"] / audit["cost"])
    for scenario in audit["cost_scenarios"]:
        assert scenario["net_pnl"] == pytest.approx(audit["gross_pnl"] - scenario["cost_multiplier"] * audit["cost"])
    invalid = trades.copy()
    invalid.loc[0, "cost"] = -1
    with pytest.raises(ValueError, match="negative"):
        cost_audit(invalid, cfg)


def test_zero_cost_break_even_is_null_and_nonfinite_ledger_rejected(config):
    cfg = _config(config, full_spread_bps=0, commission_per_side=0)
    cfg.costs.underlying_slippage_bps = 0
    trades = run_underlying_backtest(_signal(_bars()), _bars(), cfg)
    assert cost_audit(trades, cfg)["break_even_cost_multiplier"] is None
    with pytest.raises(ValidationError):
        FillCosts(fill_price=float("nan"), spread_cost=0, slippage_cost=0, impact_cost=0, commission_cost=0)


def test_selection_and_training_share_baseline_including_commission(config):
    cfg = _config(config, trade_notional=1000, full_spread_bps=6, commission_per_side=3)
    cfg.costs.underlying_slippage_bps = 2
    baseline = minimum_round_trip_cost_return(cfg)
    assert baseline == pytest.approx(.007)
    frame = pd.DataFrame({"expected_return": [.01], "win_probability": [.6], "predicted_mfe": [.01],
                          "predicted_mae": [.01], "uncertainty": [.01]})
    assert score_candidates(frame, cfg).iloc[0].expected_net_return == pytest.approx(.01 - baseline)


def _quotes(signal):
    return pd.DataFrame([{
        "timestamp": signal + pd.Timedelta(seconds=30), "option_symbol": "SPY-C", "call_put": "C",
        "bid": 1.0, "ask": 1.1, "bid_size": 10, "ask_size": 10, "delta": .5, "dte": 0,
        "iv": .2, "gamma": .1, "theta": -.1,
    }])


@pytest.mark.parametrize("field", ["bid", "ask", "bid_size", "ask_size", "delta", "dte"])
@pytest.mark.parametrize("value", [float("nan"), float("inf")])
def test_nonfinite_option_quotes_never_fill(config, field, value):
    signal = pd.Timestamp("2026-01-05 10:00", tz="America/New_York")
    quotes = _quotes(signal)
    quotes[field] = value
    assert not option_entry_fill(quotes, signal, 1, config.option_execution, .05).accepted
    if field in {"bid", "ask", "bid_size", "ask_size"}:
        assert not option_exit_fill(quotes, "SPY-C", signal, config.option_execution, .05).accepted


@pytest.mark.parametrize("slippage", [-1, float("nan"), float("inf")])
def test_option_slippage_never_creates_rebates_or_nonfinite_fills(config, slippage):
    signal = pd.Timestamp("2026-01-05 10:00", tz="America/New_York")
    with pytest.raises(ValueError, match="finite and non-negative"):
        option_entry_fill(_quotes(signal), signal, 1, config.option_execution, slippage)


def test_option_exit_requires_later_quote_and_observed_size(config):
    signal = pd.Timestamp("2026-01-05 10:00", tz="America/New_York")
    quotes = _quotes(signal)
    quotes["timestamp"] = signal
    assert not option_exit_fill(quotes, "SPY-C", signal, config.option_execution, .05).accepted
    quotes["timestamp"] = signal + pd.Timedelta(seconds=1)
    quotes["bid_size"] = 0
    assert not option_exit_fill(quotes, "SPY-C", signal, config.option_execution, .05).accepted
    quotes["bid_size"] = 10
    assert not option_exit_fill(quotes, "SPY-C", signal, config.option_execution, 2).accepted


def test_option_missing_exit_is_unliquidated_and_mid_costs_reconcile(config, monkeypatch):
    signal = pd.Timestamp("2026-01-05 10:00", tz="America/New_York")
    cfg = config.model_copy(update={"option_execution": OptionExecutionConfig(enabled=True, quotes_path="test-only")})
    trades = pd.DataFrame([{"trade_id": "x", "signal_time": signal, "exit_time": signal + pd.Timedelta(seconds=45), "direction": 1}])
    quotes = _quotes(signal)
    monkeypatch.setattr("intraday_quant.backtest.options.load_option_quotes", lambda path: quotes)
    result, status = run_options_backtest(trades, cfg)
    assert result.iloc[0].status == "unliquidated"
    assert pd.isna(result.iloc[0].net_pnl)
    assert "未清算" in status
    later = _quotes(signal)
    later["timestamp"] = signal + pd.Timedelta(seconds=60)
    quotes = pd.concat([quotes, later], ignore_index=True)
    filled, _ = run_options_backtest(trades, cfg)
    row = filled.iloc[0]
    assert row.status == "filled" and row.exit_time > row.entry_time
    assert row.mid_gross_pnl - row.all_in_cost == pytest.approx(row.net_pnl)
    assert row.spread_cost + row.slippage_cost + row.commission_cost == pytest.approx(row.all_in_cost)

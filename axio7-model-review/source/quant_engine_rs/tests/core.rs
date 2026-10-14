use std::{fs, path::Path};

use approx::assert_abs_diff_eq;
use axio_quant_engine::{
    config::ResearchConfig,
    data::{LicensedFileImporter, csv_import::MarketBarCsvImporter},
    domain::{CallPut, Candidate, MarketBar, MarketState, OptionQuote, Outcome, SetupType},
    engine::{analog, backtest, execution, features, labels, models, walk_forward},
};
use chrono::{DateTime, Duration, NaiveDate, Utc};
use tempfile::tempdir;

#[test]
fn option_costs_reconcile_mid_gross_to_net_and_increase_with_size() {
    let signal = ts("2026-07-16T14:00:00Z");
    let entry = quote(signal + Duration::seconds(1), 4.9, 5.0);
    let exit = quote(signal + Duration::minutes(5), 5.5, 5.6);
    let mut cfg = config();
    cfg.execution_costs.option_commission_per_contract_per_side = 0.65;
    cfg.execution_costs.option_impact_at_full_participation = 0.1;
    cfg.execution_costs.option_max_participation_rate = 0.5;
    let fill = execution::simulate_long_option_size(signal, exit.timestamp, &entry, &exit, 3, &cfg);
    assert_eq!(fill.filled_contracts, 3);
    assert_eq!(fill.exit_filled_contracts, 3);
    let costs = fill.cost_breakdown.unwrap();
    assert_abs_diff_eq!(
        fill.mid_gross_pnl_per_contract.unwrap(),
        60.0,
        epsilon = 1e-9
    );
    assert_abs_diff_eq!(costs.spread_cost, 10.0, epsilon = 1e-9);
    assert_abs_diff_eq!(costs.slippage_cost, 10.0, epsilon = 1e-9);
    assert_abs_diff_eq!(costs.market_impact_cost, 6.0, epsilon = 1e-9);
    assert_abs_diff_eq!(costs.commission_cost, 1.3, epsilon = 1e-9);
    assert_abs_diff_eq!(fill.net_pnl_per_contract.unwrap(), 32.7, epsilon = 1e-9);
    assert_abs_diff_eq!(fill.net_pnl_total.unwrap(), 98.1, epsilon = 1e-9);
    let smaller = execution::simulate_long_option(signal, exit.timestamp, &entry, &exit, &cfg);
    assert!(smaller.net_pnl_per_contract.unwrap() > fill.net_pnl_per_contract.unwrap());
    cfg.execution_costs.option_max_participation_rate = 0.25;
    let partial =
        execution::simulate_long_option_size(signal, exit.timestamp, &entry, &exit, 3, &cfg);
    assert_eq!(partial.fill_status, "PARTIAL_FILL");
    assert_eq!(partial.filled_contracts, 2);
    assert_eq!(partial.exit_filled_contracts, 2);
    assert_abs_diff_eq!(
        partial.net_pnl_total.unwrap(),
        2.0 * partial.net_pnl_per_contract.unwrap()
    );
}

#[test]
fn option_exit_liquidity_cannot_change_earlier_entry_or_invent_net_pnl() {
    let signal = ts("2026-07-16T14:00:00Z");
    let entry = quote(signal + Duration::seconds(1), 4.9, 5.0);
    let exit = quote(signal + Duration::minutes(5), 5.5, 5.6);
    let completed =
        execution::simulate_long_option_size(signal, exit.timestamp, &entry, &exit, 3, &config());
    let mut thin_exit = exit.clone();
    thin_exit.bid_size = 1;
    let unliquidated = execution::simulate_long_option_size(
        signal,
        exit.timestamp,
        &entry,
        &thin_exit,
        3,
        &config(),
    );
    assert_eq!(completed.filled_contracts, unliquidated.filled_contracts);
    assert_eq!(completed.entry_fill, unliquidated.entry_fill);
    assert_eq!(unliquidated.unliquidated_contracts, 2);
    assert_eq!(unliquidated.net_pnl_per_contract, None);
    assert_eq!(unliquidated.net_pnl_total, None);
    assert_eq!(unliquidated.cost_breakdown, None);
    let zero =
        execution::simulate_long_option_size(signal, exit.timestamp, &entry, &exit, 0, &config());
    assert_eq!(zero.filled_contracts, 0);
    assert_eq!(zero.net_pnl_total, None);
}

#[test]
fn option_cost_and_quote_inputs_fail_closed_on_nonfinite_negative_and_latency() {
    let signal = ts("2026-07-16T14:00:00Z");
    let entry = quote(signal + Duration::milliseconds(500), 4.9, 5.0);
    let exit = quote(
        signal + Duration::minutes(5) + Duration::milliseconds(500),
        5.5,
        5.6,
    );
    for bad in [f64::NAN, f64::INFINITY, -0.1] {
        let mut cfg = config();
        cfg.option_slippage = bad;
        let fill = execution::simulate_long_option(
            signal,
            signal + Duration::minutes(5),
            &entry,
            &exit,
            &cfg,
        );
        assert_eq!(fill.filled_contracts, 0);
        assert_eq!(fill.net_pnl_total, None);
        assert_eq!(
            fill.rejected_reason.as_deref(),
            Some("invalid_execution_cost_config")
        );
    }
    for bad in [f64::NAN, f64::INFINITY] {
        let mut bad_entry = entry.clone();
        bad_entry.bid = bad;
        let fill = execution::simulate_long_option(
            signal,
            signal + Duration::minutes(5),
            &bad_entry,
            &exit,
            &config(),
        );
        assert_eq!(fill.filled_contracts, 0);
        assert_eq!(fill.rejected_reason.as_deref(), Some("nonfinite_quote"));
    }
    let mut cfg = config();
    cfg.execution_costs.latency_ms = 750;
    let too_early =
        execution::simulate_long_option(signal, signal + Duration::minutes(5), &entry, &exit, &cfg);
    assert_eq!(
        too_early.rejected_reason.as_deref(),
        Some("entry_before_latency")
    );
    cfg.execution_costs.latency_ms = 250;
    let valid =
        execution::simulate_long_option(signal, signal + Duration::minutes(5), &entry, &exit, &cfg);
    assert_eq!(valid.fill_status, "FILLED");
    let mut bad_exit = exit.clone();
    bad_exit.timestamp = signal + Duration::minutes(5) + Duration::milliseconds(100);
    let no_exit = execution::simulate_long_option(
        signal,
        signal + Duration::minutes(5),
        &entry,
        &bad_exit,
        &cfg,
    );
    assert_eq!(
        no_exit.rejected_reason.as_deref(),
        Some("exit_before_latency")
    );
    assert_eq!(no_exit.filled_contracts, 1);
    assert_eq!(no_exit.net_pnl_total, None);
    bad_exit = exit.clone();
    bad_exit.strike += 5.0;
    let mismatch = execution::simulate_long_option(
        signal,
        signal + Duration::minutes(5),
        &entry,
        &bad_exit,
        &cfg,
    );
    assert_eq!(
        mismatch.rejected_reason.as_deref(),
        Some("contract_mismatch")
    );
}

fn cost_backtest_fixture() -> (Vec<MarketState>, Candidate, Vec<Outcome>) {
    let mut states: Vec<_> = (1..=31).map(|day| state(0, day)).collect();
    states.extend((1..=8).map(|minute| state(minute, 31)));
    let outcomes = (0..30)
        .map(|idx| Outcome {
            state_index: idx,
            entry_timestamp: states[idx].timestamp + Duration::minutes(1),
            horizon_minutes: 5,
            directional_return: 0.002,
            mfe: 0.003,
            mae: 0.001,
        })
        .collect();
    let candidate = Candidate {
        candidate_id: "cost-fixture".to_string(),
        timestamp: states[30].timestamp,
        session_date: states[30].session_date,
        state_index: 30,
        setup_type: SetupType::ClosingShortCover,
        direction: 1,
        entry_reference: states[30].close,
        reason_codes: vec!["TEST_ONLY".to_string()],
    };
    (states, candidate, outcomes)
}

#[test]
fn underlying_cost_gate_and_stress_report_include_commission_and_full_spread() {
    let (states, candidate, outcomes) = cost_backtest_fixture();
    let mut cfg = config();
    cfg.execution_costs.full_spread_bps = 4.0;
    cfg.commission_per_trade = 1.0;
    assert_abs_diff_eq!(
        backtest::estimated_underlying_cost_return(6000.0, &cfg).unwrap(),
        6.0 / 10_000.0 + 1.0 / 6000.0,
        epsilon = 1e-12
    );
    let result = backtest::run(&states, std::slice::from_ref(&candidate), &outcomes, &cfg);
    assert_eq!(result.trades.len(), 1);
    let trade = &result.trades[0];
    assert_abs_diff_eq!(
        trade.gross_return - trade.cost,
        trade.net_return,
        epsilon = 1e-12
    );
    let raw_entry = states[31].open;
    assert_abs_diff_eq!(
        (trade.underlying_exit - trade.underlying_entry - cfg.commission_per_trade) / raw_entry,
        trade.net_return,
        epsilon = 1e-12
    );
    let costs = trade.cost_breakdown.as_ref().unwrap();
    assert_abs_diff_eq!(
        costs.spread_cost + costs.slippage_cost + costs.commission_cost,
        trade.cost,
        epsilon = 1e-12
    );
    assert_eq!(result.cost_sensitivity.len(), 3);
    assert_abs_diff_eq!(
        result.cost_sensitivity[0].total_return,
        result.metrics.total_return,
        epsilon = 1e-12
    );
    assert!(
        result.cost_sensitivity[0].expectancy_per_trade
            > result.cost_sensitivity[1].expectancy_per_trade
    );
    cfg.commission_per_trade = 20.0;
    let rejected = backtest::run(&states, std::slice::from_ref(&candidate), &outcomes, &cfg);
    assert!(rejected.trades.is_empty());
    assert_eq!(
        rejected.decisions[0].rejection_reason.as_deref(),
        Some("nonpositive_expected_net_after_costs")
    );
}

#[test]
fn underlying_rejects_missing_out_of_order_bars_and_invalid_candidates() {
    let (mut states, candidate, outcomes) = cost_backtest_fixture();
    states[31].timestamp = candidate.timestamp;
    assert!(
        backtest::run(
            &states,
            std::slice::from_ref(&candidate),
            &outcomes,
            &config()
        )
        .trades
        .is_empty()
    );
    states[31].timestamp = candidate.timestamp + Duration::minutes(2);
    assert!(
        backtest::run(
            &states,
            std::slice::from_ref(&candidate),
            &outcomes,
            &config()
        )
        .trades
        .is_empty()
    );
    states[31].timestamp = candidate.timestamp + Duration::minutes(1);
    let mut invalid = candidate;
    invalid.state_index = usize::MAX;
    let result = backtest::run(&states, &[invalid], &outcomes, &config());
    assert_eq!(
        result.decisions[0].rejection_reason.as_deref(),
        Some("invalid_execution_input")
    );
    assert!(serde_json::to_string(&result.decisions).is_ok());
}

#[test]
fn execution_cost_serialization_preserves_legacy_profiles_without_invented_net() {
    let mut legacy = serde_json::to_value(config()).unwrap();
    legacy.as_object_mut().unwrap().remove("execution_costs");
    let cfg: ResearchConfig = serde_json::from_value(legacy).unwrap();
    assert_eq!(cfg.execution_costs, Default::default());
    let fill: axio_quant_engine::domain::OptionFill = serde_json::from_value(serde_json::json!({
        "option_symbol": "TEST", "entry_fill": 1.0, "exit_fill": 2.0,
        "gross_pnl_per_contract": 100.0, "rejected_reason": null
    }))
    .unwrap();
    assert_eq!(fill.net_pnl_total, None);
    assert_eq!(fill.mid_gross_pnl_per_contract, None);
}

#[test]
fn retrospective_exit_failures_invalidate_the_whole_evaluation() {
    let (states, candidate, outcomes) = cost_backtest_fixture();
    let mut invalid_prices = states.clone();
    invalid_prices[34].close = f64::NAN;
    let result = backtest::run(
        &invalid_prices,
        std::slice::from_ref(&candidate),
        &outcomes,
        &config(),
    );
    assert_eq!(result.evaluation_status, "INVALID_EVALUATION");
    assert!(result.trades.is_empty());
    assert!(result.cost_sensitivity.is_empty());
    assert!(
        backtest::try_run(
            &invalid_prices,
            std::slice::from_ref(&candidate),
            &outcomes,
            &config()
        )
        .is_err()
    );
    let truncated = &states[..34];
    let result = backtest::run(
        truncated,
        std::slice::from_ref(&candidate),
        &outcomes,
        &config(),
    );
    assert_eq!(result.evaluation_status, "INVALID_EVALUATION");
    assert_eq!(
        result.invalidation_reason.as_deref(),
        Some("truncated_holding_window_without_session_close")
    );
    assert!(result.equity.is_empty());
    assert!(backtest::try_run(truncated, &[candidate], &outcomes, &config()).is_err());
}

#[test]
fn only_a_verified_configured_session_close_can_end_a_short_holding_window() {
    let (mut states, mut candidate, outcomes) = cost_backtest_fixture();
    states.truncate(35);
    for (offset, row) in states.iter_mut().skip(30).enumerate() {
        row.timestamp = ts("2026-07-31T19:55:00Z") + Duration::minutes(offset as i64);
        row.minutes_to_close = 5 - offset as i32;
    }
    candidate.timestamp = states[30].timestamp;
    let result = backtest::try_run(&states, &[candidate], &outcomes, &config()).unwrap();
    assert_eq!(result.trades.len(), 1);
    assert_eq!(result.trades[0].exit_reason, "session_close");
}

#[test]
fn explicit_cost_profile_loads_with_execution_disabled_and_legacy_profile_still_loads() {
    let cfg = axio_quant_engine::AppConfig::load("configs/research-cost-aware.yaml").unwrap();
    assert!(!cfg.live.enabled);
    assert!(!cfg.execution.enabled);
    assert!(!cfg.execution.allow_real_orders);
    assert_abs_diff_eq!(cfg.research.execution_costs.full_spread_bps, 2.0);
    assert_abs_diff_eq!(
        cfg.research
            .execution_costs
            .option_commission_per_contract_per_side,
        0.65
    );
    assert_eq!(cfg.research.execution_costs.latency_ms, 250);
    assert!(axio_quant_engine::AppConfig::load("configs/production.yaml").is_ok());
}

#[test]
fn underlying_holding_horizons_match_forward_labels_for_one_and_two_bars() {
    let (states, candidate, outcomes) = cost_backtest_fixture();
    for horizon in [1, 2] {
        let mut cfg = config();
        cfg.max_holding_minutes = horizon;
        cfg.underlying_slippage_bps = 0.0;
        let result =
            backtest::try_run(&states, std::slice::from_ref(&candidate), &outcomes, &cfg).unwrap();
        assert_eq!(result.trades.len(), 1);
        let trade = &result.trades[0];
        let labels = labels::forward_outcomes(&states, horizon);
        let label = labels
            .iter()
            .find(|label| label.state_index == candidate.state_index)
            .unwrap();
        assert_eq!(trade.entry_time, label.entry_timestamp);
        assert_eq!(trade.holding_minutes, horizon);
        assert_eq!(
            trade.signal_time,
            candidate.timestamp + Duration::minutes(1)
        );
        assert_eq!(
            trade.exit_time,
            trade.entry_time + Duration::minutes(horizon as i64)
        );
        assert!(trade.exit_time > trade.entry_time);
        assert_abs_diff_eq!(
            trade.gross_return,
            label.directional_return,
            epsilon = 1e-12
        );
    }
}

#[test]
fn underlying_entry_bar_standing_barriers_execute_and_stop_wins_ties() {
    let (states, candidate, outcomes) = cost_backtest_fixture();
    let mut cfg = config();
    cfg.max_holding_minutes = 2;
    cfg.stop_bps = 10.0;
    cfg.take_profit_bps = 10.0;
    for (high, low, expected_reason) in [
        (6001.5, 5990.0, "stop_loss"),
        (6010.0, 6000.5, "take_profit"),
        (6010.0, 5990.0, "stop_loss"),
    ] {
        let mut scenario = states.clone();
        scenario[31].high = high;
        scenario[31].low = low;
        let result =
            backtest::try_run(&scenario, std::slice::from_ref(&candidate), &outcomes, &cfg)
                .unwrap();
        assert_eq!(result.trades.len(), 1);
        let trade = &result.trades[0];
        assert_eq!(trade.exit_reason, expected_reason);
        assert_eq!(trade.holding_minutes, 1);
        assert_eq!(
            trade.exit_time,
            scenario[31].timestamp + Duration::minutes(1)
        );
        assert!(trade.exit_time > trade.entry_time);
    }
}

#[test]
fn underlying_positive_latency_cannot_use_the_already_passed_boundary_open() {
    let (states, candidate, outcomes) = cost_backtest_fixture();
    let mut cfg = config();
    cfg.max_holding_minutes = 1;
    cfg.execution_costs.latency_ms = 250;
    let result =
        backtest::try_run(&states, std::slice::from_ref(&candidate), &outcomes, &cfg).unwrap();
    assert_eq!(result.trades.len(), 1);
    let trade = &result.trades[0];
    assert_eq!(
        trade.signal_time,
        candidate.timestamp + Duration::minutes(1)
    );
    assert_eq!(trade.entry_time, states[32].timestamp);
    assert_eq!(trade.holding_minutes, 1);
    assert!(trade.entry_time > trade.signal_time);
}

#[test]
fn forward_labels_require_complete_positive_continuous_same_instrument_horizons() {
    let states: Vec<_> = (0..4).map(|minute| state(minute, 1)).collect();
    assert!(labels::forward_outcomes(&states, 0).is_empty());
    assert!(labels::forward_outcomes(&states, usize::MAX).is_empty());
    let complete = labels::forward_outcomes(&states, 3);
    assert_eq!(complete.len(), 1);
    assert_eq!(complete[0].state_index, 0);
    assert_eq!(labels::forward_outcomes(&states, 1).len(), 3);
    let mut missing = states.clone();
    missing.remove(2);
    assert!(labels::forward_outcomes(&missing, 2).is_empty());
    let mut next_session = states.clone();
    next_session[3].session_date = NaiveDate::from_ymd_opt(2026, 7, 2).unwrap();
    assert!(labels::forward_outcomes(&next_session, 3).is_empty());
    let mut wrong_symbol = states.clone();
    wrong_symbol[2].symbol = "QQQ".to_string();
    assert!(labels::forward_outcomes(&wrong_symbol, 3).is_empty());
    let mut bad_price = states;
    bad_price[2].close = f64::NAN;
    assert!(labels::forward_outcomes(&bad_price, 3).is_empty());
}

fn config() -> ResearchConfig {
    ResearchConfig {
        target: "SPX".to_string(),
        targets: Vec::new(),
        timezone: "America/New_York".to_string(),
        session_open: "09:30".to_string(),
        session_close: "16:00".to_string(),
        horizons: vec![15, 30, 60],
        max_trades_per_day: 2,
        cooldown_minutes: 0,
        analog_neighbors: 10,
        analog_bandwidth: 1.0,
        validation_score_threshold: -100.0,
        stop_bps: 100.0,
        take_profit_bps: 100.0,
        max_holding_minutes: 5,
        underlying_slippage_bps: 1.0,
        commission_per_trade: 0.0,
        option_slippage: 0.05,
        option_max_spread_pct: 0.20,
        option_max_staleness_seconds: 60,
        execution_costs: Default::default(),
        regime: Default::default(),
    }
}

fn ts(value: &str) -> DateTime<Utc> {
    DateTime::parse_from_rfc3339(value)
        .unwrap()
        .with_timezone(&Utc)
}

fn bar(timestamp: DateTime<Utc>, symbol: &str, close: f64, volume: f64) -> MarketBar {
    MarketBar {
        timestamp,
        symbol: symbol.to_string(),
        open: close - 0.1,
        high: close + 0.3,
        low: close - 0.3,
        close,
        volume,
        vwap: None,
        bid: None,
        ask: None,
        trade_count: Some(10),
        source: "TEST_FIXTURE".to_string(),
        data_quality: "test_only".to_string(),
    }
}

fn fixture_bars(days: usize, minutes: usize) -> Vec<MarketBar> {
    let first = ts("2026-07-01T13:30:00Z");
    let mut output = Vec::new();
    for day in 0..days {
        let start = first + Duration::days(day as i64);
        for minute in 0..minutes {
            let time = start + Duration::minutes(minute as i64);
            let drift =
                day as f64 * 4.0 + minute as f64 * 0.04 + ((minute % 9) as f64 - 4.0) * 0.03;
            output.push(bar(
                time,
                "SPX",
                6000.0 + drift,
                1000.0 + minute as f64 * 5.0,
            ));
            for (symbol, multiplier) in [
                ("SPY", 0.1),
                ("QQQ", 0.07),
                ("SOXX", 0.05),
                ("IWM", 0.03),
                ("ES", 1.0),
                ("VIX", -0.01),
            ] {
                output.push(bar(time, symbol, 500.0 + drift * multiplier, 20_000.0));
            }
        }
    }
    output
}

fn state(index: usize, day: u32) -> MarketState {
    let timestamp = ts(&format!("2026-07-{day:02}T13:30:00Z")) + Duration::minutes(index as i64);
    MarketState {
        timestamp,
        session_date: NaiveDate::from_ymd_opt(2026, 7, day).unwrap(),
        symbol: "SPX".to_string(),
        open: 5999.8 + index as f64,
        high: 6000.5 + index as f64,
        low: 5999.5 + index as f64,
        close: 6000.0 + index as f64,
        atr: 2.0,
        ret_1m: index as f64 * 1e-6,
        ret_3m: index as f64 * 1.5e-6,
        ret_5m: index as f64 * 2e-6,
        ret_15m: index as f64 * 3e-6,
        ret_30m: index as f64 * 4e-6,
        ret_60m: index as f64 * 5e-6,
        active_5m_return: index as f64 * 1e-6,
        last_completed_5m_return: index.saturating_sub(5) as f64 * 1e-6,
        last_completed_15m_return: index.saturating_sub(15) as f64 * 1e-6,
        slope_15m: 0.00001,
        dist_vwap: 0.0001,
        dist_session_open: 0.0002,
        rolling_realized_vol: 0.001,
        normalized_range: 0.0002,
        upper_wick_ratio: 0.25,
        lower_wick_ratio: 0.25,
        close_location_value: 0.0,
        distance_session_high: -0.001,
        distance_session_low: 0.001,
        failed_opening_breakout: 0.0,
        consecutive_up_bars: 1,
        consecutive_down_bars: 0,
        return_acceleration: 0.0,
        volume_zscore: 0.1,
        volume_acceleration: 0.0,
        session_range_position: 0.6,
        cross_asset_breadth_score: 0.5,
        risk_rotation_score: 0.001,
        market_confirmation_score: 0.5,
        cross_asset_context_complete: true,
        cross_asset_context_coverage: 1.0,
        closing_short_cover_score: 0.0,
        rvol_same_minute: 1.0,
        minutes_from_open: index as i32,
        minutes_to_close: 390 - index as i32,
        bucket_5m: index as i32 / 5,
        bucket_15m: index as i32 / 15,
        minute_in_5m_bucket: index as i32 % 5,
        completed_5m_bucket_valid: index % 5 == 4,
        continuous_minute_count: index + 1,
    }
}

#[test]
fn csv_requires_offset_deduplicates_and_rejects_bad_rows() {
    let directory = tempdir().unwrap();
    let path = directory.path().join("bars.csv");
    fs::write(
        &path,
        "timestamp,symbol,open,high,low,close,volume,source\n\
         2026-07-16T09:30:00-04:00,SPX,6000,6002,5999,6001,0,CBOE\n\
         2026-07-16T09:30:00-04:00,SPX,6000,6002,5999,6001,0,CBOE\n\
         2026-07-16 09:31:00,SPX,6001,6003,6000,6002,0,CBOE\n\
         2026-07-16T09:32:00-04:00,SPX,6002,6000,6001,6002,-1,CBOE\n",
    )
    .unwrap();
    let report = MarketBarCsvImporter.import(Path::new(&path)).unwrap();
    assert_eq!(report.accepted_rows, 1);
    assert_eq!(report.duplicate_rows, 1);
    assert_eq!(report.rejected_rows, 2);
    assert_eq!(report.records[0].timestamp, ts("2026-07-16T13:30:00Z"));
}

#[test]
fn features_are_point_in_time_and_rvol_uses_prior_sessions() {
    let bars = fixture_bars(3, 60);
    let original = features::build_states(&bars, "SPX", &config()).unwrap();
    let mut changed = bars.clone();
    let future_timestamp = ts("2026-07-03T14:20:00Z");
    for row in changed
        .iter_mut()
        .filter(|row| row.timestamp >= future_timestamp)
    {
        row.close *= 1.25;
        row.high = row.high.max(row.close);
        row.low = row.low.min(row.close);
    }
    let mutated = features::build_states(&changed, "SPX", &config()).unwrap();
    let cutoff = original
        .iter()
        .position(|row| row.timestamp >= future_timestamp)
        .unwrap();
    assert_eq!(&original[..cutoff], &mutated[..cutoff]);
    assert!(original.iter().all(|row| row.volume_zscore.is_finite()));
}

#[test]
fn five_minute_feature_never_uses_unfinished_future_minutes() {
    let bars = fixture_bars(1, 20);
    let states = features::build_states(&bars, "SPX", &config()).unwrap();
    let first_completed = states[5].last_completed_5m_return;
    assert_ne!(first_completed, 0.0);
    assert_eq!(states[5].bucket_5m, 1);
    assert_eq!(states[7].minute_in_5m_bucket, 2);
    assert_abs_diff_eq!(states[7].last_completed_5m_return, first_completed);
    assert_ne!(states[7].active_5m_return, states[9].active_5m_return);
}

#[test]
fn time_bucket_audit_keeps_test_partition_out_of_selection() {
    let mut states = Vec::new();
    let mut outcomes = Vec::new();
    for day in 1..=20 {
        let mut row = state(4, day);
        row.active_5m_return = 0.002;
        row.minute_in_5m_bucket = 4;
        row.bucket_5m = 0;
        let idx = states.len();
        outcomes.push(Outcome {
            state_index: idx,
            entry_timestamp: row.timestamp + Duration::minutes(1),
            horizon_minutes: 15,
            directional_return: -0.001,
            mfe: 0.001,
            mae: 0.0005,
        });
        states.push(row);
    }
    let audit = axio_quant_engine::engine::effects::audit_time_bucket_reversals(&states, &outcomes);
    assert_eq!(audit.len(), 1);
    assert_eq!(audit[0].train_samples, 12);
    assert_eq!(audit[0].validation_samples, 4);
    assert_eq!(audit[0].test_samples, 4);
    assert_eq!(audit[0].test_reversal_rate, 1.0);
    assert!(!audit[0].selected_on_validation); // minimum-sample guard
}

#[test]
fn labels_begin_after_signal_minute() {
    let states: Vec<_> = (0..20).map(|idx| state(idx, 1)).collect();
    let outcomes = labels::forward_outcomes(&states, 5);
    assert_eq!(outcomes[0].state_index, 0);
    assert_eq!(outcomes[0].entry_timestamp, states[1].timestamp);
    assert_eq!(outcomes[0].horizon_minutes, 5);
}

#[test]
fn analogs_are_strictly_historical_and_label_complete() {
    // One observation per session prevents overlapping minutes from being
    // treated as independent analog evidence.
    let states: Vec<_> = (0..30)
        .map(|idx| {
            let mut row = state(0, idx as u32 + 1);
            row.ret_1m = idx as f64 * 1e-6;
            row.bucket_5m = 0;
            row
        })
        .collect();
    let outcomes: Vec<_> = (0..29)
        .map(|idx| Outcome {
            state_index: idx,
            entry_timestamp: states[idx].timestamp + Duration::minutes(1),
            horizon_minutes: 2,
            directional_return: if idx % 2 == 0 { 0.002 } else { -0.001 },
            mfe: 0.003,
            mae: 0.001,
        })
        .collect();
    let prediction = analog::predict(&states, &outcomes, 29, 1, 10, 1.0).unwrap();
    assert_eq!(prediction.neighbor_count, 10);
    assert!(
        prediction
            .analogs
            .iter()
            .all(|row| row.analog_timestamp < states[29].timestamp)
    );
    assert!(prediction.effective_sample_size > 0.0);
    assert!(prediction.max_day_weight <= 1.0);
    assert!((0.0..=1.0).contains(&prediction.win_probability));
}

#[test]
fn rule_layer_sends_at_most_ten_candidates_per_session_to_models() {
    let mut states: Vec<_> = (0..200).map(|idx| state(idx, 1)).collect();
    for row in &mut states {
        row.minutes_from_open = 60;
        row.minutes_to_close = 330;
        row.dist_session_open = 0.003;
        row.dist_vwap = 0.0002;
        row.market_confirmation_score = 1.0;
    }
    let candidates = axio_quant_engine::engine::candidates::generate_candidates(&states);
    assert!(candidates.len() <= 10);
}

#[test]
fn walk_forward_has_purge_and_embargo_gaps() {
    let folds = walk_forward::expanding_folds(1_000, 400, 100, 100, 60, 15);
    assert!(!folds.is_empty());
    for fold in folds {
        assert_eq!(fold.validation.start - fold.train.end, 60);
        assert_eq!(fold.test.start - fold.validation.end, 15);
        assert!(fold.train.end <= fold.validation.start && fold.validation.end <= fold.test.start);
    }
}

fn quote(timestamp: DateTime<Utc>, bid: f64, ask: f64) -> OptionQuote {
    OptionQuote {
        timestamp,
        underlying: "SPX".to_string(),
        option_symbol: "SPXW_TEST_C".to_string(),
        expiry: NaiveDate::from_ymd_opt(2026, 7, 16).unwrap(),
        dte: 0,
        strike: 6000.0,
        call_put: CallPut::Call,
        bid,
        ask,
        bid_size: 10,
        ask_size: 10,
        last: None,
        volume: Some(100),
        open_interest_at_open: Some(1000),
        iv: Some(0.2),
        delta: Some(0.5),
        gamma: Some(0.01),
        theta: Some(-1.0),
        vega: Some(0.2),
        underlying_price: 6000.0,
        source: "OPRA".to_string(),
    }
}

#[test]
fn option_execution_buys_ask_sells_bid_and_rejects_wide_market() {
    let signal = ts("2026-07-16T19:50:00Z");
    let entry = quote(signal + Duration::seconds(1), 9.90, 10.00);
    let exit = quote(signal + Duration::minutes(5), 11.00, 11.10);
    let fill = execution::simulate_long_option(
        signal,
        signal + Duration::minutes(5),
        &entry,
        &exit,
        &config(),
    );
    assert_abs_diff_eq!(fill.entry_fill, 10.05);
    assert_abs_diff_eq!(fill.exit_fill, 10.95);
    assert_abs_diff_eq!(fill.gross_pnl_per_contract, 90.0, epsilon = 1e-8);
    let wide = quote(signal + Duration::seconds(1), 1.0, 2.0);
    let rejected = execution::simulate_long_option(
        signal,
        signal + Duration::minutes(5),
        &wide,
        &exit,
        &config(),
    );
    assert_eq!(rejected.rejected_reason.as_deref(), Some("spread_too_wide"));
}

#[test]
fn option_execution_respects_displayed_size() {
    let signal = ts("2026-07-16T14:00:00Z");
    let mut entry = quote(signal + Duration::minutes(1), 4.9, 5.0);
    let mut exit = quote(signal + Duration::minutes(6), 5.5, 5.6);
    entry.ask_size = 2;
    exit.bid_size = 1;
    let fill = execution::simulate_long_option_size(
        signal,
        signal + Duration::minutes(5),
        &entry,
        &exit,
        3,
        &config(),
    );
    assert_eq!(fill.requested_contracts, 3);
    assert_eq!(fill.filled_contracts, 2);
    assert_eq!(fill.exit_filled_contracts, 1);
    assert_eq!(fill.unliquidated_contracts, 1);
    assert_eq!(fill.fill_status, "UNLIQUIDATED");
    assert_eq!(fill.net_pnl_total, None);
}

#[test]
fn backtest_never_exceeds_daily_cap() {
    let states: Vec<_> = (0..100).map(|idx| state(idx, 1)).collect();
    let outcomes = labels::forward_outcomes(&states, 5);
    let candidates: Vec<_> = (30..90)
        .map(|idx| Candidate {
            candidate_id: format!("c{idx}"),
            timestamp: states[idx].timestamp,
            session_date: states[idx].session_date,
            state_index: idx,
            setup_type: SetupType::ClosingShortCover,
            direction: 1,
            entry_reference: states[idx].close,
            reason_codes: vec!["test".to_string()],
        })
        .collect();
    let result = backtest::run(&states, &candidates, &outcomes, &config());
    assert!(result.trades.len() <= 2);
}

#[test]
fn native_logistic_and_boosting_learn_without_python() {
    let rows: Vec<[f64; MarketState::FEATURE_COUNT]> = (0..240)
        .map(|idx| {
            let x = idx as f64 / 240.0 - 0.5;
            let mut row = [0.0; MarketState::FEATURE_COUNT];
            row[0] = x;
            row[1] = x * 0.5;
            row[6] = if idx % 2 == 0 { 1.0 } else { -1.0 };
            row
        })
        .collect();
    let labels: Vec<f64> = rows.iter().map(|row| (row[0] > 0.0) as u8 as f64).collect();
    let logistic = models::LogisticRegression::fit(&rows, &labels, 200, 0.1, 0.001);
    assert!(logistic.probability(rows[220]) > logistic.probability(rows[20]));
    let heads: Vec<[f64; 3]> = rows
        .iter()
        .map(|row| [row[0] * 0.02, row[0].abs() * 0.03, row[0].abs() * 0.01])
        .collect();
    let boosted = models::GradientBoostedHeads::fit(&rows, &heads, 24, 0.1);
    assert!(boosted.predict(rows[220])[0] > boosted.predict(rows[20])[0]);
}

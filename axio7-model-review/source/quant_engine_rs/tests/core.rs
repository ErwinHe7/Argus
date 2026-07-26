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
    assert_eq!(fill.filled_contracts, 1);
    assert_eq!(fill.fill_status, "PARTIAL_FILL");
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

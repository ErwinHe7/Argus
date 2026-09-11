use super::*;
use chrono::{Datelike, Duration, TimeZone, Weekday};
use std::collections::BTreeMap;

fn d(value: &str) -> Decimal {
    value.parse().unwrap()
}
fn history(count: usize) -> Vec<DailyBar> {
    let mut date = NaiveDate::from_ymd_opt(2024, 1, 2).unwrap();
    (0..count)
        .map(|_| {
            while matches!(date.weekday(), Weekday::Sat | Weekday::Sun) {
                date += Duration::days(1);
            }
            let open_at = New_York
                .with_ymd_and_hms(date.year(), date.month(), date.day(), 9, 30, 0)
                .unwrap()
                .with_timezone(&Utc);
            let close_at = New_York
                .with_ymd_and_hms(date.year(), date.month(), date.day(), 16, 0, 0)
                .unwrap()
                .with_timezone(&Utc);
            let bar = DailyBar {
                session_date: date,
                open_at,
                close_at,
                available_at: close_at + Duration::seconds(1),
                open: d("100"),
                high: d("101"),
                low: d("99"),
                close: d("100"),
                volume: 1_000_000,
            };
            date += Duration::days(1);
            bar
        })
        .collect()
}
fn evidence() -> Evidence {
    Evidence {
        source: "synthetic unit fixture".into(),
        dataset_sha256: "a".repeat(64),
        calendar_source: "synthetic test calendar".into(),
        adjustment_verified: true,
        coverage_verified: true,
        availability_verified: true,
        classification: DataClass::SyntheticFixture,
        license_scope: "test_only".into(),
    }
}
fn evaluation(bars: Vec<DailyBar>, strategy: Strategy) -> EvaluateRequest {
    EvaluateRequest {
        strategy,
        as_of: bars.last().unwrap().available_at,
        bars,
        evidence: evidence(),
        position: None,
        pending_entry: false,
        history_mode: HistoryMode::PointInTime,
    }
}
fn request(bars: Vec<DailyBar>, strategy: Strategy) -> ReplayRequest {
    ReplayRequest {
        symbol: "TEST".into(),
        strategy,
        bars,
        evidence: evidence(),
        starting_capital: d("10000"),
        commission_per_order: d("1"),
        slippage_bps: 10,
        cash_flows: vec![],
        code_revision: "synthetic-test".into(),
        dependency_versions: BTreeMap::from([("engine".into(), VERSION.into())]),
        research_parameters: None,
    }
}
fn shocked_history(count: usize) -> Vec<DailyBar> {
    let mut bars = history(count);
    bars[219].open = d("52");
    bars[219].high = d("53");
    bars[219].low = d("49");
    bars[219].close = d("50");
    for bar in bars.iter_mut().skip(220) {
        bar.open = d("50");
        bar.high = d("52");
        bar.low = d("49");
        bar.close = d("51");
    }
    bars
}

#[test]
fn decimal_strings_are_exact_checked_and_never_binary_money() {
    assert_eq!(d("0.1").checked_add(d("0.2")).unwrap(), d("0.3"));
    assert_eq!(d("1.000001").bps(1, true).unwrap(), d("0.000101"));
    for invalid in ["NaN", "1e2", "0.0000001", " 1", "+1", "1.", "1.2.3"] {
        assert!(invalid.parse::<Decimal>().is_err(), "{invalid}");
    }
    assert!(Decimal(i64::MAX).checked_add(d("1")).is_err());
    assert!(serde_json::from_str::<Decimal>("1.2").is_err());
    assert_eq!(serde_json::to_string(&d("-0.25")).unwrap(), "\"-0.250000\"");
}
#[test]
fn warmup_flat_and_pending_entries_abstain() {
    assert_eq!(
        evaluate(&evaluation(history(219), Strategy::MeanReversion))
            .unwrap()
            .reason,
        "warmup_incomplete"
    );
    assert_eq!(
        evaluate(&evaluation(history(220), Strategy::MeanReversion))
            .unwrap()
            .reason,
        "zero_dispersion_or_atr"
    );
    let mut input = evaluation(shocked_history(220), Strategy::MeanReversion);
    assert_eq!(evaluate(&input).unwrap().action, Action::EnterLong);
    input.pending_entry = true;
    assert_eq!(evaluate(&input).unwrap().action, Action::Hold);
}

#[test]
fn repeated_polling_does_not_change_decision_identity() {
    let mut input = evaluation(shocked_history(220), Strategy::MeanReversion);
    let first = evaluate(&input).unwrap();
    input.as_of += Duration::minutes(5);
    let later = evaluate(&input).unwrap();
    assert_eq!(first.decision_id, later.decision_id);
    assert_eq!(first.action, later.action);
}

#[test]
fn present_observed_history_is_allowed_only_for_current_decisions() {
    let mut input = evaluation(shocked_history(220), Strategy::MeanReversion);
    input.evidence.availability_verified = false;
    for bar in &mut input.bars {
        bar.available_at = input.as_of;
    }
    assert!(evaluate(&input).is_err());
    input.history_mode = HistoryMode::CurrentObservedSnapshot;
    assert_eq!(evaluate(&input).unwrap().action, Action::EnterLong);
    let mut replay_input = request(input.bars, Strategy::MeanReversion);
    replay_input.evidence = input.evidence;
    assert!(replay(&replay_input).is_err());
}

#[test]
fn newly_filled_position_waits_for_its_first_completed_session() {
    let mut input = evaluation(history(220), Strategy::Momentum);
    let next = history(221).pop().unwrap();
    input.as_of = next.open_at;
    input.position = Some(Position {
        quantity: 1,
        first_fill_price: d("100"),
        initial_stop: d("94"),
        current_stop: d("94"),
        entry_session: next.session_date,
        highest_close: Decimal::ZERO,
        held_sessions: 0,
    });
    let answer = evaluate(&input).unwrap();
    assert_eq!(answer.reason, "awaiting_first_completed_holding_session");
    assert_eq!(answer.stop_price, Some(d("94")));
}

#[test]
fn research_overrides_cannot_enter_runtime_evaluation_contract() {
    let mut raw =
        serde_json::to_value(evaluation(shocked_history(220), Strategy::MeanReversion)).unwrap();
    raw["research_parameters"] = serde_json::json!({"mr_rsi_max": 32});
    assert!(serde_json::from_value::<EvaluateRequest>(raw).is_err());
    let mut input = request(shocked_history(225), Strategy::MeanReversion);
    let baseline = replay(&input).unwrap();
    input.research_parameters = Some(ResearchParameters {
        stop_multiple: Some(1.5),
        ..Default::default()
    });
    let variant = replay(&input).unwrap();
    assert_ne!(baseline.run_id, variant.run_id);
    assert_ne!(
        baseline.open_position.unwrap().initial_stop,
        variant.open_position.unwrap().initial_stop
    );
    assert!(!variant.promotion_eligible && !variant.execution_authorized);
}
#[test]
fn momentum_excludes_current_high_and_low_and_uses_sma200() {
    let mut bars = history(220);
    bars[219].close = d("110");
    bars[219].high = d("120");
    let answer = evaluate(&evaluation(bars, Strategy::Momentum)).unwrap();
    assert_eq!(answer.action, Action::EnterLong);
    assert_eq!(answer.indicators.unwrap().prior55_high, Some(d("101")));
}
#[test]
fn wilder_initialization_and_population_dispersion_are_explicit() {
    let flat = indicators(&history(220)).unwrap();
    assert_eq!(flat.rsi14, 50.0);
    assert_eq!(flat.atr14, d("2"));
    assert_eq!(flat.dispersion20, 0.0);
    let mut bars = history(20);
    for (index, bar) in bars.iter_mut().enumerate() {
        let close = Decimal((100 + index as i64) * decimal::SCALE);
        bar.open = close;
        bar.close = close;
        bar.high = close.checked_add(d("1")).unwrap();
        bar.low = close.checked_sub(d("1")).unwrap();
    }
    let values = indicators(&bars).unwrap();
    assert_eq!(values.sma20, 109.5);
    assert!((values.dispersion20 - 33.25_f64.sqrt()).abs() < 1e-10);
    assert_eq!(values.rsi14, 100.0);
}
#[test]
fn inputs_fail_closed_for_missing_evidence_noncausal_and_bad_sessions() {
    let mut input = evaluation(history(220), Strategy::Momentum);
    input.evidence.adjustment_verified = false;
    assert!(evaluate(&input).is_err());
    input.evidence.adjustment_verified = true;
    input.bars[100].available_at = input.as_of + Duration::seconds(1);
    assert!(evaluate(&input).is_err());
    let mut input = evaluation(history(220), Strategy::Momentum);
    input.bars[100].high = d("90");
    assert!(evaluate(&input).is_err());
    let mut input = evaluation(history(220), Strategy::Momentum);
    input.bars[100].session_date = input.bars[99].session_date;
    assert!(evaluate(&input).is_err());
}
#[test]
fn sizing_reserves_fees_whole_shares_pending_cash_and_risk() {
    let mut input = SizeRequest {
        strategy: Strategy::MeanReversion,
        equity: d("10000"),
        cash: d("10000"),
        gross_exposure: d("0"),
        pending_commitment: d("0"),
        entry_price: d("100"),
        signal_atr: d("2"),
        daily_start_equity: d("10000"),
        peak_equity: d("10000"),
        paused: false,
        commission_per_order: d("1"),
        slippage_bps: 10,
    };
    let result = size_entry(&input).unwrap();
    assert_eq!(result.quantity, 5);
    assert_eq!(result.reserved_cash, d("502"));
    assert_eq!(result.initial_stop, Some(d("96")));
    assert!(result.planned_risk <= d("25"));
    input.pending_commitment = d("1990");
    assert_eq!(size_entry(&input).unwrap().quantity, 0);
    input.pending_commitment = d("0");
    input.equity = d("9900");
    assert_eq!(size_entry(&input).unwrap().reason, "daily_loss_limit");
    input.equity = d("9500");
    input.daily_start_equity = d("9500");
    assert_eq!(size_entry(&input).unwrap().reason, "drawdown_limit");
}
#[test]
fn replay_is_deterministic_next_open_and_journal_cash_conserves() {
    let input = request(shocked_history(225), Strategy::MeanReversion);
    let first = replay(&input).unwrap();
    let second = replay(&input).unwrap();
    assert_eq!(
        serde_json::to_value(&first).unwrap(),
        serde_json::to_value(second).unwrap()
    );
    let entry = first
        .journal
        .iter()
        .find(|e| e.kind == "entry_fill")
        .unwrap();
    assert_eq!(entry.timestamp, input.bars[220].open_at);
    assert!(entry.timestamp > input.bars[219].available_at);
    let final_cash = first
        .journal
        .iter()
        .try_fold(input.starting_capital, |cash, e| {
            cash.checked_add(e.cash_delta)
        })
        .unwrap();
    assert_eq!(final_cash, first.equity.last().unwrap().cash);
    for point in &first.equity {
        assert_eq!(
            point.cash.checked_add(point.market_value).unwrap(),
            point.equity
        );
    }
    assert!(
        !first.promotion_eligible
            && !first.execution_authorized
            && !first.quote_window_experiment_available
    );
}
#[test]
fn gap_stop_fills_at_adverse_open_and_never_stop_price() {
    let mut bars = shocked_history(223);
    bars[221].open = d("20");
    bars[221].high = d("21");
    bars[221].low = d("19");
    bars[221].close = d("20");
    let answer = replay(&request(bars, Strategy::MeanReversion)).unwrap();
    assert_eq!(answer.trades[0].reason, "gap_through_stop");
    assert_eq!(answer.trades[0].exit_price, d("19.98"));
    assert!(answer.trades[0].net_pnl < Decimal::ZERO);
}
#[test]
fn ten_sessions_exit_is_submitted_next_session() {
    let answer = replay(&request(shocked_history(232), Strategy::MeanReversion)).unwrap();
    let exit = answer
        .decisions
        .iter()
        .position(|d| d.reason == "MR_TEN_HELD_SESSIONS")
        .unwrap();
    assert_eq!(exit, 229);
    assert_eq!(
        answer.trades[0].exit_session,
        answer.input_manifest.bars[230].session_date
    );
}
#[test]
fn deposits_and_withdrawals_are_not_profits() {
    let mut input = request(history(225), Strategy::Momentum);
    input.cash_flows = vec![
        replay::CashFlow {
            session_date: input.bars[100].session_date,
            amount: d("5000"),
        },
        replay::CashFlow {
            session_date: input.bars[200].session_date,
            amount: d("-3000"),
        },
    ];
    let answer = replay(&input).unwrap();
    assert_eq!(answer.equity.last().unwrap().equity, d("12000"));
    assert_eq!(answer.metrics.net_time_weighted_return, 0.0);
    assert_eq!(answer.metrics.max_drawdown, 0.0);
}
#[test]
fn future_mutation_cannot_change_prior_decisions_or_events() {
    let mut input = request(shocked_history(235), Strategy::MeanReversion);
    let original = replay(&input).unwrap();
    for bar in input.bars.iter_mut().skip(233) {
        bar.open = d("90");
        bar.high = d("92");
        bar.low = d("89");
        bar.close = d("91");
    }
    let changed = replay(&input).unwrap();
    // Run identifiers bind all input bytes; causal decision identifiers bind only prefixes.
    assert_eq!(
        serde_json::to_value(&original.decisions[..233]).unwrap(),
        serde_json::to_value(&changed.decisions[..233]).unwrap()
    );
    assert_eq!(
        serde_json::to_value(&original.equity[..233]).unwrap(),
        serde_json::to_value(&changed.equity[..233]).unwrap()
    );
}
#[test]
fn trailing_stop_only_rises_and_updates_for_subsequent_bar() {
    let mut input = evaluation(history(220), Strategy::Momentum);
    input.bars[219].open = d("120");
    input.bars[219].close = d("120");
    input.bars[219].high = d("122");
    input.bars[219].low = d("115");
    input.position = Some(Position {
        quantity: 2,
        first_fill_price: d("100"),
        initial_stop: d("94"),
        current_stop: d("115"),
        entry_session: input.bars[215].session_date,
        highest_close: d("120"),
        held_sessions: 5,
    });
    assert!(evaluate(&input).unwrap().stop_price.unwrap() >= d("115"));
}

#[test]
fn descriptors_match_existing_market_map_with_decimal_input_precision() {
    let review = crate::market_map::illustrative_review().unwrap();
    let snapshot = &review["snapshot"];
    let mut bars = history(snapshot["bars"].as_array().unwrap().len());
    for (bar, source) in bars.iter_mut().zip(snapshot["bars"].as_array().unwrap()) {
        let decimal = |name: &str| -> Decimal {
            format!("{:.6}", source[name].as_f64().unwrap())
                .parse()
                .unwrap()
        };
        bar.open = decimal("open");
        bar.high = decimal("high");
        bar.low = decimal("low");
        bar.close = decimal("close");
    }
    let actual = indicators(&bars).unwrap();
    let expected = &snapshot["technical_indicators"];
    let last_sma = expected["sma20"]["points"]
        .as_array()
        .unwrap()
        .last()
        .unwrap()["price"]
        .as_f64()
        .unwrap();
    assert!((actual.sma20 - last_sma).abs() <= 0.000001);
    assert!((actual.rsi14 - expected["rsi14"]["latest"].as_f64().unwrap()).abs() <= 0.0001);
    assert!(
        (actual.atr14.as_f64() - expected["atr14"]["latest"].as_f64().unwrap()).abs() <= 0.000002
    );
}

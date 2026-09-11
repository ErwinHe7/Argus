use super::*;
use chrono::Duration;

fn d(value: &str) -> Decimal {
    value.parse().unwrap()
}
fn request(closes: &[&str]) -> GridReplayRequest {
    let start: DateTime<Utc> = "2026-08-03T13:30:00Z".parse().unwrap();
    let bars = closes
        .iter()
        .enumerate()
        .map(|(i, close)| {
            let open_at = start + Duration::days(i as i64);
            GridBar {
                session_date: open_at.date_naive(),
                open_at,
                close_at: open_at + Duration::hours(6) + Duration::minutes(30),
                available_at: open_at + Duration::hours(6) + Duration::minutes(31),
                open: d(close),
                high: d(close),
                low: d(close),
                close: d(close),
                volume: 1000,
            }
        })
        .collect::<Vec<_>>();
    GridReplayRequest {
        schema_version: "leo-grid-request.v1".into(),
        symbol: "SPY".into(),
        configured_at: bars[0].available_at,
        as_of: bars.last().unwrap().available_at,
        lower: d("90"),
        upper: d("110"),
        intervals: 2,
        spacing: Spacing::Arithmetic,
        tick_size: d("0.01"),
        starting_capital: d("2000"),
        commission_per_order: d("0"),
        slippage_bps: 0,
        portfolio_loss_limit_bps: 10_000,
        source_evidence: SourceEvidence {
            source: "Injected unit-test observations, not broker data".into(),
            dataset_sha256: "a".repeat(64),
            calendar_source: "Fixture consecutive UTC dates, not an exchange calendar".into(),
            adjustment: Adjustment::UnadjustedNoActions,
            coverage: Coverage::UserAssertedComplete,
            availability: Availability::PointInTime,
            classification: Classification::SyntheticFixture,
            license_scope: "Generated test observations".into(),
        },
        bars,
    }
}

fn opening(request: &mut GridReplayRequest, index: usize, price: &str) {
    let price = d(price);
    let bar = &mut request.bars[index];
    bar.open = price;
    bar.high = bar.high.max(price);
    bar.low = bar.low.min(price);
}

#[test]
fn arithmetic_and_geometric_levels_and_tick_collapse() {
    let input = request(&["105", "105"]);
    assert_eq!(
        replay(&input).unwrap().levels,
        vec![d("90"), d("100"), d("110")]
    );
    let mut geometric = input.clone();
    geometric.lower = d("25");
    geometric.upper = d("100");
    geometric.spacing = Spacing::Geometric;
    assert_eq!(
        replay(&geometric).unwrap().levels,
        vec![d("25"), d("50"), d("100")]
    );
    let mut collapsed = input;
    collapsed.tick_size = d("10");
    collapsed.intervals = 10;
    assert!(
        replay(&collapsed)
            .unwrap_err()
            .to_string()
            .contains("collapses")
    );
}

#[test]
fn geometric_tick_floor_never_rounds_up_through_a_collapsed_level() {
    let mut input = request(&["100.01", "100.01"]);
    input.lower = d("100");
    input.upper = d("100.02");
    input.spacing = Spacing::Geometric;
    assert!(
        replay(&input)
            .unwrap_err()
            .to_string()
            .contains("collapses")
    );
}

#[test]
fn no_initial_inventory_and_no_same_bar_round_trip() {
    let mut input = request(&["105", "100", "112", "112"]);
    opening(&mut input, 2, "100");
    let result = replay(&input).unwrap();
    assert_eq!(result.equity[0].quantity, 0);
    assert_eq!(result.equity[1].quantity, 0);
    assert_eq!(result.equity[2].quantity, 10);
    assert_eq!(result.equity[3].quantity, 0);
    let buy = result
        .journal
        .iter()
        .find(|e| e.kind == "buy_fill")
        .unwrap();
    let sell = result
        .journal
        .iter()
        .find(|e| e.kind == "sell_fill")
        .unwrap();
    assert!(sell.session_date > buy.session_date);
    assert_eq!(result.metrics.realized_cycle_pnl, d("120"));
}

#[test]
fn missed_buy_limit_expires_without_chasing_or_invented_intraday_fill() {
    let mut input = request(&["105", "100", "99", "99"]);
    opening(&mut input, 2, "101");
    input.bars[2].low = d("90");
    input.bars[2].high = d("115");
    let result = replay(&input).unwrap();
    assert_eq!(result.metrics.ending_quantity, 0);
    assert!(result.journal.iter().any(|e| e.kind == "buy_expired"));
    assert!(!result.journal.iter().any(|e| e.kind == "buy_fill"));
}

#[test]
fn existing_sell_can_retry_on_later_completed_close() {
    let mut input = request(&["105", "100", "100", "112", "112", "112"]);
    opening(&mut input, 4, "109");
    let result = replay(&input).unwrap();
    assert!(result.journal.iter().any(|e| e.kind == "sell_expired"));
    assert_eq!(result.metrics.completed_cycles, 1);
    assert_eq!(
        result
            .journal
            .iter()
            .filter(|e| e.kind == "sell_fill")
            .count(),
        1
    );
}

#[test]
fn positive_grid_profit_can_coexist_with_negative_total_equity() {
    let result = replay(&request(&[
        "105", "100", "100", "112", "112", "105", "100", "100", "80",
    ]))
    .unwrap();
    assert_eq!(result.metrics.realized_cycle_pnl, d("120"));
    assert_eq!(result.metrics.unrealized_pnl, d("-200"));
    assert_eq!(result.metrics.total_pnl, d("-80"));
    assert_eq!(result.metrics.ending_equity, d("1920"));
    assert_eq!(result.metrics.completed_cycles, 1);
}

#[test]
fn gap_loss_exit_is_latched_and_never_restarts_entries() {
    let mut input = request(&["105", "100", "95", "70", "105", "100", "100"]);
    opening(&mut input, 2, "100");
    input.portfolio_loss_limit_bps = 200;
    let result = replay(&input).unwrap();
    assert!(result.metrics.loss_latched);
    assert_eq!(result.metrics.realized_loss_exit_pnl, d("-300"));
    assert_eq!(result.metrics.ending_quantity, 0);
    assert_eq!(
        result
            .journal
            .iter()
            .filter(|e| e.kind == "buy_fill")
            .count(),
        1
    );
    assert!(!result.metrics.pending_liquidation);
    assert_eq!(result.metrics.completed_cycles, 0);
}

#[test]
fn final_loss_latch_preserves_unliquidated_inventory() {
    let mut input = request(&["105", "100", "95"]);
    opening(&mut input, 2, "100");
    input.portfolio_loss_limit_bps = 200;
    let result = replay(&input).unwrap();
    assert!(result.metrics.pending_liquidation);
    assert_eq!(result.metrics.ending_quantity, 10);
    assert_eq!(result.metrics.realized_exit_pnl, Decimal::ZERO);
    assert_eq!(result.metrics.total_pnl, d("-50"));
}

#[test]
fn adverse_costs_respect_limits_and_round_trip_allocation() {
    let mut input = request(&["105", "100", "100", "112", "112"]);
    input.commission_per_order = d("1");
    let result = replay(&input).unwrap();
    assert_eq!(result.slots[1].quantity_per_cycle, 9);
    assert_eq!(result.metrics.fees, d("2"));
    assert_eq!(result.metrics.total_pnl, d("106"));
    input.slippage_bps = 10;
    let slipped = replay(&input).unwrap();
    assert_eq!(slipped.metrics.ending_quantity, 0);
    assert_eq!(slipped.metrics.fees, Decimal::ZERO);
    assert!(slipped.journal.iter().any(|e| e.kind == "buy_expired"));
}

#[test]
fn separate_slots_conserve_cash_inventory_and_fees() {
    let result = replay(&request(&["105", "90", "90", "110", "110"])).unwrap();
    assert_eq!(result.metrics.completed_cycles, 2);
    let mut cash = d("2000");
    let mut quantity = 0_i64;
    for event in &result.journal {
        cash = cash.checked_add(event.cash_delta).unwrap();
        quantity += event.quantity_delta;
        assert!(cash >= Decimal::ZERO);
        assert!(quantity >= 0);
    }
    assert_eq!(cash, result.metrics.ending_cash);
    assert_eq!(quantity as u64, result.metrics.ending_quantity);
    assert_eq!(
        result.metrics.ending_equity,
        cash.checked_add(result.metrics.marked_inventory).unwrap()
    );
}

#[test]
fn future_observations_do_not_change_past_events_or_equity() {
    let full = request(&["105", "100", "100", "112", "112", "105", "100"]);
    let mut prefix = full.clone();
    prefix.bars.truncate(4);
    prefix.as_of = prefix.bars.last().unwrap().available_at;
    prefix.source_evidence.dataset_sha256 = "b".repeat(64);
    let early = replay(&prefix).unwrap();
    let later = replay(&full).unwrap();
    assert_eq!(
        serde_json::to_value(&early.equity).unwrap(),
        serde_json::to_value(&later.equity[..4]).unwrap()
    );
    assert_eq!(
        serde_json::to_value(&early.journal).unwrap(),
        serde_json::to_value(&later.journal[..early.journal.len()]).unwrap()
    );
    assert_eq!(early.configuration_hash, later.configuration_hash);
}

#[test]
fn intraday_extremes_do_not_fabricate_cycles() {
    let mut input = request(&["105", "105", "105", "105"]);
    for bar in &mut input.bars {
        bar.low = d("1");
        bar.high = d("1000");
    }
    let result = replay(&input).unwrap();
    assert_eq!(result.metrics.completed_cycles, 0);
    assert!(result.journal.is_empty());
}

#[test]
fn range_break_blocks_new_buys_but_keeps_owned_exits() {
    let mut input = request(&["105", "100", "89", "105"]);
    let result = replay(&input).unwrap();
    assert_eq!(result.metrics.ending_quantity, 0);
    assert!(
        result
            .journal
            .iter()
            .any(|e| e.reason == "opening_price_outside_frozen_range")
    );
    opening(&mut input, 2, "100");
    let result = replay(&input).unwrap();
    assert_eq!(result.metrics.ending_quantity, 10);
    assert_eq!(result.metrics.range_breaches, 1);
}

#[test]
fn hostile_or_unsupported_inputs_fail_closed() {
    let input = request(&["105", "105"]);
    let mut late = input.clone();
    late.configured_at += Duration::seconds(1);
    assert!(replay(&late).is_err());
    let mut future = input.clone();
    future.as_of -= Duration::seconds(1);
    assert!(replay(&future).is_err());
    let mut unavailable = input.clone();
    unavailable.bars[0].available_at = unavailable.bars[1].open_at;
    assert!(replay(&unavailable).is_err());
    let mut poor = input.clone();
    poor.starting_capital = d("1");
    assert!(replay(&poor).is_err());
    let mut no_trades = input.clone();
    no_trades.bars[1].volume = 0;
    assert!(replay(&no_trades).is_err());
    let mut too_much_work = input.clone();
    too_much_work.intervals = 100;
    too_much_work.bars = vec![input.bars[0].clone(); 1001];
    assert!(
        replay(&too_much_work)
            .unwrap_err()
            .to_string()
            .contains("work limit")
    );
    let mut invalid = serde_json::to_value(input).unwrap();
    invalid["source_evidence"]["coverage"] = "unknown".into();
    assert!(serde_json::from_value::<GridReplayRequest>(invalid).is_err());
    let mut invalid = serde_json::to_value(request(&["105", "105"])).unwrap();
    invalid["broker_password"] = "not allowed".into();
    assert!(serde_json::from_value::<GridReplayRequest>(invalid).is_err());
}

#[test]
fn source_classification_is_never_promoted_or_execution_authorized() {
    let mut input = request(&["105", "105"]);
    let fixture = replay(&input).unwrap();
    assert_eq!(fixture.evidence_status, "SYNTHETIC_DEMONSTRATION");
    input.source_evidence.classification = Classification::Observed;
    let observed = replay(&input).unwrap();
    assert_eq!(
        observed.evidence_status,
        "USER_SUPPLIED_OBSERVED_NOT_INDEPENDENTLY_VERIFIED"
    );
    assert!(
        !observed.execution_authorized
            && !observed.paper_execution_available
            && !observed.promotion_eligible
    );
    assert!(serde_json::to_value(observed).unwrap()["metrics"]["total_pnl"].is_string());
}

#[test]
fn repeated_fee_losses_cannot_borrow_or_size_up() {
    let mut prices = vec!["105"];
    for _ in 0..150 {
        prices.extend(["100", "100", "110", "110", "105"]);
    }
    let mut input = request(&prices);
    input.starting_capital = d("500");
    input.commission_per_order = d("12");
    let result = replay(&input).unwrap();
    assert!(result.metrics.total_pnl < Decimal::ZERO);
    assert!(
        result
            .equity
            .iter()
            .all(|point| point.cash >= Decimal::ZERO)
    );
    assert!(
        result
            .journal
            .iter()
            .filter(|e| e.kind == "buy_fill")
            .all(|e| e.quantity_delta == 2)
    );
    assert!(
        result
            .journal
            .iter()
            .any(|e| e.reason == "cash_or_exit_fee_reserve_insufficient")
    );
}

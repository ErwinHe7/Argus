use anyhow::{Context, Result, ensure};
use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};

use crate::data::massive_live::RealtimeStockTapeEvent;

pub const L1_ORDER_FLOW_SCHEMA_VERSION: &str = "axio.l1-order-flow-proxy.v1";

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum L1OrderFlowAvailability {
    Unavailable,
    ResearchProxy,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct L1OrderFlowSnapshot {
    pub schema_version: String,
    pub availability: L1OrderFlowAvailability,
    pub symbol: String,
    pub provider: String,
    pub observation_cutoff: DateTime<Utc>,
    pub latest_event_at: DateTime<Utc>,
    pub latest_input_available_at: DateTime<Utc>,
    pub quote_events: usize,
    pub quote_pairs: usize,
    pub sequence_gap_count: usize,
    pub raw_bid_order_flow: f64,
    pub raw_ask_order_flow: f64,
    pub raw_order_flow_imbalance: f64,
    pub normalized_order_flow_imbalance: f64,
    pub mean_depth_imbalance: f64,
    pub mean_microprice_deviation_bps: f64,
    pub mean_spread_bps: f64,
    pub quote_event_rate_per_second: f64,
    pub event_coverage_ratio: f64,
    pub size_semantics: String,
    pub source_scope: String,
    pub deep_ofi_compatible: bool,
    pub affects_decision: bool,
    pub caveats: Vec<String>,
}

#[derive(Debug, Clone, Copy)]
struct Quote<'a> {
    event: &'a RealtimeStockTapeEvent,
    event_at: DateTime<Utc>,
    sequence: u64,
    bid: f64,
    bid_size: f64,
    ask: f64,
    ask_size: f64,
}

fn valid_sha256(value: &str) -> bool {
    value.len() == 64
        && value.bytes().all(|byte| byte.is_ascii_hexdigit())
        && value.bytes().any(|byte| byte != b'0')
}

fn quote(event: &RealtimeStockTapeEvent, cutoff: DateTime<Utc>) -> Result<Option<Quote<'_>>> {
    if event.event_type != "Q" {
        return Ok(None);
    }
    let event_at = event
        .provider_timestamp
        .context("quote provider timestamp is required")?;
    ensure!(event_at <= cutoff, "future quote event is not eligible");
    ensure!(
        event.received_at <= cutoff,
        "quote received after the observation cutoff"
    );
    ensure!(
        event.model_eligible && !event.delayed && !event.stale && !event.future_timestamp,
        "delayed, stale, future, or unentitled quote is not model eligible"
    );
    ensure!(
        valid_sha256(&event.payload_sha256),
        "quote lineage hash is invalid"
    );
    let sequence = event.sequence.context("quote sequence is required")?;
    let bid = event.bid.context("quote bid is required")?;
    let bid_size = event
        .bid_size_provider_units
        .context("quote bid size is required")?;
    let ask = event.ask.context("quote ask is required")?;
    let ask_size = event
        .ask_size_provider_units
        .context("quote ask size is required")?;
    ensure!(
        bid.is_finite() && ask.is_finite() && bid_size.is_finite() && ask_size.is_finite(),
        "quote values must be finite"
    );
    ensure!(
        bid > 0.0 && ask > bid,
        "quote market must be positive and uncrossed"
    );
    ensure!(
        bid_size > 0.0 && ask_size > 0.0,
        "quote sizes must be positive"
    );
    Ok(Some(Quote {
        event,
        event_at,
        sequence,
        bid,
        bid_size,
        ask,
        ask_size,
    }))
}

fn bid_flow(previous: Quote<'_>, current: Quote<'_>) -> f64 {
    if current.bid > previous.bid {
        current.bid_size
    } else if current.bid < previous.bid {
        -previous.bid_size
    } else {
        current.bid_size - previous.bid_size
    }
}

/// Positive ask flow means displayed sell liquidity was removed or moved away;
/// negative ask flow means displayed sell pressure increased or moved closer.
fn ask_flow(previous: Quote<'_>, current: Quote<'_>) -> f64 {
    if current.ask < previous.ask {
        -current.ask_size
    } else if current.ask > previous.ask {
        previous.ask_size
    } else {
        previous.ask_size - current.ask_size
    }
}

/// Computes a causal level-1 stationary order-flow proxy. This is useful as an
/// engineering precursor, but it is not the ten-level LOBSTER input used by
/// Deep Order Flow Imbalance and is never inserted into the frozen model.
pub fn derive_l1_order_flow_snapshot(
    events: &[RealtimeStockTapeEvent],
    cutoff: DateTime<Utc>,
    max_age: Duration,
    minimum_pairs: usize,
) -> Result<L1OrderFlowSnapshot> {
    ensure!(
        max_age > Duration::zero(),
        "positive max quote age is required"
    );
    ensure!(minimum_pairs > 0, "minimum quote pairs must be positive");
    let mut quotes = events
        .iter()
        .filter_map(|event| quote(event, cutoff).transpose())
        .collect::<Result<Vec<_>>>()?;
    ensure!(
        quotes.len() > minimum_pairs,
        "insufficient eligible quote events"
    );
    let symbol = quotes[0].event.symbol.trim().to_ascii_uppercase();
    let provider = quotes[0].event.provider.trim().to_ascii_uppercase();
    let size_semantics = quotes[0].event.size_semantics.trim().to_string();
    ensure!(
        !symbol.is_empty() && !provider.is_empty(),
        "quote symbol and provider are required"
    );
    ensure!(
        !size_semantics.is_empty(),
        "quote size semantics are required"
    );
    ensure!(
        quotes.iter().all(|row| {
            row.event.symbol.trim().eq_ignore_ascii_case(&symbol)
                && row.event.provider.trim().eq_ignore_ascii_case(&provider)
                && row.event.size_semantics.trim() == size_semantics
        }),
        "quotes must share symbol, provider, and size semantics"
    );
    quotes.sort_by_key(|row| (row.event_at, row.sequence));
    let latest = *quotes.last().context("quote window is empty")?;
    ensure!(
        cutoff - latest.event_at <= max_age,
        "latest quote is stale at cutoff"
    );

    let mut raw_bid = 0.0;
    let mut raw_ask = 0.0;
    let mut normalized_ofi = 0.0;
    let mut depth_imbalance = 0.0;
    let mut microprice_deviation_bps = 0.0;
    let mut spread_bps = 0.0;
    let mut sequence_gap_count = 0_usize;
    for pair in quotes.windows(2) {
        let previous = pair[0];
        let current = pair[1];
        ensure!(
            current.event_at >= previous.event_at,
            "quote timestamps are not ordered"
        );
        ensure!(
            current.sequence > previous.sequence,
            "quote sequence is not strictly increasing"
        );
        if current.sequence != previous.sequence + 1 {
            sequence_gap_count += 1;
        }
        let bid = bid_flow(previous, current);
        let ask = ask_flow(previous, current);
        let pair_ofi = bid + ask;
        let mean_depth =
            (previous.bid_size + previous.ask_size + current.bid_size + current.ask_size) / 4.0;
        raw_bid += bid;
        raw_ask += ask;
        normalized_ofi += pair_ofi / mean_depth.max(1.0e-12);
        let current_depth = current.bid_size + current.ask_size;
        depth_imbalance += (current.bid_size - current.ask_size) / current_depth;
        let midpoint = (current.bid + current.ask) * 0.5;
        let microprice =
            (current.ask * current.bid_size + current.bid * current.ask_size) / current_depth;
        microprice_deviation_bps += (microprice / midpoint - 1.0) * 10_000.0;
        spread_bps += (current.ask - current.bid) / midpoint * 10_000.0;
    }
    ensure!(
        sequence_gap_count == 0,
        "quote sequence gaps make OFI incomplete"
    );
    let quote_pairs = quotes.len() - 1;
    let elapsed_seconds = (latest.event_at - quotes[0].event_at)
        .num_milliseconds()
        .max(1) as f64
        / 1_000.0;
    let latest_input_available_at = quotes
        .iter()
        .map(|row| row.event.received_at)
        .max()
        .context("quote availability is missing")?;

    Ok(L1OrderFlowSnapshot {
        schema_version: L1_ORDER_FLOW_SCHEMA_VERSION.into(),
        availability: L1OrderFlowAvailability::ResearchProxy,
        symbol,
        provider,
        observation_cutoff: cutoff,
        latest_event_at: latest.event_at,
        latest_input_available_at,
        quote_events: quotes.len(),
        quote_pairs,
        sequence_gap_count,
        raw_bid_order_flow: raw_bid,
        raw_ask_order_flow: raw_ask,
        raw_order_flow_imbalance: raw_bid + raw_ask,
        normalized_order_flow_imbalance: normalized_ofi / quote_pairs as f64,
        mean_depth_imbalance: depth_imbalance / quote_pairs as f64,
        mean_microprice_deviation_bps: microprice_deviation_bps / quote_pairs as f64,
        mean_spread_bps: spread_bps / quote_pairs as f64,
        quote_event_rate_per_second: quote_pairs as f64 / elapsed_seconds,
        event_coverage_ratio: 1.0,
        size_semantics,
        source_scope: "L1_TOP_OF_BOOK_STATIONARY_ORDER_FLOW_PROXY".into(),
        deep_ofi_compatible: false,
        affects_decision: false,
        caveats: vec![
            "NOT_L2_L10_DEEP_OFI".into(),
            "DOES_NOT_IDENTIFY_RETAIL_INSTITUTION_OR_DEALER".into(),
            "SPX_HAS_NO_NATIVE_ORDER_BOOK_USE_SOURCE_SPECIFIC_SPY_OR_ES_PROXY".into(),
            "NOT_IN_FROZEN_FEATURE_SCHEMA_REQUIRES_PURGED_WALK_FORWARD_AND_PROMOTION".into(),
        ],
    })
}
#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;
    use serde_json::json;

    fn quote_event(
        sequence: u64,
        seconds: i64,
        bid: f64,
        bid_size: f64,
        ask: f64,
        ask_size: f64,
    ) -> RealtimeStockTapeEvent {
        let event_at =
            Utc.with_ymd_and_hms(2026, 7, 24, 15, 0, 0).unwrap() + Duration::seconds(seconds);
        RealtimeStockTapeEvent {
            schema_version: "normalized_realtime_stock_tape.v1".into(),
            provider: "MASSIVE".into(),
            event_type: "Q".into(),
            symbol: "SPY".into(),
            provider_timestamp: Some(event_at),
            received_at: event_at + Duration::milliseconds(10),
            sequence: Some(sequence),
            trade_price: None,
            trade_size_provider_units: None,
            bid: Some(bid),
            bid_size_provider_units: Some(bid_size),
            ask: Some(ask),
            ask_size_provider_units: Some(ask_size),
            open: None,
            high: None,
            low: None,
            close: None,
            volume: None,
            size_semantics: "PROVIDER_UNITS".into(),
            entitlement: "REALTIME".into(),
            delayed: false,
            stale: false,
            future_timestamp: false,
            model_eligible: true,
            payload_sha256: "a".repeat(64),
            raw: json!({"ev":"Q"}),
        }
    }

    #[test]
    fn bid_add_and_ask_remove_produce_positive_stationary_ofi() {
        let events = vec![
            quote_event(1, 0, 100.00, 10.0, 100.02, 12.0),
            quote_event(2, 1, 100.00, 15.0, 100.02, 8.0),
            quote_event(3, 2, 100.01, 9.0, 100.03, 10.0),
        ];
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 24, 15, 0, 3).unwrap();
        let snapshot =
            derive_l1_order_flow_snapshot(&events, cutoff, Duration::seconds(5), 2).unwrap();
        assert!(snapshot.raw_order_flow_imbalance > 0.0);
        assert!(snapshot.normalized_order_flow_imbalance > 0.0);
        assert_eq!(snapshot.quote_pairs, 2);
        assert!(!snapshot.deep_ofi_compatible);
        assert!(!snapshot.affects_decision);
    }

    #[test]
    fn sequence_gap_future_and_stale_quotes_fail_closed() {
        let mut gapped = vec![
            quote_event(1, 0, 100.00, 10.0, 100.02, 12.0),
            quote_event(3, 1, 100.00, 11.0, 100.02, 11.0),
        ];
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 24, 15, 0, 2).unwrap();
        assert!(derive_l1_order_flow_snapshot(&gapped, cutoff, Duration::seconds(5), 1).is_err());
        gapped[1].sequence = Some(2);
        gapped[1].provider_timestamp = Some(cutoff + Duration::seconds(1));
        assert!(derive_l1_order_flow_snapshot(&gapped, cutoff, Duration::seconds(5), 1).is_err());
        gapped[1] = quote_event(2, 1, 100.00, 11.0, 100.02, 11.0);
        assert!(
            derive_l1_order_flow_snapshot(
                &gapped,
                cutoff + Duration::minutes(1),
                Duration::seconds(5),
                1,
            )
            .is_err()
        );
    }

    #[test]
    fn unentitled_or_unverified_lineage_fails_closed() {
        let mut events = vec![
            quote_event(1, 0, 100.00, 10.0, 100.02, 12.0),
            quote_event(2, 1, 100.00, 11.0, 100.02, 11.0),
        ];
        let cutoff = Utc.with_ymd_and_hms(2026, 7, 24, 15, 0, 2).unwrap();
        events[1].model_eligible = false;
        assert!(derive_l1_order_flow_snapshot(&events, cutoff, Duration::seconds(5), 1).is_err());
        events[1].model_eligible = true;
        events[1].payload_sha256 = "0".repeat(64);
        assert!(derive_l1_order_flow_snapshot(&events, cutoff, Duration::seconds(5), 1).is_err());
    }
}

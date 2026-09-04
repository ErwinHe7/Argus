use std::collections::{BTreeMap, BTreeSet};

use anyhow::{Result, bail};
use chrono::NaiveDate;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum MarketDataScope {
    Consolidated,
    SingleVenue,
    Indicative,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum TimestampPrecision {
    NanosecondEvent,
    MinuteInterval,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum OptionType {
    Call,
    Put,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OptionDefinition {
    pub source: String,
    pub dataset: String,
    pub publisher_id: u16,
    pub instrument_id: u32,
    pub raw_symbol: String,
    pub parent_symbol: String,
    pub trading_class: String,
    pub valid_from_ns: i64,
    pub valid_to_ns: Option<i64>,
    pub listing_date: NaiveDate,
    pub expiration_date: NaiveDate,
    pub expiration_timestamp_ns: Option<i64>,
    pub strike: f64,
    pub option_type: OptionType,
    pub multiplier: f64,
    pub tick_size: f64,
    pub exercise_style: String,
    pub settlement_style: String,
    pub adjusted_contract: bool,
    pub definition_version: String,
    pub ts_received_ns: i64,
}

impl OptionDefinition {
    pub fn validate(&self) -> Result<()> {
        if self.source.is_empty()
            || self.raw_symbol.is_empty()
            || self.parent_symbol.is_empty()
            || self.valid_from_ns <= 0
            || self.strike <= 0.0
            || self.multiplier <= 0.0
            || self.tick_size <= 0.0
        {
            bail!("CONTRACT_DEFINITION_INCOMPLETE");
        }
        if self
            .valid_to_ns
            .is_some_and(|end| end <= self.valid_from_ns)
        {
            bail!("invalid definition validity interval");
        }
        Ok(())
    }

    pub fn is_valid_at(&self, timestamp_ns: i64) -> bool {
        self.valid_from_ns <= timestamp_ns && self.valid_to_ns.is_none_or(|end| timestamp_ns < end)
    }

    pub fn is_supported_spxw(&self) -> bool {
        self.parent_symbol == "SPXW"
            && self.trading_class == "SPXW"
            && self.settlement_style.eq_ignore_ascii_case("PM")
            && !self.adjusted_contract
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OptionQuote {
    pub source: String,
    pub dataset: String,
    pub schema: String,
    pub scope: MarketDataScope,
    pub consolidated: bool,
    pub timestamp_precision: TimestampPrecision,
    pub instrument_id: u32,
    pub raw_symbol: String,
    pub ts_event_ns: i64,
    pub ts_recv_ns: i64,
    pub ts_interval_end_ns: Option<i64>,
    pub bid: f64,
    pub ask: f64,
    pub bid_size: u32,
    pub ask_size: u32,
    pub bid_venue: Option<u16>,
    pub ask_venue: Option<u16>,
    pub flags: u8,
    pub sequence: u64,
    pub quote_condition: Option<String>,
    pub is_crossed: bool,
    pub is_locked: bool,
    pub is_stale: bool,
    pub source_file_hash: String,
}

impl OptionQuote {
    pub fn validate_provenance(&self) -> Result<()> {
        if self.source == "NASDAQ_QBBO"
            && (self.scope != MarketDataScope::SingleVenue || self.consolidated)
        {
            bail!("Nasdaq QBBO is SINGLE_VENUE and cannot be consolidated NBBO");
        }
        if self.schema == "cbbo-1m"
            && self.timestamp_precision != TimestampPrecision::MinuteInterval
        {
            bail!("CBBO-1m cannot be represented as an exact tick quote");
        }
        if self.schema == "cmbp-1"
            && self.timestamp_precision != TimestampPrecision::NanosecondEvent
        {
            bail!("CMBP-1 must retain nanosecond event precision");
        }
        if self.bid <= 0.0
            || self.ask < self.bid
            || self.bid_size == 0
            || self.ask_size == 0
            || self.ts_event_ns <= 0
            || self.ts_recv_ns <= 0
        {
            bail!("invalid executable quote");
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OptionTrade {
    pub source: String,
    pub instrument_id: u32,
    pub raw_symbol: String,
    pub ts_event_ns: i64,
    pub ts_recv_ns: i64,
    pub price: f64,
    pub size: u32,
    pub venue: u16,
    pub condition: Option<String>,
    pub nbbo_bid_at_trade: Option<f64>,
    pub nbbo_ask_at_trade: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct IndexValue {
    pub source: String,
    pub symbol: String,
    pub ts_event_ns: i64,
    pub ts_recv_ns: i64,
    pub value: f64,
    pub status: String,
    pub source_file_hash: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AlignedOptionQuote {
    pub quote: OptionQuote,
    pub index: Option<IndexValue>,
    pub index_age_ms: Option<i64>,
    pub alignment_source: String,
    pub alignment_quality: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OptionAnalytics {
    pub instrument_id: u32,
    pub timestamp_ns: i64,
    pub analytics_source: String,
    pub option_price_input: String,
    pub underlying_input: f64,
    pub forward_input: Option<f64>,
    pub discount_factor: Option<f64>,
    pub time_to_expiry: f64,
    pub implied_volatility: Option<f64>,
    pub delta: Option<f64>,
    pub gamma: Option<f64>,
    pub theta: Option<f64>,
    pub vega: Option<f64>,
    pub rho: Option<f64>,
    pub calculation_model: String,
    pub calculation_version: String,
    pub convergence_status: String,
    pub rejection_reason: Option<String>,
}

impl OptionAnalytics {
    pub fn validate(&self) -> Result<()> {
        if self.analytics_source == "CBOE_VENDOR" && self.calculation_model == "INTERNAL_AUDITABLE"
        {
            bail!("vendor and internal analytics provenance cannot be mixed");
        }
        if self.convergence_status == "FAILED" && self.implied_volatility == Some(0.0) {
            bail!("failed IV solver cannot write zero as a value");
        }
        Ok(())
    }
}

#[derive(Debug, Clone)]
pub struct TradingCalendar {
    sessions: BTreeSet<NaiveDate>,
}

impl TradingCalendar {
    pub fn new(sessions: impl IntoIterator<Item = NaiveDate>) -> Self {
        Self {
            sessions: sessions.into_iter().collect(),
        }
    }

    pub fn session_distance(&self, from: NaiveDate, to: NaiveDate) -> Option<usize> {
        if !self.sessions.contains(&from) || !self.sessions.contains(&to) || to < from {
            return None;
        }
        Some(self.sessions.range(from..=to).count().saturating_sub(1))
    }
}

pub fn point_in_time_chain<'a>(
    definitions: &'a [OptionDefinition],
    parent: &str,
    session_date: NaiveDate,
    timestamp_ns: i64,
    calendar: &TradingCalendar,
    allowed_dte: &[usize],
) -> Vec<&'a OptionDefinition> {
    definitions
        .iter()
        .filter(|definition| {
            definition.parent_symbol == parent
                && definition.is_supported_spxw()
                && definition.is_valid_at(timestamp_ns)
                && definition.listing_date <= session_date
                && definition
                    .expiration_timestamp_ns
                    .is_some_and(|expiry| expiry > timestamp_ns)
                && calendar
                    .session_distance(session_date, definition.expiration_date)
                    .is_some_and(|dte| allowed_dte.contains(&dte))
        })
        .collect()
}

/// Backward-only as-of join. A future index value is never selected.
pub fn align_spx_backward(
    quotes: &[OptionQuote],
    index_values: &[IndexValue],
    maximum_age_ms: i64,
) -> Vec<AlignedOptionQuote> {
    let mut by_time = BTreeMap::<i64, &IndexValue>::new();
    for value in index_values
        .iter()
        .filter(|value| value.symbol == "SPX" && value.value > 0.0)
    {
        by_time.insert(value.ts_event_ns, value);
    }
    quotes
        .iter()
        .cloned()
        .map(|quote| {
            let matched = by_time
                .range(..=quote.ts_event_ns)
                .next_back()
                .map(|(_, value)| (*value).clone());
            let age_ms = matched
                .as_ref()
                .map(|value| (quote.ts_event_ns - value.ts_event_ns) / 1_000_000);
            let usable = age_ms.is_some_and(|age| (0..=maximum_age_ms).contains(&age));
            AlignedOptionQuote {
                quote,
                index: usable.then_some(matched).flatten(),
                index_age_ms: age_ms,
                alignment_source: "BACKWARD_ASOF_SPX".to_string(),
                alignment_quality: if usable {
                    "READY".to_string()
                } else {
                    "STALE_UNDERLYING".to_string()
                },
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use chrono::NaiveDate;

    use super::*;

    fn quote(source: &str, schema: &str, event: i64) -> OptionQuote {
        OptionQuote {
            source: source.to_string(),
            dataset: "TEST".to_string(),
            schema: schema.to_string(),
            scope: if source == "NASDAQ_QBBO" {
                MarketDataScope::SingleVenue
            } else {
                MarketDataScope::Consolidated
            },
            consolidated: source != "NASDAQ_QBBO",
            timestamp_precision: if schema == "cbbo-1m" {
                TimestampPrecision::MinuteInterval
            } else {
                TimestampPrecision::NanosecondEvent
            },
            instrument_id: 1,
            raw_symbol: "SPXW TEST".to_string(),
            ts_event_ns: event,
            ts_recv_ns: event + 10,
            ts_interval_end_ns: None,
            bid: 1.0,
            ask: 1.1,
            bid_size: 5,
            ask_size: 5,
            bid_venue: None,
            ask_venue: None,
            flags: 0,
            sequence: 1,
            quote_condition: None,
            is_crossed: false,
            is_locked: false,
            is_stale: false,
            source_file_hash: "hash".to_string(),
        }
    }

    fn definition(valid_from_ns: i64, valid_to_ns: Option<i64>) -> OptionDefinition {
        OptionDefinition {
            source: "DATABENTO".to_string(),
            dataset: "OPRA.PILLAR".to_string(),
            publisher_id: 30,
            instrument_id: 7,
            raw_symbol: "SPXW TEST C06000000".to_string(),
            parent_symbol: "SPXW".to_string(),
            trading_class: "SPXW".to_string(),
            valid_from_ns,
            valid_to_ns,
            listing_date: NaiveDate::from_ymd_opt(2026, 7, 15).unwrap(),
            expiration_date: NaiveDate::from_ymd_opt(2026, 7, 17).unwrap(),
            expiration_timestamp_ns: Some(10_000),
            strike: 6000.0,
            option_type: OptionType::Call,
            multiplier: 100.0,
            tick_size: 0.05,
            exercise_style: "EUROPEAN".to_string(),
            settlement_style: "PM".to_string(),
            adjusted_contract: false,
            definition_version: "fixture-v1".to_string(),
            ts_received_ns: valid_from_ns,
        }
    }

    #[test]
    fn nasdaq_qbbo_cannot_claim_consolidated_nbbo() {
        let mut row = quote("NASDAQ_QBBO", "qbbo", 2_000_000_000);
        row.consolidated = true;
        assert!(row.validate_provenance().is_err());
    }

    #[test]
    fn cbbo_minute_cannot_claim_tick_precision() {
        let mut row = quote("DATABENTO", "cbbo-1m", 2_000_000_000);
        row.timestamp_precision = TimestampPrecision::NanosecondEvent;
        assert!(row.validate_provenance().is_err());
    }

    #[test]
    fn spx_alignment_never_reads_future_value() {
        let rows = [quote("DATABENTO", "cmbp-1", 3_000_000_000)];
        let indexes = [
            IndexValue {
                source: "CBOE_CGIF".to_string(),
                symbol: "SPX".to_string(),
                ts_event_ns: 2_000_000_000,
                ts_recv_ns: 2_000_000_010,
                value: 6000.0,
                status: "OK".to_string(),
                source_file_hash: "a".to_string(),
            },
            IndexValue {
                ts_event_ns: 4_000_000_000,
                value: 9000.0,
                ..IndexValue {
                    source: "CBOE_CGIF".to_string(),
                    symbol: "SPX".to_string(),
                    ts_event_ns: 0,
                    ts_recv_ns: 4_000_000_010,
                    value: 0.0,
                    status: "OK".to_string(),
                    source_file_hash: "b".to_string(),
                }
            },
        ];
        let aligned = align_spx_backward(&rows, &indexes, 2_000);
        assert_eq!(aligned[0].index.as_ref().unwrap().value, 6000.0);
    }

    #[test]
    fn dte_uses_supplied_trading_calendar() {
        let friday = NaiveDate::from_ymd_opt(2026, 7, 17).unwrap();
        let monday = NaiveDate::from_ymd_opt(2026, 7, 20).unwrap();
        let calendar = TradingCalendar::new([friday, monday]);
        assert_eq!(calendar.session_distance(friday, monday), Some(1));
    }

    #[test]
    fn chain_uses_only_definition_version_known_at_quote_time() {
        let session = NaiveDate::from_ymd_opt(2026, 7, 17).unwrap();
        let calendar = TradingCalendar::new([session]);
        let old = definition(1_000, Some(5_000));
        let mut future_revision = definition(5_000, None);
        future_revision.strike = 6100.0;
        future_revision.definition_version = "future-revision".to_string();

        let definitions = [old, future_revision];
        let chain = point_in_time_chain(&definitions, "SPXW", session, 4_000, &calendar, &[0]);
        assert_eq!(chain.len(), 1);
        assert_eq!(chain[0].strike, 6000.0);
        assert_eq!(chain[0].definition_version, "fixture-v1");
    }

    #[test]
    fn failed_analytics_never_encodes_missing_iv_as_zero() {
        let analytics = OptionAnalytics {
            instrument_id: 7,
            timestamp_ns: 4_000,
            analytics_source: "INTERNAL".to_string(),
            option_price_input: "NBBO_MICROPRICE".to_string(),
            underlying_input: 6000.0,
            forward_input: None,
            discount_factor: None,
            time_to_expiry: 0.0001,
            implied_volatility: Some(0.0),
            delta: None,
            gamma: None,
            theta: None,
            vega: None,
            rho: None,
            calculation_model: "INTERNAL_AUDITABLE".to_string(),
            calculation_version: "v1".to_string(),
            convergence_status: "FAILED".to_string(),
            rejection_reason: Some("no_bracket".to_string()),
        };
        assert!(analytics.validate().is_err());
    }
}

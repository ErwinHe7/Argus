//! Descriptive comparison of an ATM straddle cost with event-aligned price moves.
//! This is neither a direction model nor an option strategy backtest.
use chrono::{DateTime, Datelike, NaiveDate, Timelike, Utc, Weekday};
use chrono_tz::America::New_York;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::BTreeSet;

pub const FEATURE_VERSION: &str = "earnings-comparison-1.0.0";

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Source {
    pub title: String,
    pub url: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Session {
    pub date: NaiveDate,
    pub open_at: DateTime<Utc>,
    pub close_at: DateTime<Utc>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Calendar {
    pub source: Source,
    pub version: String,
    pub coverage_start: NaiveDate,
    pub coverage_end: NaiveDate,
    pub sessions: Vec<Session>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Close {
    pub session_date: NaiveDate,
    pub observed_at: DateTime<Utc>,
    pub available_at: DateTime<Utc>,
    pub price: f64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct HistoricalEvent {
    pub event_id: String,
    pub event_at: DateTime<Utc>,
    pub event_known_at: DateTime<Utc>,
    pub source: Source,
    pub before: Close,
    pub after: Close,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Quote {
    pub symbol: String,
    pub right: String,
    pub strike: f64,
    pub expiry_at: DateTime<Utc>,
    pub bid: f64,
    pub ask: f64,
    pub observed_at: DateTime<Utc>,
    pub available_at: DateTime<Utc>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct OptionSnapshot {
    pub source: Source,
    pub entitled: bool,
    pub quote_unit: String,
    pub spot: f64,
    pub spot_observed_at: DateTime<Utc>,
    pub spot_available_at: DateTime<Utc>,
    /// Call and put must share this strike, expiry and underlying symbol.
    pub strike: f64,
    pub listed_strikes: Vec<f64>,
    pub expiry_at: DateTime<Utc>,
    pub call: Quote,
    pub put: Quote,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Request {
    pub schema_version: String,
    pub symbol: String,
    pub as_of: DateTime<Utc>,
    pub event_at: DateTime<Utc>,
    pub event_known_at: DateTime<Utc>,
    pub event_source: Source,
    pub history_source: Source,
    pub history_price_basis: String,
    pub history_entitled: bool,
    pub calendar: Option<Calendar>,
    #[serde(default)]
    pub history: Vec<HistoricalEvent>,
    pub options: Option<OptionSnapshot>,
}

#[derive(Debug, Serialize)]
pub struct Comparison {
    pub historical_count: usize,
    pub event_ids: Vec<String>,
    pub absolute_moves_percent: Vec<f64>,
    pub median_absolute_move_percent: f64,
    pub raw_up_count: usize,
    pub raw_down_count: usize,
    pub raw_flat_count: usize,
    pub raw_up_frequency_percent: f64,
    pub straddle_mid_cost_percent: f64,
    pub straddle_ask_cost_percent: f64,
    pub cost_to_historical_median_ratio: Option<f64>,
}

#[derive(Debug, Serialize)]
pub struct Report {
    pub schema_version: &'static str,
    pub feature_version: &'static str,
    pub status: &'static str,
    pub symbol: String,
    pub as_of: DateTime<Utc>,
    pub event_at: DateTime<Utc>,
    pub reason_codes: Vec<&'static str>,
    pub comparison: Option<Comparison>,
    pub sources: Vec<Source>,
    pub input_sha256: String,
    pub prediction_enabled: bool,
    pub execution_enabled: bool,
    pub limitations: Vec<&'static str>,
}

fn source_valid(source: &Source) -> bool {
    !source.title.trim().is_empty()
        && source.title.len() <= 300
        && source.url.starts_with("https://")
        && source.url.len() > 8
        && source.url.len() <= 2048
        && !source.url.chars().any(char::is_whitespace)
        && !source.url.contains('@')
}

fn positive(value: f64) -> bool {
    value.is_finite() && value > 0.0 && value <= 1_000_000_000.0
}

fn calendar_valid(calendar: &Calendar) -> bool {
    source_valid(&calendar.source)
        && !calendar.version.trim().is_empty()
        && calendar.version.len() <= 100
        && calendar.coverage_start < calendar.coverage_end
        && (2..=4000).contains(&calendar.sessions.len())
        && calendar
            .sessions
            .windows(2)
            .all(|pair| pair[0].date < pair[1].date)
        && calendar.sessions.iter().all(|session| {
            let open = session.open_at.with_timezone(&New_York);
            let close = session.close_at.with_timezone(&New_York);
            session.date >= calendar.coverage_start
                && session.date <= calendar.coverage_end
                && !matches!(session.date.weekday(), Weekday::Sat | Weekday::Sun)
                && open.date_naive() == session.date
                && close.date_naive() == session.date
                && open.hour() == 9
                && open.minute() == 30
                && open.second() == 0
                && open.nanosecond() == 0
                && matches!(close.hour(), 13 | 16)
                && close.minute() == 0
                && close.second() == 0
                && close.nanosecond() == 0
        })
}

/// Select adjacent supplied sessions straddling an out-of-hours earnings event.
/// Unknown/intraday timestamps cannot be silently treated as after-close reports.
fn aligned_sessions(calendar: &Calendar, at: DateTime<Utc>) -> Option<(&Session, &Session)> {
    let date = at.with_timezone(&New_York).date_naive();
    if date < calendar.coverage_start || date > calendar.coverage_end {
        return None;
    }
    calendar.sessions.windows(2).find_map(|pair| {
        (pair[0].close_at < at && at < pair[1].open_at).then_some((&pair[0], &pair[1]))
    })
}

fn close_valid(close: &Close, session: &Session, cutoff: DateTime<Utc>) -> bool {
    positive(close.price)
        && close.session_date == session.date
        && close.observed_at == session.close_at
        && close.available_at >= close.observed_at
        && close.available_at <= cutoff
}

fn quote_valid(quote: &Quote, cutoff: DateTime<Utc>) -> bool {
    quote.bid.is_finite()
        && quote.bid >= 0.0
        && positive(quote.ask)
        && quote.bid <= quote.ask
        && quote.observed_at <= cutoff
        && quote.available_at >= quote.observed_at
        && quote.available_at <= cutoff
        && (cutoff - quote.observed_at).num_milliseconds() <= 60_000
}

fn validate(request: &Request) -> Result<(), &'static str> {
    if request.schema_version != "leo-earnings-comparison-request.v1"
        || request.symbol.is_empty()
        || request.symbol.len() > 12
        || !request
            .symbol
            .chars()
            .all(|c| c.is_ascii_uppercase() || c.is_ascii_digit() || c == '.' || c == '-')
        || !source_valid(&request.event_source)
        || !source_valid(&request.history_source)
    {
        return Err("invalid_identity_or_provenance");
    }
    if request.event_known_at > request.as_of || request.event_at <= request.as_of {
        return Err("event_not_known_before_cutoff_or_already_occurred");
    }
    if request.history_price_basis != "split_adjusted_regular_close" || !request.history_entitled {
        return Err("history_basis_or_entitlement_unavailable");
    }
    let calendar = request.calendar.as_ref().ok_or("calendar_unavailable")?;
    if !calendar_valid(calendar) {
        return Err("invalid_calendar");
    }
    let (_, after_current) = aligned_sessions(calendar, request.event_at)
        .ok_or("event_session_alignment_unavailable")?;
    if !(3..=40).contains(&request.history.len()) {
        return Err("insufficient_or_excessive_history");
    }
    let mut ids = BTreeSet::new();
    let mut times = BTreeSet::new();
    let mut reaction_sessions = BTreeSet::new();
    for event in &request.history {
        if event.event_id.trim().is_empty()
            || event.event_id.len() > 100
            || !ids.insert(&event.event_id)
            || !times.insert(event.event_at)
            || !source_valid(&event.source)
        {
            return Err("invalid_or_duplicate_historical_event");
        }
        let (before, after) = aligned_sessions(calendar, event.event_at)
            .ok_or("historical_session_alignment_unavailable")?;
        if !reaction_sessions.insert(after.date) {
            return Err("duplicate_historical_reaction_session");
        }
        if event.event_at >= request.as_of
            || event.event_known_at > before.close_at
            || !close_valid(&event.before, before, request.as_of)
            || !close_valid(&event.after, after, request.as_of)
        {
            return Err("historical_lookahead_or_invalid_close");
        }
    }
    let quotes = request
        .options
        .as_ref()
        .ok_or("option_quotes_unavailable")?;
    if !source_valid(&quotes.source) || !quotes.entitled {
        return Err("option_provenance_or_entitlement_unavailable");
    }
    if quotes.quote_unit != "usd_per_share"
        || quotes.call.symbol != request.symbol
        || quotes.put.symbol != request.symbol
        || quotes.call.right != "call"
        || quotes.put.right != "put"
        || quotes.call.strike != quotes.strike
        || quotes.put.strike != quotes.strike
        || quotes.call.expiry_at != quotes.expiry_at
        || quotes.put.expiry_at != quotes.expiry_at
    {
        return Err("mismatched_option_contracts_or_units");
    }
    if !positive(quotes.spot)
        || !positive(quotes.strike)
        || quotes.spot_observed_at > request.as_of
        || quotes.spot_available_at < quotes.spot_observed_at
        || quotes.spot_available_at > request.as_of
        || (request.as_of - quotes.spot_observed_at).num_milliseconds() > 60_000
        || !quote_valid(&quotes.call, request.as_of)
        || !quote_valid(&quotes.put, request.as_of)
    {
        return Err("stale_crossed_or_invalid_quote");
    }
    let timestamps = [
        quotes.spot_observed_at,
        quotes.call.observed_at,
        quotes.put.observed_at,
    ];
    if (*timestamps.iter().max().unwrap() - *timestamps.iter().min().unwrap()).num_milliseconds()
        > 5_000
    {
        return Err("unsynchronized_quotes");
    }
    if !timestamps.iter().all(|time| {
        calendar
            .sessions
            .iter()
            .any(|session| session.open_at <= *time && *time <= session.close_at)
    }) {
        return Err("quotes_outside_regular_session");
    }
    if quotes.expiry_at < after_current.close_at
        || !calendar
            .sessions
            .iter()
            .any(|session| session.close_at == quotes.expiry_at)
    {
        return Err("expiry_does_not_cover_event_reaction_session");
    }
    if quotes.listed_strikes.is_empty()
        || quotes.listed_strikes.len() > 2000
        || quotes.listed_strikes.iter().any(|value| !positive(*value))
        || !quotes
            .listed_strikes
            .windows(2)
            .all(|pair| pair[0] < pair[1])
        || !quotes.listed_strikes.contains(&quotes.strike)
    {
        return Err("strike_grid_unavailable");
    }
    let nearest = quotes
        .listed_strikes
        .iter()
        .min_by(|a, b| {
            (**a - quotes.spot)
                .abs()
                .total_cmp(&(**b - quotes.spot).abs())
        })
        .unwrap();
    if *nearest != quotes.strike {
        return Err("strike_is_not_nearest_atm");
    }
    Ok(())
}

pub fn compare(request: &Request) -> Report {
    let serialized = serde_json::to_vec(request).unwrap_or_default();
    let mut report = Report {
        schema_version: "leo-earnings-comparison.v1",
        feature_version: FEATURE_VERSION,
        status: "unavailable",
        symbol: request.symbol.clone(),
        as_of: request.as_of,
        event_at: request.event_at,
        reason_codes: vec![],
        comparison: None,
        sources: vec![request.event_source.clone(), request.history_source.clone()],
        input_sha256: format!("{:x}", Sha256::digest(&serialized)),
        prediction_enabled: false,
        execution_enabled: false,
        limitations: vec![
            "Research only. No direction forecast, calibrated probability, option return, or trading instruction.",
            "Straddle cost divided by spot is a premium proxy; it is not a guaranteed earnings range or isolated event volatility.",
            "Historical moves use the last completed regular close before the event and the first regular close after it. They include overnight and next-session market moves.",
            "Only the latest nine supplied events are summarized; at least three are required. Raw up frequency describes that sample and is not a prediction.",
            "Calendar completeness, source permission, and split adjustments are supplied provenance, not independently certified by this offline calculation.",
            "Midpoint is not a promised fill. Ask cost excludes commissions, future spreads, slippage, early exercise, dividends, and volatility changes.",
        ],
    };
    if let Err(reason) = validate(request) {
        report.reason_codes.push(reason);
        return report;
    }
    let mut events: Vec<_> = request.history.iter().collect();
    events.sort_by_key(|event| event.event_at);
    let events = &events[events.len().saturating_sub(9)..];
    let moves: Vec<f64> = events
        .iter()
        .map(|event| (event.after.price / event.before.price - 1.0) * 100.0)
        .collect();
    let mut sorted: Vec<f64> = moves.iter().map(|value| value.abs()).collect();
    sorted.sort_by(f64::total_cmp);
    let middle = sorted.len() / 2;
    let median = if sorted.len().is_multiple_of(2) {
        sorted[middle - 1] / 2.0 + sorted[middle] / 2.0
    } else {
        sorted[middle]
    };
    let quotes = request.options.as_ref().expect("validated quotes");
    let mid = (quotes.call.bid / 2.0
        + quotes.call.ask / 2.0
        + quotes.put.bid / 2.0
        + quotes.put.ask / 2.0)
        / quotes.spot
        * 100.0;
    let ask = (quotes.call.ask + quotes.put.ask) / quotes.spot * 100.0;
    let ratio = (median > 0.0).then_some(mid / median);
    if moves
        .iter()
        .chain([&median, &mid, &ask])
        .any(|value| !value.is_finite())
        || ratio.is_some_and(|value| !value.is_finite())
    {
        report.reason_codes.push("nonfinite_comparison");
        return report;
    }
    let up = moves.iter().filter(|value| **value > 0.0).count();
    let down = moves.iter().filter(|value| **value < 0.0).count();
    report.status = "available";
    report.sources.push(quotes.source.clone());
    report
        .sources
        .push(request.calendar.as_ref().unwrap().source.clone());
    for event in events {
        report.sources.push(event.source.clone());
    }
    report.comparison = Some(Comparison {
        historical_count: events.len(),
        event_ids: events.iter().map(|event| event.event_id.clone()).collect(),
        absolute_moves_percent: moves.iter().map(|value| value.abs()).collect(),
        median_absolute_move_percent: median,
        raw_up_count: up,
        raw_down_count: down,
        raw_flat_count: moves.len() - up - down,
        raw_up_frequency_percent: up as f64 / moves.len() as f64 * 100.0,
        straddle_mid_cost_percent: mid,
        straddle_ask_cost_percent: ask,
        cost_to_historical_median_ratio: ratio,
    });
    report
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{Duration, TimeZone};

    fn utc(text: &str) -> DateTime<Utc> {
        text.parse().unwrap()
    }
    fn source() -> Source {
        Source {
            title: "FICTIONAL unit-test evidence".into(),
            url: "https://example.invalid/test-only".into(),
        }
    }
    fn fixture() -> Request {
        let start = NaiveDate::from_ymd_opt(2026, 8, 3).unwrap();
        let sessions: Vec<_> = (0..60)
            .filter_map(|offset| {
                let date = start + Duration::days(offset);
                if matches!(date.weekday(), Weekday::Sat | Weekday::Sun)
                    || date == NaiveDate::from_ymd_opt(2026, 9, 7).unwrap()
                {
                    return None;
                }
                Some(Session {
                    date,
                    open_at: New_York
                        .from_local_datetime(&date.and_hms_opt(9, 30, 0).unwrap())
                        .unwrap()
                        .with_timezone(&Utc),
                    close_at: New_York
                        .from_local_datetime(&date.and_hms_opt(16, 0, 0).unwrap())
                        .unwrap()
                        .with_timezone(&Utc),
                })
            })
            .collect();
        let history = (0..3)
            .map(|index| {
                let before = &sessions[index * 2];
                let after = &sessions[index * 2 + 1];
                HistoricalEvent {
                    event_id: format!("TEST-{index}"),
                    event_at: before.close_at + Duration::hours(1),
                    event_known_at: before.open_at - Duration::days(1),
                    source: source(),
                    before: Close {
                        session_date: before.date,
                        observed_at: before.close_at,
                        available_at: before.close_at,
                        price: 100.0,
                    },
                    after: Close {
                        session_date: after.date,
                        observed_at: after.close_at,
                        available_at: after.close_at,
                        price: [110.0, 95.0, 100.0][index],
                    },
                }
            })
            .collect();
        let cutoff = utc("2026-09-10T19:59:00Z");
        let quote = Quote {
            symbol: "TEST".into(),
            right: "call".into(),
            strike: 100.0,
            expiry_at: utc("2026-09-11T20:00:00Z"),
            bid: 2.0,
            ask: 3.0,
            observed_at: cutoff,
            available_at: cutoff,
        };
        Request {
            schema_version: "leo-earnings-comparison-request.v1".into(),
            symbol: "TEST".into(),
            as_of: cutoff,
            event_at: utc("2026-09-10T21:00:00Z"),
            event_known_at: utc("2026-09-01T12:00:00Z"),
            event_source: source(),
            history_source: source(),
            history_price_basis: "split_adjusted_regular_close".into(),
            history_entitled: true,
            calendar: Some(Calendar {
                source: source(),
                version: "FICTIONAL-test-calendar".into(),
                coverage_start: start,
                coverage_end: start + Duration::days(59),
                sessions,
            }),
            history,
            options: Some(OptionSnapshot {
                source: source(),
                entitled: true,
                quote_unit: "usd_per_share".into(),
                spot: 100.0,
                spot_observed_at: cutoff,
                spot_available_at: cutoff,
                strike: 100.0,
                listed_strikes: vec![95.0, 100.0, 105.0],
                expiry_at: utc("2026-09-11T20:00:00Z"),
                call: quote.clone(),
                put: Quote {
                    right: "put".into(),
                    ..quote
                },
            }),
        }
    }
    fn unavailable(request: &Request, code: &str) {
        let result = compare(request);
        assert_eq!(result.status, "unavailable");
        assert!(result.comparison.is_none());
        assert!(result.reason_codes.contains(&code));
    }

    #[test]
    fn known_values_and_reproducible_receipt() {
        let request = fixture();
        let result = compare(&request);
        assert_eq!(result.status, "available");
        assert!(!result.prediction_enabled && !result.execution_enabled);
        assert_eq!(result.input_sha256, compare(&request).input_sha256);
        let value = result.comparison.unwrap();
        assert_eq!(
            (
                value.raw_up_count,
                value.raw_down_count,
                value.raw_flat_count
            ),
            (1, 1, 1)
        );
        assert!((value.median_absolute_move_percent - 5.0).abs() < 1e-10);
        assert_eq!(value.straddle_mid_cost_percent, 5.0);
        assert_eq!(value.straddle_ask_cost_percent, 6.0);
        assert!((value.cost_to_historical_median_ratio.unwrap() - 1.0).abs() < 1e-10);
    }
    #[test]
    fn before_open_and_after_close_align_to_same_pair() {
        let mut request = fixture();
        request.event_at = utc("2026-09-11T12:00:00Z");
        assert_eq!(compare(&request).status, "available");
        request.history[0].event_at =
            request.calendar.as_ref().unwrap().sessions[1].open_at - Duration::minutes(1);
        assert_eq!(compare(&request).status, "available");
        request.event_at = utc("2026-09-11T15:00:00Z");
        unavailable(&request, "event_session_alignment_unavailable");
    }
    #[test]
    fn reject_future_event_information_and_historical_lookahead() {
        let mut request = fixture();
        request.event_known_at = request.as_of + Duration::seconds(1);
        unavailable(
            &request,
            "event_not_known_before_cutoff_or_already_occurred",
        );
        let mut request = fixture();
        request.history[0].after.available_at = request.as_of + Duration::seconds(1);
        unavailable(&request, "historical_lookahead_or_invalid_close");
        let mut request = fixture();
        request.history[0].after.observed_at -= Duration::minutes(1);
        unavailable(&request, "historical_lookahead_or_invalid_close");
    }
    #[test]
    fn missing_and_short_history_never_generate_performance() {
        let mut request = fixture();
        request.options = None;
        unavailable(&request, "option_quotes_unavailable");
        let mut request = fixture();
        request.calendar = None;
        unavailable(&request, "calendar_unavailable");
        let mut request = fixture();
        request.history.pop();
        unavailable(&request, "insufficient_or_excessive_history");
    }
    #[test]
    fn quote_age_and_synchronization_thresholds_are_exact() {
        let mut request = fixture();
        let quotes = request.options.as_mut().unwrap();
        quotes.spot_observed_at -= Duration::seconds(60);
        quotes.call.observed_at -= Duration::seconds(60);
        quotes.put.observed_at -= Duration::seconds(60);
        assert_eq!(compare(&request).status, "available");
        request.options.as_mut().unwrap().call.observed_at -= Duration::milliseconds(1);
        unavailable(&request, "stale_crossed_or_invalid_quote");
        let mut request = fixture();
        request.options.as_mut().unwrap().call.observed_at -= Duration::seconds(5);
        assert_eq!(compare(&request).status, "available");
        request.options.as_mut().unwrap().call.observed_at -= Duration::milliseconds(1);
        unavailable(&request, "unsynchronized_quotes");
    }
    #[test]
    fn crossed_unentitled_out_of_session_and_wrong_expiry_rejected() {
        let mut request = fixture();
        request.options.as_mut().unwrap().call.bid = 4.0;
        unavailable(&request, "stale_crossed_or_invalid_quote");
        let mut request = fixture();
        request.options.as_mut().unwrap().entitled = false;
        unavailable(&request, "option_provenance_or_entitlement_unavailable");
        let mut request = fixture();
        request.options.as_mut().unwrap().expiry_at = utc("2026-09-10T20:00:00Z");
        request.options.as_mut().unwrap().call.expiry_at = utc("2026-09-10T20:00:00Z");
        request.options.as_mut().unwrap().put.expiry_at = utc("2026-09-10T20:00:00Z");
        unavailable(&request, "expiry_does_not_cover_event_reaction_session");
        let mut request = fixture();
        request.as_of = utc("2026-09-10T20:10:00Z");
        let q = request.options.as_mut().unwrap();
        q.spot_observed_at = request.as_of;
        q.spot_available_at = request.as_of;
        q.call.observed_at = request.as_of;
        q.call.available_at = request.as_of;
        q.put = q.call.clone();
        q.put.right = "put".into();
        unavailable(&request, "quotes_outside_regular_session");
    }
    #[test]
    fn atm_verification_and_duplicates_fail_closed() {
        let mut request = fixture();
        request.options.as_mut().unwrap().strike = 105.0;
        request.options.as_mut().unwrap().call.strike = 105.0;
        request.options.as_mut().unwrap().put.strike = 105.0;
        unavailable(&request, "strike_is_not_nearest_atm");
        let mut request = fixture();
        request.options.as_mut().unwrap().listed_strikes = vec![];
        unavailable(&request, "strike_grid_unavailable");
        let mut request = fixture();
        request.history[1] = request.history[0].clone();
        unavailable(&request, "invalid_or_duplicate_historical_event");
        let mut request = fixture();
        request.history[1] = request.history[0].clone();
        request.history[1].event_id = "another-id".into();
        request.history[1].event_at += Duration::minutes(5);
        unavailable(&request, "duplicate_historical_reaction_session");
    }
    #[test]
    fn only_latest_nine_events_enter_summary_and_order_does_not_change_values() {
        let mut request = fixture();
        let original = request.history[0].clone();
        let calendar = request.calendar.as_ref().unwrap();
        request.history = (0..10)
            .map(|index| {
                let mut event = original.clone();
                let before = &calendar.sessions[index * 2];
                let after = &calendar.sessions[index * 2 + 1];
                event.event_id = format!("TEST-{index}");
                event.event_at = before.close_at + Duration::hours(1);
                event.event_known_at = before.open_at;
                event.before = Close {
                    session_date: before.date,
                    observed_at: before.close_at,
                    available_at: before.close_at,
                    price: 100.0,
                };
                event.after = Close {
                    session_date: after.date,
                    observed_at: after.close_at,
                    available_at: after.close_at,
                    price: 101.0 + index as f64,
                };
                event
            })
            .collect();
        let report = compare(&request);
        assert_eq!(report.status, "available");
        let value = report.comparison.unwrap();
        assert_eq!(value.historical_count, 9);
        assert_eq!(value.event_ids[0], "TEST-1");
        request.history.reverse();
        assert_eq!(
            value.absolute_moves_percent,
            compare(&request).comparison.unwrap().absolute_moves_percent
        );
    }
    #[test]
    fn zero_move_median_withholds_ratio_and_extreme_overflow_fails_closed() {
        let mut request = fixture();
        for event in &mut request.history {
            event.after.price = event.before.price;
        }
        let result = compare(&request).comparison.unwrap();
        assert_eq!(result.cost_to_historical_median_ratio, None);
        assert_eq!(result.raw_flat_count, 3);
        request.history[0].before.price = f64::MIN_POSITIVE;
        unavailable(&request, "nonfinite_comparison");
    }
    #[test]
    fn calendar_timezone_and_close_are_checked() {
        let mut request = fixture();
        request.calendar.as_mut().unwrap().sessions[0].close_at -= Duration::hours(1);
        unavailable(&request, "invalid_calendar");
        let mut request = fixture();
        request.history_price_basis = "unadjusted".into();
        unavailable(&request, "history_basis_or_entitlement_unavailable");
    }
    #[test]
    fn unknown_input_fields_are_rejected() {
        let mut value = serde_json::to_value(fixture()).unwrap();
        value["predicted_up_probability"] = serde_json::json!(0.99);
        assert!(serde_json::from_value::<Request>(value).is_err());
    }
    #[test]
    fn individual_contract_identity_and_currency_must_match() {
        let mut request = fixture();
        request.options.as_mut().unwrap().put.expiry_at += Duration::days(7);
        unavailable(&request, "mismatched_option_contracts_or_units");
        let mut request = fixture();
        request.options.as_mut().unwrap().put.symbol = "OTHER".into();
        unavailable(&request, "mismatched_option_contracts_or_units");
        let mut request = fixture();
        request.options.as_mut().unwrap().quote_unit = "usd_per_contract".into();
        unavailable(&request, "mismatched_option_contracts_or_units");
    }
}

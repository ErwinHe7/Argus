//! GRID-R1: offline, cash-start, whole-share grid research.
//! Daily closes generate proposals for the next observed opening price only.
//! No intraday path, quote, order queue or broker execution is inferred.
mod replay;
#[cfg(test)]
mod tests;

use super::decimal::Decimal;
use anyhow::{Result, ensure};
use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

pub use replay::replay;

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Spacing {
    Arithmetic,
    Geometric,
}
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Classification {
    Observed,
    SyntheticFixture,
}
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Adjustment {
    SplitAdjusted,
    UnadjustedNoActions,
}
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Coverage {
    UserAssertedComplete,
}
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Availability {
    PointInTime,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SourceEvidence {
    pub source: String,
    pub dataset_sha256: String,
    pub calendar_source: String,
    pub adjustment: Adjustment,
    pub coverage: Coverage,
    pub availability: Availability,
    pub classification: Classification,
    pub license_scope: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GridBar {
    pub session_date: NaiveDate,
    pub open_at: DateTime<Utc>,
    pub close_at: DateTime<Utc>,
    pub available_at: DateTime<Utc>,
    pub open: Decimal,
    pub high: Decimal,
    pub low: Decimal,
    pub close: Decimal,
    pub volume: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GridReplayRequest {
    pub schema_version: String,
    pub symbol: String,
    pub configured_at: DateTime<Utc>,
    pub as_of: DateTime<Utc>,
    pub lower: Decimal,
    pub upper: Decimal,
    pub intervals: usize,
    pub spacing: Spacing,
    pub tick_size: Decimal,
    pub starting_capital: Decimal,
    pub commission_per_order: Decimal,
    pub slippage_bps: u32,
    pub portfolio_loss_limit_bps: u32,
    pub source_evidence: SourceEvidence,
    pub bars: Vec<GridBar>,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Pending {
    Buy,
    Sell,
}

#[derive(Clone, Debug, Serialize)]
pub struct GridSlot {
    pub slot_id: usize,
    pub buy_level: Decimal,
    pub sell_level: Decimal,
    pub budget: Decimal,
    pub quantity_per_cycle: u64,
    pub held_quantity: u64,
    pub entry_price: Option<Decimal>,
    pub entry_fee: Decimal,
    pub completed_cycles: usize,
    pub pending: Option<Pending>,
}

#[derive(Clone, Debug, Serialize)]
pub struct GridEvent {
    pub event_id: String,
    pub at: DateTime<Utc>,
    pub session_date: NaiveDate,
    pub slot_id: Option<usize>,
    pub kind: String,
    pub reason: String,
    pub quantity_delta: i64,
    pub price: Option<Decimal>,
    pub cash_delta: Decimal,
    pub fee: Decimal,
}

#[derive(Clone, Debug, Serialize)]
pub struct GridEquity {
    pub session_date: NaiveDate,
    pub at: DateTime<Utc>,
    pub cash: Decimal,
    pub quantity: u64,
    pub market_value: Decimal,
    pub equity: Decimal,
    pub total_pnl: Decimal,
    pub total_return: f64,
    pub drawdown: f64,
    pub realized_cycle_pnl: Decimal,
    pub realized_exit_pnl: Decimal,
    pub unrealized_pnl: Decimal,
    pub fees: Decimal,
    pub loss_latched: bool,
    pub out_of_range: bool,
}

#[derive(Clone, Debug, Serialize)]
pub struct GridMetrics {
    pub sessions: usize,
    pub completed_cycles: usize,
    pub open_slots: usize,
    pub ending_cash: Decimal,
    pub ending_quantity: u64,
    pub ending_equity: Decimal,
    pub total_pnl: Decimal,
    pub total_return: f64,
    pub max_drawdown: f64,
    pub realized_cycle_pnl: Decimal,
    pub realized_exit_pnl: Decimal,
    pub unrealized_pnl: Decimal,
    pub fees: Decimal,
    pub loss_latched: bool,
    pub pending_liquidation: bool,
    pub range_breach_sessions: usize,
    // Display aliases are computed here, never in TypeScript.
    pub return_bps: f64,
    pub buy_hold_return_bps: f64,
    pub realized_loss_exit_pnl: Decimal,
    pub cash: Decimal,
    pub marked_inventory: Decimal,
    pub equity: Decimal,
    pub max_drawdown_bps: f64,
    pub range_breaches: usize,
}

#[derive(Clone, Debug, Serialize)]
pub struct GridBenchmarks {
    pub cash_ending_equity: Decimal,
    pub cash_total_return: f64,
    pub buy_and_hold_ending_equity: Decimal,
    pub buy_and_hold_total_return: f64,
}

#[derive(Clone, Debug, Serialize)]
pub struct GridReplayResult {
    pub schema_version: String,
    pub strategy: String,
    pub run_id: String,
    pub configuration_hash: String,
    pub canonical_bars_sha256: String,
    pub configuration: serde_json::Value,
    pub fill_model: String,
    pub evidence_status: String,
    pub execution_authorized: bool,
    pub paper_execution_available: bool,
    pub promotion_eligible: bool,
    pub limitations: Vec<String>,
    pub levels: Vec<Decimal>,
    pub slots: Vec<GridSlot>,
    pub journal: Vec<GridEvent>,
    pub equity: Vec<GridEquity>,
    pub metrics: GridMetrics,
    pub benchmarks: GridBenchmarks,
}

pub(super) fn hash<T: Serialize>(value: &T) -> Result<String> {
    Ok(format!("{:x}", Sha256::digest(serde_json::to_vec(value)?)))
}

fn validate(request: &GridReplayRequest) -> Result<()> {
    ensure!(
        request.schema_version == "leo-grid-request.v1",
        "unsupported grid request schema"
    );
    ensure!(
        !request.symbol.is_empty()
            && request.symbol.len() <= 16
            && request
                .symbol
                .bytes()
                .all(|b| b.is_ascii_uppercase() || b.is_ascii_digit() || matches!(b, b'.' | b'-')),
        "invalid research symbol"
    );
    ensure!(
        (2..=100).contains(&request.intervals) && (2..=5000).contains(&request.bars.len()),
        "grid requires 2..100 intervals and 2..5000 bars"
    );
    ensure!(
        request
            .bars
            .len()
            .checked_mul(request.intervals)
            .is_some_and(|n| n <= 100_000),
        "grid work limit exceeded; bars times intervals must be at most 100000"
    );
    ensure!(
        request.lower > Decimal::ZERO
            && request.upper > request.lower
            && request.tick_size > Decimal::ZERO,
        "invalid grid bounds or tick size"
    );
    ensure!(
        request.lower.0 % request.tick_size.0 == 0 && request.upper.0 % request.tick_size.0 == 0,
        "grid bounds must align to tick size"
    );
    ensure!(
        request.starting_capital > Decimal::ZERO
            && request.commission_per_order >= Decimal::ZERO
            && request.slippage_bps <= 1000
            && (1..=10_000).contains(&request.portfolio_loss_limit_bps),
        "invalid capital, costs or portfolio loss limit"
    );
    let evidence = &request.source_evidence;
    ensure!(
        [
            &evidence.source,
            &evidence.calendar_source,
            &evidence.license_scope
        ]
        .into_iter()
        .all(|v| !v.trim().is_empty() && v.len() <= 1000),
        "source, calendar and license manifest required"
    );
    ensure!(
        evidence.dataset_sha256.len() == 64
            && evidence
                .dataset_sha256
                .bytes()
                .all(|v| v.is_ascii_hexdigit()),
        "invalid declared dataset hash"
    );
    ensure!(
        request.configured_at <= request.bars[0].available_at,
        "configuration must be frozen by the first observation"
    );
    for (i, bar) in request.bars.iter().enumerate() {
        ensure!(
            bar.volume > 0,
            "zero-volume bar cannot support a sampled opening fill"
        );
        ensure!(
            bar.low > Decimal::ZERO
                && bar.low <= bar.open
                && bar.open <= bar.high
                && bar.low <= bar.close
                && bar.close <= bar.high,
            "invalid OHLC prices"
        );
        ensure!(
            bar.open_at < bar.close_at
                && bar.close_at <= bar.available_at
                && bar.available_at <= request.as_of,
            "unfinished, future or noncausal bar"
        );
        ensure!(
            bar.open_at.date_naive() == bar.session_date
                && bar.close_at.date_naive() == bar.session_date,
            "session date must match the supplied UTC session boundaries"
        );
        if i > 0 {
            ensure!(
                request.bars[i - 1].session_date < bar.session_date
                    && request.bars[i - 1].available_at < bar.open_at,
                "duplicate/out-of-order session or prior close unavailable before next open"
            );
        }
    }
    Ok(())
}

fn levels(request: &GridReplayRequest) -> Result<Vec<Decimal>> {
    let mut result = Vec::with_capacity(request.intervals + 1);
    for i in 0..=request.intervals {
        let units = if i == 0 {
            request.lower.0
        } else if i == request.intervals {
            request.upper.0
        } else {
            match request.spacing {
                Spacing::Arithmetic => {
                    let raw = i128::from(request.lower.0)
                        + i128::from(request.upper.0 - request.lower.0) * i as i128
                            / request.intervals as i128;
                    i64::try_from(raw)?
                }
                Spacing::Geometric => {
                    let raw = (request.lower.0 as f64)
                        * ((request.upper.0 as f64) / (request.lower.0 as f64))
                            .powf(i as f64 / request.intervals as f64);
                    ensure!(
                        raw.is_finite() && raw >= 1.0 && raw < i64::MAX as f64,
                        "geometric grid overflow"
                    );
                    // Floor directly in tick units. Rounding to an intermediate
                    // micro-dollar first can cross a tick boundary upward.
                    let ticks = (raw / request.tick_size.0 as f64).floor();
                    i64::try_from((ticks as i128) * i128::from(request.tick_size.0))?
                }
            }
        };
        let rounded = Decimal(units / request.tick_size.0 * request.tick_size.0);
        if let Some(previous) = result.last() {
            ensure!(rounded > *previous, "tick rounding collapses grid levels");
        }
        result.push(rounded);
    }
    Ok(result)
}

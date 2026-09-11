//! Versioned, deterministic daily equity research. No broker or network access.
pub mod decimal;
pub mod grid;
mod replay;
#[cfg(test)]
mod tests;

use anyhow::{Result, ensure};
use chrono::{DateTime, NaiveDate, Timelike, Utc};
use chrono_tz::America::New_York;
pub use decimal::Decimal;
pub use replay::{ReplayRequest, ReplayResult, replay};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

pub const VERSION: &str = "leo-strategy-lab.v1";
pub const WARMUP: usize = 220;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum Strategy {
    #[serde(rename = "MR-v1")]
    MeanReversion,
    #[serde(rename = "MOM-v1")]
    Momentum,
}
impl Strategy {
    pub fn stop_multiple(self) -> u64 {
        match self {
            Self::MeanReversion => 2,
            Self::Momentum => 3,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DailyBar {
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
pub struct Evidence {
    pub source: String,
    pub dataset_sha256: String,
    pub calendar_source: String,
    pub adjustment_verified: bool,
    pub coverage_verified: bool,
    pub availability_verified: bool,
    pub classification: DataClass,
    pub license_scope: String,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DataClass {
    Observed,
    SyntheticFixture,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Position {
    pub quantity: u64,
    pub first_fill_price: Decimal,
    pub initial_stop: Decimal,
    pub current_stop: Decimal,
    pub entry_session: NaiveDate,
    pub highest_close: Decimal,
    /// Includes the current completed session; entry session counts as one.
    pub held_sessions: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EvaluateRequest {
    pub strategy: Strategy,
    pub as_of: DateTime<Utc>,
    pub bars: Vec<DailyBar>,
    pub evidence: Evidence,
    pub position: Option<Position>,
    #[serde(default)]
    pub pending_entry: bool,
    #[serde(default)]
    pub history_mode: HistoryMode,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HistoryMode {
    #[default]
    PointInTime,
    CurrentObservedSnapshot,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Indicators {
    pub sma20: f64,
    pub dispersion20: f64,
    pub z20: Option<f64>,
    pub rsi14: f64,
    pub atr14: Decimal,
    pub sma200: Option<f64>,
    pub prior55_high: Option<Decimal>,
    pub prior20_low: Option<Decimal>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Action {
    EnterLong,
    ExitLong,
    Hold,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Decision {
    pub schema_version: String,
    pub strategy: Strategy,
    pub action: Action,
    pub reason: String,
    pub signal_atr: Option<Decimal>,
    pub stop_price: Option<Decimal>,
    pub indicators: Option<Indicators>,
    pub decision_id: String,
    pub eligible_after: DateTime<Utc>,
    pub classification: DataClass,
    pub execution_authorized: bool,
    pub history_mode: HistoryMode,
}

pub fn sha256<T: Serialize>(value: &T) -> Result<String> {
    Ok(format!("{:x}", Sha256::digest(serde_json::to_vec(value)?)))
}

pub fn validate_bars(bars: &[DailyBar], evidence: &Evidence, as_of: DateTime<Utc>) -> Result<()> {
    validate_bars_mode(bars, evidence, as_of, HistoryMode::PointInTime)
}

fn validate_bars_mode(
    bars: &[DailyBar],
    evidence: &Evidence,
    as_of: DateTime<Utc>,
    mode: HistoryMode,
) -> Result<()> {
    ensure!(
        !bars.is_empty() && bars.len() <= 20_000,
        "daily history is empty or oversized"
    );
    ensure!(
        !evidence.source.trim().is_empty()
            && !evidence.calendar_source.trim().is_empty()
            && !evidence.license_scope.trim().is_empty(),
        "source, calendar and license evidence required"
    );
    ensure!(
        evidence.dataset_sha256.len() == 64
            && evidence
                .dataset_sha256
                .bytes()
                .all(|b| b.is_ascii_hexdigit()),
        "invalid dataset hash"
    );
    ensure!(
        evidence.adjustment_verified
            && evidence.coverage_verified
            && (evidence.availability_verified || mode == HistoryMode::CurrentObservedSnapshot),
        "unverified adjustments, session coverage or historical availability"
    );
    for (index, bar) in bars.iter().enumerate() {
        ensure!(
            bar.low > Decimal::ZERO
                && bar.low <= bar.open
                && bar.open <= bar.high
                && bar.low <= bar.close
                && bar.close <= bar.high,
            "invalid OHLC"
        );
        ensure!(
            bar.open_at < bar.close_at
                && bar.close_at <= bar.available_at
                && bar.available_at <= as_of,
            "unfinished or noncausal daily observation"
        );
        let opened = bar.open_at.with_timezone(&New_York);
        let closed = bar.close_at.with_timezone(&New_York);
        ensure!(
            opened.date_naive() == bar.session_date
                && closed.date_naive() == bar.session_date
                && opened.hour() == 9
                && opened.minute() == 30
                && opened.second() == 0
                && closed.hour() <= 16,
            "invalid regular-session boundary"
        );
        if index > 0 {
            ensure!(
                bars[index - 1].session_date < bar.session_date
                    && (mode == HistoryMode::CurrentObservedSnapshot
                        || bars[index - 1].available_at < bar.open_at),
                "duplicate/out-of-order session or prior bar unavailable before next open"
            );
        }
    }
    Ok(())
}

pub fn indicators(bars: &[DailyBar]) -> Result<Indicators> {
    ensure!(bars.len() >= 20, "indicator warmup incomplete");
    let n = bars.len();
    let mean =
        |rows: &[DailyBar]| rows.iter().map(|b| b.close.as_f64()).sum::<f64>() / rows.len() as f64;
    let sma20 = mean(&bars[n - 20..]);
    let dispersion20 = (bars[n - 20..]
        .iter()
        .map(|b| (b.close.as_f64() - sma20).powi(2))
        .sum::<f64>()
        / 20.0)
        .sqrt();
    let (mut gain, mut loss, mut atr) = (0.0, 0.0, 0.0);
    for (index, pair) in bars.windows(2).enumerate() {
        let previous = pair[0].close.as_f64();
        let current = &pair[1];
        let change = current.close.as_f64() - previous;
        let tr = (current.high.as_f64() - current.low.as_f64())
            .max((current.high.as_f64() - previous).abs())
            .max((current.low.as_f64() - previous).abs());
        if index < 14 {
            gain += change.max(0.0) / 14.0;
            loss += (-change).max(0.0) / 14.0;
            atr += tr / 14.0;
        } else {
            gain = (gain * 13.0 + change.max(0.0)) / 14.0;
            loss = (loss * 13.0 + (-change).max(0.0)) / 14.0;
            atr = (atr * 13.0 + tr) / 14.0;
        }
    }
    let rsi14 = if gain == 0.0 && loss == 0.0 {
        50.0
    } else if loss == 0.0 {
        100.0
    } else {
        100.0 - 100.0 / (1.0 + gain / loss)
    };
    Ok(Indicators {
        sma20,
        dispersion20,
        z20: (dispersion20 > 0.0).then(|| (bars[n - 1].close.as_f64() - sma20) / dispersion20),
        rsi14,
        atr14: Decimal::positive_ceil(atr)?,
        sma200: (n >= 200).then(|| mean(&bars[n - 200..])),
        prior55_high: (n >= 56).then(|| bars[n - 56..n - 1].iter().map(|b| b.high).max().unwrap()),
        prior20_low: (n >= 21).then(|| bars[n - 21..n - 1].iter().map(|b| b.low).min().unwrap()),
    })
}

pub fn initial_stop(
    strategy: Strategy,
    first_fill_price: Decimal,
    signal_atr: Decimal,
) -> Result<Decimal> {
    ensure!(
        first_fill_price > Decimal::ZERO && signal_atr > Decimal::ZERO,
        "positive entry and ATR required"
    );
    let stop = first_fill_price.checked_sub(signal_atr.quantity(strategy.stop_multiple())?)?;
    ensure!(
        stop > Decimal::ZERO,
        "protective stop outside positive price domain"
    );
    Ok(stop)
}

pub fn evaluate(request: &EvaluateRequest) -> Result<Decision> {
    evaluate_research(request, None)
}

/// Only replay accepts these overrides. They never alter deployable versions.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ResearchParameters {
    pub mr_z_abs: Option<f64>,
    pub mr_rsi_max: Option<f64>,
    pub momentum_lookback: Option<usize>,
    pub stop_multiple: Option<f64>,
}
impl ResearchParameters {
    fn validate(&self) -> Result<()> {
        ensure!(
            self.mr_z_abs
                .is_none_or(|x| x.is_finite() && (1.0..=4.0).contains(&x)),
            "invalid research z threshold"
        );
        ensure!(
            self.mr_rsi_max
                .is_none_or(|x| x.is_finite() && (1.0..=70.0).contains(&x)),
            "invalid research RSI threshold"
        );
        ensure!(
            self.momentum_lookback
                .is_none_or(|x| (20..=100).contains(&x)),
            "invalid research breakout lookback"
        );
        ensure!(
            self.stop_multiple
                .is_none_or(|x| x.is_finite() && (1.0..=5.0).contains(&x)),
            "invalid research stop multiple"
        );
        Ok(())
    }
    fn adjusted_atr(&self, strategy: Strategy, atr: Decimal) -> Result<Decimal> {
        self.validate()?;
        Decimal::positive_ceil(
            atr.as_f64()
                * self
                    .stop_multiple
                    .unwrap_or(strategy.stop_multiple() as f64)
                / strategy.stop_multiple() as f64,
        )
    }
}

fn evaluate_research(
    request: &EvaluateRequest,
    parameters: Option<&ResearchParameters>,
) -> Result<Decision> {
    if let Some(params) = parameters {
        params.validate()?;
    }
    validate_bars_mode(
        &request.bars,
        &request.evidence,
        request.as_of,
        request.history_mode,
    )?;
    let last = request.bars.last().unwrap();
    ensure!(
        (request.as_of - last.close_at).num_seconds() <= 7 * 24 * 60 * 60,
        "daily history is stale; caller must additionally verify the latest expected exchange session"
    );
    let mut decision = Decision {
        schema_version: VERSION.into(),
        strategy: request.strategy,
        action: Action::Hold,
        reason: "warmup_incomplete".into(),
        signal_atr: None,
        stop_price: None,
        indicators: None,
        // Wall-clock polling time is validation context, not signal identity.
        decision_id: sha256(&(
            request.strategy,
            &request.bars,
            &request.evidence,
            &request.position,
            request.pending_entry,
            request.history_mode,
            parameters,
        ))?,
        eligible_after: last.available_at,
        classification: request.evidence.classification,
        execution_authorized: false,
        history_mode: request.history_mode,
    };
    if request.bars.len() < WARMUP {
        return Ok(decision);
    }
    let values = indicators(&request.bars)?;
    let breakout_high =
        parameters
            .and_then(|p| p.momentum_lookback)
            .map_or(values.prior55_high, |lookback| {
                request.bars[request.bars.len() - lookback - 1..request.bars.len() - 1]
                    .iter()
                    .map(|b| b.high)
                    .max()
            });
    let stop_atr = parameters.map_or(Ok(values.atr14), |p| {
        p.adjusted_atr(request.strategy, values.atr14)
    })?;
    decision.signal_atr = Some(values.atr14);
    decision.reason = "no_entry_condition".into();
    if let Some(position) = &request.position {
        if position.entry_session > last.session_date {
            ensure!(
                position.entry_session <= request.as_of.with_timezone(&New_York).date_naive()
                    && position.held_sessions == 0
                    && position.quantity > 0
                    && position.first_fill_price > Decimal::ZERO
                    && position.initial_stop > Decimal::ZERO
                    && position.current_stop >= position.initial_stop,
                "invalid uncompleted-entry-session position"
            );
            decision.reason = "awaiting_first_completed_holding_session".into();
            decision.stop_price = Some(position.current_stop);
            decision.indicators = Some(values);
            return Ok(decision);
        }
        ensure!(
            position.quantity > 0
                && position.entry_session <= last.session_date
                && position.held_sessions > 0
                && position.first_fill_price > Decimal::ZERO
                && position.current_stop >= position.initial_stop
                && position.initial_stop > Decimal::ZERO,
            "invalid owned position"
        );
        let candidate_stop = match request.strategy {
            Strategy::MeanReversion => position.initial_stop,
            Strategy::Momentum => position.current_stop.max(
                position
                    .highest_close
                    .max(last.close)
                    .checked_sub(stop_atr.quantity(3)?)?,
            ),
        };
        decision.stop_price = Some(candidate_stop);
        decision.reason = "position_managed".into();
        let exit_reason = match request.strategy {
            Strategy::MeanReversion if last.close.as_f64() >= values.sma20 => {
                Some("MR_SMA20_RECLAIM")
            }
            Strategy::MeanReversion if position.held_sessions >= 10 => Some("MR_TEN_HELD_SESSIONS"),
            Strategy::Momentum if last.close < values.prior20_low.unwrap() => {
                Some("MOM_PRIOR20_LOW_BREAK")
            }
            _ => None,
        };
        if let Some(reason) = exit_reason {
            decision.action = Action::ExitLong;
            decision.reason = reason.into();
        }
    } else if request.pending_entry {
        decision.reason = "unresolved_entry_commitment".into();
    } else if values.dispersion20 == 0.0 || values.atr14 == Decimal::ZERO {
        decision.reason = "zero_dispersion_or_atr".into();
    } else {
        let enters = match request.strategy {
            Strategy::MeanReversion => {
                values
                    .z20
                    .is_some_and(|z| z <= -parameters.and_then(|p| p.mr_z_abs).unwrap_or(2.0))
                    && values.rsi14 <= parameters.and_then(|p| p.mr_rsi_max).unwrap_or(30.0)
            }
            Strategy::Momentum => {
                last.close > breakout_high.unwrap() && last.close.as_f64() > values.sma200.unwrap()
            }
        };
        if enters {
            decision.action = Action::EnterLong;
            decision.reason = match request.strategy {
                Strategy::MeanReversion => "MR_Z20_RSI14",
                Strategy::Momentum => "MOM_PRIOR55_HIGH_SMA200",
            }
            .into();
        }
    }
    decision.indicators = Some(values);
    if parameters.is_some() {
        decision.reason = format!("RESEARCH_VARIANT:{}", decision.reason);
    }
    Ok(decision)
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SizeRequest {
    pub strategy: Strategy,
    pub equity: Decimal,
    pub cash: Decimal,
    pub gross_exposure: Decimal,
    pub pending_commitment: Decimal,
    pub entry_price: Decimal,
    pub signal_atr: Decimal,
    pub daily_start_equity: Decimal,
    pub peak_equity: Decimal,
    pub paused: bool,
    pub commission_per_order: Decimal,
    pub slippage_bps: u32,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SizeResult {
    pub eligible: bool,
    pub quantity: u64,
    pub entry_price: Decimal,
    pub initial_stop: Option<Decimal>,
    pub reserved_cash: Decimal,
    pub planned_risk: Decimal,
    pub reason: String,
}
pub fn size_entry(request: &SizeRequest) -> Result<SizeResult> {
    ensure!(
        request.equity > Decimal::ZERO
            && request.daily_start_equity > Decimal::ZERO
            && request.peak_equity >= request.equity
            && request.cash >= Decimal::ZERO
            && request.gross_exposure >= Decimal::ZERO
            && request.pending_commitment >= Decimal::ZERO
            && request.commission_per_order >= Decimal::ZERO
            && request.slippage_bps <= 1_000,
        "invalid risk inputs"
    );
    let mut result = SizeResult {
        eligible: false,
        quantity: 0,
        entry_price: request.entry_price,
        initial_stop: None,
        reserved_cash: Decimal::ZERO,
        planned_risk: Decimal::ZERO,
        reason: "paused".into(),
    };
    if request.paused {
        return Ok(result);
    }
    if request.equity
        <= request
            .daily_start_equity
            .checked_sub(request.daily_start_equity.bps(100, false)?)?
    {
        result.reason = "daily_loss_limit".into();
        return Ok(result);
    }
    if request.equity
        <= request
            .peak_equity
            .checked_sub(request.peak_equity.bps(500, false)?)?
    {
        result.reason = "drawdown_limit".into();
        return Ok(result);
    }
    let stop = initial_stop(request.strategy, request.entry_price, request.signal_atr)?;
    result.initial_stop = Some(stop);
    let fees = request.commission_per_order.quantity(2)?;
    let distance = request
        .entry_price
        .checked_sub(stop)?
        .checked_add(request.entry_price.bps(request.slippage_bps, true)?)?;
    let risk_budget = request.equity.bps(25, false)?.checked_sub(fees)?;
    let position_budget = request.equity.bps(500, false)?;
    let gross_budget = request
        .equity
        .bps(2000, false)?
        .checked_sub(request.gross_exposure)?
        .checked_sub(request.pending_commitment)?;
    let cash_budget = request
        .cash
        .checked_sub(request.pending_commitment)?
        .checked_sub(fees)?;
    let quantity = (risk_budget.0 / distance.0)
        .min(position_budget.0 / request.entry_price.0)
        .min(gross_budget.0 / request.entry_price.0)
        .min(cash_budget.0 / request.entry_price.0)
        .max(0) as u64;
    result.reason = "zero_affordable_quantity".into();
    if quantity > 0 {
        result.eligible = true;
        result.quantity = quantity;
        result.reason = "within_simulation_limits".into();
        result.reserved_cash = request.entry_price.quantity(quantity)?.checked_add(fees)?;
        result.planned_risk = distance.quantity(quantity)?.checked_add(fees)?;
    }
    Ok(result)
}

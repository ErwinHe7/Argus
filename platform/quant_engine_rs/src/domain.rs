use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};

pub const CAUSAL_MINUTE_OBSERVATION_SCHEMA_VERSION: &str = "causal_minute_observation.v2";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MarketBar {
    pub timestamp: DateTime<Utc>,
    pub symbol: String,
    pub open: f64,
    pub high: f64,
    pub low: f64,
    pub close: f64,
    pub volume: f64,
    pub vwap: Option<f64>,
    pub bid: Option<f64>,
    pub ask: Option<f64>,
    pub trade_count: Option<u64>,
    pub source: String,
    pub data_quality: String,
}

impl MarketBar {
    pub fn validate(&self) -> bool {
        self.open.is_finite()
            && self.high.is_finite()
            && self.low.is_finite()
            && self.close.is_finite()
            && self.volume.is_finite()
            && self.open > 0.0
            && self.low > 0.0
            && self.high >= self.low
            && self.high >= self.open.max(self.close)
            && self.low <= self.open.min(self.close)
            && self.volume >= 0.0
    }

    /// A completed OHLCV row is evidence of an observed trade interval only
    /// when it contains positive traded volume. Zero-volume rows and an absent
    /// row are not silently reinterpreted as trades.
    pub fn is_observed_trade_bar(&self) -> bool {
        self.validate() && self.volume > 0.0 && self.trade_count != Some(0)
    }
}

/// Point-in-time classification of one exchange-clock minute. The production
/// OHLCV stream can create `ObservedTradeBar` evidence.
/// `CausallyInferredNoTrade` is an AXIO7 inference from the provider's absence
/// convention plus verified continuous transport health; it is not a vendor
/// assertion. Unqualified stream silence is always `UnknownMissing`.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "snake_case")]
pub enum MinuteObservationState {
    ObservedTradeBar,
    CausallyInferredNoTrade,
    UnknownMissing,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CausalMinuteObservation {
    pub schema_version: String,
    pub symbol: String,
    pub interval_start: DateTime<Utc>,
    pub interval_end: DateTime<Utc>,
    pub state: MinuteObservationState,
    pub evidence_available_at: Option<DateTime<Utc>>,
    pub evidence_source: Option<String>,
    pub evidence_reference: Option<String>,
}

impl CausalMinuteObservation {
    pub fn unknown_missing(symbol: impl Into<String>, interval_start: DateTime<Utc>) -> Self {
        Self {
            schema_version: CAUSAL_MINUTE_OBSERVATION_SCHEMA_VERSION.to_string(),
            symbol: symbol.into(),
            interval_start,
            interval_end: interval_start + chrono::Duration::minutes(1),
            state: MinuteObservationState::UnknownMissing,
            evidence_available_at: None,
            evidence_source: None,
            evidence_reference: None,
        }
    }

    pub fn validate(&self) -> bool {
        if self.schema_version != CAUSAL_MINUTE_OBSERVATION_SCHEMA_VERSION
            || self.symbol.trim().is_empty()
            || self.interval_end != self.interval_start + chrono::Duration::minutes(1)
        {
            return false;
        }
        match self.state {
            MinuteObservationState::ObservedTradeBar => {
                self.evidence_available_at
                    .is_some_and(|available_at| available_at >= self.interval_end)
                    && self
                        .evidence_source
                        .as_deref()
                        .is_some_and(|source| !source.trim().is_empty())
            }
            MinuteObservationState::CausallyInferredNoTrade => {
                self.evidence_available_at
                    .is_some_and(|available_at| available_at >= self.interval_end)
                    && self
                        .evidence_source
                        .as_deref()
                        .is_some_and(|source| !source.trim().is_empty())
                    && self
                        .evidence_reference
                        .as_deref()
                        .is_some_and(|reference| !reference.trim().is_empty())
            }
            MinuteObservationState::UnknownMissing => {
                self.evidence_available_at.is_none()
                    && self.evidence_source.is_none()
                    && self.evidence_reference.is_none()
            }
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OptionQuote {
    pub timestamp: DateTime<Utc>,
    pub underlying: String,
    pub option_symbol: String,
    pub expiry: NaiveDate,
    pub dte: i32,
    pub strike: f64,
    pub call_put: CallPut,
    pub bid: f64,
    pub ask: f64,
    pub bid_size: u32,
    pub ask_size: u32,
    pub last: Option<f64>,
    pub volume: Option<u64>,
    pub open_interest_at_open: Option<u64>,
    pub iv: Option<f64>,
    pub delta: Option<f64>,
    pub gamma: Option<f64>,
    pub theta: Option<f64>,
    pub vega: Option<f64>,
    pub underlying_price: f64,
    pub source: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RawOptionNbbo {
    pub timestamp: DateTime<Utc>,
    pub instrument_id: u32,
    pub option_symbol: String,
    pub bid: f64,
    pub ask: f64,
    pub bid_size: u32,
    pub ask_size: u32,
    pub last: Option<f64>,
    pub source: String,
}

impl OptionQuote {
    pub fn mid(&self) -> f64 {
        (self.bid + self.ask) * 0.5
    }
    pub fn spread_pct(&self) -> f64 {
        let mid = self.mid();
        if mid <= 0.0 {
            f64::INFINITY
        } else {
            (self.ask - self.bid) / mid
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum CallPut {
    Call,
    Put,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MarketState {
    pub timestamp: DateTime<Utc>,
    pub session_date: NaiveDate,
    pub symbol: String,
    pub open: f64,
    pub high: f64,
    pub low: f64,
    pub close: f64,
    pub atr: f64,
    pub ret_1m: f64,
    pub ret_3m: f64,
    pub ret_5m: f64,
    pub ret_15m: f64,
    pub ret_30m: f64,
    pub ret_60m: f64,
    /// Return of the currently forming 5m bucket using only bars observed so far.
    pub active_5m_return: f64,
    /// Return of the most recent fully closed 5m bucket. Never includes the current bucket.
    pub last_completed_5m_return: f64,
    /// Return of the most recent fully closed 15m bucket. Never includes the current bucket.
    pub last_completed_15m_return: f64,
    pub slope_15m: f64,
    pub dist_vwap: f64,
    pub dist_session_open: f64,
    pub rolling_realized_vol: f64,
    pub normalized_range: f64,
    pub upper_wick_ratio: f64,
    pub lower_wick_ratio: f64,
    pub close_location_value: f64,
    pub distance_session_high: f64,
    pub distance_session_low: f64,
    pub failed_opening_breakout: f64,
    pub consecutive_up_bars: i32,
    pub consecutive_down_bars: i32,
    pub return_acceleration: f64,
    pub volume_zscore: f64,
    pub volume_acceleration: f64,
    pub session_range_position: f64,
    pub cross_asset_breadth_score: f64,
    /// Risk-on minus defensive 5m return basket (QQQ/IWM/HYG vs TLT/UUP).
    pub risk_rotation_score: f64,
    pub market_confirmation_score: f64,
    /// True only when every symbol required by the versioned cross-asset
    /// feature schema was causally present at this state's cutoff. A numeric
    /// zero is not sufficient evidence of availability.
    #[serde(default)]
    pub cross_asset_context_complete: bool,
    /// Fraction of required cross-asset symbols present at the exact cutoff.
    #[serde(default)]
    pub cross_asset_context_coverage: f64,
    pub closing_short_cover_score: f64,
    pub rvol_same_minute: f64,
    pub minutes_from_open: i32,
    pub minutes_to_close: i32,
    pub bucket_5m: i32,
    pub bucket_15m: i32,
    pub minute_in_5m_bucket: i32,
    /// True only when all five one-minute observations in the just-completed
    /// exchange-clock bucket are present and exactly one minute apart.
    #[serde(default)]
    pub completed_5m_bucket_valid: bool,
    /// Number of consecutive one-minute observations ending at this state,
    /// capped only by the current session history.
    #[serde(default)]
    pub continuous_minute_count: usize,
}

impl MarketState {
    pub const FEATURE_COUNT: usize = 33;
    pub fn feature_vector(&self) -> [f64; Self::FEATURE_COUNT] {
        let phase = self.minutes_from_open.max(0) as f64 / 390.0;
        [
            self.ret_1m,
            self.ret_5m,
            self.ret_15m,
            self.dist_vwap,
            self.dist_session_open,
            self.rolling_realized_vol,
            self.normalized_range,
            self.upper_wick_ratio,
            self.lower_wick_ratio,
            self.close_location_value,
            self.distance_session_high,
            self.distance_session_low,
            self.failed_opening_breakout,
            self.consecutive_up_bars as f64,
            self.consecutive_down_bars as f64,
            self.return_acceleration,
            self.volume_zscore,
            self.volume_acceleration,
            self.session_range_position,
            self.cross_asset_breadth_score,
            self.risk_rotation_score,
            self.market_confirmation_score,
            self.closing_short_cover_score,
            self.ret_3m,
            self.ret_30m,
            self.ret_60m,
            self.active_5m_return,
            self.last_completed_5m_return,
            self.last_completed_15m_return,
            self.slope_15m,
            self.rvol_same_minute,
            (std::f64::consts::TAU * phase).sin(),
            (std::f64::consts::TAU * phase).cos(),
        ]
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum SetupType {
    OpeningRangeBreakout,
    OpeningDriveContinuation,
    FailedBreakout,
    LiquiditySweepReclaim,
    VwapPullback,
    VwapRejection,
    MeanReversion,
    ClosingShortCover,
    TimeBucketReversal,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Candidate {
    pub candidate_id: String,
    pub timestamp: DateTime<Utc>,
    pub session_date: NaiveDate,
    pub state_index: usize,
    pub setup_type: SetupType,
    pub direction: i8,
    pub entry_reference: f64,
    pub reason_codes: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Outcome {
    pub state_index: usize,
    pub entry_timestamp: DateTime<Utc>,
    pub horizon_minutes: usize,
    pub directional_return: f64,
    pub mfe: f64,
    pub mae: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AnalogCase {
    pub rank: usize,
    pub analog_timestamp: DateTime<Utc>,
    pub distance: f64,
    pub similarity: f64,
    pub forward_return: f64,
    pub mfe: f64,
    pub mae: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Prediction {
    pub expected_return: f64,
    pub median_return: f64,
    pub win_probability: f64,
    pub predicted_mfe: f64,
    pub predicted_mae: f64,
    pub neighbor_count: usize,
    pub similarity_score: f64,
    pub uncertainty: f64,
    #[serde(default)]
    pub effective_sample_size: f64,
    #[serde(default)]
    pub max_day_weight: f64,
    #[serde(default)]
    pub concentration_penalty: f64,
    pub analogs: Vec<AnalogCase>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CandidateDecision {
    pub candidate: Candidate,
    pub selected: bool,
    pub score: f64,
    pub expected_net_return: f64,
    pub prediction: Option<Prediction>,
    pub rejection_reason: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Trade {
    pub trade_id: String,
    pub trade_date: NaiveDate,
    pub setup: SetupType,
    pub direction: i8,
    pub signal_time: DateTime<Utc>,
    pub entry_time: DateTime<Utc>,
    pub exit_time: DateTime<Utc>,
    pub underlying_entry: f64,
    pub underlying_exit: f64,
    pub gross_return: f64,
    pub cost: f64,
    pub net_return: f64,
    pub mfe: f64,
    pub mae: f64,
    pub holding_minutes: usize,
    pub exit_reason: String,
    pub model_probability: f64,
    pub score: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OptionFill {
    pub option_symbol: String,
    pub entry_fill: f64,
    pub exit_fill: f64,
    pub gross_pnl_per_contract: f64,
    #[serde(default = "default_one_contract")]
    pub requested_contracts: u32,
    #[serde(default)]
    pub filled_contracts: u32,
    #[serde(default)]
    pub fill_status: String,
    pub rejected_reason: Option<String>,
}

fn default_one_contract() -> u32 {
    1
}

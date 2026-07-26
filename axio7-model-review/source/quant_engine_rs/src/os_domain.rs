use std::collections::BTreeMap;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

pub const EVENT_SCHEMA_VERSION: &str = "axio.quant.v1";

pub fn stable_id(parts: &[&str]) -> String {
    let mut hash = Sha256::new();
    for part in parts {
        hash.update(part.as_bytes());
        hash.update([0]);
    }
    format!("axio_{}", &format!("{:x}", hash.finalize())[..24])
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct EventMeta {
    pub event_id: String,
    pub schema_version: String,
    pub symbol: String,
    pub event_time: DateTime<Utc>,
    pub received_time: DateTime<Utc>,
    pub source: String,
    pub model_version: Option<String>,
    pub correlation_id: String,
    pub causation_id: Option<String>,
}

impl EventMeta {
    pub fn deterministic(
        kind: &str,
        symbol: &str,
        event_time: DateTime<Utc>,
        source: &str,
        correlation_id: &str,
    ) -> Self {
        let time = event_time.to_rfc3339();
        Self {
            event_id: stable_id(&[kind, symbol, &time, correlation_id]),
            schema_version: EVENT_SCHEMA_VERSION.to_string(),
            symbol: symbol.to_string(),
            event_time,
            received_time: Utc::now(),
            source: source.to_string(),
            model_version: None,
            correlation_id: correlation_id.to_string(),
            causation_id: None,
        }
    }

    pub fn validate(&self) -> Result<(), String> {
        if self.event_id.is_empty() || self.symbol.is_empty() || self.correlation_id.is_empty() {
            return Err("event identity fields cannot be empty".to_string());
        }
        if self.schema_version != EVENT_SCHEMA_VERSION {
            return Err("unsupported schema version".to_string());
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MarketEvent {
    pub meta: EventMeta,
    pub event_type: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BarEvent {
    pub meta: EventMeta,
    pub open: f64,
    pub high: f64,
    pub low: f64,
    pub close: f64,
    pub volume: f64,
    pub interval_seconds: u32,
    pub completed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FeatureSnapshot {
    pub meta: EventMeta,
    pub snapshot_time: DateTime<Utc>,
    pub last_completed_1m_bar: DateTime<Utc>,
    pub last_completed_5m_bar: Option<DateTime<Utc>>,
    pub active_5m_partial_state: BTreeMap<String, f64>,
    pub data_freshness_seconds: i64,
    pub features: BTreeMap<String, Option<f64>>,
    pub missing_features: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ModelPrediction {
    pub meta: EventMeta,
    pub horizon_minutes: usize,
    pub direction_probability: f64,
    pub expected_return_bps: f64,
    pub expected_mfe_bps: f64,
    pub expected_mae_bps: f64,
    pub confidence: f64,
    pub sample_count: usize,
    pub calibration_status: String,
    pub calibration_error: Option<f64>,
    pub data_quality: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CalibratedPrediction {
    pub prediction: ModelPrediction,
    pub calibrated_probability: f64,
    pub method: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RegimeState {
    pub meta: EventMeta,
    pub regime: String,
    pub confidence: f64,
    pub evidence: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AlphaContribution {
    pub model_id: String,
    pub raw_alpha_bps: f64,
    pub weight: f64,
    pub weighted_alpha_bps: f64,
    pub penalty_reason: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EnsembleSignal {
    pub meta: EventMeta,
    pub action: String,
    pub expected_return_bps: f64,
    pub probability: f64,
    pub confidence: f64,
    pub contributions: Vec<AlphaContribution>,
    pub reason_codes: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PositionIntent {
    pub meta: EventMeta,
    pub side: String,
    pub target_notional: f64,
    pub target_weight: f64,
    pub stop_bps: f64,
    pub take_profit_bps: f64,
    pub max_holding_minutes: usize,
    pub sizing_reasons: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RiskDecision {
    pub meta: EventMeta,
    pub approved: bool,
    pub checks: BTreeMap<String, bool>,
    pub rejection_reasons: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OrderIntent {
    pub meta: EventMeta,
    pub side: String,
    pub quantity: f64,
    pub order_type: String,
    pub limit_price: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum OrderStatus {
    Created,
    RiskRejected,
    Approved,
    Submitted,
    PartiallyFilled,
    Filled,
    Cancelled,
    Expired,
    Rejected,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Order {
    pub order_id: String,
    pub intent: OrderIntent,
    pub status: OrderStatus,
    pub filled_quantity: f64,
    pub rejection_reason: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Fill {
    pub meta: EventMeta,
    pub fill_id: String,
    pub order_id: String,
    pub quantity: f64,
    pub price: f64,
    pub fee: f64,
    pub liquidity: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Position {
    pub symbol: String,
    pub quantity: f64,
    pub average_price: f64,
    pub mark_price: f64,
    pub realized_pnl: f64,
    pub unrealized_pnl: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PortfolioSnapshot {
    pub as_of: DateTime<Utc>,
    pub cash: f64,
    pub equity: f64,
    pub gross_exposure: f64,
    pub net_exposure: f64,
    pub positions: Vec<Position>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PnLSnapshot {
    pub as_of: DateTime<Utc>,
    pub realized: f64,
    pub unrealized: f64,
    pub fees: f64,
    pub daily_return: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ModelVersion {
    pub model_id: String,
    pub version: String,
    pub status: String,
    pub feature_schema_version: String,
    pub training_period: String,
    pub validation_period: String,
    pub test_period: String,
    pub metrics: BTreeMap<String, f64>,
    pub calibration_status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ExperimentRun {
    pub experiment_id: String,
    pub git_commit: Option<String>,
    pub data_manifest_hashes: Vec<String>,
    pub feature_schema_version: String,
    pub label_definition: String,
    pub hyperparameters: BTreeMap<String, String>,
    pub random_seed: u64,
    pub promoted_status: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AuditEvent {
    pub meta: EventMeta,
    pub category: String,
    pub action: String,
    pub outcome: String,
    pub details: BTreeMap<String, String>,
}

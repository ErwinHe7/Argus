use std::{
    collections::{BTreeMap, BTreeSet, HashMap},
    fs,
    path::Path,
    sync::Arc,
};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Duration, NaiveDate, SecondsFormat, TimeZone, Utc};
use chrono_tz::America::New_York;
use parking_lot::Mutex;
use rusqlite::{Connection, OptionalExtension, Transaction, TransactionBehavior, params};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::domain::MarketState;

pub const MARKET_SNAPSHOT_SCHEMA_VERSION: &str = "axio.market-memory.snapshot.v1";
pub const FORWARD_LABEL_SCHEMA_VERSION: &str = "axio.market-memory.forward-label.v1";
pub const REQUIRED_HORIZONS_MINUTES: [u16; 4] = [5, 15, 30, 60];
pub const AUTHORITATIVE_STORE_FORMAT: &str = "SQLITE_APPEND_ONLY";
pub const EXPORT_FORMAT: &str = "SQLITE";
pub const EXPORT_STATUS: &str = "SQLITE_AUTHORITATIVE_PARQUET_ARROW_EXPORT_PENDING";
pub const FORWARD_LABEL_STORAGE_MODE: &str = "SEPARATE_APPEND_ONLY_FORWARD_LABEL_SETTLEMENT";

/// A value and the point-in-time evidence supporting it.
///
/// `value_observed` means the value was available without imputation at
/// `available_at`. Derived features computed solely from observed inputs also
/// use this state. Missing and imputed values remain distinguishable; callers
/// must never serialize a numeric sentinel as if it were an observation.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PointInTimeValue<T> {
    pub value: Option<T>,
    pub value_observed: bool,
    pub value_imputed: bool,
    pub imputation_method: Option<String>,
    pub imputation_uncertainty: Option<f64>,
    pub original_availability_status: String,
    pub available_at: Option<DateTime<Utc>>,
    pub source: Option<String>,
}

impl<T> PointInTimeValue<T> {
    pub fn observed(value: T, available_at: DateTime<Utc>, source: impl Into<String>) -> Self {
        Self {
            value: Some(value),
            value_observed: true,
            value_imputed: false,
            imputation_method: None,
            imputation_uncertainty: None,
            original_availability_status: "OBSERVED".to_string(),
            available_at: Some(available_at),
            source: Some(source.into()),
        }
    }

    pub fn missing(status: impl Into<String>) -> Self {
        Self {
            value: None,
            value_observed: false,
            value_imputed: false,
            imputation_method: None,
            imputation_uncertainty: None,
            original_availability_status: status.into(),
            available_at: None,
            source: None,
        }
    }

    pub fn imputed(
        value: T,
        available_at: DateTime<Utc>,
        source: impl Into<String>,
        method: impl Into<String>,
        uncertainty: f64,
        original_status: impl Into<String>,
    ) -> Self {
        Self {
            value: Some(value),
            value_observed: false,
            value_imputed: true,
            imputation_method: Some(method.into()),
            imputation_uncertainty: Some(uncertainty),
            original_availability_status: original_status.into(),
            available_at: Some(available_at),
            source: Some(source.into()),
        }
    }

    pub fn is_available(&self) -> bool {
        self.value.is_some()
    }

    fn validate_metadata(&self, name: &str, cutoff: DateTime<Utc>) -> Result<()> {
        if self.original_availability_status.trim().is_empty() {
            bail!("{name} must retain its original availability status");
        }
        if self.value_observed && self.value_imputed {
            bail!("{name} cannot be both observed and imputed");
        }
        match self.value.as_ref() {
            Some(_) => {
                if !self.value_observed && !self.value_imputed {
                    bail!("{name} has a value without observed/imputed provenance");
                }
                let available_at = self
                    .available_at
                    .with_context(|| format!("{name} has a value without available_at"))?;
                if available_at > cutoff {
                    bail!("{name} became available after the record cutoff");
                }
                if self.source.as_deref().is_none_or(str::is_empty) {
                    bail!("{name} has a value without source lineage");
                }
            }
            None => {
                if self.value_observed || self.value_imputed {
                    bail!("{name} is marked available but has no value");
                }
                if self.available_at.is_some() || self.source.is_some() {
                    bail!("{name} missing value cannot claim availability or source");
                }
            }
        }
        if self.value_imputed {
            if self.imputation_method.as_deref().is_none_or(str::is_empty) {
                bail!("{name} imputation method is absent");
            }
            let uncertainty = self
                .imputation_uncertainty
                .with_context(|| format!("{name} imputation uncertainty is absent"))?;
            if !uncertainty.is_finite() || uncertainty < 0.0 {
                bail!("{name} imputation uncertainty is invalid");
            }
        } else if self.imputation_method.is_some() || self.imputation_uncertainty.is_some() {
            bail!("{name} has imputation metadata but is not imputed");
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct SourceLineage {
    pub provider: String,
    pub source_version: String,
    pub data_manifest_hash: String,
    pub source_record_ids: Vec<String>,
    pub availability_semantics: String,
    pub feature_version: String,
}

impl SourceLineage {
    fn normalized(mut self) -> Self {
        self.source_record_ids.sort();
        self.source_record_ids.dedup();
        self
    }

    fn validate(&self) -> Result<()> {
        for (name, value) in [
            ("provider", self.provider.as_str()),
            ("source_version", self.source_version.as_str()),
            ("data_manifest_hash", self.data_manifest_hash.as_str()),
            (
                "availability_semantics",
                self.availability_semantics.as_str(),
            ),
            ("feature_version", self.feature_version.as_str()),
        ] {
            if value.trim().is_empty() {
                bail!("source lineage {name} is empty");
            }
        }
        if self.source_record_ids.is_empty()
            || self.source_record_ids.iter().any(|value| value.is_empty())
        {
            bail!("source lineage requires non-empty source record IDs");
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ReturnWindows {
    pub return_1m: PointInTimeValue<f64>,
    pub return_2m: PointInTimeValue<f64>,
    pub return_3m: PointInTimeValue<f64>,
    pub return_5m: PointInTimeValue<f64>,
    pub return_10m: PointInTimeValue<f64>,
    pub return_15m: PointInTimeValue<f64>,
    pub return_30m: PointInTimeValue<f64>,
    pub return_60m: PointInTimeValue<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ForwardLabelReference {
    pub storage_mode: String,
    pub required_horizons_minutes: Vec<u16>,
    pub point_in_time_rule: String,
}

impl Default for ForwardLabelReference {
    fn default() -> Self {
        Self {
            storage_mode: FORWARD_LABEL_STORAGE_MODE.to_string(),
            required_horizons_minutes: REQUIRED_HORIZONS_MINUTES.to_vec(),
            point_in_time_rule:
                "LABELS_ARE_NEVER_FEATURES_AND_ARE_APPENDED_ONLY_AFTER_LABEL_AVAILABLE_AT"
                    .to_string(),
        }
    }
}

/// Immutable feature record for one decision timestamp.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MarketSnapshotRecord {
    pub schema_version: String,
    pub dataset_version: String,
    pub symbol: String,
    pub decision_as_of: DateTime<Utc>,
    pub information_available_as_of: DateTime<Utc>,
    pub session_date: NaiveDate,
    pub minute_of_session: u16,
    pub reference_price: PointInTimeValue<f64>,
    pub returns: ReturnWindows,
    pub overnight_gap: PointInTimeValue<f64>,
    pub vwap_distance: PointInTimeValue<f64>,
    pub opening_price_distance: PointInTimeValue<f64>,
    pub previous_close_distance: PointInTimeValue<f64>,
    pub previous_high_distance: PointInTimeValue<f64>,
    pub previous_low_distance: PointInTimeValue<f64>,
    pub current_session_range_position: PointInTimeValue<f64>,
    pub realized_volatility: PointInTimeValue<f64>,
    pub upside_semivariance: PointInTimeValue<f64>,
    pub downside_semivariance: PointInTimeValue<f64>,
    pub relative_volume: PointInTimeValue<f64>,
    pub volume_acceleration: PointInTimeValue<f64>,
    pub signed_volume_proxy: PointInTimeValue<f64>,
    pub trade_intensity: PointInTimeValue<f64>,
    pub relative_strength: PointInTimeValue<f64>,
    pub cross_asset_returns: BTreeMap<String, PointInTimeValue<f64>>,
    pub breadth_proxy: PointInTimeValue<f64>,
    pub hmm_filtered_regime_probabilities: BTreeMap<String, PointInTimeValue<f64>>,
    pub regime_entropy: PointInTimeValue<f64>,
    pub volatility_percentile: PointInTimeValue<f64>,
    pub liquidity_state: PointInTimeValue<String>,
    pub spread_state: PointInTimeValue<String>,
    pub data_quality_flags: PointInTimeValue<Vec<String>>,
    pub known_scheduled_event_flags: PointInTimeValue<Vec<String>>,
    pub applicable_unscheduled_event_flags: PointInTimeValue<Vec<String>>,
    pub forward_labels: ForwardLabelReference,
    pub source_lineage: SourceLineage,
    pub correction_of: Option<String>,
    pub correction_reason: Option<String>,
}

impl MarketSnapshotRecord {
    /// Honest adapter from the current feature engine. Fields not present in
    /// `MarketState` remain missing rather than receiving a zero sentinel.
    pub fn from_market_state(
        state: &MarketState,
        decision_as_of: DateTime<Utc>,
        information_available_as_of: DateTime<Utc>,
        dataset_version: impl Into<String>,
        source_lineage: SourceLineage,
    ) -> Result<Self> {
        if !(0..390).contains(&state.minutes_from_open) {
            bail!("market state is outside the regular-session minute range");
        }
        let earliest_bar_availability = state.timestamp + Duration::minutes(1);
        if information_available_as_of > decision_as_of
            || information_available_as_of < earliest_bar_availability
        {
            bail!(
                "market-state availability must be at least one completed minute after the bar timestamp and no later than decision_as_of"
            );
        }
        let source = "MARKET_STATE_POINT_IN_TIME_DERIVATION";
        let observed =
            |value| PointInTimeValue::observed(value, information_available_as_of, source);
        let return_if_warm = |minutes: i32, value: f64| {
            if state.minutes_from_open >= minutes {
                observed(value)
            } else {
                PointInTimeValue::missing(format!("WARMUP_REQUIRES_{minutes}_MINUTES"))
            }
        };
        Ok(Self {
            schema_version: MARKET_SNAPSHOT_SCHEMA_VERSION.to_string(),
            dataset_version: dataset_version.into(),
            symbol: state.symbol.clone(),
            decision_as_of,
            information_available_as_of,
            session_date: state.session_date,
            minute_of_session: state.minutes_from_open as u16,
            reference_price: observed(state.close),
            returns: ReturnWindows {
                return_1m: return_if_warm(1, state.ret_1m),
                return_2m: PointInTimeValue::missing(
                    "NOT_COMPUTED_BY_MARKET_STATE_POINT_IN_TIME_V3",
                ),
                return_3m: return_if_warm(3, state.ret_3m),
                return_5m: return_if_warm(5, state.ret_5m),
                return_10m: PointInTimeValue::missing(
                    "NOT_COMPUTED_BY_MARKET_STATE_POINT_IN_TIME_V3",
                ),
                return_15m: return_if_warm(15, state.ret_15m),
                return_30m: return_if_warm(30, state.ret_30m),
                return_60m: return_if_warm(60, state.ret_60m),
            },
            overnight_gap: PointInTimeValue::missing("PRIOR_CLOSE_NOT_IN_MARKET_STATE"),
            vwap_distance: observed(state.dist_vwap),
            opening_price_distance: observed(state.dist_session_open),
            previous_close_distance: PointInTimeValue::missing(
                "PRIOR_SESSION_REFERENCE_NOT_IN_MARKET_STATE",
            ),
            previous_high_distance: PointInTimeValue::missing(
                "PRIOR_SESSION_REFERENCE_NOT_IN_MARKET_STATE",
            ),
            previous_low_distance: PointInTimeValue::missing(
                "PRIOR_SESSION_REFERENCE_NOT_IN_MARKET_STATE",
            ),
            current_session_range_position: observed(state.session_range_position),
            realized_volatility: observed(state.rolling_realized_vol),
            upside_semivariance: PointInTimeValue::missing("NOT_COMPUTED"),
            downside_semivariance: PointInTimeValue::missing("NOT_COMPUTED"),
            relative_volume: observed(state.rvol_same_minute),
            volume_acceleration: observed(state.volume_acceleration),
            signed_volume_proxy: PointInTimeValue::missing("NOT_COMPUTED"),
            trade_intensity: PointInTimeValue::missing("TRADE_COUNT_NOT_IN_MARKET_STATE"),
            relative_strength: PointInTimeValue::missing("NOT_COMPUTED"),
            cross_asset_returns: BTreeMap::new(),
            breadth_proxy: if state.cross_asset_context_complete {
                observed(state.cross_asset_breadth_score)
            } else {
                PointInTimeValue::missing(format!(
                    "CROSS_ASSET_CONTEXT_INCOMPLETE:{:.3}",
                    state.cross_asset_context_coverage
                ))
            },
            hmm_filtered_regime_probabilities: BTreeMap::new(),
            regime_entropy: PointInTimeValue::missing("HMM_CONTEXT_NOT_ATTACHED"),
            volatility_percentile: PointInTimeValue::missing("NOT_COMPUTED"),
            liquidity_state: PointInTimeValue::missing("QUOTE_STATE_NOT_ATTACHED"),
            spread_state: PointInTimeValue::missing("QUOTE_STATE_NOT_ATTACHED"),
            data_quality_flags: PointInTimeValue::observed(
                vec!["MARKET_STATE_POINT_IN_TIME_DERIVATION".to_string()],
                information_available_as_of,
                source,
            ),
            known_scheduled_event_flags: PointInTimeValue::missing(
                "POINT_IN_TIME_EVENT_CALENDAR_NOT_ATTACHED",
            ),
            applicable_unscheduled_event_flags: PointInTimeValue::missing(
                "EVENT_DETECTOR_NOT_ATTACHED",
            ),
            forward_labels: ForwardLabelReference::default(),
            source_lineage,
            correction_of: None,
            correction_reason: None,
        })
    }

    /// Attach a causal, forward-filtered HMM posterior before finalizing the
    /// immutable snapshot. The caller must supply the actual model-observation
    /// availability time; smoothed or future-informed probabilities are not
    /// accepted by this adapter's semantics.
    pub fn with_filtered_regime(
        mut self,
        probabilities: &[f64],
        available_at: DateTime<Utc>,
        model_artifact_sha256: &str,
    ) -> Result<Self> {
        if probabilities.len() < 2
            || probabilities
                .iter()
                .any(|probability| !probability.is_finite() || !(0.0..=1.0).contains(probability))
        {
            bail!("filtered regime posterior must contain at least two finite probabilities");
        }
        let total = probabilities.iter().sum::<f64>();
        if (total - 1.0).abs() > 1.0e-8 {
            bail!("filtered regime posterior must sum to one");
        }
        if available_at < self.information_available_as_of || available_at > self.decision_as_of {
            bail!("filtered regime posterior availability is outside the snapshot cutoff");
        }
        if model_artifact_sha256.trim().is_empty() {
            bail!("filtered regime posterior requires a model artifact hash");
        }
        let source = format!("HMM_FORWARD_FILTERED:{model_artifact_sha256}");
        self.hmm_filtered_regime_probabilities = probabilities
            .iter()
            .enumerate()
            .map(|(state, probability)| {
                (
                    format!("raw_state_{state}"),
                    PointInTimeValue::observed(*probability, available_at, source.clone()),
                )
            })
            .collect();
        let entropy = -probabilities
            .iter()
            .filter(|probability| **probability > 0.0)
            .map(|probability| probability * probability.ln())
            .sum::<f64>();
        self.regime_entropy = PointInTimeValue::observed(entropy, available_at, source);
        Ok(self)
    }

    fn validate(&self) -> Result<()> {
        if self.schema_version != MARKET_SNAPSHOT_SCHEMA_VERSION {
            bail!("unsupported MarketSnapshot schema version");
        }
        if self.dataset_version.trim().is_empty() || self.symbol.trim().is_empty() {
            bail!("snapshot dataset version and symbol are required");
        }
        if self.information_available_as_of > self.decision_as_of {
            bail!("snapshot information became available after decision_as_of");
        }
        if self.minute_of_session >= 390 {
            bail!("snapshot minute_of_session must be in 0..390");
        }
        self.source_lineage.validate()?;
        match (&self.correction_of, &self.correction_reason) {
            (None, None) => {}
            (Some(id), Some(reason)) if !id.is_empty() && !reason.trim().is_empty() => {}
            _ => bail!("snapshot correction ID and reason must be supplied together"),
        }
        if self.forward_labels.storage_mode != FORWARD_LABEL_STORAGE_MODE
            || self.forward_labels.required_horizons_minutes != REQUIRED_HORIZONS_MINUTES
        {
            bail!("snapshot forward-label settlement contract is invalid");
        }

        let cutoff = self.information_available_as_of;
        validate_numeric("reference_price", &self.reference_price, cutoff)?;
        if self.reference_price.value.is_none()
            || !self.reference_price.value_observed
            || self.reference_price.value_imputed
            || self.reference_price.value.is_some_and(|value| value <= 0.0)
        {
            bail!("reference price must be a positive observed value");
        }
        for (name, value) in [
            ("return_1m", &self.returns.return_1m),
            ("return_2m", &self.returns.return_2m),
            ("return_3m", &self.returns.return_3m),
            ("return_5m", &self.returns.return_5m),
            ("return_10m", &self.returns.return_10m),
            ("return_15m", &self.returns.return_15m),
            ("return_30m", &self.returns.return_30m),
            ("return_60m", &self.returns.return_60m),
            ("overnight_gap", &self.overnight_gap),
            ("vwap_distance", &self.vwap_distance),
            ("opening_price_distance", &self.opening_price_distance),
            ("previous_close_distance", &self.previous_close_distance),
            ("previous_high_distance", &self.previous_high_distance),
            ("previous_low_distance", &self.previous_low_distance),
            (
                "current_session_range_position",
                &self.current_session_range_position,
            ),
            ("realized_volatility", &self.realized_volatility),
            ("upside_semivariance", &self.upside_semivariance),
            ("downside_semivariance", &self.downside_semivariance),
            ("relative_volume", &self.relative_volume),
            ("volume_acceleration", &self.volume_acceleration),
            ("signed_volume_proxy", &self.signed_volume_proxy),
            ("trade_intensity", &self.trade_intensity),
            ("relative_strength", &self.relative_strength),
            ("breadth_proxy", &self.breadth_proxy),
            ("regime_entropy", &self.regime_entropy),
            ("volatility_percentile", &self.volatility_percentile),
        ] {
            validate_numeric(name, value, cutoff)?;
        }
        if self
            .current_session_range_position
            .value
            .is_some_and(|value| !(0.0..=1.0).contains(&value))
        {
            bail!("current session range position must be in [0,1]");
        }
        if self
            .volatility_percentile
            .value
            .is_some_and(|value| !(0.0..=1.0).contains(&value))
        {
            bail!("volatility percentile must be in [0,1]");
        }
        for (symbol, value) in &self.cross_asset_returns {
            if symbol.trim().is_empty() {
                bail!("cross-asset return has an empty symbol");
            }
            validate_numeric(&format!("cross_asset_returns.{symbol}"), value, cutoff)?;
        }
        let mut probability_sum = 0.0;
        let mut probability_count = 0_usize;
        for (state, value) in &self.hmm_filtered_regime_probabilities {
            if state.trim().is_empty() {
                bail!("HMM probability has an empty state ID");
            }
            validate_numeric(&format!("hmm_probability.{state}"), value, cutoff)?;
            if let Some(probability) = value.value {
                if !(0.0..=1.0).contains(&probability) {
                    bail!("HMM probability must be in [0,1]");
                }
                probability_sum += probability;
                probability_count += 1;
            }
        }
        if probability_count > 0 && (probability_sum - 1.0).abs() > 1.0e-6 {
            bail!("available HMM filtered probabilities must sum to one");
        }
        self.liquidity_state
            .validate_metadata("liquidity_state", cutoff)?;
        self.spread_state
            .validate_metadata("spread_state", cutoff)?;
        self.data_quality_flags
            .validate_metadata("data_quality_flags", cutoff)?;
        self.known_scheduled_event_flags
            .validate_metadata("known_scheduled_event_flags", cutoff)?;
        self.applicable_unscheduled_event_flags
            .validate_metadata("applicable_unscheduled_event_flags", cutoff)?;
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MarketSnapshot {
    pub snapshot_id: String,
    pub content_sha256: String,
    pub lineage_sha256: String,
    #[serde(flatten)]
    pub record: MarketSnapshotRecord,
}

impl MarketSnapshot {
    pub fn finalize(mut record: MarketSnapshotRecord) -> Result<Self> {
        record.source_lineage = record.source_lineage.normalized();
        record.validate()?;
        let lineage_sha256 =
            hash_serializable("market-memory/source-lineage/v1", &record.source_lineage)?;
        let content_sha256 = hash_serializable("market-memory/snapshot-content/v1", &record)?;
        let identity = SnapshotIdentity {
            schema_version: &record.schema_version,
            dataset_version: &record.dataset_version,
            symbol: &record.symbol,
            decision_as_of: record.decision_as_of,
            content_sha256: &content_sha256,
            lineage_sha256: &lineage_sha256,
        };
        let snapshot_id = format!(
            "ms_{}",
            hash_serializable("market-memory/snapshot-id/v1", &identity)?
        );
        Ok(Self {
            snapshot_id,
            content_sha256,
            lineage_sha256,
            record,
        })
    }

    pub fn validate_integrity(&self) -> Result<()> {
        let expected = Self::finalize(self.record.clone())?;
        if self.snapshot_id != expected.snapshot_id
            || self.content_sha256 != expected.content_sha256
            || self.lineage_sha256 != expected.lineage_sha256
        {
            bail!("MarketSnapshot deterministic identity check failed");
        }
        Ok(())
    }
}

#[derive(Serialize)]
struct SnapshotIdentity<'a> {
    schema_version: &'a str,
    dataset_version: &'a str,
    symbol: &'a str,
    decision_as_of: DateTime<Utc>,
    content_sha256: &'a str,
    lineage_sha256: &'a str,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ForwardLabelStatus {
    Complete,
    InvalidDataGap,
    NotApplicableSessionBoundary,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "outcome", rename_all = "SCREAMING_SNAKE_CASE")]
pub enum FirstBarrierHit {
    UpperFirst {
        threshold_return: f64,
        minutes_to_hit: u16,
    },
    LowerFirst {
        threshold_return: f64,
        minutes_to_hit: u16,
    },
    Neither,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ForwardHorizonLabel {
    pub horizon_minutes: u16,
    pub status: ForwardLabelStatus,
    pub terminal_return: PointInTimeValue<f64>,
    pub maximum_favorable_excursion: PointInTimeValue<f64>,
    pub maximum_adverse_excursion: PointInTimeValue<f64>,
    pub first_barrier_hit: PointInTimeValue<FirstBarrierHit>,
    pub future_realized_volatility: PointInTimeValue<f64>,
}

impl ForwardHorizonLabel {
    fn validate(
        &self,
        decision_as_of: DateTime<Utc>,
        settlement_cutoff: DateTime<Utc>,
    ) -> Result<()> {
        if !REQUIRED_HORIZONS_MINUTES.contains(&self.horizon_minutes) {
            bail!("unsupported forward-label horizon");
        }
        self.terminal_return
            .validate_metadata("terminal_return", settlement_cutoff)?;
        self.maximum_favorable_excursion
            .validate_metadata("maximum_favorable_excursion", settlement_cutoff)?;
        self.maximum_adverse_excursion
            .validate_metadata("maximum_adverse_excursion", settlement_cutoff)?;
        self.first_barrier_hit
            .validate_metadata("first_barrier_hit", settlement_cutoff)?;
        self.future_realized_volatility
            .validate_metadata("future_realized_volatility", settlement_cutoff)?;
        for (name, value) in [
            ("terminal_return", &self.terminal_return),
            (
                "maximum_favorable_excursion",
                &self.maximum_favorable_excursion,
            ),
            ("maximum_adverse_excursion", &self.maximum_adverse_excursion),
            (
                "future_realized_volatility",
                &self.future_realized_volatility,
            ),
        ] {
            validate_numeric(name, value, settlement_cutoff)?;
        }
        match self.status {
            ForwardLabelStatus::Complete => {
                for (name, value) in [
                    ("terminal_return", &self.terminal_return),
                    (
                        "maximum_favorable_excursion",
                        &self.maximum_favorable_excursion,
                    ),
                    ("maximum_adverse_excursion", &self.maximum_adverse_excursion),
                    (
                        "future_realized_volatility",
                        &self.future_realized_volatility,
                    ),
                ] {
                    require_observed_label(name, value)?;
                    let earliest =
                        decision_as_of + Duration::minutes(i64::from(self.horizon_minutes));
                    if value
                        .available_at
                        .is_some_and(|available| available < earliest)
                    {
                        bail!("{name} became available before its label horizon ended");
                    }
                }
                if self
                    .maximum_favorable_excursion
                    .value
                    .is_some_and(|value| value < 0.0)
                    || self
                        .maximum_adverse_excursion
                        .value
                        .is_some_and(|value| value < 0.0)
                    || self
                        .future_realized_volatility
                        .value
                        .is_some_and(|value| value < 0.0)
                {
                    bail!("MFE, MAE, and future realized volatility must be non-negative");
                }
                if !self.first_barrier_hit.value_observed || self.first_barrier_hit.value_imputed {
                    bail!("complete first-barrier label must be observed");
                }
                let barrier_available_at = self
                    .first_barrier_hit
                    .available_at
                    .context("complete first-barrier label has no availability timestamp")?;
                match self
                    .first_barrier_hit
                    .value
                    .as_ref()
                    .context("complete first-barrier label is absent")?
                {
                    FirstBarrierHit::UpperFirst {
                        threshold_return,
                        minutes_to_hit,
                    } => {
                        if !threshold_return.is_finite()
                            || *threshold_return <= 0.0
                            || *minutes_to_hit == 0
                            || *minutes_to_hit > self.horizon_minutes
                        {
                            bail!("upper first-hit label is invalid");
                        }
                        let earliest_hit =
                            decision_as_of + Duration::minutes(i64::from(*minutes_to_hit));
                        if barrier_available_at < earliest_hit {
                            bail!("upper first-hit label was available before its stated hit time");
                        }
                    }
                    FirstBarrierHit::LowerFirst {
                        threshold_return,
                        minutes_to_hit,
                    } => {
                        if !threshold_return.is_finite()
                            || *threshold_return >= 0.0
                            || *minutes_to_hit == 0
                            || *minutes_to_hit > self.horizon_minutes
                        {
                            bail!("lower first-hit label is invalid");
                        }
                        let earliest_hit =
                            decision_as_of + Duration::minutes(i64::from(*minutes_to_hit));
                        if barrier_available_at < earliest_hit {
                            bail!("lower first-hit label was available before its stated hit time");
                        }
                    }
                    FirstBarrierHit::Neither => {
                        let horizon_end =
                            decision_as_of + Duration::minutes(i64::from(self.horizon_minutes));
                        if barrier_available_at < horizon_end {
                            bail!("neither-barrier label cannot mature before the horizon ends");
                        }
                    }
                }
            }
            ForwardLabelStatus::InvalidDataGap
            | ForwardLabelStatus::NotApplicableSessionBoundary => {
                if self.terminal_return.value.is_some()
                    || self.maximum_favorable_excursion.value.is_some()
                    || self.maximum_adverse_excursion.value.is_some()
                    || self.first_barrier_hit.value.is_some()
                    || self.future_realized_volatility.value.is_some()
                {
                    bail!("unavailable forward horizon cannot carry realized values");
                }
            }
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct NextSessionForwardLabels {
    pub status: ForwardLabelStatus,
    pub session_date: Option<NaiveDate>,
    pub open_price: PointInTimeValue<f64>,
    pub close_price: PointInTimeValue<f64>,
    pub open_return_from_reference: PointInTimeValue<f64>,
    pub close_return_from_reference: PointInTimeValue<f64>,
}

impl NextSessionForwardLabels {
    fn validate(&self, snapshot: &MarketSnapshot, settlement_cutoff: DateTime<Utc>) -> Result<()> {
        for (name, value) in [
            ("next_session_open_price", &self.open_price),
            ("next_session_close_price", &self.close_price),
            (
                "next_session_open_return_from_reference",
                &self.open_return_from_reference,
            ),
            (
                "next_session_close_return_from_reference",
                &self.close_return_from_reference,
            ),
        ] {
            validate_numeric(name, value, settlement_cutoff)?;
        }
        match self.status {
            ForwardLabelStatus::Complete => {
                let date = self
                    .session_date
                    .context("complete next-session label has no session date")?;
                if date <= snapshot.record.session_date {
                    bail!("next-session label date must follow the snapshot session");
                }
                let open_local = date
                    .and_hms_opt(9, 30, 0)
                    .context("invalid next-session open timestamp")?;
                let earliest_close_local = date
                    .and_hms_opt(13, 0, 0)
                    .context("invalid next-session close timestamp")?;
                let open_available_from = New_York
                    .from_local_datetime(&open_local)
                    .single()
                    .context("ambiguous next-session open timestamp")?
                    .with_timezone(&Utc);
                let close_available_from = New_York
                    .from_local_datetime(&earliest_close_local)
                    .single()
                    .context("ambiguous next-session close timestamp")?
                    .with_timezone(&Utc);
                for (name, value) in [
                    ("next_session_open_price", &self.open_price),
                    ("next_session_close_price", &self.close_price),
                    (
                        "next_session_open_return_from_reference",
                        &self.open_return_from_reference,
                    ),
                    (
                        "next_session_close_return_from_reference",
                        &self.close_return_from_reference,
                    ),
                ] {
                    require_observed_label(name, value)?;
                }
                for (name, value) in [
                    ("next_session_open_price", &self.open_price),
                    (
                        "next_session_open_return_from_reference",
                        &self.open_return_from_reference,
                    ),
                ] {
                    if value
                        .available_at
                        .is_some_and(|available| available < open_available_from)
                    {
                        bail!("{name} became available before the next session opened");
                    }
                }
                for (name, value) in [
                    ("next_session_close_price", &self.close_price),
                    (
                        "next_session_close_return_from_reference",
                        &self.close_return_from_reference,
                    ),
                ] {
                    if value
                        .available_at
                        .is_some_and(|available| available < close_available_from)
                    {
                        bail!("{name} became available before the earliest valid equity close");
                    }
                }
                if self.open_price.value.is_some_and(|value| value <= 0.0)
                    || self.close_price.value.is_some_and(|value| value <= 0.0)
                {
                    bail!("next-session open and close prices must be positive");
                }
                let reference = snapshot
                    .record
                    .reference_price
                    .value
                    .context("snapshot reference price is unavailable")?;
                let open = self
                    .open_price
                    .value
                    .context("next-session open is unavailable")?;
                let close = self
                    .close_price
                    .value
                    .context("next-session close is unavailable")?;
                let open_return = self
                    .open_return_from_reference
                    .value
                    .context("next-session open return is unavailable")?;
                let close_return = self
                    .close_return_from_reference
                    .value
                    .context("next-session close return is unavailable")?;
                if (open_return - (open / reference).ln()).abs() > 1.0e-4
                    || (close_return - (close / reference).ln()).abs() > 1.0e-4
                {
                    bail!("next-session price and log-return labels are inconsistent");
                }
            }
            ForwardLabelStatus::InvalidDataGap
            | ForwardLabelStatus::NotApplicableSessionBoundary => {
                if self.session_date.is_some()
                    || self.open_price.value.is_some()
                    || self.close_price.value.is_some()
                    || self.open_return_from_reference.value.is_some()
                    || self.close_return_from_reference.value.is_some()
                {
                    bail!("unavailable next-session label cannot carry realized values");
                }
            }
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ForwardLabelSettlementRecord {
    pub schema_version: String,
    pub snapshot_id: String,
    pub label_available_at: DateTime<Utc>,
    pub horizons: Vec<ForwardHorizonLabel>,
    pub next_session: NextSessionForwardLabels,
    pub source_lineage: SourceLineage,
    pub correction_of: Option<String>,
    pub correction_reason: Option<String>,
}

impl ForwardLabelSettlementRecord {
    fn validate_internal(&self) -> Result<()> {
        if self.schema_version != FORWARD_LABEL_SCHEMA_VERSION || self.snapshot_id.is_empty() {
            bail!("forward-label schema version or snapshot ID is invalid");
        }
        self.source_lineage.validate()?;
        match (&self.correction_of, &self.correction_reason) {
            (None, None) => {}
            (Some(id), Some(reason)) if !id.is_empty() && !reason.trim().is_empty() => {}
            _ => bail!("label correction ID and reason must be supplied together"),
        }
        let horizons = self
            .horizons
            .iter()
            .map(|label| label.horizon_minutes)
            .collect::<BTreeSet<_>>();
        if horizons != REQUIRED_HORIZONS_MINUTES.into_iter().collect()
            || horizons.len() != self.horizons.len()
        {
            bail!("forward-label settlement must contain exactly 5/15/30/60m horizons");
        }
        Ok(())
    }

    fn validate_for_snapshot(&self, snapshot: &MarketSnapshot) -> Result<()> {
        self.validate_internal()?;
        if self.snapshot_id != snapshot.snapshot_id {
            bail!("forward-label settlement references the wrong snapshot");
        }
        if self.label_available_at < snapshot.record.decision_as_of {
            bail!("forward labels cannot be available before decision_as_of");
        }
        for label in &self.horizons {
            label.validate(snapshot.record.decision_as_of, self.label_available_at)?;
        }
        self.next_session
            .validate(snapshot, self.label_available_at)?;
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ForwardLabelSettlement {
    pub label_settlement_id: String,
    pub content_sha256: String,
    pub lineage_sha256: String,
    #[serde(flatten)]
    pub record: ForwardLabelSettlementRecord,
}

impl ForwardLabelSettlement {
    pub fn finalize(mut record: ForwardLabelSettlementRecord) -> Result<Self> {
        record.source_lineage = record.source_lineage.normalized();
        record.horizons.sort_by_key(|label| label.horizon_minutes);
        record.validate_internal()?;
        let lineage_sha256 = hash_serializable(
            "market-memory/label-source-lineage/v1",
            &record.source_lineage,
        )?;
        let content_sha256 = hash_serializable("market-memory/forward-label-content/v1", &record)?;
        let identity = LabelIdentity {
            schema_version: &record.schema_version,
            snapshot_id: &record.snapshot_id,
            label_available_at: record.label_available_at,
            content_sha256: &content_sha256,
            lineage_sha256: &lineage_sha256,
        };
        let label_settlement_id = format!(
            "ml_{}",
            hash_serializable("market-memory/forward-label-id/v1", &identity)?
        );
        Ok(Self {
            label_settlement_id,
            content_sha256,
            lineage_sha256,
            record,
        })
    }

    pub fn validate_integrity(&self) -> Result<()> {
        let expected = Self::finalize(self.record.clone())?;
        if self.label_settlement_id != expected.label_settlement_id
            || self.content_sha256 != expected.content_sha256
            || self.lineage_sha256 != expected.lineage_sha256
        {
            bail!("ForwardLabelSettlement deterministic identity check failed");
        }
        Ok(())
    }
}

#[derive(Serialize)]
struct LabelIdentity<'a> {
    schema_version: &'a str,
    snapshot_id: &'a str,
    label_available_at: DateTime<Utc>,
    content_sha256: &'a str,
    lineage_sha256: &'a str,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum AppendDisposition {
    Appended,
    CorrectionAppended,
    Duplicate,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AppendOutcome {
    pub record_id: String,
    pub disposition: AppendDisposition,
    pub correction_of: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct MarketMemoryAuditCounts {
    pub snapshot_records: usize,
    pub active_snapshots: usize,
    pub snapshot_corrections: usize,
    pub forward_label_records: usize,
    pub active_forward_label_records: usize,
    pub forward_label_corrections: usize,
    pub pending_active_snapshots: usize,
    pub independent_sessions: usize,
    pub symbols: usize,
    pub duplicate_snapshot_attempts: usize,
    pub duplicate_forward_label_attempts: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MarketMemorySymbolCoverage {
    pub symbol: String,
    pub active_snapshot_count: usize,
    pub independent_sessions: usize,
    pub first_decision_as_of: String,
    pub last_decision_as_of: String,
    pub settled_snapshot_count: usize,
    pub pending_snapshot_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MarketMemoryManifest {
    pub manifest_version: u32,
    pub authoritative_store_format: String,
    pub export_format: String,
    pub export_status: String,
    pub schema_versions: Vec<String>,
    pub dataset_versions: Vec<String>,
    pub symbols: Vec<String>,
    pub first_decision_as_of: Option<DateTime<Utc>>,
    pub last_decision_as_of: Option<DateTime<Utc>>,
    pub snapshot_chain_sha256: String,
    pub forward_label_chain_sha256: String,
    pub manifest_sha256: String,
    pub audit: MarketMemoryAuditCounts,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MarketMemoryReconstruction {
    pub snapshots: Vec<MarketSnapshot>,
    pub forward_label_settlements: Vec<ForwardLabelSettlement>,
    pub manifest: MarketMemoryManifest,
    pub audit: MarketMemoryAuditCounts,
}

pub struct MarketMemoryStore {
    connection: Mutex<Connection>,
}

impl MarketMemoryStore {
    pub fn open(path: &Path) -> Result<Arc<Self>> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        let connection = Connection::open(path)
            .with_context(|| format!("open Market Memory store {}", path.display()))?;
        connection.execute_batch(
            "PRAGMA foreign_keys=ON;
             PRAGMA journal_mode=WAL;
             PRAGMA synchronous=FULL;
             CREATE TABLE IF NOT EXISTS market_snapshots (
               snapshot_id TEXT PRIMARY KEY,
               schema_version TEXT NOT NULL,
               dataset_version TEXT NOT NULL,
               symbol TEXT NOT NULL,
               decision_as_of TEXT NOT NULL,
               information_available_as_of TEXT NOT NULL,
               session_date TEXT NOT NULL,
               minute_of_session INTEGER NOT NULL,
               content_sha256 TEXT NOT NULL UNIQUE,
               lineage_sha256 TEXT NOT NULL,
               correction_of TEXT UNIQUE REFERENCES market_snapshots(snapshot_id),
               appended_at TEXT NOT NULL,
               payload_json TEXT NOT NULL
             );
             CREATE INDEX IF NOT EXISTS idx_market_snapshots_natural_key
               ON market_snapshots(symbol, decision_as_of);
             CREATE TABLE IF NOT EXISTS forward_label_settlements (
               label_settlement_id TEXT PRIMARY KEY,
               snapshot_id TEXT NOT NULL REFERENCES market_snapshots(snapshot_id),
               schema_version TEXT NOT NULL,
               label_available_at TEXT NOT NULL,
               content_sha256 TEXT NOT NULL UNIQUE,
               lineage_sha256 TEXT NOT NULL,
               correction_of TEXT UNIQUE REFERENCES forward_label_settlements(label_settlement_id),
               appended_at TEXT NOT NULL,
               payload_json TEXT NOT NULL
             );
             CREATE INDEX IF NOT EXISTS idx_forward_labels_snapshot
               ON forward_label_settlements(snapshot_id, label_available_at);
             CREATE TABLE IF NOT EXISTS market_memory_append_audit (
               audit_id INTEGER PRIMARY KEY AUTOINCREMENT,
               occurred_at TEXT NOT NULL,
               record_kind TEXT NOT NULL,
               record_id TEXT NOT NULL,
               outcome TEXT NOT NULL,
               detail TEXT NOT NULL
             );
             CREATE TRIGGER IF NOT EXISTS market_snapshots_no_update
               BEFORE UPDATE ON market_snapshots BEGIN
                 SELECT RAISE(ABORT, 'MARKET_MEMORY_APPEND_ONLY');
               END;
             CREATE TRIGGER IF NOT EXISTS market_snapshots_no_delete
               BEFORE DELETE ON market_snapshots BEGIN
                 SELECT RAISE(ABORT, 'MARKET_MEMORY_APPEND_ONLY');
               END;
             CREATE TRIGGER IF NOT EXISTS forward_labels_no_update
               BEFORE UPDATE ON forward_label_settlements BEGIN
                 SELECT RAISE(ABORT, 'MARKET_MEMORY_LABELS_APPEND_ONLY');
               END;
             CREATE TRIGGER IF NOT EXISTS forward_labels_no_delete
               BEFORE DELETE ON forward_label_settlements BEGIN
                 SELECT RAISE(ABORT, 'MARKET_MEMORY_LABELS_APPEND_ONLY');
               END;
             CREATE TRIGGER IF NOT EXISTS market_memory_audit_no_update
               BEFORE UPDATE ON market_memory_append_audit BEGIN
                 SELECT RAISE(ABORT, 'MARKET_MEMORY_AUDIT_APPEND_ONLY');
               END;
             CREATE TRIGGER IF NOT EXISTS market_memory_audit_no_delete
               BEFORE DELETE ON market_memory_append_audit BEGIN
                 SELECT RAISE(ABORT, 'MARKET_MEMORY_AUDIT_APPEND_ONLY');
               END;",
        )?;
        Ok(Arc::new(Self {
            connection: Mutex::new(connection),
        }))
    }

    pub fn append_snapshot(&self, snapshot: &MarketSnapshot) -> Result<AppendOutcome> {
        snapshot.validate_integrity()?;
        let mut connection = self.connection.lock();
        let transaction = connection.transaction_with_behavior(TransactionBehavior::Immediate)?;
        let duplicate = transaction
            .query_row(
                "SELECT snapshot_id FROM market_snapshots
                 WHERE snapshot_id=?1 OR content_sha256=?2 LIMIT 1",
                params![snapshot.snapshot_id, snapshot.content_sha256],
                |row| row.get::<_, String>(0),
            )
            .optional()?;
        if let Some(existing) = duplicate {
            append_audit(
                &transaction,
                "SNAPSHOT",
                &snapshot.snapshot_id,
                "DUPLICATE",
                &format!("matches {existing}"),
            )?;
            transaction.commit()?;
            return Ok(AppendOutcome {
                record_id: existing,
                disposition: AppendDisposition::Duplicate,
                correction_of: snapshot.record.correction_of.clone(),
            });
        }
        let decision = timestamp_text(snapshot.record.decision_as_of);
        let latest = latest_snapshot_id(&transaction, &snapshot.record.symbol, &decision)?;
        validate_correction_target(
            "snapshot",
            latest.as_deref(),
            snapshot.record.correction_of.as_deref(),
        )?;
        transaction.execute(
            "INSERT INTO market_snapshots
             (snapshot_id,schema_version,dataset_version,symbol,decision_as_of,
              information_available_as_of,session_date,minute_of_session,
              content_sha256,lineage_sha256,correction_of,appended_at,payload_json)
             VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13)",
            params![
                snapshot.snapshot_id,
                snapshot.record.schema_version,
                snapshot.record.dataset_version,
                snapshot.record.symbol,
                decision,
                timestamp_text(snapshot.record.information_available_as_of),
                snapshot.record.session_date.to_string(),
                i64::from(snapshot.record.minute_of_session),
                snapshot.content_sha256,
                snapshot.lineage_sha256,
                snapshot.record.correction_of,
                timestamp_text(Utc::now()),
                serde_json::to_string(snapshot)?,
            ],
        )?;
        let disposition = if snapshot.record.correction_of.is_some() {
            AppendDisposition::CorrectionAppended
        } else {
            AppendDisposition::Appended
        };
        append_audit(
            &transaction,
            "SNAPSHOT",
            &snapshot.snapshot_id,
            match disposition {
                AppendDisposition::CorrectionAppended => "CORRECTION_APPENDED",
                _ => "APPENDED",
            },
            snapshot
                .record
                .correction_reason
                .as_deref()
                .unwrap_or("root"),
        )?;
        transaction.commit()?;
        Ok(AppendOutcome {
            record_id: snapshot.snapshot_id.clone(),
            disposition,
            correction_of: snapshot.record.correction_of.clone(),
        })
    }

    pub fn append_forward_labels(
        &self,
        settlement: &ForwardLabelSettlement,
    ) -> Result<AppendOutcome> {
        self.append_forward_labels_at(settlement, Utc::now())
    }

    /// Clock-injectable append entry point used by deterministic replays and
    /// tests. A settlement cannot enter the immutable ledger before every
    /// value it declares has legally matured.
    pub fn append_forward_labels_at(
        &self,
        settlement: &ForwardLabelSettlement,
        appended_at: DateTime<Utc>,
    ) -> Result<AppendOutcome> {
        settlement.validate_integrity()?;
        if appended_at < settlement.record.label_available_at {
            bail!("forward-label settlement cannot be appended before label_available_at");
        }
        let mut connection = self.connection.lock();
        let transaction = connection.transaction_with_behavior(TransactionBehavior::Immediate)?;
        let snapshot_json = transaction
            .query_row(
                "SELECT payload_json FROM market_snapshots WHERE snapshot_id=?1",
                params![settlement.record.snapshot_id],
                |row| row.get::<_, String>(0),
            )
            .optional()?
            .context("forward-label settlement references an unknown snapshot")?;
        let snapshot: MarketSnapshot = serde_json::from_str(&snapshot_json)?;
        snapshot.validate_integrity()?;
        settlement.record.validate_for_snapshot(&snapshot)?;
        let duplicate = transaction
            .query_row(
                "SELECT label_settlement_id FROM forward_label_settlements
                 WHERE label_settlement_id=?1 OR content_sha256=?2 LIMIT 1",
                params![settlement.label_settlement_id, settlement.content_sha256],
                |row| row.get::<_, String>(0),
            )
            .optional()?;
        if let Some(existing) = duplicate {
            append_audit(
                &transaction,
                "FORWARD_LABEL",
                &settlement.label_settlement_id,
                "DUPLICATE",
                &format!("matches {existing}"),
            )?;
            transaction.commit()?;
            return Ok(AppendOutcome {
                record_id: existing,
                disposition: AppendDisposition::Duplicate,
                correction_of: settlement.record.correction_of.clone(),
            });
        }
        let latest = latest_label_id(&transaction, &settlement.record.snapshot_id)?;
        validate_correction_target(
            "forward-label settlement",
            latest.as_deref(),
            settlement.record.correction_of.as_deref(),
        )?;
        transaction.execute(
            "INSERT INTO forward_label_settlements
             (label_settlement_id,snapshot_id,schema_version,label_available_at,
              content_sha256,lineage_sha256,correction_of,appended_at,payload_json)
             VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9)",
            params![
                settlement.label_settlement_id,
                settlement.record.snapshot_id,
                settlement.record.schema_version,
                timestamp_text(settlement.record.label_available_at),
                settlement.content_sha256,
                settlement.lineage_sha256,
                settlement.record.correction_of,
                timestamp_text(appended_at),
                serde_json::to_string(settlement)?,
            ],
        )?;
        let disposition = if settlement.record.correction_of.is_some() {
            AppendDisposition::CorrectionAppended
        } else {
            AppendDisposition::Appended
        };
        append_audit(
            &transaction,
            "FORWARD_LABEL",
            &settlement.label_settlement_id,
            match disposition {
                AppendDisposition::CorrectionAppended => "CORRECTION_APPENDED",
                _ => "APPENDED",
            },
            settlement
                .record
                .correction_reason
                .as_deref()
                .unwrap_or("root"),
        )?;
        transaction.commit()?;
        Ok(AppendOutcome {
            record_id: settlement.label_settlement_id.clone(),
            disposition,
            correction_of: settlement.record.correction_of.clone(),
        })
    }

    pub fn snapshot(&self, snapshot_id: &str) -> Result<Option<MarketSnapshot>> {
        let payload = self
            .connection
            .lock()
            .query_row(
                "SELECT payload_json FROM market_snapshots WHERE snapshot_id=?1",
                params![snapshot_id],
                |row| row.get::<_, String>(0),
            )
            .optional()?;
        payload.map(decode_snapshot).transpose()
    }

    pub fn latest_snapshot(
        &self,
        symbol: &str,
        decision_as_of: DateTime<Utc>,
    ) -> Result<Option<MarketSnapshot>> {
        let payload = self
            .connection
            .lock()
            .query_row(
                "SELECT s.payload_json FROM market_snapshots s
                 WHERE s.symbol=?1 AND s.decision_as_of=?2
                   AND NOT EXISTS (
                     SELECT 1 FROM market_snapshots child
                     WHERE child.correction_of=s.snapshot_id
                   )
                 LIMIT 1",
                params![symbol, timestamp_text(decision_as_of)],
                |row| row.get::<_, String>(0),
            )
            .optional()?;
        payload.map(decode_snapshot).transpose()
    }

    pub fn latest_forward_labels(
        &self,
        snapshot_id: &str,
    ) -> Result<Option<ForwardLabelSettlement>> {
        let payload = self
            .connection
            .lock()
            .query_row(
                "SELECT labels.payload_json FROM forward_label_settlements labels
                 WHERE labels.snapshot_id=?1
                   AND NOT EXISTS (
                     SELECT 1 FROM forward_label_settlements child
                     WHERE child.correction_of=labels.label_settlement_id
                   )
                 LIMIT 1",
                params![snapshot_id],
                |row| row.get::<_, String>(0),
            )
            .optional()?;
        let Some(payload) = payload else {
            return Ok(None);
        };
        let settlement: ForwardLabelSettlement = serde_json::from_str(&payload)?;
        settlement.validate_integrity()?;
        let snapshot = self
            .snapshot(snapshot_id)?
            .context("stored forward labels reference a missing snapshot")?;
        settlement.record.validate_for_snapshot(&snapshot)?;
        Ok(Some(settlement))
    }

    /// Latest active correction leaf across every symbol. This is a bounded
    /// O(1)-row read intended for operational status surfaces.
    pub fn latest_active_snapshot_any(&self) -> Result<Option<MarketSnapshot>> {
        let payload = self
            .connection
            .lock()
            .query_row(
                "SELECT s.payload_json FROM market_snapshots s
                 WHERE NOT EXISTS (
                   SELECT 1 FROM market_snapshots child
                   WHERE child.correction_of=s.snapshot_id
                 )
                 ORDER BY s.decision_as_of DESC,s.rowid DESC
                 LIMIT 1",
                [],
                |row| row.get::<_, String>(0),
            )
            .optional()?;
        payload.map(decode_snapshot).transpose()
    }

    /// Fast aggregate coverage that never deserializes the complete archive.
    /// Full chain verification remains an explicit reconstruction operation.
    pub fn coverage_by_symbol(&self) -> Result<Vec<MarketMemorySymbolCoverage>> {
        let connection = self.connection.lock();
        let mut statement = connection.prepare(
            "SELECT s.symbol,
                    COUNT(*) AS active_snapshots,
                    COUNT(DISTINCT s.session_date) AS sessions,
                    MIN(s.decision_as_of) AS first_as_of,
                    MAX(s.decision_as_of) AS last_as_of,
                    SUM(CASE WHEN EXISTS (
                      SELECT 1 FROM forward_label_settlements labels
                      WHERE labels.snapshot_id=s.snapshot_id
                        AND NOT EXISTS (
                          SELECT 1 FROM forward_label_settlements child_labels
                          WHERE child_labels.correction_of=labels.label_settlement_id
                        )
                    ) THEN 1 ELSE 0 END) AS settled_snapshots
             FROM market_snapshots s
             WHERE NOT EXISTS (
               SELECT 1 FROM market_snapshots child
               WHERE child.correction_of=s.snapshot_id
             )
             GROUP BY s.symbol
             ORDER BY s.symbol",
        )?;
        let rows = statement.query_map([], |row| {
            let active = row.get::<_, i64>(1)? as usize;
            let settled = row.get::<_, i64>(5)? as usize;
            Ok(MarketMemorySymbolCoverage {
                symbol: row.get(0)?,
                active_snapshot_count: active,
                independent_sessions: row.get::<_, i64>(2)? as usize,
                first_decision_as_of: row.get(3)?,
                last_decision_as_of: row.get(4)?,
                settled_snapshot_count: settled,
                pending_snapshot_count: active.saturating_sub(settled),
            })
        })?;
        rows.collect::<rusqlite::Result<Vec<_>>>()
            .map_err(Into::into)
    }

    pub fn audit_counts(&self) -> Result<MarketMemoryAuditCounts> {
        let connection = self.connection.lock();
        let scalar = |sql: &str| -> Result<usize> {
            let value: i64 = connection.query_row(sql, [], |row| row.get(0))?;
            Ok(value as usize)
        };
        Ok(MarketMemoryAuditCounts {
            snapshot_records: scalar("SELECT COUNT(*) FROM market_snapshots")?,
            active_snapshots: scalar(
                "SELECT COUNT(*) FROM market_snapshots s WHERE NOT EXISTS
                 (SELECT 1 FROM market_snapshots child WHERE child.correction_of=s.snapshot_id)",
            )?,
            snapshot_corrections: scalar(
                "SELECT COUNT(*) FROM market_snapshots WHERE correction_of IS NOT NULL",
            )?,
            forward_label_records: scalar("SELECT COUNT(*) FROM forward_label_settlements")?,
            active_forward_label_records: scalar(
                "SELECT COUNT(*) FROM forward_label_settlements labels WHERE NOT EXISTS
                 (SELECT 1 FROM forward_label_settlements child
                  WHERE child.correction_of=labels.label_settlement_id)",
            )?,
            forward_label_corrections: scalar(
                "SELECT COUNT(*) FROM forward_label_settlements
                 WHERE correction_of IS NOT NULL",
            )?,
            pending_active_snapshots: scalar(
                "SELECT COUNT(*) FROM market_snapshots snapshots
                 WHERE NOT EXISTS (
                   SELECT 1 FROM market_snapshots child
                   WHERE child.correction_of=snapshots.snapshot_id
                 ) AND NOT EXISTS (
                   SELECT 1 FROM forward_label_settlements labels
                   WHERE labels.snapshot_id=snapshots.snapshot_id
                     AND NOT EXISTS (
                       SELECT 1 FROM forward_label_settlements child_labels
                       WHERE child_labels.correction_of=labels.label_settlement_id
                     )
                 )",
            )?,
            independent_sessions: scalar(
                "SELECT COUNT(DISTINCT session_date) FROM market_snapshots",
            )?,
            symbols: scalar("SELECT COUNT(DISTINCT symbol) FROM market_snapshots")?,
            duplicate_snapshot_attempts: scalar(
                "SELECT COUNT(*) FROM market_memory_append_audit
                 WHERE record_kind='SNAPSHOT' AND outcome='DUPLICATE'",
            )?,
            duplicate_forward_label_attempts: scalar(
                "SELECT COUNT(*) FROM market_memory_append_audit
                 WHERE record_kind='FORWARD_LABEL' AND outcome='DUPLICATE'",
            )?,
        })
    }

    pub fn manifest(&self) -> Result<MarketMemoryManifest> {
        let (snapshots, labels) = self.load_and_validate_records()?;
        let audit = self.audit_counts()?;
        build_manifest(&snapshots, &labels, audit)
    }

    pub fn reconstruct(&self) -> Result<MarketMemoryReconstruction> {
        let (snapshots, forward_label_settlements) = self.load_and_validate_records()?;
        let audit = self.audit_counts()?;
        let manifest = build_manifest(&snapshots, &forward_label_settlements, audit.clone())?;
        Ok(MarketMemoryReconstruction {
            snapshots,
            forward_label_settlements,
            manifest,
            audit,
        })
    }

    fn load_and_validate_records(
        &self,
    ) -> Result<(Vec<MarketSnapshot>, Vec<ForwardLabelSettlement>)> {
        let connection = self.connection.lock();
        let snapshot_payloads = {
            let mut statement = connection.prepare(
                "SELECT payload_json FROM market_snapshots
                 ORDER BY decision_as_of,symbol,rowid",
            )?;
            statement
                .query_map([], |row| row.get::<_, String>(0))?
                .collect::<rusqlite::Result<Vec<_>>>()?
        };
        let label_payloads = {
            let mut statement = connection.prepare(
                "SELECT payload_json FROM forward_label_settlements
                 ORDER BY label_available_at,snapshot_id,rowid",
            )?;
            statement
                .query_map([], |row| row.get::<_, String>(0))?
                .collect::<rusqlite::Result<Vec<_>>>()?
        };
        drop(connection);

        let snapshots = snapshot_payloads
            .into_iter()
            .map(decode_snapshot)
            .collect::<Result<Vec<_>>>()?;
        let by_id = snapshots
            .iter()
            .map(|snapshot| (snapshot.snapshot_id.clone(), snapshot))
            .collect::<HashMap<_, _>>();
        let mut labels = Vec::with_capacity(label_payloads.len());
        for payload in label_payloads {
            let settlement: ForwardLabelSettlement = serde_json::from_str(&payload)?;
            settlement.validate_integrity()?;
            let snapshot = by_id
                .get(&settlement.record.snapshot_id)
                .context("forward-label reconstruction found an orphan")?;
            settlement.record.validate_for_snapshot(snapshot)?;
            labels.push(settlement);
        }
        Ok((snapshots, labels))
    }
}

fn latest_snapshot_id(
    transaction: &Transaction<'_>,
    symbol: &str,
    decision_as_of: &str,
) -> Result<Option<String>> {
    transaction
        .query_row(
            "SELECT s.snapshot_id FROM market_snapshots s
             WHERE s.symbol=?1 AND s.decision_as_of=?2
               AND NOT EXISTS (
                 SELECT 1 FROM market_snapshots child
                 WHERE child.correction_of=s.snapshot_id
               )
             LIMIT 1",
            params![symbol, decision_as_of],
            |row| row.get(0),
        )
        .optional()
        .map_err(Into::into)
}

fn latest_label_id(transaction: &Transaction<'_>, snapshot_id: &str) -> Result<Option<String>> {
    transaction
        .query_row(
            "SELECT labels.label_settlement_id FROM forward_label_settlements labels
             WHERE labels.snapshot_id=?1
               AND NOT EXISTS (
                 SELECT 1 FROM forward_label_settlements child
                 WHERE child.correction_of=labels.label_settlement_id
               )
             LIMIT 1",
            params![snapshot_id],
            |row| row.get(0),
        )
        .optional()
        .map_err(Into::into)
}

fn validate_correction_target(
    kind: &str,
    current: Option<&str>,
    correction_of: Option<&str>,
) -> Result<()> {
    match (current, correction_of) {
        (None, None) => Ok(()),
        (None, Some(_)) => bail!("{kind} correction target does not exist"),
        (Some(_), None) => bail!("{kind} already exists; append an explicit correction"),
        (Some(latest), Some(target)) if latest == target => Ok(()),
        (Some(_), Some(_)) => bail!("{kind} correction must target the current leaf record"),
    }
}

fn append_audit(
    transaction: &Transaction<'_>,
    kind: &str,
    record_id: &str,
    outcome: &str,
    detail: &str,
) -> Result<()> {
    transaction.execute(
        "INSERT INTO market_memory_append_audit
         (occurred_at,record_kind,record_id,outcome,detail)
         VALUES (?1,?2,?3,?4,?5)",
        params![timestamp_text(Utc::now()), kind, record_id, outcome, detail],
    )?;
    Ok(())
}

fn decode_snapshot(payload: String) -> Result<MarketSnapshot> {
    let snapshot: MarketSnapshot = serde_json::from_str(&payload)?;
    snapshot.validate_integrity()?;
    Ok(snapshot)
}

fn build_manifest(
    snapshots: &[MarketSnapshot],
    labels: &[ForwardLabelSettlement],
    audit: MarketMemoryAuditCounts,
) -> Result<MarketMemoryManifest> {
    let schema_versions = snapshots
        .iter()
        .map(|snapshot| snapshot.record.schema_version.clone())
        .chain(
            labels
                .iter()
                .map(|label| label.record.schema_version.clone()),
        )
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    let dataset_versions = snapshots
        .iter()
        .map(|snapshot| snapshot.record.dataset_version.clone())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    let symbols = snapshots
        .iter()
        .map(|snapshot| snapshot.record.symbol.clone())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect::<Vec<_>>();
    let first_decision_as_of = snapshots
        .iter()
        .map(|snapshot| snapshot.record.decision_as_of)
        .min();
    let last_decision_as_of = snapshots
        .iter()
        .map(|snapshot| snapshot.record.decision_as_of)
        .max();
    let mut snapshot_ids = snapshots
        .iter()
        .map(|snapshot| snapshot.snapshot_id.clone())
        .collect::<Vec<_>>();
    snapshot_ids.sort();
    let mut label_ids = labels
        .iter()
        .map(|label| label.label_settlement_id.clone())
        .collect::<Vec<_>>();
    label_ids.sort();
    let snapshot_chain_sha256 =
        hash_serializable("market-memory/snapshot-chain/v1", &snapshot_ids)?;
    let forward_label_chain_sha256 =
        hash_serializable("market-memory/forward-label-chain/v1", &label_ids)?;
    let body = ManifestBody {
        manifest_version: 1,
        authoritative_store_format: AUTHORITATIVE_STORE_FORMAT,
        export_format: EXPORT_FORMAT,
        export_status: EXPORT_STATUS,
        schema_versions: &schema_versions,
        dataset_versions: &dataset_versions,
        symbols: &symbols,
        first_decision_as_of,
        last_decision_as_of,
        snapshot_chain_sha256: &snapshot_chain_sha256,
        forward_label_chain_sha256: &forward_label_chain_sha256,
        audit: &audit,
    };
    let manifest_sha256 = hash_serializable("market-memory/manifest/v1", &body)?;
    Ok(MarketMemoryManifest {
        manifest_version: 1,
        authoritative_store_format: AUTHORITATIVE_STORE_FORMAT.to_string(),
        export_format: EXPORT_FORMAT.to_string(),
        export_status: EXPORT_STATUS.to_string(),
        schema_versions,
        dataset_versions,
        symbols,
        first_decision_as_of,
        last_decision_as_of,
        snapshot_chain_sha256,
        forward_label_chain_sha256,
        manifest_sha256,
        audit,
    })
}

#[derive(Serialize)]
struct ManifestBody<'a> {
    manifest_version: u32,
    authoritative_store_format: &'a str,
    export_format: &'a str,
    export_status: &'a str,
    schema_versions: &'a [String],
    dataset_versions: &'a [String],
    symbols: &'a [String],
    first_decision_as_of: Option<DateTime<Utc>>,
    last_decision_as_of: Option<DateTime<Utc>>,
    snapshot_chain_sha256: &'a str,
    forward_label_chain_sha256: &'a str,
    audit: &'a MarketMemoryAuditCounts,
}

fn validate_numeric(
    name: &str,
    value: &PointInTimeValue<f64>,
    cutoff: DateTime<Utc>,
) -> Result<()> {
    value.validate_metadata(name, cutoff)?;
    if value.value.is_some_and(|number| !number.is_finite()) {
        bail!("{name} is not finite");
    }
    Ok(())
}

fn require_observed_label(name: &str, value: &PointInTimeValue<f64>) -> Result<()> {
    if value.value.is_none() || !value.value_observed || value.value_imputed {
        bail!("{name} must be a non-imputed observed label");
    }
    Ok(())
}

fn hash_serializable<T: Serialize + ?Sized>(domain: &str, value: &T) -> Result<String> {
    let mut hasher = Sha256::new();
    hasher.update(domain.as_bytes());
    hasher.update([0]);
    hasher.update(serde_json::to_vec(value)?);
    Ok(format!("{:x}", hasher.finalize()))
}

fn timestamp_text(value: DateTime<Utc>) -> String {
    value.to_rfc3339_opts(SecondsFormat::Nanos, true)
}

#[cfg(test)]
mod tests {
    use chrono::{Duration, TimeZone, Utc};
    use tempfile::tempdir;

    use super::*;

    fn state() -> MarketState {
        let timestamp = Utc.with_ymd_and_hms(2026, 7, 21, 15, 10, 0).unwrap();
        MarketState {
            timestamp,
            session_date: NaiveDate::from_ymd_opt(2026, 7, 21).unwrap(),
            symbol: "SPY".to_string(),
            open: 600.0,
            high: 601.0,
            low: 599.5,
            close: 600.5,
            atr: 0.8,
            ret_1m: 0.0002,
            ret_3m: 0.0004,
            ret_5m: 0.0007,
            ret_15m: 0.001,
            ret_30m: -0.0003,
            ret_60m: 0.0015,
            active_5m_return: 0.0002,
            last_completed_5m_return: 0.0005,
            last_completed_15m_return: 0.0008,
            slope_15m: 0.00001,
            dist_vwap: 0.0006,
            dist_session_open: 0.001,
            rolling_realized_vol: 0.0009,
            normalized_range: 0.002,
            upper_wick_ratio: 0.2,
            lower_wick_ratio: 0.2,
            close_location_value: 0.3,
            distance_session_high: -0.0005,
            distance_session_low: 0.002,
            failed_opening_breakout: 0.0,
            consecutive_up_bars: 2,
            consecutive_down_bars: 0,
            return_acceleration: 0.0001,
            volume_zscore: 0.8,
            volume_acceleration: 0.2,
            session_range_position: 0.7,
            cross_asset_breadth_score: 0.5,
            risk_rotation_score: 0.0004,
            market_confirmation_score: 0.5,
            cross_asset_context_complete: true,
            cross_asset_context_coverage: 1.0,
            closing_short_cover_score: 0.0,
            rvol_same_minute: 1.2,
            minutes_from_open: 100,
            minutes_to_close: 290,
            bucket_5m: 20,
            bucket_15m: 6,
            minute_in_5m_bucket: 0,
            completed_5m_bucket_valid: false,
            continuous_minute_count: 1,
        }
    }

    fn lineage(suffix: &str) -> SourceLineage {
        SourceLineage {
            provider: "TEST_VENDOR".to_string(),
            source_version: "fixture-v1".to_string(),
            data_manifest_hash: format!("manifest-{suffix}"),
            source_record_ids: vec![format!("bar-b-{suffix}"), format!("bar-a-{suffix}")],
            availability_semantics: "EVENT_RECEIVE_AVAILABLE".to_string(),
            feature_version: "point-in-time-v3".to_string(),
        }
    }

    fn snapshot() -> MarketSnapshot {
        let state = state();
        let available = state.timestamp + Duration::minutes(1);
        let record = MarketSnapshotRecord::from_market_state(
            &state,
            available,
            available,
            "fixture-dataset-v1",
            lineage("snapshot"),
        )
        .unwrap();
        MarketSnapshot::finalize(record).unwrap()
    }

    #[test]
    fn missing_cross_asset_context_round_trips_differently_from_observed_zero() {
        let mut missing = state();
        missing.cross_asset_context_complete = false;
        missing.cross_asset_context_coverage = 5.0 / 6.0;
        missing.cross_asset_breadth_score = 0.0;
        let available = missing.timestamp + Duration::minutes(1);
        let missing_record = MarketSnapshotRecord::from_market_state(
            &missing,
            available,
            available,
            "fixture-dataset-v1",
            lineage("missing-cross-asset"),
        )
        .unwrap();
        assert!(missing_record.breadth_proxy.value.is_none());
        assert!(!missing_record.breadth_proxy.value_observed);

        let mut observed_zero = missing;
        observed_zero.cross_asset_context_complete = true;
        observed_zero.cross_asset_context_coverage = 1.0;
        let observed_record = MarketSnapshotRecord::from_market_state(
            &observed_zero,
            available,
            available,
            "fixture-dataset-v1",
            lineage("observed-zero-cross-asset"),
        )
        .unwrap();
        assert_eq!(observed_record.breadth_proxy.value, Some(0.0));
        assert!(observed_record.breadth_proxy.value_observed);
    }

    fn complete_horizon(decision: DateTime<Utc>, horizon: u16) -> ForwardHorizonLabel {
        let available = decision + Duration::minutes(i64::from(horizon));
        let observed = |value| PointInTimeValue::observed(value, available, "TEST_LABEL_BARS");
        ForwardHorizonLabel {
            horizon_minutes: horizon,
            status: ForwardLabelStatus::Complete,
            terminal_return: observed(0.0001 * f64::from(horizon)),
            maximum_favorable_excursion: observed(0.002),
            maximum_adverse_excursion: observed(0.001),
            first_barrier_hit: PointInTimeValue::observed(
                FirstBarrierHit::Neither,
                available,
                "TEST_LABEL_BARS",
            ),
            future_realized_volatility: observed(0.0015),
        }
    }

    fn settlement(snapshot: &MarketSnapshot) -> ForwardLabelSettlement {
        let next_date = snapshot.record.session_date.succ_opt().unwrap();
        let next_open = Utc.with_ymd_and_hms(2026, 7, 22, 13, 30, 0).unwrap();
        let next_close = Utc.with_ymd_and_hms(2026, 7, 22, 20, 0, 0).unwrap();
        let record = ForwardLabelSettlementRecord {
            schema_version: FORWARD_LABEL_SCHEMA_VERSION.to_string(),
            snapshot_id: snapshot.snapshot_id.clone(),
            label_available_at: next_close,
            horizons: REQUIRED_HORIZONS_MINUTES
                .into_iter()
                .rev()
                .map(|horizon| complete_horizon(snapshot.record.decision_as_of, horizon))
                .collect(),
            next_session: NextSessionForwardLabels {
                status: ForwardLabelStatus::Complete,
                session_date: Some(next_date),
                open_price: PointInTimeValue::observed(601.0, next_open, "TEST_LABEL_BARS"),
                close_price: PointInTimeValue::observed(602.0, next_close, "TEST_LABEL_BARS"),
                open_return_from_reference: PointInTimeValue::observed(
                    0.0008,
                    next_open,
                    "TEST_LABEL_BARS",
                ),
                close_return_from_reference: PointInTimeValue::observed(
                    0.0025,
                    next_close,
                    "TEST_LABEL_BARS",
                ),
            },
            source_lineage: lineage("labels"),
            correction_of: None,
            correction_reason: None,
        };
        ForwardLabelSettlement::finalize(record).unwrap()
    }

    #[test]
    fn snapshot_identity_is_deterministic_and_missingness_is_explicit() {
        let first = snapshot();
        let second = snapshot();
        assert_eq!(first, second);
        assert!(first.record.returns.return_1m.value_observed);
        assert!(first.record.returns.return_2m.value.is_none());
        assert_eq!(
            first.record.returns.return_2m.original_availability_status,
            "NOT_COMPUTED_BY_MARKET_STATE_POINT_IN_TIME_V3"
        );
        assert!(first.record.overnight_gap.value.is_none());
        assert_eq!(
            first.record.source_lineage.source_record_ids[0],
            "bar-a-snapshot"
        );
        first.validate_integrity().unwrap();

        let mut tampered = first.clone();
        tampered.record.reference_price.value = Some(999.0);
        assert!(tampered.validate_integrity().is_err());
    }

    #[test]
    fn snapshot_rejects_future_availability_and_ambiguous_imputation() {
        let base = snapshot();
        let mut future = base.record.clone();
        future.returns.return_1m.available_at =
            Some(future.information_available_as_of + Duration::seconds(1));
        assert!(MarketSnapshot::finalize(future).is_err());

        let mut ambiguous = base.record;
        ambiguous.returns.return_1m.value_imputed = true;
        assert!(MarketSnapshot::finalize(ambiguous).is_err());
    }

    #[test]
    fn snapshot_attaches_only_normalized_causal_filtered_regime() {
        let base = snapshot();
        let cutoff = base.record.decision_as_of;
        let record = base
            .record
            .clone()
            .with_filtered_regime(&[0.70, 0.20, 0.10], cutoff, "model-sha256")
            .unwrap();
        let finalized = MarketSnapshot::finalize(record).unwrap();
        assert_eq!(finalized.record.hmm_filtered_regime_probabilities.len(), 3);
        assert!(
            finalized
                .record
                .regime_entropy
                .value
                .is_some_and(|value| value > 0.0)
        );
        assert!(
            base.record
                .clone()
                .with_filtered_regime(&[0.8, 0.3], cutoff, "model-sha256")
                .is_err()
        );
        assert!(
            base.record
                .with_filtered_regime(&[0.5, 0.5], cutoff + Duration::seconds(1), "model-sha256")
                .is_err()
        );
    }

    #[test]
    fn store_is_append_only_detects_duplicates_and_reconstructs_corrections() {
        let directory = tempdir().unwrap();
        let store = MarketMemoryStore::open(&directory.path().join("memory.sqlite3")).unwrap();
        let original = snapshot();
        assert_eq!(
            store.append_snapshot(&original).unwrap().disposition,
            AppendDisposition::Appended
        );
        assert_eq!(
            store.append_snapshot(&original).unwrap().disposition,
            AppendDisposition::Duplicate
        );

        let mut corrected_record = original.record.clone();
        corrected_record.correction_of = Some(original.snapshot_id.clone());
        corrected_record.correction_reason = Some("vendor correction".to_string());
        corrected_record.reference_price = PointInTimeValue::observed(
            600.6,
            corrected_record.information_available_as_of,
            "CORRECTED_VENDOR_BAR",
        );
        let corrected = MarketSnapshot::finalize(corrected_record).unwrap();
        assert_eq!(
            store.append_snapshot(&corrected).unwrap().disposition,
            AppendDisposition::CorrectionAppended
        );
        let latest = store
            .latest_snapshot(&original.record.symbol, original.record.decision_as_of)
            .unwrap()
            .unwrap();
        assert_eq!(latest.snapshot_id, corrected.snapshot_id);
        assert_eq!(latest.record.reference_price.value, Some(600.6));

        let reconstruction = store.reconstruct().unwrap();
        assert_eq!(reconstruction.snapshots.len(), 2);
        assert_eq!(reconstruction.audit.snapshot_corrections, 1);
        assert_eq!(reconstruction.audit.active_snapshots, 1);
        assert_eq!(reconstruction.audit.duplicate_snapshot_attempts, 1);
        assert_eq!(reconstruction.audit.pending_active_snapshots, 1);
        assert_eq!(reconstruction.manifest.export_format, "SQLITE");
        assert!(
            reconstruction
                .manifest
                .export_status
                .contains("PARQUET_ARROW_EXPORT_PENDING")
        );
        assert_eq!(store.manifest().unwrap(), store.manifest().unwrap());

        assert!(
            store
                .connection
                .lock()
                .execute(
                    "UPDATE market_snapshots SET symbol='QQQ' WHERE snapshot_id=?1",
                    params![corrected.snapshot_id]
                )
                .is_err()
        );
        assert!(
            store
                .connection
                .lock()
                .execute(
                    "DELETE FROM market_snapshots WHERE snapshot_id=?1",
                    params![corrected.snapshot_id]
                )
                .is_err()
        );
    }

    #[test]
    fn labels_are_separate_append_only_complete_and_correctable() {
        let directory = tempdir().unwrap();
        let store = MarketMemoryStore::open(&directory.path().join("memory.sqlite3")).unwrap();
        let snapshot = snapshot();
        store.append_snapshot(&snapshot).unwrap();
        let original = settlement(&snapshot);
        assert_eq!(
            store
                .append_forward_labels_at(&original, original.record.label_available_at)
                .unwrap()
                .disposition,
            AppendDisposition::Appended
        );
        assert_eq!(
            store
                .append_forward_labels_at(&original, original.record.label_available_at)
                .unwrap()
                .disposition,
            AppendDisposition::Duplicate
        );

        let mut correction_record = original.record.clone();
        correction_record.correction_of = Some(original.label_settlement_id.clone());
        correction_record.correction_reason = Some("late consolidated bar".to_string());
        correction_record.horizons[0].terminal_return.value = Some(0.003);
        let correction = ForwardLabelSettlement::finalize(correction_record).unwrap();
        assert_eq!(
            store
                .append_forward_labels_at(&correction, correction.record.label_available_at)
                .unwrap()
                .disposition,
            AppendDisposition::CorrectionAppended
        );
        let latest = store
            .latest_forward_labels(&snapshot.snapshot_id)
            .unwrap()
            .unwrap();
        assert_eq!(latest.label_settlement_id, correction.label_settlement_id);
        assert_eq!(latest.record.horizons[0].terminal_return.value, Some(0.003));

        let audit = store.audit_counts().unwrap();
        assert_eq!(audit.forward_label_records, 2);
        assert_eq!(audit.active_forward_label_records, 1);
        assert_eq!(audit.forward_label_corrections, 1);
        assert_eq!(audit.duplicate_forward_label_attempts, 1);
        assert_eq!(audit.pending_active_snapshots, 0);
        assert!(
            store
                .append_forward_labels_at(
                    &correction,
                    correction.record.label_available_at - Duration::seconds(1),
                )
                .is_err()
        );
        assert!(
            store
                .connection
                .lock()
                .execute(
                    "UPDATE forward_label_settlements SET schema_version='bad'
                     WHERE label_settlement_id=?1",
                    params![correction.label_settlement_id]
                )
                .is_err()
        );
    }

    #[test]
    fn label_contract_rejects_early_or_incomplete_horizon_sets() {
        let snapshot = snapshot();
        let mut early = settlement(&snapshot).record;
        early.label_available_at = snapshot.record.decision_as_of - Duration::seconds(1);
        let early = ForwardLabelSettlement::finalize(early).unwrap();
        assert!(early.record.validate_for_snapshot(&snapshot).is_err());

        let mut incomplete = settlement(&snapshot).record;
        incomplete.horizons.pop();
        assert!(ForwardLabelSettlement::finalize(incomplete).is_err());
    }
}

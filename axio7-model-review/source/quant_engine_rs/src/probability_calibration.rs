//! Strict point-in-time calibration contract for the analog model's raw
//! probability-up frequency.
//!
//! The predictor deliberately does not fit a calibrator at request time.
//! A separately materialized artifact may be supplied through
//! `AXIO_PROBABILITY_CALIBRATION_ARTIFACT`. Only an artifact whose calibrator
//! fit window precedes an untouched OOS evaluation window, whose OOS window
//! precedes its validity window, and whose lifecycle is `promoted_oos` may
//! change the effective forecast probability.

use std::{env, fs, path::Path};

use anyhow::{Context, Result, bail};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

pub const CALIBRATION_SCHEMA_VERSION: &str = "axio.probability_calibration.v1";
pub const CALIBRATION_ARTIFACT_ENV: &str = "AXIO_PROBABILITY_CALIBRATION_ARTIFACT";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TimePartition {
    pub start: DateTime<Utc>,
    pub end_exclusive: DateTime<Utc>,
}

impl TimePartition {
    fn validate(&self, name: &str) -> Result<()> {
        if self.start >= self.end_exclusive {
            bail!("{name} must have start < end_exclusive");
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ReliabilityBin {
    pub lower_bound: f64,
    pub upper_bound: f64,
    pub sample_count: usize,
    pub mean_predicted_probability: f64,
    pub observed_frequency: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProbabilityEstimateInterval {
    pub estimate: f64,
    pub lower: f64,
    pub upper: f64,
    pub confidence_level: f64,
    pub effective_sample_size: f64,
    pub method: String,
    pub status: String,
    pub semantics: String,
}

impl ProbabilityEstimateInterval {
    pub fn validate(&self) -> Result<()> {
        if !self.estimate.is_finite()
            || !self.lower.is_finite()
            || !self.upper.is_finite()
            || !(0.0..=1.0).contains(&self.estimate)
            || !(0.0..=1.0).contains(&self.lower)
            || !(0.0..=1.0).contains(&self.upper)
            || self.lower > self.estimate
            || self.estimate > self.upper
        {
            bail!("probability estimate interval values must be ordered inside [0, 1]");
        }
        if !self.confidence_level.is_finite() || !(0.0..1.0).contains(&self.confidence_level) {
            bail!("probability estimate interval confidence_level must be in (0, 1)");
        }
        if !self.effective_sample_size.is_finite() || self.effective_sample_size < 1.0 {
            bail!("probability estimate interval effective_sample_size must be at least one");
        }
        if self.method.trim().is_empty()
            || self.status.trim().is_empty()
            || self.semantics.trim().is_empty()
        {
            bail!("probability estimate interval metadata must not be empty");
        }
        Ok(())
    }
}

/// Two-sided 95% Wilson score interval for a binomial proportion.
///
/// `effective_sample_size` may be fractional, which is useful for weighted
/// estimators. Invalid probabilities and effective sample sizes below one fail
/// closed rather than emitting a synthetic interval.
pub fn wilson_score_interval_95(
    estimate: f64,
    effective_sample_size: f64,
) -> Result<ProbabilityEstimateInterval> {
    if !estimate.is_finite() || !(0.0..=1.0).contains(&estimate) {
        bail!("Wilson estimate must be finite and in [0, 1]");
    }
    if !effective_sample_size.is_finite() || effective_sample_size < 1.0 {
        bail!("Wilson effective_sample_size must be finite and at least one");
    }

    const CONFIDENCE_LEVEL: f64 = 0.95;
    const Z_95_TWO_SIDED: f64 = 1.959_963_984_540_054;
    let z_squared = Z_95_TWO_SIDED * Z_95_TWO_SIDED;
    let denominator = 1.0 + z_squared / effective_sample_size;
    let center = (estimate + z_squared / (2.0 * effective_sample_size)) / denominator;
    let half_width = Z_95_TWO_SIDED
        * (estimate * (1.0 - estimate) / effective_sample_size
            + z_squared / (4.0 * effective_sample_size * effective_sample_size))
            .sqrt()
        / denominator;
    let interval = ProbabilityEstimateInterval {
        estimate,
        lower: (center - half_width).clamp(0.0, 1.0),
        upper: (center + half_width).clamp(0.0, 1.0),
        confidence_level: CONFIDENCE_LEVEL,
        effective_sample_size,
        method: "wilson_score".into(),
        status: "AVAILABLE".into(),
        semantics: "BINOMIAL_PROPORTION_95_PERCENT_WILSON_SCORE_SAMPLING_INTERVAL; DOES_NOT_INCLUDE_DRIFT_OR_MODEL_SELECTION_UNCERTAINTY".into(),
    };
    interval.validate()?;
    Ok(interval)
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct OosCalibrationMetrics {
    pub sample_count: usize,
    pub positive_count: usize,
    pub brier_score: f64,
    pub log_loss: f64,
    pub expected_calibration_error: f64,
    pub reliability_bins: Vec<ReliabilityBin>,
}

impl OosCalibrationMetrics {
    fn validate(&self) -> Result<()> {
        if self.sample_count == 0 {
            bail!("OOS calibration metrics require at least one observation");
        }
        if self.positive_count > self.sample_count {
            bail!("positive_count exceeds sample_count");
        }
        if !self.brier_score.is_finite() || !(0.0..=1.0).contains(&self.brier_score) {
            bail!("brier_score must be finite and in [0, 1]");
        }
        if !self.log_loss.is_finite() || self.log_loss < 0.0 {
            bail!("log_loss must be finite and non-negative");
        }
        if !self.expected_calibration_error.is_finite()
            || !(0.0..=1.0).contains(&self.expected_calibration_error)
        {
            bail!("expected_calibration_error must be finite and in [0, 1]");
        }
        let mut previous_upper = 0.0;
        let mut bin_count = 0_usize;
        let mut recomputed_ece = 0.0;
        for (index, bin) in self.reliability_bins.iter().enumerate() {
            if !bin.lower_bound.is_finite()
                || !bin.upper_bound.is_finite()
                || !(0.0..=1.0).contains(&bin.lower_bound)
                || !(0.0..=1.0).contains(&bin.upper_bound)
                || bin.lower_bound >= bin.upper_bound
            {
                bail!("reliability bin {index} has invalid bounds");
            }
            if bin.sample_count == 0 {
                bail!("reliability bin {index} must contain at least one observation");
            }
            if index > 0 && bin.lower_bound < previous_upper {
                bail!("reliability bins overlap or are not ordered");
            }
            if !bin.mean_predicted_probability.is_finite()
                || !(0.0..=1.0).contains(&bin.mean_predicted_probability)
                || !bin.observed_frequency.is_finite()
                || !(0.0..=1.0).contains(&bin.observed_frequency)
            {
                bail!("reliability bin {index} has an invalid probability");
            }
            previous_upper = bin.upper_bound;
            bin_count = bin_count.saturating_add(bin.sample_count);
            recomputed_ece += bin.sample_count as f64 / self.sample_count as f64
                * (bin.mean_predicted_probability - bin.observed_frequency).abs();
        }
        if bin_count != self.sample_count {
            bail!("reliability-bin counts do not equal OOS sample_count");
        }
        if (recomputed_ece - self.expected_calibration_error).abs() > 1.0e-8 {
            bail!("reported ECE does not match reliability bins");
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum CalibrationMethod {
    /// Platt scaling applied to the logit of the raw analog frequency:
    /// sigmoid(slope * logit(raw_probability) + intercept).
    PlattLogit {
        slope: f64,
        intercept: f64,
        input_clip: f64,
    },
    /// Right-continuous isotonic step function. `thresholds` and `values`
    /// must be the same length and both non-decreasing.
    Isotonic {
        thresholds: Vec<f64>,
        values: Vec<f64>,
    },
}

impl CalibrationMethod {
    fn validate(&self) -> Result<()> {
        match self {
            Self::PlattLogit {
                slope,
                intercept,
                input_clip,
            } => {
                if !slope.is_finite() || !intercept.is_finite() || *slope < 0.0 {
                    bail!("Platt slope/intercept must be finite and slope non-negative");
                }
                if !input_clip.is_finite() || *input_clip <= 0.0 || *input_clip >= 0.5 {
                    bail!("Platt input_clip must be finite and in (0, 0.5)");
                }
            }
            Self::Isotonic { thresholds, values } => {
                if thresholds.is_empty() || thresholds.len() != values.len() {
                    bail!("isotonic thresholds/values must have the same non-zero length");
                }
                for index in 0..thresholds.len() {
                    if !thresholds[index].is_finite()
                        || !(0.0..=1.0).contains(&thresholds[index])
                        || !values[index].is_finite()
                        || !(0.0..=1.0).contains(&values[index])
                    {
                        bail!("isotonic knot {index} is outside [0, 1]");
                    }
                    if index > 0
                        && (thresholds[index] <= thresholds[index - 1]
                            || values[index] < values[index - 1])
                    {
                        bail!("isotonic thresholds must increase and values must not decrease");
                    }
                }
            }
        }
        Ok(())
    }

    fn apply(&self, raw_probability: f64) -> f64 {
        match self {
            Self::PlattLogit {
                slope,
                intercept,
                input_clip,
            } => {
                let clipped = raw_probability.clamp(*input_clip, 1.0 - *input_clip);
                let logit = (clipped / (1.0 - clipped)).ln();
                let score = slope * logit + intercept;
                if score >= 0.0 {
                    1.0 / (1.0 + (-score).exp())
                } else {
                    let exponential = score.exp();
                    exponential / (1.0 + exponential)
                }
            }
            Self::Isotonic { thresholds, values } => {
                let index = thresholds
                    .iter()
                    .position(|threshold| raw_probability <= *threshold)
                    .unwrap_or(values.len() - 1);
                values[index]
            }
        }
        .clamp(0.0, 1.0)
    }

    fn name(&self) -> &'static str {
        match self {
            Self::PlattLogit { .. } => "platt_logit",
            Self::Isotonic { .. } => "isotonic",
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum CalibrationLifecycle {
    Candidate,
    OosValidated,
    PromotedOos,
    Retired,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProbabilityCalibrationArtifact {
    pub artifact_id: String,
    pub created_at: DateTime<Utc>,
    pub horizon_minutes: usize,
    pub target_model_id: String,
    pub target_model_hash: String,
    pub feature_version: String,
    pub calibrator_fit_window: TimePartition,
    pub untouched_oos_evaluation_window: TimePartition,
    pub valid_from: DateTime<Utc>,
    pub valid_until: Option<DateTime<Utc>>,
    pub method: CalibrationMethod,
    pub oos_metrics: OosCalibrationMetrics,
    pub lifecycle: CalibrationLifecycle,
}

impl ProbabilityCalibrationArtifact {
    pub fn validate(&self) -> Result<()> {
        if self.artifact_id.trim().is_empty()
            || self.target_model_id.trim().is_empty()
            || self.target_model_hash.trim().is_empty()
            || self.feature_version.trim().is_empty()
        {
            bail!("calibration artifact identities must not be empty");
        }
        if !matches!(self.horizon_minutes, 5 | 15 | 30 | 60) {
            bail!("calibration artifact horizon must be one of 5/15/30/60");
        }
        self.calibrator_fit_window
            .validate("calibrator_fit_window")?;
        self.untouched_oos_evaluation_window
            .validate("untouched_oos_evaluation_window")?;
        if self.calibrator_fit_window.end_exclusive > self.untouched_oos_evaluation_window.start {
            bail!("calibrator fit window overlaps the untouched OOS window");
        }
        if self.untouched_oos_evaluation_window.end_exclusive > self.valid_from {
            bail!("OOS evaluation must finish before valid_from");
        }
        if self.created_at < self.untouched_oos_evaluation_window.end_exclusive {
            bail!("artifact cannot be created before OOS evaluation finishes");
        }
        if self.created_at > self.valid_from {
            bail!("valid_from cannot precede artifact creation");
        }
        if self.valid_until.is_some_and(|end| end <= self.valid_from) {
            bail!("valid_until must be later than valid_from");
        }
        self.method.validate()?;
        self.oos_metrics.validate()?;
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProbabilityCalibrationRegistry {
    pub schema_version: String,
    pub generated_at: DateTime<Utc>,
    pub artifacts: Vec<ProbabilityCalibrationArtifact>,
}

impl ProbabilityCalibrationRegistry {
    pub fn validate(&self) -> Result<()> {
        if self.schema_version != CALIBRATION_SCHEMA_VERSION {
            bail!(
                "unsupported calibration schema {}; expected {}",
                self.schema_version,
                CALIBRATION_SCHEMA_VERSION
            );
        }
        let mut horizons = std::collections::BTreeSet::new();
        for artifact in &self.artifacts {
            artifact.validate()?;
            if !horizons.insert(artifact.horizon_minutes) {
                bail!(
                    "duplicate calibration artifact for horizon {}",
                    artifact.horizon_minutes
                );
            }
            if self.generated_at < artifact.created_at {
                bail!("registry generated_at precedes an artifact created_at");
            }
        }
        Ok(())
    }

    pub fn load(path: &Path) -> Result<Self> {
        let bytes = fs::read(path)
            .with_context(|| format!("read calibration artifact {}", path.display()))?;
        let registry = serde_json::from_slice::<Self>(&bytes)
            .with_context(|| format!("parse calibration artifact {}", path.display()))?;
        registry.validate()?;
        Ok(registry)
    }

    fn artifact_for_horizon(
        &self,
        horizon_minutes: usize,
    ) -> Option<&ProbabilityCalibrationArtifact> {
        self.artifacts
            .iter()
            .find(|artifact| artifact.horizon_minutes == horizon_minutes)
    }
}

#[derive(Debug, Clone)]
pub struct CalibrationRegistrySource {
    registry: Option<ProbabilityCalibrationRegistry>,
    source_status: String,
}

impl CalibrationRegistrySource {
    pub fn from_environment() -> Self {
        let Some(path) = env::var_os(CALIBRATION_ARTIFACT_ENV) else {
            return Self {
                registry: None,
                source_status: "ARTIFACT_NOT_CONFIGURED".into(),
            };
        };
        match ProbabilityCalibrationRegistry::load(Path::new(&path)) {
            Ok(registry) => Self {
                registry: Some(registry),
                source_status: "ARTIFACT_REGISTRY_LOADED".into(),
            },
            Err(error) => Self {
                registry: None,
                source_status: format!("ARTIFACT_LOAD_FAILED:{error:#}"),
            },
        }
    }

    #[cfg(test)]
    fn loaded(registry: ProbabilityCalibrationRegistry) -> Self {
        Self {
            registry: Some(registry),
            source_status: "TEST_REGISTRY_LOADED".into(),
        }
    }

    pub fn evaluate(&self, request: &CalibrationRequest<'_>) -> ProbabilityCalibrationRuntime {
        if !request.raw_analog_up_frequency.is_finite()
            || !(0.0..=1.0).contains(&request.raw_analog_up_frequency)
        {
            return ProbabilityCalibrationRuntime::rejected(
                request.raw_analog_up_frequency,
                "INVALID_RAW_ANALOG_FREQUENCY",
                vec!["RAW_ANALOG_UP_FREQUENCY_MUST_BE_IN_UNIT_INTERVAL".into()],
            );
        }
        let Some(registry) = &self.registry else {
            return ProbabilityCalibrationRuntime::rejected(
                request.raw_analog_up_frequency,
                "CALIBRATION_ARTIFACT_UNAVAILABLE",
                vec![self.source_status.clone()],
            );
        };
        let Some(artifact) = registry.artifact_for_horizon(request.horizon_minutes) else {
            return ProbabilityCalibrationRuntime::rejected(
                request.raw_analog_up_frequency,
                "HORIZON_ARTIFACT_MISSING",
                vec![format!(
                    "NO_CALIBRATION_ARTIFACT_FOR_{}M",
                    request.horizon_minutes
                )],
            );
        };
        let mut reasons = Vec::new();
        if artifact.target_model_id != request.model_id {
            reasons.push("TARGET_MODEL_ID_MISMATCH".into());
        }
        if artifact.target_model_hash != request.model_hash {
            reasons.push("TARGET_MODEL_HASH_MISMATCH".into());
        }
        if artifact.feature_version != request.feature_version {
            reasons.push("FEATURE_VERSION_MISMATCH".into());
        }
        if request.observation_cutoff < artifact.valid_from
            || artifact
                .valid_until
                .is_some_and(|end| request.observation_cutoff >= end)
        {
            reasons.push("ARTIFACT_OUTSIDE_VALIDITY_WINDOW".into());
        }
        if artifact.untouched_oos_evaluation_window.end_exclusive > request.observation_cutoff {
            reasons.push("OOS_EVALUATION_NOT_COMPLETE_AT_OBSERVATION_CUTOFF".into());
        }
        if artifact.lifecycle != CalibrationLifecycle::PromotedOos {
            reasons.push(format!(
                "LIFECYCLE_NOT_PROMOTED_OOS:{:?}",
                artifact.lifecycle
            ));
        }
        if !reasons.is_empty() {
            return ProbabilityCalibrationRuntime {
                status: "CALIBRATION_FAIL_CLOSED".into(),
                artifact_id: Some(artifact.artifact_id.clone()),
                method: Some(artifact.method.name().into()),
                raw_analog_up_frequency: request.raw_analog_up_frequency,
                calibrated_probability_up: None,
                calibrated_probability_up_interval: None,
                eligible_for_probability_use: false,
                oos_metrics: Some(artifact.oos_metrics.clone()),
                reasons,
                probability_semantics: "RAW_ANALOG_FREQUENCY_ONLY; CALIBRATED_PROBABILITY_WITHHELD"
                    .into(),
            };
        }
        let calibrated_probability_up = artifact.method.apply(request.raw_analog_up_frequency);
        let calibrated_probability_up_interval = artifact
            .oos_metrics
            .reliability_bins
            .iter()
            .find(|bin| {
                calibrated_probability_up >= bin.lower_bound
                    && (calibrated_probability_up < bin.upper_bound
                        || (bin.upper_bound >= 1.0
                            && calibrated_probability_up <= bin.upper_bound))
            })
            .and_then(|bin| {
                wilson_score_interval_95(bin.observed_frequency, bin.sample_count as f64).ok()
            })
            .map(|mut interval| {
                interval.status =
                    "AVAILABLE_OOS_RELIABILITY_BIN_SAMPLING_INTERVAL".into();
                interval.semantics = "OOS_RELIABILITY_BIN_OBSERVED_FREQUENCY_95_PERCENT_WILSON_SCORE_SAMPLING_INTERVAL; BIN_SELECTED_BY_CALIBRATED_PROBABILITY_UP; DOES_NOT_INCLUDE_DRIFT_OR_MODEL_SELECTION_UNCERTAINTY".into();
                interval
            });
        ProbabilityCalibrationRuntime {
            status: "PROMOTED_OOS_CALIBRATION_APPLIED".into(),
            artifact_id: Some(artifact.artifact_id.clone()),
            method: Some(artifact.method.name().into()),
            raw_analog_up_frequency: request.raw_analog_up_frequency,
            calibrated_probability_up: Some(calibrated_probability_up),
            calibrated_probability_up_interval,
            eligible_for_probability_use: true,
            oos_metrics: Some(artifact.oos_metrics.clone()),
            reasons: Vec::new(),
            probability_semantics: "PROMOTED_OOS_CALIBRATOR_APPLIED_TO_RAW_ANALOG_UP_FREQUENCY"
                .into(),
        }
    }
}

pub struct CalibrationRequest<'a> {
    pub horizon_minutes: usize,
    pub observation_cutoff: DateTime<Utc>,
    pub raw_analog_up_frequency: f64,
    pub model_id: &'a str,
    pub model_hash: &'a str,
    pub feature_version: &'a str,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProbabilityCalibrationRuntime {
    pub status: String,
    pub artifact_id: Option<String>,
    pub method: Option<String>,
    pub raw_analog_up_frequency: f64,
    pub calibrated_probability_up: Option<f64>,
    #[serde(default)]
    pub calibrated_probability_up_interval: Option<ProbabilityEstimateInterval>,
    pub eligible_for_probability_use: bool,
    pub oos_metrics: Option<OosCalibrationMetrics>,
    pub reasons: Vec<String>,
    pub probability_semantics: String,
}

impl ProbabilityCalibrationRuntime {
    pub fn unavailable(raw_analog_up_frequency: f64) -> Self {
        Self::rejected(
            raw_analog_up_frequency,
            "CALIBRATION_NOT_EVALUATED",
            vec!["NO_RUNTIME_CALIBRATION_EVALUATION".into()],
        )
    }

    fn rejected(raw_analog_up_frequency: f64, status: &str, reasons: Vec<String>) -> Self {
        Self {
            status: status.into(),
            artifact_id: None,
            method: None,
            raw_analog_up_frequency,
            calibrated_probability_up: None,
            calibrated_probability_up_interval: None,
            eligible_for_probability_use: false,
            oos_metrics: None,
            reasons,
            probability_semantics: "RAW_ANALOG_FREQUENCY_ONLY; CALIBRATED_PROBABILITY_WITHHELD"
                .into(),
        }
    }
}

impl Default for ProbabilityCalibrationRuntime {
    fn default() -> Self {
        Self::unavailable(0.0)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CalibrationObservation {
    pub observation_cutoff: DateTime<Utc>,
    pub horizon_minutes: usize,
    pub raw_probability_up: f64,
    pub outcome_up: bool,
    pub model_id: String,
    pub model_hash: String,
    pub feature_version: String,
}

// This input contract does not record vendor label availability. A horizon
// establishes only the earliest possible maturity, not proof of point-in-time
// availability. Never let even that theoretical label window cross a partition.
fn estimated_label_maturity(row: &CalibrationObservation) -> Result<DateTime<Utc>> {
    if !matches!(row.horizon_minutes, 5 | 15 | 30 | 60) {
        bail!("calibration observation horizon must be one of 5/15/30/60");
    }
    row.observation_cutoff
        .checked_add_signed(chrono::Duration::minutes(row.horizon_minutes as i64))
        .context("calibration label maturity exceeds the timestamp range")
}

fn calibration_method_partitions<'a, 'b>(
    fit: &'b [&'a CalibrationObservation],
) -> Result<(
    Vec<&'a CalibrationObservation>,
    &'b [&'a CalibrationObservation],
)> {
    if fit.len() < 100 {
        bail!("calibration method selection needs at least 100 mature fit observations");
    }
    let selection_size = (fit.len() / 5).max(25).min(fit.len() - 50);
    let split = fit.len() - selection_size;
    let selection = &fit[split..];
    let selection_start = selection[0].observation_cutoff;
    let mut method_fit = Vec::new();
    for row in &fit[..split] {
        if estimated_label_maturity(row)? <= selection_start {
            method_fit.push(*row);
        }
    }
    if method_fit.len() < 50 {
        bail!("calibration method selection needs at least 50 fit labels mature before selection");
    }
    Ok((method_fit, selection))
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CalibrationHorizonBuild {
    pub horizon_minutes: usize,
    pub fit_samples: usize,
    pub selection_samples: usize,
    pub untouched_oos_samples: usize,
    pub selected_method: String,
    pub selection_platt_log_loss: f64,
    pub selection_isotonic_log_loss: f64,
    pub lifecycle: CalibrationLifecycle,
    pub promotion_eligible: bool,
    pub gates: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CalibrationBuildReport {
    pub schema_version: String,
    pub generated_at: DateTime<Utc>,
    pub registry: ProbabilityCalibrationRegistry,
    pub horizons: Vec<CalibrationHorizonBuild>,
    pub promotion_policy: String,
}

fn clipped_logit(probability: f64, clip: f64) -> f64 {
    let value = probability.clamp(clip, 1.0 - clip);
    (value / (1.0 - value)).ln()
}

fn sigmoid(value: f64) -> f64 {
    if value >= 0.0 {
        1.0 / (1.0 + (-value).exp())
    } else {
        let exponential = value.exp();
        exponential / (1.0 + exponential)
    }
}

fn binary_target(value: bool) -> f64 {
    if value { 1.0 } else { 0.0 }
}

fn fit_platt(rows: &[&CalibrationObservation]) -> CalibrationMethod {
    const CLIP: f64 = 1.0e-5;
    let positive_rate =
        rows.iter().filter(|row| row.outcome_up).count() as f64 / rows.len().max(1) as f64;
    let mut slope = 1.0;
    let mut intercept = clipped_logit(positive_rate, CLIP);
    if positive_rate <= 0.0 || positive_rate >= 1.0 {
        slope = 0.0;
    } else {
        for iteration in 0..2_000 {
            let learning_rate = 0.08 / (1.0 + iteration as f64 * 0.002);
            let mut slope_gradient = 0.0;
            let mut intercept_gradient = 0.0;
            for row in rows {
                let input = clipped_logit(row.raw_probability_up, CLIP);
                let target = binary_target(row.outcome_up);
                let error = sigmoid(slope * input + intercept) - target;
                slope_gradient += error * input;
                intercept_gradient += error;
            }
            let count = rows.len().max(1) as f64;
            slope = (slope - learning_rate * (slope_gradient / count + 1.0e-4 * slope))
                .clamp(0.0, 20.0);
            intercept = (intercept - learning_rate * intercept_gradient / count).clamp(-20.0, 20.0);
        }
    }
    CalibrationMethod::PlattLogit {
        slope,
        intercept,
        input_clip: CLIP,
    }
}

#[derive(Debug, Clone)]
struct IsotonicBlock {
    minimum_x: f64,
    maximum_x: f64,
    positive_sum: f64,
    weight: usize,
}

impl IsotonicBlock {
    fn value(&self) -> f64 {
        self.positive_sum / self.weight.max(1) as f64
    }
}

fn fit_isotonic(rows: &[&CalibrationObservation]) -> CalibrationMethod {
    let mut sorted = rows.to_vec();
    sorted.sort_by(|left, right| {
        left.raw_probability_up
            .total_cmp(&right.raw_probability_up)
            .then_with(|| left.observation_cutoff.cmp(&right.observation_cutoff))
    });
    let mut blocks = Vec::<IsotonicBlock>::new();
    for row in sorted {
        let x = row.raw_probability_up.clamp(0.0, 1.0);
        if let Some(last) = blocks.last_mut().filter(|last| last.maximum_x == x) {
            last.positive_sum += binary_target(row.outcome_up);
            last.weight += 1;
        } else {
            blocks.push(IsotonicBlock {
                minimum_x: x,
                maximum_x: x,
                positive_sum: binary_target(row.outcome_up),
                weight: 1,
            });
        }
        while blocks.len() >= 2 {
            let length = blocks.len();
            if blocks[length - 2].value() <= blocks[length - 1].value() {
                break;
            }
            let right = blocks.pop().expect("right isotonic block");
            let left = blocks.pop().expect("left isotonic block");
            blocks.push(IsotonicBlock {
                minimum_x: left.minimum_x,
                maximum_x: right.maximum_x,
                positive_sum: left.positive_sum + right.positive_sum,
                weight: left.weight + right.weight,
            });
        }
    }
    let mut thresholds = blocks
        .iter()
        .map(|block| block.maximum_x)
        .collect::<Vec<_>>();
    let values = blocks.iter().map(IsotonicBlock::value).collect::<Vec<_>>();
    // Right-continuous application needs the final interval to include one.
    if let Some(last) = thresholds.last_mut() {
        *last = 1.0;
    }
    CalibrationMethod::Isotonic { thresholds, values }
}

fn binary_log_loss(method: &CalibrationMethod, rows: &[&CalibrationObservation]) -> f64 {
    rows.iter()
        .map(|row| {
            let probability = method
                .apply(row.raw_probability_up)
                .clamp(1.0e-12, 1.0 - 1.0e-12);
            if row.outcome_up {
                -probability.ln()
            } else {
                -(1.0 - probability).ln()
            }
        })
        .sum::<f64>()
        / rows.len().max(1) as f64
}

fn calibration_metrics(
    method: &CalibrationMethod,
    rows: &[&CalibrationObservation],
) -> OosCalibrationMetrics {
    let probabilities = rows
        .iter()
        .map(|row| method.apply(row.raw_probability_up))
        .collect::<Vec<_>>();
    let sample_count = rows.len();
    let positive_count = rows.iter().filter(|row| row.outcome_up).count();
    let brier_score = probabilities
        .iter()
        .zip(rows)
        .map(|(probability, row)| (probability - binary_target(row.outcome_up)).powi(2))
        .sum::<f64>()
        / sample_count.max(1) as f64;
    let log_loss = probabilities
        .iter()
        .zip(rows)
        .map(|(probability, row)| {
            let probability = probability.clamp(1.0e-12, 1.0 - 1.0e-12);
            if row.outcome_up {
                -probability.ln()
            } else {
                -(1.0 - probability).ln()
            }
        })
        .sum::<f64>()
        / sample_count.max(1) as f64;
    let mut reliability_bins = Vec::new();
    for index in 0..10 {
        let lower = index as f64 / 10.0;
        let upper = (index + 1) as f64 / 10.0;
        let members = probabilities
            .iter()
            .zip(rows)
            .filter(|(probability, _)| {
                if index == 9 {
                    **probability >= lower && **probability <= upper
                } else {
                    **probability >= lower && **probability < upper
                }
            })
            .collect::<Vec<_>>();
        if members.is_empty() {
            continue;
        }
        reliability_bins.push(ReliabilityBin {
            lower_bound: lower,
            upper_bound: upper,
            sample_count: members.len(),
            mean_predicted_probability: members
                .iter()
                .map(|(probability, _)| **probability)
                .sum::<f64>()
                / members.len() as f64,
            observed_frequency: members.iter().filter(|(_, row)| row.outcome_up).count() as f64
                / members.len() as f64,
        });
    }
    let expected_calibration_error = reliability_bins
        .iter()
        .map(|bin| {
            bin.sample_count as f64 / sample_count.max(1) as f64
                * (bin.mean_predicted_probability - bin.observed_frequency).abs()
        })
        .sum();
    OosCalibrationMetrics {
        sample_count,
        positive_count,
        brier_score,
        log_loss,
        expected_calibration_error,
        reliability_bins,
    }
}

pub fn materialize_oos_calibration_registry(
    observations: &[CalibrationObservation],
    fit_window: TimePartition,
    untouched_oos_window: TimePartition,
    valid_from: DateTime<Utc>,
    minimum_oos_samples: usize,
    maximum_ece: f64,
) -> Result<CalibrationBuildReport> {
    fit_window.validate("fit_window")?;
    untouched_oos_window.validate("untouched_oos_window")?;
    if fit_window.end_exclusive > untouched_oos_window.start {
        bail!("calibrator fit window overlaps untouched OOS evaluation");
    }
    if untouched_oos_window.end_exclusive > valid_from {
        bail!("valid_from must follow the untouched OOS evaluation window");
    }
    if minimum_oos_samples < 50 || !maximum_ece.is_finite() || !(0.0..=0.25).contains(&maximum_ece)
    {
        bail!("calibration promotion gates are invalid");
    }
    let created_at = Utc::now();
    if created_at > valid_from {
        bail!("valid_from must not precede artifact creation");
    }
    let mut artifacts = Vec::new();
    let mut horizon_reports = Vec::new();
    for horizon in [5, 15, 30, 60] {
        let mut rows = observations
            .iter()
            .filter(|row| row.horizon_minutes == horizon)
            .map(|row| estimated_label_maturity(row).map(|maturity| (row, maturity)))
            .collect::<Result<Vec<_>>>()?;
        rows.sort_by_key(|(row, _)| row.observation_cutoff);
        let fit = rows
            .iter()
            .filter(|(row, maturity)| {
                row.observation_cutoff >= fit_window.start
                    && row.observation_cutoff < fit_window.end_exclusive
                    && *maturity <= fit_window.end_exclusive
            })
            .map(|(row, _)| *row)
            .collect::<Vec<_>>();
        let oos = rows
            .iter()
            .filter(|(row, maturity)| {
                row.observation_cutoff >= untouched_oos_window.start
                    && row.observation_cutoff < untouched_oos_window.end_exclusive
                    && *maturity <= untouched_oos_window.end_exclusive
            })
            .map(|(row, _)| *row)
            .collect::<Vec<_>>();
        if fit.len() < 100 || oos.len() < 50 {
            bail!(
                "horizon {horizon} needs at least 100 fit and 50 untouched OOS observations with labels mature within their partition"
            );
        }
        if fit.iter().chain(&oos).any(|row| {
            !row.raw_probability_up.is_finite()
                || !(0.0..=1.0).contains(&row.raw_probability_up)
                || row.model_id.trim().is_empty()
                || row.model_hash.trim().is_empty()
                || row.feature_version.trim().is_empty()
        }) {
            bail!("horizon {horizon} contains an invalid OOF observation");
        }
        let identities = fit
            .iter()
            .chain(&oos)
            .map(|row| (&row.model_id, &row.model_hash, &row.feature_version))
            .collect::<std::collections::BTreeSet<_>>();
        if identities.len() != 1 {
            bail!("horizon {horizon} mixes model/feature identities");
        }
        let (method_fit, selection) = calibration_method_partitions(&fit)?;
        let platt_candidate = fit_platt(&method_fit);
        let isotonic_candidate = fit_isotonic(&method_fit);
        let platt_loss = binary_log_loss(&platt_candidate, selection);
        let isotonic_loss = binary_log_loss(&isotonic_candidate, selection);
        let selected_name = if isotonic_loss + 1.0e-12 < platt_loss {
            "isotonic"
        } else {
            "platt_logit"
        };
        let method = if selected_name == "isotonic" {
            fit_isotonic(&fit)
        } else {
            fit_platt(&fit)
        };
        let metrics = calibration_metrics(&method, &oos);
        let positive_rate = metrics.positive_count as f64 / metrics.sample_count as f64;
        let baseline_brier = positive_rate * (1.0 - positive_rate);
        let mut gates = Vec::new();
        if metrics.sample_count < minimum_oos_samples {
            gates.push(format!(
                "OOS_SAMPLE_COUNT_BELOW_GATE:{}/{}",
                metrics.sample_count, minimum_oos_samples
            ));
        }
        if metrics.positive_count < 20
            || metrics.sample_count.saturating_sub(metrics.positive_count) < 20
        {
            gates.push("OOS_CLASS_SUPPORT_BELOW_20".to_string());
        }
        if metrics.expected_calibration_error > maximum_ece {
            gates.push(format!(
                "OOS_ECE_ABOVE_GATE:{:.6}>{maximum_ece:.6}",
                metrics.expected_calibration_error
            ));
        }
        if metrics.brier_score >= baseline_brier {
            gates.push(format!(
                "OOS_BRIER_NOT_BETTER_THAN_UNCONDITIONAL:{:.6}>={baseline_brier:.6}",
                metrics.brier_score
            ));
        }
        let lifecycle = if gates.is_empty() {
            CalibrationLifecycle::OosValidated
        } else {
            CalibrationLifecycle::Candidate
        };
        let identity = identities
            .iter()
            .next()
            .context("calibration identity missing")?;
        let artifact_material = serde_json::to_vec(&json_identity(
            horizon,
            identity.0,
            identity.1,
            identity.2,
            &fit_window,
            &untouched_oos_window,
            &method,
        ))?;
        let artifact_id = format!(
            "calibration-{horizon}-{}",
            &format!("{:x}", Sha256::digest(artifact_material))[..20]
        );
        artifacts.push(ProbabilityCalibrationArtifact {
            artifact_id,
            created_at,
            horizon_minutes: horizon,
            target_model_id: (*identity.0).clone(),
            target_model_hash: (*identity.1).clone(),
            feature_version: (*identity.2).clone(),
            calibrator_fit_window: fit_window.clone(),
            untouched_oos_evaluation_window: untouched_oos_window.clone(),
            valid_from,
            valid_until: None,
            method,
            oos_metrics: metrics,
            lifecycle,
        });
        horizon_reports.push(CalibrationHorizonBuild {
            horizon_minutes: horizon,
            fit_samples: method_fit.len(),
            selection_samples: selection.len(),
            untouched_oos_samples: oos.len(),
            selected_method: selected_name.to_string(),
            selection_platt_log_loss: platt_loss,
            selection_isotonic_log_loss: isotonic_loss,
            lifecycle,
            promotion_eligible: false,
            gates,
        });
    }
    let registry = ProbabilityCalibrationRegistry {
        schema_version: CALIBRATION_SCHEMA_VERSION.to_string(),
        generated_at: created_at,
        artifacts,
    };
    registry.validate()?;
    Ok(CalibrationBuildReport {
        schema_version: "axio.probability_calibration_build.v1".to_string(),
        generated_at: created_at,
        registry,
        horizons: horizon_reports,
        promotion_policy: "Materialization may reach oos_validated only. promoted_oos requires a separate locked forward-shadow governance action; serving rejects candidate/oos_validated artifacts. Partition and method-selection boundaries purge labels using observation_cutoff + horizon as estimated earliest maturity; actual vendor label availability is not supplied and full point-in-time lineage is not established.".to_string(),
    })
}

fn json_identity(
    horizon: usize,
    model_id: &str,
    model_hash: &str,
    feature_version: &str,
    fit: &TimePartition,
    oos: &TimePartition,
    method: &CalibrationMethod,
) -> serde_json::Value {
    serde_json::json!({
        "horizon":horizon,
        "model_id":model_id,
        "model_hash":model_hash,
        "feature_version":feature_version,
        "fit":fit,
        "oos":oos,
        "method":method
    })
}

#[cfg(test)]
mod tests {
    use chrono::{Duration, TimeZone};

    use super::*;

    fn metrics() -> OosCalibrationMetrics {
        OosCalibrationMetrics {
            sample_count: 100,
            positive_count: 50,
            brier_score: 0.2,
            log_loss: 0.6,
            expected_calibration_error: 0.1,
            reliability_bins: vec![
                ReliabilityBin {
                    lower_bound: 0.0,
                    upper_bound: 0.5,
                    sample_count: 50,
                    mean_predicted_probability: 0.3,
                    observed_frequency: 0.2,
                },
                ReliabilityBin {
                    lower_bound: 0.5,
                    upper_bound: 1.0,
                    sample_count: 50,
                    mean_predicted_probability: 0.7,
                    observed_frequency: 0.6,
                },
            ],
        }
    }

    fn artifact(method: CalibrationMethod) -> ProbabilityCalibrationArtifact {
        let origin = Utc.with_ymd_and_hms(2026, 1, 1, 0, 0, 0).unwrap();
        ProbabilityCalibrationArtifact {
            artifact_id: "cal-15m-v1".into(),
            created_at: origin + Duration::days(31),
            horizon_minutes: 15,
            target_model_id: "model-v1".into(),
            target_model_hash: "hash-v1".into(),
            feature_version: "features-v1".into(),
            calibrator_fit_window: TimePartition {
                start: origin,
                end_exclusive: origin + Duration::days(10),
            },
            untouched_oos_evaluation_window: TimePartition {
                start: origin + Duration::days(10),
                end_exclusive: origin + Duration::days(20),
            },
            valid_from: origin + Duration::days(31),
            valid_until: None,
            method,
            oos_metrics: metrics(),
            lifecycle: CalibrationLifecycle::PromotedOos,
        }
    }

    fn source(artifact: ProbabilityCalibrationArtifact) -> CalibrationRegistrySource {
        CalibrationRegistrySource::loaded(ProbabilityCalibrationRegistry {
            schema_version: CALIBRATION_SCHEMA_VERSION.into(),
            generated_at: artifact.created_at,
            artifacts: vec![artifact],
        })
    }

    fn request<'a>(at: DateTime<Utc>) -> CalibrationRequest<'a> {
        CalibrationRequest {
            horizon_minutes: 15,
            observation_cutoff: at,
            raw_analog_up_frequency: 0.8,
            model_id: "model-v1",
            model_hash: "hash-v1",
            feature_version: "features-v1",
        }
    }

    #[test]
    fn wilson_interval_accepts_fractional_effective_sample_size() {
        let interval = wilson_score_interval_95(0.4, 12.5).unwrap();
        assert_eq!(interval.estimate, 0.4);
        assert_eq!(interval.confidence_level, 0.95);
        assert_eq!(interval.effective_sample_size, 12.5);
        assert!(interval.lower < interval.estimate);
        assert!(interval.upper > interval.estimate);
        assert_eq!(interval.method, "wilson_score");
        assert!(interval.validate().is_ok());

        let serialized = serde_json::to_value(&interval).unwrap();
        assert_eq!(serialized["effective_sample_size"], 12.5);
        assert_eq!(serialized["status"], "AVAILABLE");
    }

    #[test]
    fn wilson_interval_rejects_invalid_probability_and_effective_sample() {
        assert!(wilson_score_interval_95(f64::NAN, 20.0).is_err());
        assert!(wilson_score_interval_95(-0.01, 20.0).is_err());
        assert!(wilson_score_interval_95(1.01, 20.0).is_err());
        assert!(wilson_score_interval_95(0.5, f64::NAN).is_err());
        assert!(wilson_score_interval_95(0.5, 0.999).is_err());
    }

    #[test]
    fn reliability_bins_reject_zero_sample_membership() {
        let mut invalid = metrics();
        invalid.reliability_bins[0].sample_count = 0;
        assert!(invalid.validate().is_err());
    }

    #[test]
    fn platt_artifact_applies_only_after_strict_oos_boundary() {
        let origin = Utc.with_ymd_and_hms(2026, 1, 1, 0, 0, 0).unwrap();
        let source = source(artifact(CalibrationMethod::PlattLogit {
            slope: 0.5,
            intercept: 0.0,
            input_clip: 1.0e-6,
        }));
        let runtime = source.evaluate(&request(origin + Duration::days(40)));
        assert!(runtime.eligible_for_probability_use);
        assert_eq!(runtime.status, "PROMOTED_OOS_CALIBRATION_APPLIED");
        let calibrated = runtime.calibrated_probability_up.unwrap();
        assert!(calibrated > 0.5 && calibrated < 0.8);
        let interval = runtime.calibrated_probability_up_interval.unwrap();
        assert_eq!(interval.estimate, 0.6);
        assert_eq!(interval.effective_sample_size, 50.0);
        assert!(interval.lower < interval.estimate);
        assert!(interval.upper > interval.estimate);
        assert_eq!(
            interval.status,
            "AVAILABLE_OOS_RELIABILITY_BIN_SAMPLING_INTERVAL"
        );
        assert!(
            interval
                .semantics
                .contains("DOES_NOT_INCLUDE_DRIFT_OR_MODEL_SELECTION_UNCERTAINTY")
        );
    }

    #[test]
    fn reliability_interval_uses_calibrated_probability_bin_coordinates() {
        let origin = Utc.with_ymd_and_hms(2026, 1, 1, 0, 0, 0).unwrap();
        let mut promoted = artifact(CalibrationMethod::PlattLogit {
            slope: 0.5,
            intercept: 0.0,
            input_clip: 1.0e-6,
        });
        promoted.oos_metrics = OosCalibrationMetrics {
            sample_count: 100,
            positive_count: 67,
            brier_score: 0.2,
            log_loss: 0.6,
            expected_calibration_error: 0.08,
            reliability_bins: vec![
                ReliabilityBin {
                    lower_bound: 0.6,
                    upper_bound: 0.7,
                    sample_count: 50,
                    mean_predicted_probability: 0.65,
                    observed_frequency: 0.54,
                },
                ReliabilityBin {
                    lower_bound: 0.8,
                    upper_bound: 0.9,
                    sample_count: 50,
                    mean_predicted_probability: 0.85,
                    observed_frequency: 0.8,
                },
            ],
        };
        assert!(promoted.validate().is_ok());

        let runtime = source(promoted).evaluate(&request(origin + Duration::days(40)));
        let calibrated = runtime.calibrated_probability_up.unwrap();
        assert!((calibrated - (2.0 / 3.0)).abs() < 1.0e-12);
        let interval = runtime.calibrated_probability_up_interval.unwrap();
        assert_eq!(interval.estimate, 0.54);
        assert_eq!(interval.effective_sample_size, 50.0);
        assert!(
            interval
                .semantics
                .contains("BIN_SELECTED_BY_CALIBRATED_PROBABILITY_UP")
        );
    }

    #[test]
    fn non_promoted_artifact_fails_closed() {
        let origin = Utc.with_ymd_and_hms(2026, 1, 1, 0, 0, 0).unwrap();
        let mut candidate = artifact(CalibrationMethod::Isotonic {
            thresholds: vec![0.5, 1.0],
            values: vec![0.4, 0.6],
        });
        candidate.lifecycle = CalibrationLifecycle::OosValidated;
        let runtime = source(candidate).evaluate(&request(origin + Duration::days(40)));
        assert!(!runtime.eligible_for_probability_use);
        assert!(runtime.calibrated_probability_up.is_none());
        assert!(runtime.calibrated_probability_up_interval.is_none());
        assert!(
            runtime
                .reasons
                .iter()
                .any(|reason| reason.starts_with("LIFECYCLE_NOT_PROMOTED_OOS"))
        );
    }

    #[test]
    fn promoted_artifact_without_matching_reliability_bin_withholds_interval() {
        let origin = Utc.with_ymd_and_hms(2026, 1, 1, 0, 0, 0).unwrap();
        let mut promoted = artifact(CalibrationMethod::Isotonic {
            thresholds: vec![0.5, 1.0],
            values: vec![0.4, 0.6],
        });
        promoted.oos_metrics = OosCalibrationMetrics {
            sample_count: 100,
            positive_count: 50,
            brier_score: 0.25,
            log_loss: 0.69,
            expected_calibration_error: 0.2,
            reliability_bins: vec![ReliabilityBin {
                lower_bound: 0.0,
                upper_bound: 0.5,
                sample_count: 100,
                mean_predicted_probability: 0.3,
                observed_frequency: 0.5,
            }],
        };
        assert!(promoted.validate().is_ok());

        let runtime = source(promoted).evaluate(&request(origin + Duration::days(40)));
        assert!(runtime.eligible_for_probability_use);
        assert!(runtime.calibrated_probability_up.is_some());
        assert!(runtime.calibrated_probability_up_interval.is_none());
    }

    #[test]
    fn registry_rejects_overlapping_fit_and_oos_windows() {
        let mut invalid = artifact(CalibrationMethod::Isotonic {
            thresholds: vec![0.5, 1.0],
            values: vec![0.4, 0.6],
        });
        invalid.calibrator_fit_window.end_exclusive =
            invalid.untouched_oos_evaluation_window.start + Duration::minutes(1);
        assert!(invalid.validate().is_err());
    }

    #[test]
    fn missing_artifact_never_synthesizes_a_probability() {
        let source = CalibrationRegistrySource {
            registry: None,
            source_status: "ARTIFACT_NOT_CONFIGURED".into(),
        };
        let runtime = source.evaluate(&request(Utc::now()));
        assert!(!runtime.eligible_for_probability_use);
        assert!(runtime.calibrated_probability_up.is_none());
        assert!(runtime.calibrated_probability_up_interval.is_none());
        assert_eq!(runtime.raw_analog_up_frequency, 0.8);
    }

    fn minute_observations(origin: DateTime<Utc>, minutes: i64) -> Vec<CalibrationObservation> {
        [5, 15, 30, 60]
            .into_iter()
            .flat_map(|horizon| {
                (0..minutes).map(move |index| CalibrationObservation {
                    observation_cutoff: origin + Duration::minutes(index),
                    horizon_minutes: horizon,
                    raw_probability_up: if index % 2 == 0 { 0.8 } else { 0.2 },
                    outcome_up: index % 2 == 0,
                    model_id: "analog-v4".to_string(),
                    model_hash: "abc123".to_string(),
                    feature_version: "point-in-time-v4-strict-context".to_string(),
                })
            })
            .collect()
    }

    #[test]
    fn label_maturity_uses_checked_timestamp_arithmetic() {
        let origin = Utc.with_ymd_and_hms(2025, 1, 1, 0, 0, 0).unwrap();
        let mut row = minute_observations(origin, 1).remove(0);
        assert_eq!(
            estimated_label_maturity(&row).unwrap(),
            origin + Duration::minutes(5)
        );
        row.observation_cutoff = DateTime::<Utc>::MAX_UTC;
        assert!(estimated_label_maturity(&row).is_err());
        row.horizon_minutes = 0;
        assert!(estimated_label_maturity(&row).is_err());
    }

    #[test]
    fn method_selection_purges_unmatured_fit_labels() {
        let origin = Utc.with_ymd_and_hms(2025, 1, 1, 0, 0, 0).unwrap();
        let observations = minute_observations(origin, 200);
        let fit = observations
            .iter()
            .filter(|row| row.horizon_minutes == 60)
            .collect::<Vec<_>>();
        let (method_fit, selection) = calibration_method_partitions(&fit).unwrap();
        assert_eq!(method_fit.len(), 101);
        assert_eq!(selection.len(), 40);
        assert_eq!(
            selection[0].observation_cutoff,
            origin + Duration::minutes(160)
        );
        assert!(method_fit.iter().all(|row| {
            estimated_label_maturity(row).unwrap() <= selection[0].observation_cutoff
        }));
        assert_eq!(
            estimated_label_maturity(method_fit.last().unwrap()).unwrap(),
            selection[0].observation_cutoff
        );
        // Changing labels that cross into selection cannot change either
        // candidate calibrator. These rows were eligible before this purge.
        let mut changed = observations.clone();
        for row in &mut changed {
            if row.horizon_minutes == 60
                && row.observation_cutoff > origin + Duration::minutes(100)
                && row.observation_cutoff < selection[0].observation_cutoff
            {
                row.outcome_up = !row.outcome_up;
            }
        }
        let changed_fit = changed
            .iter()
            .filter(|row| row.horizon_minutes == 60)
            .collect::<Vec<_>>();
        let (changed_method_fit, _) = calibration_method_partitions(&changed_fit).unwrap();
        assert_eq!(fit_platt(&method_fit), fit_platt(&changed_method_fit));
        assert_eq!(fit_isotonic(&method_fit), fit_isotonic(&changed_method_fit));
    }

    #[test]
    fn materializer_purges_labels_crossing_adjacent_fit_and_oos_boundaries() {
        let origin = Utc.with_ymd_and_hms(2025, 1, 1, 0, 0, 0).unwrap();
        let mut observations = minute_observations(origin, 480);
        let fit = TimePartition {
            start: origin,
            end_exclusive: origin + Duration::minutes(300),
        };
        let oos = TimePartition {
            start: fit.end_exclusive,
            end_exclusive: origin + Duration::minutes(480),
        };
        let build = |rows: &[CalibrationObservation]| {
            materialize_oos_calibration_registry(
                rows,
                fit.clone(),
                oos.clone(),
                Utc::now() + Duration::minutes(1),
                100,
                0.25,
            )
            .unwrap()
        };
        let baseline = build(&observations);
        let sixty = baseline
            .horizons
            .iter()
            .find(|row| row.horizon_minutes == 60)
            .unwrap();
        assert_eq!(sixty.fit_samples, 134);
        assert_eq!(sixty.selection_samples, 48);
        assert_eq!(sixty.untouched_oos_samples, 121);
        for row in &mut observations {
            let boundary = if row.observation_cutoff < fit.end_exclusive {
                fit.end_exclusive
            } else {
                oos.end_exclusive
            };
            if estimated_label_maturity(row).unwrap() > boundary {
                row.outcome_up = !row.outcome_up;
            }
        }
        let changed = build(&observations);
        for (before, after) in baseline
            .registry
            .artifacts
            .iter()
            .zip(&changed.registry.artifacts)
        {
            assert_eq!(before.method, after.method);
            assert_eq!(before.oos_metrics, after.oos_metrics);
            assert_ne!(after.lifecycle, CalibrationLifecycle::PromotedOos);
        }
        assert!(changed.horizons.iter().all(|row| !row.promotion_eligible));
        assert!(
            changed
                .promotion_policy
                .contains("actual vendor label availability is not supplied")
        );
    }

    #[test]
    fn mature_label_purges_do_not_relax_minimum_sample_requirements() {
        let origin = Utc.with_ymd_and_hms(2025, 1, 1, 0, 0, 0).unwrap();
        let observations = minute_observations(origin, 480);
        for (fit_end, oos_end) in [(140, 480), (300, 380)] {
            let error = materialize_oos_calibration_registry(
                &observations,
                TimePartition {
                    start: origin,
                    end_exclusive: origin + Duration::minutes(fit_end),
                },
                TimePartition {
                    start: origin + Duration::minutes(fit_end),
                    end_exclusive: origin + Duration::minutes(oos_end),
                },
                Utc::now() + Duration::minutes(1),
                100,
                0.25,
            )
            .unwrap_err();
            assert!(
                error.to_string().contains(
                    "horizon 60 needs at least 100 fit and 50 untouched OOS observations"
                )
            );
        }
        let compressed = minute_observations(origin, 120);
        let fit = compressed
            .iter()
            .filter(|row| row.horizon_minutes == 60)
            .collect::<Vec<_>>();
        assert!(
            calibration_method_partitions(&fit)
                .unwrap_err()
                .to_string()
                .contains("at least 50 fit labels mature before selection")
        );
        assert!(calibration_method_partitions(&[]).is_err());
    }

    #[test]
    fn materializer_selects_without_touching_oos_and_never_auto_promotes() {
        let origin = Utc.with_ymd_and_hms(2025, 1, 1, 0, 0, 0).unwrap();
        let mut observations = Vec::new();
        for horizon in [5, 15, 30, 60] {
            for index in 0..260 {
                let outcome_up = index % 2 == 0;
                observations.push(CalibrationObservation {
                    observation_cutoff: origin + Duration::hours(index),
                    horizon_minutes: horizon,
                    raw_probability_up: if outcome_up { 0.8 } else { 0.2 },
                    outcome_up,
                    model_id: "analog-v4".to_string(),
                    model_hash: "abc123".to_string(),
                    feature_version: "point-in-time-v4-strict-context".to_string(),
                });
            }
        }
        let report = materialize_oos_calibration_registry(
            &observations,
            TimePartition {
                start: origin,
                end_exclusive: origin + Duration::hours(160),
            },
            TimePartition {
                start: origin + Duration::hours(160),
                end_exclusive: origin + Duration::hours(260),
            },
            Utc::now() + Duration::minutes(1),
            100,
            0.25,
        )
        .unwrap();
        assert_eq!(report.registry.artifacts.len(), 4);
        assert!(
            report
                .registry
                .artifacts
                .iter()
                .all(|artifact| artifact.lifecycle == CalibrationLifecycle::OosValidated)
        );
        assert!(
            report
                .horizons
                .iter()
                .all(|horizon| !horizon.promotion_eligible)
        );
    }
}

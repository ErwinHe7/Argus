use std::collections::BTreeMap;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ExplanationAnalog {
    /// Canonical Market Memory identity, present only after a successful store lookup.
    #[serde(default, alias = "snapshot_id")]
    pub market_snapshot_id: Option<String>,
    /// Non-canonical trace identity for legacy rows; never a Market Memory foreign key.
    #[serde(default)]
    pub derived_trace_id: String,
    pub timestamp: DateTime<Utc>,
    pub similarity: f64,
    pub weight: f64,
    pub subsequent_path: Vec<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ExplanationDetection {
    pub id: String,
    pub name: String,
    pub detected_at: DateTime<Utc>,
    pub historical_count: usize,
    pub validation_status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ModelComponentExplanation {
    pub model_id: String,
    pub raw_probability: Option<f64>,
    pub expected_return: Option<f64>,
    pub validation_weight: f64,
    pub contribution: f64,
    pub oos_status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FeatureContribution {
    pub feature: String,
    pub value: Option<f64>,
    pub contribution: f64,
    pub method: String,
    pub interpretation_only: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ExplanationDistribution {
    pub mean: Option<f64>,
    pub median: Option<f64>,
    pub quantiles: BTreeMap<String, f64>,
    pub probability_up: Option<f64>,
    pub maximum_favorable_excursion_quantiles: BTreeMap<String, f64>,
    pub maximum_adverse_excursion_quantiles: BTreeMap<String, f64>,
    pub first_upper_hit_probability: Option<f64>,
    pub first_lower_hit_probability: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ForecastEvidence {
    pub raw_probability_up: Option<f64>,
    pub calibrated_probability_up: Option<f64>,
    pub analog_probability_up: Option<f64>,
    pub baseline_probability_up: Option<f64>,
    pub expected_return: Option<f64>,
    pub median_return: Option<f64>,
    pub central_interval_50: Option<[f64; 2]>,
    pub central_interval_80: Option<[f64; 2]>,
    pub oos_sample_count: usize,
    pub oos_brier_score: Option<f64>,
    pub oos_log_loss: Option<f64>,
    pub baseline_brier_score: Option<f64>,
    pub baseline_log_loss: Option<f64>,
    pub improvement_ci_95: Option<[f64; 2]>,
    pub improvement_ci_excludes_zero: bool,
    pub evidence_grade: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MarketMemoryCard {
    pub current_snapshot_id: Option<String>,
    pub snapshot_link_status: String,
    pub nearest_historical_environments: usize,
    pub top_analog_dates: Vec<DateTime<Utc>>,
    pub analog_similarity: Option<f64>,
    pub effective_analog_count: f64,
    pub analog_outcome_distribution: ExplanationDistribution,
    pub current_regime_probabilities: BTreeMap<String, f64>,
    pub regime_entropy: Option<f64>,
    pub detected_events: Vec<ExplanationDetection>,
    pub detected_motifs: Vec<ExplanationDetection>,
    pub model_disagreement: Option<f64>,
    pub out_of_distribution_score: Option<f64>,
    pub historical_stability: Option<f64>,
    pub recent_decay_score: Option<f64>,
    pub status: String,
    pub failure_conditions: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PredictionExplanation {
    pub schema_version: String,
    pub prediction_id: String,
    #[serde(default)]
    pub current_snapshot_id: Option<String>,
    pub reference_price: f64,
    pub decision_as_of: DateTime<Utc>,
    pub horizon_minutes: usize,
    pub regime_probabilities: BTreeMap<String, f64>,
    pub detected_events: Vec<ExplanationDetection>,
    pub detected_motifs: Vec<ExplanationDetection>,
    pub top_analogs: Vec<ExplanationAnalog>,
    pub analog_effective_sample_size: f64,
    pub analog_distribution: ExplanationDistribution,
    pub model_components: Vec<ModelComponentExplanation>,
    pub feature_contributions: Vec<FeatureContribution>,
    pub raw_probability: Option<f64>,
    pub calibrated_probability: Option<f64>,
    pub baseline_probability: Option<f64>,
    pub out_of_distribution_score: Option<f64>,
    pub model_disagreement: Option<f64>,
    #[serde(default)]
    pub regime_entropy: Option<f64>,
    #[serde(default)]
    pub historical_stability: Option<f64>,
    #[serde(default)]
    pub recent_decay_score: Option<f64>,
    pub evidence_grade: String,
    pub no_trade_reasons: Vec<String>,
    pub human_summary: String,
    pub interpretation_limitations: Vec<String>,
}

pub fn human_summary(explanation: &PredictionExplanation) -> String {
    let regime = explanation
        .regime_probabilities
        .iter()
        .max_by(|left, right| left.1.total_cmp(right.1))
        .map(|(name, probability)| {
            format!("当前最可能状态为 {name}（{:.0}%）", probability * 100.0)
        })
        .unwrap_or_else(|| "当前状态模型不可用".to_string());
    let analog = if explanation.top_analogs.is_empty() {
        "没有足够可靠的历史相似环境".to_string()
    } else {
        format!(
            "检索到 {} 个展示样本、有效样本数 {:.1}",
            explanation.top_analogs.len(),
            explanation.analog_effective_sample_size
        )
    };
    let disagreement = explanation
        .model_disagreement
        .map(|value| format!("模型分歧 {:.2}", value))
        .unwrap_or_else(|| "模型分歧尚未估计".to_string());
    let evidence = if explanation.no_trade_reasons.is_empty() {
        format!("证据等级 {}，仍需遵守晋级门槛", explanation.evidence_grade)
    } else {
        format!(
            "证据等级 {}；当前仅可继续 forward shadow：{}",
            explanation.evidence_grade,
            explanation.no_trade_reasons.join("、")
        )
    };
    format!("{regime}；{analog}；{disagreement}；{evidence}。")
}

impl PredictionExplanation {
    pub fn finalize(mut self) -> Self {
        self.no_trade_reasons.sort();
        self.no_trade_reasons.dedup();
        self.human_summary = human_summary(&self);
        self
    }

    pub fn market_memory_card(&self) -> MarketMemoryCard {
        let mut failure_conditions = self.no_trade_reasons.clone();
        if self.current_snapshot_id.is_none() {
            failure_conditions.push("MARKET_SNAPSHOT_ID_UNAVAILABLE".into());
        }
        failure_conditions.sort();
        failure_conditions.dedup();
        let status = if self.current_snapshot_id.is_none() {
            "BLOCKED_LINEAGE"
        } else if failure_conditions.is_empty() {
            "RESEARCH_CANDIDATE"
        } else {
            "NO_TRADE"
        };
        MarketMemoryCard {
            current_snapshot_id: self.current_snapshot_id.clone(),
            snapshot_link_status: if self.current_snapshot_id.is_some() {
                "CANONICAL_MARKET_MEMORY_ID"
            } else {
                "UNAVAILABLE_NOT_MATERIALIZED_OR_NOT_RESOLVED"
            }
            .into(),
            nearest_historical_environments: self.top_analogs.len(),
            top_analog_dates: self.top_analogs.iter().map(|row| row.timestamp).collect(),
            analog_similarity: self.top_analogs.first().map(|row| row.similarity),
            effective_analog_count: self.analog_effective_sample_size,
            analog_outcome_distribution: self.analog_distribution.clone(),
            current_regime_probabilities: self.regime_probabilities.clone(),
            regime_entropy: self.regime_entropy,
            detected_events: self.detected_events.clone(),
            detected_motifs: self.detected_motifs.clone(),
            model_disagreement: self.model_disagreement,
            out_of_distribution_score: self.out_of_distribution_score,
            historical_stability: self.historical_stability,
            recent_decay_score: self.recent_decay_score,
            status: status.into(),
            failure_conditions,
        }
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use chrono::{TimeZone, Utc};

    use super::{ExplanationDistribution, PredictionExplanation};

    #[test]
    fn explanation_always_names_evidence_and_failure_conditions() {
        let explanation = PredictionExplanation {
            schema_version: "axio.prediction-explanation.v1".into(),
            prediction_id: "p1".into(),
            current_snapshot_id: None,
            reference_price: 100.0,
            decision_as_of: Utc.with_ymd_and_hms(2026, 7, 21, 14, 0, 0).unwrap(),
            horizon_minutes: 30,
            regime_probabilities: BTreeMap::from([("HIGH_VOL_RECOVERY".into(), 0.6)]),
            detected_events: Vec::new(),
            detected_motifs: Vec::new(),
            top_analogs: Vec::new(),
            analog_effective_sample_size: 0.0,
            analog_distribution: ExplanationDistribution {
                mean: None,
                median: None,
                quantiles: BTreeMap::new(),
                probability_up: None,
                maximum_favorable_excursion_quantiles: BTreeMap::new(),
                maximum_adverse_excursion_quantiles: BTreeMap::new(),
                first_upper_hit_probability: None,
                first_lower_hit_probability: None,
            },
            model_components: Vec::new(),
            feature_contributions: Vec::new(),
            raw_probability: None,
            calibrated_probability: None,
            baseline_probability: None,
            out_of_distribution_score: Some(1.2),
            model_disagreement: None,
            regime_entropy: Some(0.4),
            historical_stability: None,
            recent_decay_score: None,
            evidence_grade: "CONTAMINATED_EXPLORATORY".into(),
            no_trade_reasons: vec!["OUT_OF_DISTRIBUTION".into()],
            human_summary: String::new(),
            interpretation_limitations: vec![
                "SHAP-style contributions are explanations, not causal effects".into(),
            ],
        }
        .finalize();
        assert!(explanation.human_summary.contains("forward shadow"));
        let card = explanation.market_memory_card();
        assert_eq!(card.status, "BLOCKED_LINEAGE");
        assert!(card.current_snapshot_id.is_none());
        assert!(
            card.failure_conditions
                .contains(&"MARKET_SNAPSHOT_ID_UNAVAILABLE".to_string())
        );
    }
}

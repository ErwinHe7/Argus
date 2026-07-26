use std::collections::{BTreeMap, BTreeSet};

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "snake_case")]
pub enum SignalKind {
    Momentum,
    MeanReversion,
    OpeningGapBehavior,
    VwapBehavior,
    AbnormalVolume,
    RelativeStrength,
    CrossAssetLeadLag,
    MotifMatch,
    AnalogForecast,
    HmmTransition,
    EventReaction,
    LiquidityCondition,
    TimeBucketDrift,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SignalAudit {
    pub kind: SignalKind,
    pub standardized_score: f64,
    pub validation_information_ratio: f64,
    pub validation_q_value: f64,
    pub expected_turnover: f64,
    pub assumed_cost_bps: f64,
    pub expected_gross_edge_bps: f64,
    pub independently_audited: bool,
    pub correlation_group: String,
}

impl SignalAudit {
    pub fn expected_net_edge_bps(&self) -> f64 {
        self.expected_gross_edge_bps - self.expected_turnover * self.assumed_cost_bps
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SignalContribution {
    pub kind: SignalKind,
    pub raw_score: f64,
    pub validation_weight: f64,
    pub weighted_score: f64,
    pub expected_net_edge_bps: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct LeaveOneSignalOut {
    pub omitted: SignalKind,
    pub ensemble_score_without_signal: f64,
    pub score_change: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct WeakSignalEnsembleOutput {
    pub ensemble_score: f64,
    pub contributions: Vec<SignalContribution>,
    pub effective_number_of_signals: f64,
    pub maximum_single_signal_weight: f64,
    pub model_disagreement: f64,
    pub leave_one_signal_out: Vec<LeaveOneSignalOut>,
    pub no_trade_reasons: Vec<String>,
    pub action: String,
    pub weight_semantics: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct EnsemblePolicy {
    pub maximum_q_value: f64,
    pub maximum_group_weight: f64,
    pub maximum_signal_weight: f64,
    pub minimum_effective_signals: f64,
    pub maximum_disagreement: f64,
    pub maximum_ood_score: f64,
    pub maximum_normalized_regime_entropy: f64,
}

impl Default for EnsemblePolicy {
    fn default() -> Self {
        Self {
            maximum_q_value: 0.10,
            maximum_group_weight: 0.40,
            maximum_signal_weight: 0.35,
            minimum_effective_signals: 2.5,
            maximum_disagreement: 0.85,
            maximum_ood_score: 0.80,
            maximum_normalized_regime_entropy: 0.90,
        }
    }
}

const WEIGHT_TOLERANCE: f64 = 1.0e-10;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum WeightAllocationStatus {
    Complete,
    NoEligibleSignal,
    InfeasibleCaps,
    NumericFailure,
}

struct WeightAllocation {
    weights: Vec<f64>,
    status: WeightAllocationStatus,
}

fn finite_or_zero(value: f64) -> f64 {
    if value.is_finite() { value } else { 0.0 }
}

fn policy_validation_reasons(policy: &EnsemblePolicy) -> Vec<String> {
    let mut reasons = Vec::new();
    if !policy.maximum_q_value.is_finite() || !(0.0..=1.0).contains(&policy.maximum_q_value) {
        reasons.push("INVALID_POLICY_MAXIMUM_Q_VALUE".to_string());
    }
    if !policy.maximum_group_weight.is_finite()
        || !(0.0..=1.0).contains(&policy.maximum_group_weight)
        || policy.maximum_group_weight == 0.0
    {
        reasons.push("INVALID_POLICY_MAXIMUM_GROUP_WEIGHT".to_string());
    }
    if !policy.maximum_signal_weight.is_finite()
        || !(0.0..=1.0).contains(&policy.maximum_signal_weight)
        || policy.maximum_signal_weight == 0.0
    {
        reasons.push("INVALID_POLICY_MAXIMUM_SIGNAL_WEIGHT".to_string());
    }
    if !policy.minimum_effective_signals.is_finite() || policy.minimum_effective_signals < 1.0 {
        reasons.push("INVALID_POLICY_MINIMUM_EFFECTIVE_SIGNALS".to_string());
    }
    if !policy.maximum_disagreement.is_finite() || policy.maximum_disagreement < 0.0 {
        reasons.push("INVALID_POLICY_MAXIMUM_DISAGREEMENT".to_string());
    }
    if !policy.maximum_ood_score.is_finite() || !(0.0..=1.0).contains(&policy.maximum_ood_score) {
        reasons.push("INVALID_POLICY_MAXIMUM_OOD_SCORE".to_string());
    }
    if !policy.maximum_normalized_regime_entropy.is_finite()
        || !(0.0..=1.0).contains(&policy.maximum_normalized_regime_entropy)
    {
        reasons.push("INVALID_POLICY_MAXIMUM_NORMALIZED_REGIME_ENTROPY".to_string());
    }
    reasons
}

fn signal_validation_reasons(rows: &[SignalAudit]) -> Vec<String> {
    let mut reasons = Vec::new();
    let mut kinds = BTreeSet::new();
    for row in rows {
        let kind = format!("{:?}", row.kind).to_ascii_uppercase();
        if !kinds.insert(row.kind) {
            reasons.push(format!("DUPLICATE_SIGNAL_KIND:{kind}"));
        }
        if !row.standardized_score.is_finite()
            || !row.validation_information_ratio.is_finite()
            || !row.validation_q_value.is_finite()
            || !(0.0..=1.0).contains(&row.validation_q_value)
            || !row.expected_turnover.is_finite()
            || row.expected_turnover < 0.0
            || !row.assumed_cost_bps.is_finite()
            || row.assumed_cost_bps < 0.0
            || !row.expected_gross_edge_bps.is_finite()
            || !row.expected_net_edge_bps().is_finite()
        {
            reasons.push(format!("INVALID_SIGNAL_NUMERIC_INPUT:{kind}"));
        }
        if row.correlation_group.trim().is_empty()
            || row.correlation_group.trim() != row.correlation_group
        {
            reasons.push(format!("INVALID_SIGNAL_CORRELATION_GROUP:{kind}"));
        }
    }
    reasons
}

/// Proportional water-filling with heterogeneous element capacities.
///
/// The residual is redistributed only to elements with remaining capacity, so
/// a binding cap can never be broken by a final normalization pass.
fn capped_proportional(raw: &[f64], capacities: &[f64], target: f64) -> Option<Vec<f64>> {
    if raw.len() != capacities.len()
        || !target.is_finite()
        || target < 0.0
        || raw.iter().zip(capacities).any(|(value, capacity)| {
            !value.is_finite() || *value < 0.0 || !capacity.is_finite() || *capacity < 0.0
        })
    {
        return None;
    }
    if target <= WEIGHT_TOLERANCE {
        return Some(vec![0.0; raw.len()]);
    }
    let active_capacity = raw
        .iter()
        .zip(capacities)
        .filter(|(value, capacity)| **value > 0.0 && **capacity > 0.0)
        .map(|(_, capacity)| *capacity)
        .sum::<f64>();
    if !active_capacity.is_finite() || active_capacity + WEIGHT_TOLERANCE < target {
        return None;
    }

    let raw_scale = raw.iter().copied().fold(0.0, f64::max);
    if !raw_scale.is_finite() || raw_scale <= 0.0 {
        return None;
    }
    let scaled = raw
        .iter()
        .map(|value| value / raw_scale)
        .collect::<Vec<_>>();
    let mut output = vec![0.0; raw.len()];
    let mut active = scaled
        .iter()
        .zip(capacities)
        .map(|(value, capacity)| *value > 0.0 && *capacity > 0.0)
        .collect::<Vec<_>>();
    let mut remaining = target;

    loop {
        let active_indices = active
            .iter()
            .enumerate()
            .filter_map(|(index, enabled)| (*enabled).then_some(index))
            .collect::<Vec<_>>();
        if active_indices.is_empty() {
            break;
        }
        let raw_total = active_indices
            .iter()
            .map(|index| scaled[*index])
            .sum::<f64>();
        if !raw_total.is_finite() || raw_total <= 0.0 {
            return None;
        }
        let saturated = active_indices
            .iter()
            .copied()
            .filter(|index| {
                remaining * scaled[*index] / raw_total > capacities[*index] + WEIGHT_TOLERANCE
            })
            .collect::<Vec<_>>();
        if saturated.is_empty() {
            for index in active_indices {
                output[index] = remaining * scaled[index] / raw_total;
                active[index] = false;
            }
            break;
        }
        for index in saturated {
            output[index] = capacities[index];
            remaining -= capacities[index];
            active[index] = false;
        }
        if remaining < -WEIGHT_TOLERANCE {
            return None;
        }
        remaining = remaining.max(0.0);
    }

    // Repair only floating-point residue. A blanket normalization here would
    // re-introduce the cap violation this routine exists to prevent.
    let mut residual = target - output.iter().sum::<f64>();
    if residual > WEIGHT_TOLERANCE {
        for index in 0..output.len() {
            let slack = (capacities[index] - output[index]).max(0.0);
            let addition = slack.min(residual);
            output[index] += addition;
            residual -= addition;
            if residual <= WEIGHT_TOLERANCE {
                break;
            }
        }
    }
    let total = output.iter().sum::<f64>();
    if output
        .iter()
        .any(|weight| !weight.is_finite() || *weight < 0.0)
        || (total - target).abs() > WEIGHT_TOLERANCE * 10.0
        || output
            .iter()
            .zip(capacities)
            .any(|(weight, capacity)| *weight > *capacity + WEIGHT_TOLERANCE)
    {
        return None;
    }
    Some(output)
}

fn validation_weights(rows: &[SignalAudit], policy: &EnsemblePolicy) -> WeightAllocation {
    let raw = rows
        .iter()
        .map(|row| {
            if !row.independently_audited
                || row.validation_q_value > policy.maximum_q_value
                || row.expected_net_edge_bps() <= 0.0
            {
                0.0
            } else {
                row.validation_information_ratio.max(0.0) * row.expected_net_edge_bps().sqrt()
            }
        })
        .collect::<Vec<_>>();
    if raw.iter().any(|value| !value.is_finite() || *value < 0.0) {
        return WeightAllocation {
            weights: vec![0.0; rows.len()],
            status: WeightAllocationStatus::NumericFailure,
        };
    }
    let raw_scale = raw.iter().copied().fold(0.0, f64::max);
    if raw_scale <= 0.0 {
        return WeightAllocation {
            weights: vec![0.0; rows.len()],
            status: WeightAllocationStatus::NoEligibleSignal,
        };
    }
    let scaled_raw = raw
        .iter()
        .map(|value| value / raw_scale)
        .collect::<Vec<_>>();

    let mut groups = BTreeMap::<&str, Vec<usize>>::new();
    for (index, row) in rows.iter().enumerate() {
        groups
            .entry(row.correlation_group.as_str())
            .or_default()
            .push(index);
    }
    let group_rows = groups.values().collect::<Vec<_>>();
    let group_raw = group_rows
        .iter()
        .map(|members| members.iter().map(|index| scaled_raw[*index]).sum::<f64>())
        .collect::<Vec<_>>();
    let group_capacities = group_rows
        .iter()
        .map(|members| {
            let positive_members = members
                .iter()
                .filter(|index| scaled_raw[**index] > 0.0)
                .count();
            policy
                .maximum_group_weight
                .min(positive_members as f64 * policy.maximum_signal_weight)
        })
        .collect::<Vec<_>>();
    let Some(group_weights) = capped_proportional(&group_raw, &group_capacities, 1.0) else {
        return WeightAllocation {
            weights: vec![0.0; rows.len()],
            status: WeightAllocationStatus::InfeasibleCaps,
        };
    };

    let mut weights = vec![0.0; rows.len()];
    for (group_index, members) in group_rows.iter().enumerate() {
        let member_raw = members
            .iter()
            .map(|index| scaled_raw[*index])
            .collect::<Vec<_>>();
        let member_capacities = vec![policy.maximum_signal_weight; members.len()];
        let Some(member_weights) =
            capped_proportional(&member_raw, &member_capacities, group_weights[group_index])
        else {
            return WeightAllocation {
                weights: vec![0.0; rows.len()],
                status: WeightAllocationStatus::InfeasibleCaps,
            };
        };
        for (member, weight) in members.iter().zip(member_weights) {
            weights[*member] = weight;
        }
    }
    WeightAllocation {
        weights,
        status: WeightAllocationStatus::Complete,
    }
}

pub fn combine(
    rows: &[SignalAudit],
    policy: &EnsemblePolicy,
    out_of_distribution_score: f64,
    normalized_regime_entropy: f64,
) -> WeakSignalEnsembleOutput {
    let policy_reasons = policy_validation_reasons(policy);
    let policy_valid = policy_reasons.is_empty();
    let signal_reasons = signal_validation_reasons(rows);
    let signals_valid = signal_reasons.is_empty();
    let ood_valid =
        out_of_distribution_score.is_finite() && (0.0..=1.0).contains(&out_of_distribution_score);
    let entropy_valid =
        normalized_regime_entropy.is_finite() && (0.0..=1.0).contains(&normalized_regime_entropy);
    let mut reasons = policy_reasons;
    reasons.extend(signal_reasons);
    if !ood_valid {
        reasons.push("INVALID_OUT_OF_DISTRIBUTION_SCORE".to_string());
    }
    if !entropy_valid {
        reasons.push("INVALID_NORMALIZED_REGIME_ENTROPY".to_string());
    }
    let validation_inputs_valid = policy_valid && signals_valid && ood_valid && entropy_valid;
    let allocation = if validation_inputs_valid {
        validation_weights(rows, policy)
    } else {
        WeightAllocation {
            weights: vec![0.0; rows.len()],
            status: WeightAllocationStatus::NumericFailure,
        }
    };
    match allocation.status {
        WeightAllocationStatus::Complete => {}
        WeightAllocationStatus::NoEligibleSignal => {
            reasons.push("NO_INDEPENDENTLY_VALIDATED_SIGNAL".to_string());
        }
        WeightAllocationStatus::InfeasibleCaps => {
            reasons.push("ENSEMBLE_CAP_CONSTRAINTS_INFEASIBLE".to_string());
        }
        WeightAllocationStatus::NumericFailure if validation_inputs_valid => {
            reasons.push("ENSEMBLE_WEIGHT_NUMERIC_FAILURE".to_string());
        }
        WeightAllocationStatus::NumericFailure => {}
    }
    let weights = allocation.weights;

    let mut ensemble_score = rows
        .iter()
        .zip(&weights)
        .map(|(row, weight)| finite_or_zero(row.standardized_score) * weight)
        .sum::<f64>();
    if !ensemble_score.is_finite() {
        reasons.push("ENSEMBLE_SCORE_NUMERIC_FAILURE".to_string());
        ensemble_score = 0.0;
    }
    let sum_squared = weights.iter().map(|weight| weight * weight).sum::<f64>();
    let effective = if sum_squared.is_finite() && sum_squared > 0.0 {
        1.0 / sum_squared
    } else {
        0.0
    };
    let maximum_weight = weights.iter().copied().fold(0.0, f64::max);
    let mut disagreement = rows
        .iter()
        .zip(&weights)
        .map(|(row, weight)| {
            weight * (finite_or_zero(row.standardized_score) - ensemble_score).powi(2)
        })
        .sum::<f64>()
        .sqrt();
    if !disagreement.is_finite() {
        reasons.push("ENSEMBLE_DISAGREEMENT_NUMERIC_FAILURE".to_string());
        disagreement = 0.0;
    }
    let contributions = rows
        .iter()
        .zip(&weights)
        .map(|(row, weight)| SignalContribution {
            kind: row.kind,
            raw_score: finite_or_zero(row.standardized_score),
            validation_weight: *weight,
            weighted_score: finite_or_zero(row.standardized_score) * weight,
            expected_net_edge_bps: finite_or_zero(row.expected_net_edge_bps()),
        })
        .collect::<Vec<_>>();
    let leave_one_signal_out = rows
        .iter()
        .enumerate()
        .map(|(omitted_index, row)| {
            let remaining_weight = 1.0 - weights[omitted_index];
            let without = if remaining_weight > 1.0e-12 {
                (ensemble_score - finite_or_zero(row.standardized_score) * weights[omitted_index])
                    / remaining_weight
            } else {
                0.0
            };
            LeaveOneSignalOut {
                omitted: row.kind,
                ensemble_score_without_signal: finite_or_zero(without),
                score_change: finite_or_zero(ensemble_score - without),
            }
        })
        .collect::<Vec<_>>();

    if contributions.iter().all(|row| row.validation_weight == 0.0) {
        reasons.push("NO_INDEPENDENTLY_VALIDATED_SIGNAL".to_string());
    }
    if validation_inputs_valid && allocation.status == WeightAllocationStatus::Complete {
        let total_weight = weights.iter().sum::<f64>();
        if (total_weight - 1.0).abs() > WEIGHT_TOLERANCE * 10.0 {
            reasons.push("ENSEMBLE_WEIGHT_NORMALIZATION_FAILED".to_string());
        }
        if effective < policy.minimum_effective_signals {
            reasons.push("INSUFFICIENT_EFFECTIVE_SIGNAL_DIVERSITY".to_string());
        }
        if maximum_weight > policy.maximum_signal_weight + WEIGHT_TOLERANCE {
            reasons.push("ENSEMBLE_SIGNAL_CAP_VIOLATION".to_string());
        }
        let mut group_weights = BTreeMap::<&str, f64>::new();
        for (row, weight) in rows.iter().zip(&weights) {
            *group_weights
                .entry(row.correlation_group.as_str())
                .or_default() += weight;
        }
        if group_weights
            .values()
            .any(|weight| *weight > policy.maximum_group_weight + WEIGHT_TOLERANCE)
        {
            reasons.push("ENSEMBLE_GROUP_CAP_VIOLATION".to_string());
        }
        if disagreement > policy.maximum_disagreement {
            reasons.push("MODEL_DISAGREEMENT_NO_TRADE".to_string());
        }
    }
    if policy_valid && ood_valid && out_of_distribution_score > policy.maximum_ood_score {
        reasons.push("OUT_OF_DISTRIBUTION".to_string());
    }
    if policy_valid
        && entropy_valid
        && normalized_regime_entropy > policy.maximum_normalized_regime_entropy
    {
        reasons.push("HIGH_REGIME_ENTROPY".to_string());
    }
    reasons.sort();
    reasons.dedup();

    WeakSignalEnsembleOutput {
        ensemble_score,
        contributions,
        effective_number_of_signals: effective,
        maximum_single_signal_weight: maximum_weight,
        model_disagreement: disagreement,
        leave_one_signal_out,
        action: if reasons.is_empty() {
            "EXPERIMENTAL_SIGNAL"
        } else {
            "NO_TRADE"
        }
        .to_string(),
        no_trade_reasons: reasons,
        weight_semantics: "VALIDATION_ONLY_COST_AWARE_HIERARCHICAL_CAPPED_SIMPLEX_TEST_FROZEN"
            .to_string(),
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{EnsemblePolicy, SignalAudit, SignalKind, combine};

    fn signal(kind: SignalKind, score: f64, group: &str) -> SignalAudit {
        SignalAudit {
            kind,
            standardized_score: score,
            validation_information_ratio: 0.5,
            validation_q_value: 0.05,
            expected_turnover: 1.0,
            assumed_cost_bps: 1.0,
            expected_gross_edge_bps: 3.0,
            independently_audited: true,
            correlation_group: group.to_string(),
        }
    }

    #[test]
    fn ood_and_disagreement_force_no_trade() {
        let rows = vec![
            signal(SignalKind::Momentum, 1.0, "price"),
            signal(SignalKind::MeanReversion, -1.0, "price"),
            signal(SignalKind::AnalogForecast, 0.5, "memory"),
        ];
        let output = combine(&rows, &EnsemblePolicy::default(), 0.95, 0.2);
        assert_eq!(output.action, "NO_TRADE");
        assert!(
            output
                .no_trade_reasons
                .iter()
                .any(|reason| reason == "OUT_OF_DISTRIBUTION")
        );
        assert_eq!(output.leave_one_signal_out.len(), 3);
    }

    #[test]
    fn unaudited_signal_gets_zero_weight() {
        let mut row = signal(SignalKind::MotifMatch, 4.0, "motif");
        row.independently_audited = false;
        let output = combine(&[row], &EnsemblePolicy::default(), 0.1, 0.1);
        assert_eq!(output.contributions[0].validation_weight, 0.0);
        assert_eq!(output.action, "NO_TRADE");
    }

    #[test]
    fn water_filling_preserves_signal_and_group_caps_after_normalization() {
        let mut rows = vec![
            signal(SignalKind::Momentum, 1.0, "price"),
            signal(SignalKind::MeanReversion, 0.8, "price"),
            signal(SignalKind::VwapBehavior, 0.6, "price"),
            signal(SignalKind::AnalogForecast, 0.5, "memory"),
            signal(SignalKind::MotifMatch, 0.4, "memory"),
            signal(SignalKind::HmmTransition, 0.3, "state"),
            signal(SignalKind::EventReaction, 0.2, "event"),
        ];
        rows[0].validation_information_ratio = 100.0;
        let policy = EnsemblePolicy {
            minimum_effective_signals: 1.0,
            maximum_disagreement: 10.0,
            ..EnsemblePolicy::default()
        };
        let output = combine(&rows, &policy, 0.1, 0.1);
        let total = output
            .contributions
            .iter()
            .map(|row| row.validation_weight)
            .sum::<f64>();
        assert!((total - 1.0).abs() < 1.0e-9);
        assert!(
            output
                .contributions
                .iter()
                .all(|row| row.validation_weight <= policy.maximum_signal_weight + 1.0e-10)
        );
        let mut by_group = BTreeMap::<&str, f64>::new();
        for (row, contribution) in rows.iter().zip(&output.contributions) {
            *by_group.entry(row.correlation_group.as_str()).or_default() +=
                contribution.validation_weight;
        }
        assert!(
            by_group
                .values()
                .all(|weight| *weight <= policy.maximum_group_weight + 1.0e-10)
        );
        assert_eq!(output.action, "EXPERIMENTAL_SIGNAL");
    }

    #[test]
    fn infeasible_caps_fail_closed_instead_of_renormalizing_through_caps() {
        let rows = vec![
            signal(SignalKind::Momentum, 1.0, "price"),
            signal(SignalKind::MeanReversion, 0.5, "price"),
            signal(SignalKind::AnalogForecast, 0.3, "memory"),
        ];
        let output = combine(&rows, &EnsemblePolicy::default(), 0.1, 0.1);
        assert_eq!(output.action, "NO_TRADE");
        assert!(
            output
                .no_trade_reasons
                .iter()
                .any(|reason| reason == "ENSEMBLE_CAP_CONSTRAINTS_INFEASIBLE")
        );
        assert!(
            output
                .contributions
                .iter()
                .all(|row| row.validation_weight == 0.0)
        );
    }

    #[test]
    fn non_finite_signal_or_context_is_never_trade_eligible() {
        let mut row = signal(SignalKind::Momentum, f64::NAN, "price");
        row.expected_turnover = -1.0;
        let output = combine(&[row], &EnsemblePolicy::default(), f64::NAN, -0.1);
        assert_eq!(output.action, "NO_TRADE");
        assert!(output.ensemble_score.is_finite());
        assert!(output.model_disagreement.is_finite());
        assert!(
            output
                .no_trade_reasons
                .iter()
                .any(|reason| reason.starts_with("INVALID_SIGNAL_NUMERIC_INPUT"))
        );
        assert!(
            output
                .no_trade_reasons
                .iter()
                .any(|reason| reason == "INVALID_OUT_OF_DISTRIBUTION_SCORE")
        );
        assert!(
            output
                .no_trade_reasons
                .iter()
                .any(|reason| reason == "INVALID_NORMALIZED_REGIME_ENTROPY")
        );
    }

    #[test]
    fn invalid_policy_is_fail_closed() {
        let policy = EnsemblePolicy {
            maximum_group_weight: f64::NAN,
            ..EnsemblePolicy::default()
        };
        let output = combine(
            &[signal(SignalKind::Momentum, 1.0, "price")],
            &policy,
            0.1,
            0.1,
        );
        assert_eq!(output.action, "NO_TRADE");
        assert!(
            output
                .no_trade_reasons
                .iter()
                .any(|reason| reason == "INVALID_POLICY_MAXIMUM_GROUP_WEIGHT")
        );
    }

    #[test]
    fn out_of_range_ood_policy_or_context_is_fail_closed() {
        let rows = [
            signal(SignalKind::Momentum, 1.0, "price"),
            signal(SignalKind::AnalogForecast, 0.5, "memory"),
            signal(SignalKind::HmmTransition, 0.25, "state"),
        ];
        let output = combine(&rows, &EnsemblePolicy::default(), 1.01, 0.1);
        assert_eq!(output.action, "NO_TRADE");
        assert!(
            output
                .no_trade_reasons
                .iter()
                .any(|reason| { reason == "INVALID_OUT_OF_DISTRIBUTION_SCORE" })
        );

        let policy = EnsemblePolicy {
            maximum_ood_score: 1.01,
            minimum_effective_signals: 1.0,
            ..EnsemblePolicy::default()
        };
        let output = combine(&rows, &policy, 0.1, 0.1);
        assert_eq!(output.action, "NO_TRADE");
        assert!(
            output
                .no_trade_reasons
                .iter()
                .any(|reason| { reason == "INVALID_POLICY_MAXIMUM_OOD_SCORE" })
        );
    }
}

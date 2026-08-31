use std::collections::{BTreeMap, BTreeSet};

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "snake_case")]
pub enum ModelFamily {
    RegularizedLinearLogistic,
    GeneralizedAdditive,
    KernelRegression,
    GradientBoostedTrees,
    QuantileRegression,
    HistoricalAnalogDistribution,
    RegimeSwitching,
    SmallEnsemble,
    GeometricBrownianMotionScenarioBaseline,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MonotonicConstraint {
    pub feature: String,
    pub direction: i8,
    pub economically_required: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PartialDependencePoint {
    pub feature: String,
    pub feature_value: f64,
    pub average_prediction: f64,
    pub fold: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ModelFoldPredictions {
    pub family: ModelFamily,
    pub fold: usize,
    /// Stable sample identities make it possible to prove that every model in
    /// a fold was scored on the same validation observations and labels.
    #[serde(default)]
    pub validation_sample_ids: Vec<String>,
    pub validation_probabilities: Vec<f64>,
    pub validation_labels: Vec<f64>,
    /// Test identities are separate because validation and untouched test must
    /// be disjoint even when their row counts happen to be equal.
    #[serde(default)]
    pub test_sample_ids: Vec<String>,
    pub test_probabilities: Vec<f64>,
    pub test_labels: Vec<f64>,
    pub feature_importance: BTreeMap<String, f64>,
    pub interaction_strength: BTreeMap<String, f64>,
    pub partial_dependence: Vec<PartialDependencePoint>,
    pub test_was_used_for_tuning: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ModelFoldAudit {
    pub family: ModelFamily,
    pub fold: usize,
    pub validation_log_loss: f64,
    pub validation_brier: f64,
    pub test_log_loss: f64,
    pub test_brier: f64,
    pub monotonicity_violations: Vec<String>,
    pub feature_importance_stability_to_previous_fold: Option<f64>,
    pub interaction_stability_to_previous_fold: Option<f64>,
    pub test_was_used_for_tuning: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct NonlinearModelComparison {
    pub folds: Vec<ModelFoldAudit>,
    pub validation_selected_family: Option<ModelFamily>,
    pub average_test_log_loss_by_family: BTreeMap<ModelFamily, f64>,
    pub average_test_brier_by_family: BTreeMap<ModelFamily, f64>,
    /// Root-mean-square cross-model probability dispersion on common test rows.
    pub model_disagreement: f64,
    pub promotion_status: String,
    pub rejection_reasons: Vec<String>,
    pub interpretation_policy: String,
    pub sde_usage_policy: String,
}

const INVALID_METRIC: f64 = f64::MAX;

fn probability(value: f64) -> f64 {
    value.clamp(1.0e-6, 1.0 - 1.0e-6)
}

fn metrics(probabilities: &[f64], labels: &[f64]) -> Option<(f64, f64)> {
    if probabilities.is_empty()
        || probabilities.len() != labels.len()
        || probabilities
            .iter()
            .any(|value| !value.is_finite() || !(0.0..=1.0).contains(value))
        || labels
            .iter()
            .any(|value| !value.is_finite() || !matches!(*value, 0.0 | 1.0))
    {
        return None;
    }
    let observations = probabilities.len() as f64;
    let log_loss = probabilities
        .iter()
        .zip(labels)
        .map(|(forecast, label)| {
            let forecast = probability(*forecast);
            (-*label * forecast.ln() - (1.0 - *label) * (1.0 - forecast).ln()) / observations
        })
        .sum::<f64>();
    let brier = probabilities
        .iter()
        .zip(labels)
        .map(|(forecast, label)| (*forecast - *label).powi(2) / observations)
        .sum::<f64>();
    (log_loss.is_finite() && brier.is_finite()).then_some((log_loss, brier))
}

fn vector_similarity(left: &BTreeMap<String, f64>, right: &BTreeMap<String, f64>) -> Option<f64> {
    if left
        .values()
        .chain(right.values())
        .any(|value| !value.is_finite())
    {
        return None;
    }
    let keys = left
        .keys()
        .chain(right.keys())
        .cloned()
        .collect::<BTreeSet<_>>();
    if keys.is_empty() {
        return None;
    }
    let dot = keys
        .iter()
        .map(|key| {
            left.get(key).copied().unwrap_or_default() * right.get(key).copied().unwrap_or_default()
        })
        .sum::<f64>();
    let left_norm = keys
        .iter()
        .map(|key| left.get(key).copied().unwrap_or_default().powi(2))
        .sum::<f64>()
        .sqrt();
    let right_norm = keys
        .iter()
        .map(|key| right.get(key).copied().unwrap_or_default().powi(2))
        .sum::<f64>()
        .sqrt();
    (left_norm > 0.0 && right_norm > 0.0)
        .then_some((dot / (left_norm * right_norm)).clamp(-1.0, 1.0))
}

fn family_name(family: ModelFamily) -> String {
    format!("{family:?}").to_ascii_uppercase()
}

fn partition_contract_reasons(
    family: ModelFamily,
    fold: usize,
    partition: &str,
    sample_ids: &[String],
    probabilities: &[f64],
    labels: &[f64],
) -> Vec<String> {
    let identity = format!("{}:FOLD{fold}:{partition}", family_name(family));
    let mut reasons = Vec::new();
    if sample_ids.is_empty() || probabilities.is_empty() || labels.is_empty() {
        reasons.push(format!("EMPTY_EVALUATION_PARTITION:{identity}"));
    }
    if sample_ids.len() != probabilities.len() || probabilities.len() != labels.len() {
        reasons.push(format!("EVALUATION_VECTOR_LENGTH_MISMATCH:{identity}"));
    }
    let mut unique_ids = BTreeSet::new();
    if sample_ids.iter().any(|sample_id| {
        sample_id.trim().is_empty()
            || sample_id.trim() != sample_id
            || !unique_ids.insert(sample_id.as_str())
    }) {
        reasons.push(format!("INVALID_OR_DUPLICATE_SAMPLE_ID:{identity}"));
    }
    if probabilities
        .iter()
        .any(|value| !value.is_finite() || !(0.0..=1.0).contains(value))
    {
        reasons.push(format!("INVALID_FORECAST_PROBABILITY:{identity}"));
    }
    if labels
        .iter()
        .any(|value| !value.is_finite() || !matches!(*value, 0.0 | 1.0))
    {
        reasons.push(format!("INVALID_BINARY_LABEL:{identity}"));
    }
    reasons
}

#[derive(Clone)]
struct FoldSampleContract {
    validation_sample_ids: Vec<String>,
    validation_labels: Vec<f64>,
    test_sample_ids: Vec<String>,
    test_labels: Vec<f64>,
}

fn comparison_contract_reasons(
    rows: &[ModelFoldPredictions],
    constraints: &[MonotonicConstraint],
    baseline: ModelFamily,
) -> Vec<String> {
    let mut reasons = Vec::new();
    if rows.is_empty() {
        reasons.push("NO_MODEL_FOLD_PREDICTIONS".to_string());
        return reasons;
    }

    let mut required_constraints = BTreeMap::<&str, i8>::new();
    for constraint in constraints.iter().filter(|row| row.economically_required) {
        if constraint.feature.trim().is_empty()
            || constraint.feature.trim() != constraint.feature
            || !matches!(constraint.direction, -1 | 1)
        {
            reasons.push("INVALID_REQUIRED_MONOTONIC_CONSTRAINT".to_string());
            continue;
        }
        if required_constraints
            .insert(constraint.feature.as_str(), constraint.direction)
            .is_some_and(|existing| existing != constraint.direction)
        {
            reasons.push(format!(
                "CONFLICTING_REQUIRED_MONOTONIC_CONSTRAINT:{}",
                constraint.feature
            ));
        }
    }

    let mut seen_rows = BTreeSet::new();
    let mut family_folds = BTreeMap::<ModelFamily, BTreeSet<usize>>::new();
    let mut fold_contracts = BTreeMap::<usize, FoldSampleContract>::new();
    for row in rows {
        let row_identity = format!("{}:FOLD{}", family_name(row.family), row.fold);
        if !seen_rows.insert((row.family, row.fold)) {
            reasons.push(format!("DUPLICATE_MODEL_FOLD:{row_identity}"));
        }
        family_folds.entry(row.family).or_default().insert(row.fold);
        reasons.extend(partition_contract_reasons(
            row.family,
            row.fold,
            "VALIDATION",
            &row.validation_sample_ids,
            &row.validation_probabilities,
            &row.validation_labels,
        ));
        reasons.extend(partition_contract_reasons(
            row.family,
            row.fold,
            "TEST",
            &row.test_sample_ids,
            &row.test_probabilities,
            &row.test_labels,
        ));
        let validation_ids = row
            .validation_sample_ids
            .iter()
            .map(String::as_str)
            .collect::<BTreeSet<_>>();
        if row
            .test_sample_ids
            .iter()
            .any(|sample_id| validation_ids.contains(sample_id.as_str()))
        {
            reasons.push(format!("VALIDATION_TEST_SAMPLE_OVERLAP:{row_identity}"));
        }
        if row
            .feature_importance
            .iter()
            .chain(&row.interaction_strength)
            .any(|(name, value)| name.trim().is_empty() || !value.is_finite())
        {
            reasons.push(format!("INVALID_IMPORTANCE_OR_INTERACTION:{row_identity}"));
        }
        if row.partial_dependence.iter().any(|point| {
            point.feature.trim().is_empty()
                || point.fold != row.fold
                || !point.feature_value.is_finite()
                || !point.average_prediction.is_finite()
                || !(0.0..=1.0).contains(&point.average_prediction)
        }) {
            reasons.push(format!("INVALID_PARTIAL_DEPENDENCE_POINT:{row_identity}"));
        }

        let contract = FoldSampleContract {
            validation_sample_ids: row.validation_sample_ids.clone(),
            validation_labels: row.validation_labels.clone(),
            test_sample_ids: row.test_sample_ids.clone(),
            test_labels: row.test_labels.clone(),
        };
        if let Some(expected) = fold_contracts.get(&row.fold) {
            if row.validation_sample_ids != expected.validation_sample_ids {
                reasons.push(format!(
                    "VALIDATION_SAMPLE_IDS_DIFFER_WITHIN_FOLD:FOLD{}",
                    row.fold
                ));
            }
            if row.validation_labels != expected.validation_labels {
                reasons.push(format!(
                    "VALIDATION_LABELS_DIFFER_WITHIN_FOLD:FOLD{}",
                    row.fold
                ));
            }
            if row.test_sample_ids != expected.test_sample_ids {
                reasons.push(format!(
                    "TEST_SAMPLE_IDS_DIFFER_WITHIN_FOLD:FOLD{}",
                    row.fold
                ));
            }
            if row.test_labels != expected.test_labels {
                reasons.push(format!("TEST_LABELS_DIFFER_WITHIN_FOLD:FOLD{}", row.fold));
            }
        } else {
            fold_contracts.insert(row.fold, contract);
        }
    }

    if !family_folds.contains_key(&baseline) {
        reasons.push("BASELINE_FAMILY_MISSING".to_string());
    }
    if family_folds.len() < 2 {
        reasons.push("MODEL_COMPARISON_REQUIRES_BASELINE_AND_CHALLENGER".to_string());
    }
    let expected_folds = family_folds
        .values()
        .flat_map(BTreeSet::iter)
        .copied()
        .collect::<BTreeSet<_>>();
    if expected_folds.len() < 2 {
        reasons.push("INSUFFICIENT_COMPLETE_FOLDS".to_string());
    }
    for (family, folds) in &family_folds {
        if *folds != expected_folds {
            reasons.push(format!("INCOMPLETE_FOLD_COVERAGE:{}", family_name(*family)));
        }
    }
    reasons.sort();
    reasons.dedup();
    reasons
}

fn monotonicity_violations(
    points: &[PartialDependencePoint],
    constraints: &[MonotonicConstraint],
    fold: usize,
) -> Vec<String> {
    let mut output = Vec::new();
    for constraint in constraints.iter().filter(|row| row.economically_required) {
        if constraint.feature.trim().is_empty() || !matches!(constraint.direction, -1 | 1) {
            output.push(format!(
                "{}:fold{fold}:INVALID_REQUIRED_MONOTONIC_CONSTRAINT",
                constraint.feature
            ));
            continue;
        }
        let mut rows = points
            .iter()
            .filter(|row| {
                row.fold == fold
                    && row.feature == constraint.feature
                    && row.feature_value.is_finite()
                    && row.average_prediction.is_finite()
            })
            .collect::<Vec<_>>();
        rows.sort_by(|left, right| left.feature_value.total_cmp(&right.feature_value));
        let distinct_values = rows.iter().map(|row| row.feature_value).collect::<Vec<_>>();
        let distinct_count = distinct_values
            .windows(2)
            .filter(|pair| pair[0].total_cmp(&pair[1]).is_ne())
            .count()
            + usize::from(!distinct_values.is_empty());
        if distinct_count < 2 {
            output.push(format!(
                "{}:fold{fold}:MISSING_REQUIRED_PARTIAL_DEPENDENCE_EVIDENCE",
                constraint.feature
            ));
            continue;
        }
        for pair in rows.windows(2) {
            if pair[0]
                .feature_value
                .total_cmp(&pair[1].feature_value)
                .is_eq()
            {
                continue;
            }
            let delta = pair[1].average_prediction - pair[0].average_prediction;
            if (constraint.direction > 0 && delta < -1.0e-8)
                || (constraint.direction < 0 && delta > 1.0e-8)
            {
                output.push(format!(
                    "{}:fold{}:{:.6}->{:.6}",
                    constraint.feature, fold, pair[0].feature_value, pair[1].feature_value
                ));
            }
        }
    }
    output.sort();
    output.dedup();
    output
}

fn family_average(
    audits: &[ModelFoldAudit],
    family: ModelFamily,
    pick: fn(&ModelFoldAudit) -> f64,
) -> Option<f64> {
    let values = audits
        .iter()
        .filter(|row| row.family == family)
        .map(pick)
        .collect::<Vec<_>>();
    if values.is_empty() || values.iter().any(|value| !value.is_finite()) {
        return None;
    }
    let count = values.len() as f64;
    let mean = values.iter().map(|value| *value / count).sum::<f64>();
    mean.is_finite().then_some(mean)
}

fn prediction_disagreement(rows: &[ModelFoldPredictions], contract_valid: bool) -> f64 {
    if !contract_valid {
        return 0.0;
    }
    let mut by_fold = BTreeMap::<usize, Vec<&ModelFoldPredictions>>::new();
    for row in rows {
        by_fold.entry(row.fold).or_default().push(row);
    }
    let mut variances = Vec::new();
    for fold_rows in by_fold.values() {
        let observations = fold_rows
            .first()
            .map(|row| row.test_probabilities.len())
            .unwrap_or_default();
        for observation in 0..observations {
            let mean = fold_rows
                .iter()
                .map(|row| row.test_probabilities[observation])
                .sum::<f64>()
                / fold_rows.len() as f64;
            let variance = fold_rows
                .iter()
                .map(|row| (row.test_probabilities[observation] - mean).powi(2))
                .sum::<f64>()
                / fold_rows.len() as f64;
            variances.push(variance);
        }
    }
    if variances.is_empty() {
        0.0
    } else {
        (variances.iter().sum::<f64>() / variances.len() as f64).sqrt()
    }
}

pub fn compare_models(
    rows: &[ModelFoldPredictions],
    constraints: &[MonotonicConstraint],
    baseline: ModelFamily,
) -> NonlinearModelComparison {
    let mut reasons = comparison_contract_reasons(rows, constraints, baseline);
    let contract_valid = reasons.is_empty();
    let mut ordered_rows = rows.iter().collect::<Vec<_>>();
    ordered_rows.sort_by_key(|row| (row.fold, row.family));

    let mut audits = Vec::new();
    let mut previous_importance = BTreeMap::<ModelFamily, BTreeMap<String, f64>>::new();
    let mut previous_interactions = BTreeMap::<ModelFamily, BTreeMap<String, f64>>::new();
    for row in ordered_rows {
        let (validation_log_loss, validation_brier) =
            metrics(&row.validation_probabilities, &row.validation_labels)
                .unwrap_or((INVALID_METRIC, INVALID_METRIC));
        let (test_log_loss, test_brier) = metrics(&row.test_probabilities, &row.test_labels)
            .unwrap_or((INVALID_METRIC, INVALID_METRIC));
        let importance_stability = previous_importance
            .get(&row.family)
            .and_then(|previous| vector_similarity(previous, &row.feature_importance));
        let interaction_stability = previous_interactions
            .get(&row.family)
            .and_then(|previous| vector_similarity(previous, &row.interaction_strength));
        previous_importance.insert(row.family, row.feature_importance.clone());
        previous_interactions.insert(row.family, row.interaction_strength.clone());
        audits.push(ModelFoldAudit {
            family: row.family,
            fold: row.fold,
            validation_log_loss,
            validation_brier,
            test_log_loss,
            test_brier,
            monotonicity_violations: monotonicity_violations(
                &row.partial_dependence,
                constraints,
                row.fold,
            ),
            feature_importance_stability_to_previous_fold: importance_stability,
            interaction_stability_to_previous_fold: interaction_stability,
            test_was_used_for_tuning: row.test_was_used_for_tuning,
        });
    }

    let families = audits.iter().map(|row| row.family).collect::<BTreeSet<_>>();
    let validation_selected_family = contract_valid
        .then(|| {
            families
                .iter()
                .copied()
                .filter(|family| {
                    audits
                        .iter()
                        .filter(|row| row.family == *family)
                        .all(|row| {
                            !row.test_was_used_for_tuning
                                && row.monotonicity_violations.is_empty()
                                && row.validation_log_loss != INVALID_METRIC
                        })
                })
                .min_by(|left, right| {
                    family_average(&audits, *left, |row| row.validation_log_loss)
                        .unwrap_or(INVALID_METRIC)
                        .total_cmp(
                            &family_average(&audits, *right, |row| row.validation_log_loss)
                                .unwrap_or(INVALID_METRIC),
                        )
                })
        })
        .flatten();

    let average_test_log_loss_by_family = families
        .iter()
        .map(|family| {
            (
                *family,
                family_average(&audits, *family, |row| row.test_log_loss).unwrap_or(INVALID_METRIC),
            )
        })
        .collect::<BTreeMap<_, _>>();
    let average_test_brier_by_family = families
        .iter()
        .map(|family| {
            (
                *family,
                family_average(&audits, *family, |row| row.test_brier).unwrap_or(INVALID_METRIC),
            )
        })
        .collect::<BTreeMap<_, _>>();
    let model_disagreement = prediction_disagreement(rows, contract_valid);

    if rows.iter().any(|row| row.test_was_used_for_tuning) {
        reasons.push("TEST_PERIOD_USED_FOR_TUNING".to_string());
    }
    let selected = validation_selected_family;
    if selected.is_none() {
        reasons.push("NO_VALIDATION_ELIGIBLE_MODEL".to_string());
    }
    if let Some(selected) = selected {
        let selected_loss = average_test_log_loss_by_family.get(&selected).copied();
        let baseline_loss = average_test_log_loss_by_family.get(&baseline).copied();
        if !matches!((selected_loss, baseline_loss), (Some(selected), Some(baseline)) if selected < baseline)
        {
            reasons.push("VALIDATION_SELECTED_MODEL_DOES_NOT_BEAT_TEST_BASELINE".to_string());
        }
        let selected_audits = audits
            .iter()
            .filter(|row| row.family == selected)
            .collect::<Vec<_>>();
        if selected_audits.iter().any(|row| {
            row.feature_importance_stability_to_previous_fold
                .is_some_and(|value| value < 0.25)
                || row
                    .interaction_stability_to_previous_fold
                    .is_some_and(|value| value < 0.10)
        }) {
            reasons.push("FEATURE_OR_INTERACTION_IMPORTANCE_UNSTABLE_ACROSS_FOLDS".to_string());
        }
    }
    reasons.sort();
    reasons.dedup();

    NonlinearModelComparison {
        folds: audits,
        validation_selected_family: selected,
        average_test_log_loss_by_family,
        average_test_brier_by_family,
        model_disagreement,
        promotion_status: if reasons.is_empty() {
            "OOS_CHALLENGER_FORWARD_SHADOW_REQUIRED"
        } else {
            "REJECTED"
        }
        .to_string(),
        rejection_reasons: reasons,
        interpretation_policy:
            "PARTIAL_DEPENDENCE_AND_LOCAL_CONTRIBUTIONS_ARE_EXPLANATION_ONLY_NOT_CAUSAL"
                .to_string(),
        sde_usage_policy:
            "SDE_ALLOWED_ONLY_FOR_PATH_SCENARIO_VOLATILITY_BARRIER_BASELINE_AND_RESIDUAL_DIAGNOSTICS"
                .to_string(),
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{
        ModelFamily, ModelFoldPredictions, MonotonicConstraint, PartialDependencePoint,
        compare_models,
    };

    fn sample_ids(prefix: &str, fold: usize) -> Vec<String> {
        (0..4)
            .map(|index| format!("{prefix}-fold{fold}-sample{index}"))
            .collect()
    }

    fn row(family: ModelFamily, fold: usize, probabilities: Vec<f64>) -> ModelFoldPredictions {
        ModelFoldPredictions {
            family,
            fold,
            validation_sample_ids: sample_ids("validation", fold),
            validation_probabilities: probabilities.clone(),
            validation_labels: vec![0.0, 1.0, 0.0, 1.0],
            test_sample_ids: sample_ids("test", fold),
            test_probabilities: probabilities,
            test_labels: vec![0.0, 1.0, 0.0, 1.0],
            feature_importance: BTreeMap::from([("ret_5m".into(), 1.0)]),
            interaction_strength: BTreeMap::new(),
            partial_dependence: Vec::new(),
            test_was_used_for_tuning: false,
        }
    }

    fn complete_rows() -> Vec<ModelFoldPredictions> {
        [1, 2]
            .into_iter()
            .flat_map(|fold| {
                [
                    row(
                        ModelFamily::RegularizedLinearLogistic,
                        fold,
                        vec![0.4, 0.6, 0.4, 0.6],
                    ),
                    row(
                        ModelFamily::GradientBoostedTrees,
                        fold,
                        vec![0.2, 0.8, 0.2, 0.8],
                    ),
                ]
            })
            .collect()
    }

    #[test]
    fn validation_selects_but_test_baseline_remains_promotion_gate() {
        let report = compare_models(
            &complete_rows(),
            &[],
            ModelFamily::RegularizedLinearLogistic,
        );
        assert_eq!(
            report.validation_selected_family,
            Some(ModelFamily::GradientBoostedTrees)
        );
        assert_eq!(
            report.promotion_status,
            "OOS_CHALLENGER_FORWARD_SHADOW_REQUIRED"
        );
        assert!(report.model_disagreement > 0.0);
    }

    #[test]
    fn mismatched_sample_contract_is_rejected() {
        let mut rows = complete_rows();
        rows[1].validation_sample_ids[0] = "different-sample".into();
        rows[1].validation_labels[0] = 1.0;
        let report = compare_models(&rows, &[], ModelFamily::RegularizedLinearLogistic);
        assert_eq!(report.promotion_status, "REJECTED");
        assert_eq!(report.validation_selected_family, None);
        assert!(
            report
                .rejection_reasons
                .iter()
                .any(|reason| reason.starts_with("VALIDATION_SAMPLE_IDS_DIFFER_WITHIN_FOLD"))
        );
        assert!(
            report
                .rejection_reasons
                .iter()
                .any(|reason| reason.starts_with("VALIDATION_LABELS_DIFFER_WITHIN_FOLD"))
        );
    }

    #[test]
    fn invalid_probability_or_vector_length_is_rejected() {
        let mut rows = complete_rows();
        rows[0].validation_probabilities[0] = f64::NAN;
        rows[0].test_probabilities.pop();
        let report = compare_models(&rows, &[], ModelFamily::RegularizedLinearLogistic);
        assert_eq!(report.promotion_status, "REJECTED");
        assert!(
            report
                .rejection_reasons
                .iter()
                .any(|reason| reason.starts_with("INVALID_FORECAST_PROBABILITY"))
        );
        assert!(
            report
                .rejection_reasons
                .iter()
                .any(|reason| reason.starts_with("EVALUATION_VECTOR_LENGTH_MISMATCH"))
        );
        assert!(
            report
                .folds
                .iter()
                .all(|row| row.validation_log_loss.is_finite())
        );
    }

    #[test]
    fn missing_family_fold_is_rejected() {
        let mut rows = complete_rows();
        rows.retain(|row| !(row.family == ModelFamily::GradientBoostedTrees && row.fold == 2));
        let report = compare_models(&rows, &[], ModelFamily::RegularizedLinearLogistic);
        assert_eq!(report.promotion_status, "REJECTED");
        assert!(
            report
                .rejection_reasons
                .iter()
                .any(|reason| reason == "INCOMPLETE_FOLD_COVERAGE:GRADIENTBOOSTEDTREES")
        );
    }

    #[test]
    fn required_monotonic_constraint_needs_fold_level_pdp_evidence() {
        let constraint = MonotonicConstraint {
            feature: "ret_5m".into(),
            direction: 1,
            economically_required: true,
        };
        let report = compare_models(
            &complete_rows(),
            &[constraint],
            ModelFamily::RegularizedLinearLogistic,
        );
        assert_eq!(report.promotion_status, "REJECTED");
        assert_eq!(report.validation_selected_family, None);
        assert!(report.folds.iter().all(|row| {
            row.monotonicity_violations
                .iter()
                .any(|reason| reason.contains("MISSING_REQUIRED_PARTIAL_DEPENDENCE_EVIDENCE"))
        }));
    }

    #[test]
    fn required_monotonic_constraint_passes_with_ordered_evidence() {
        let mut rows = complete_rows();
        for row in &mut rows {
            row.partial_dependence = vec![
                PartialDependencePoint {
                    feature: "ret_5m".into(),
                    feature_value: -1.0,
                    average_prediction: 0.4,
                    fold: row.fold,
                },
                PartialDependencePoint {
                    feature: "ret_5m".into(),
                    feature_value: 1.0,
                    average_prediction: 0.6,
                    fold: row.fold,
                },
            ];
        }
        let report = compare_models(
            &rows,
            &[MonotonicConstraint {
                feature: "ret_5m".into(),
                direction: 1,
                economically_required: true,
            }],
            ModelFamily::RegularizedLinearLogistic,
        );
        assert_eq!(
            report.validation_selected_family,
            Some(ModelFamily::GradientBoostedTrees)
        );
        assert_eq!(
            report.promotion_status,
            "OOS_CHALLENGER_FORWARD_SHADOW_REQUIRED"
        );
    }
}

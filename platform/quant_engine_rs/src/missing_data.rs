use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ImputationMethod {
    None,
    ForwardFill,
    SeasonalTimeOfDayMedian,
    ModelBased,
    MultipleImputation,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AuditedValue {
    pub value: Option<f64>,
    pub value_observed: bool,
    pub value_imputed: bool,
    pub imputation_method: ImputationMethod,
    pub imputation_uncertainty: Option<f64>,
    pub original_availability_status: String,
    pub eligible_for_live_qualification: bool,
}

impl AuditedValue {
    pub fn observed(value: f64) -> Self {
        Self {
            value: value.is_finite().then_some(value),
            value_observed: value.is_finite(),
            value_imputed: false,
            imputation_method: ImputationMethod::None,
            imputation_uncertainty: None,
            original_availability_status: if value.is_finite() {
                "OBSERVED"
            } else {
                "INVALID_NON_FINITE"
            }
            .to_string(),
            eligible_for_live_qualification: value.is_finite(),
        }
    }

    pub fn missing(status: impl Into<String>) -> Self {
        Self {
            value: None,
            value_observed: false,
            value_imputed: false,
            imputation_method: ImputationMethod::None,
            imputation_uncertainty: None,
            original_availability_status: status.into(),
            eligible_for_live_qualification: false,
        }
    }

    /// Records an imputed value under an explicit, pre-registered live policy.
    ///
    /// This constructor never makes model-based or multiple-imputation values
    /// live-eligible. Critical fields are still rejected by
    /// [`live_qualification_reasons`] even when this flag is true.
    pub fn imputed(
        value: f64,
        method: ImputationMethod,
        uncertainty: f64,
        live_uncertainty_limit: f64,
    ) -> Self {
        Self::imputed_with_live_policy(value, method, uncertainty, Some(live_uncertainty_limit))
    }

    fn imputed_with_live_policy(
        value: f64,
        method: ImputationMethod,
        uncertainty: f64,
        live_uncertainty_limit: Option<f64>,
    ) -> Self {
        let uncertainty_is_valid = uncertainty.is_finite() && uncertainty >= 0.0;
        let limit_is_valid = match live_uncertainty_limit {
            Some(limit) => limit.is_finite() && limit >= 0.0,
            None => true,
        };
        let input_is_valid = value.is_finite()
            && method != ImputationMethod::None
            && uncertainty_is_valid
            && limit_is_valid;
        if !input_is_valid {
            return Self {
                value: None,
                value_observed: false,
                value_imputed: true,
                imputation_method: method,
                imputation_uncertainty: uncertainty_is_valid.then_some(uncertainty),
                original_availability_status: "INVALID_IMPUTATION_INPUT".to_string(),
                eligible_for_live_qualification: false,
            };
        }

        Self {
            value: Some(value),
            value_observed: false,
            value_imputed: true,
            imputation_method: method,
            imputation_uncertainty: Some(uncertainty),
            original_availability_status: "MISSING_AT_DECISION_TIME".to_string(),
            eligible_for_live_qualification: live_uncertainty_limit
                .is_some_and(|limit| uncertainty <= limit)
                && matches!(
                    method,
                    ImputationMethod::ForwardFill | ImputationMethod::SeasonalTimeOfDayMedian
                ),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ImputationAblationResult {
    pub no_imputation_metric: Option<f64>,
    pub simple_imputation_metric: Option<f64>,
    pub model_imputation_metric: Option<f64>,
    pub maximum_metric_spread: Option<f64>,
    pub stable_across_methods: bool,
    pub status: String,
}

pub fn audit_ablation(
    no_imputation: Option<f64>,
    simple: Option<f64>,
    model: Option<f64>,
    tolerance: f64,
) -> ImputationAblationResult {
    let raw = [no_imputation, simple, model];
    let invalid_metric = raw
        .iter()
        .any(|value| value.is_some_and(|candidate| !candidate.is_finite()));
    let tolerance_is_valid = tolerance.is_finite() && tolerance >= 0.0;
    let normalized = raw.map(|value| value.filter(|candidate| candidate.is_finite()));
    let valid = normalized.iter().flatten().copied().collect::<Vec<_>>();
    let complete = valid.len() == 3 && !invalid_metric && tolerance_is_valid;
    let spread = complete.then(|| {
        valid.iter().copied().fold(f64::NEG_INFINITY, f64::max)
            - valid.iter().copied().fold(f64::INFINITY, f64::min)
    });
    let stable = complete && spread.is_some_and(|value| value <= tolerance);
    let status = if invalid_metric || !tolerance_is_valid {
        "INVALID_ABLATION_INPUT"
    } else if stable {
        "STABLE_ACROSS_IMPUTATION_METHODS"
    } else if complete {
        "UNSTABLE_IMPUTATION_SENSITIVE"
    } else {
        "INCOMPLETE_ABLATION"
    };

    ImputationAblationResult {
        no_imputation_metric: normalized[0],
        simple_imputation_metric: normalized[1],
        model_imputation_metric: normalized[2],
        maximum_metric_spread: spread,
        stable_across_methods: stable,
        status: status.to_string(),
    }
}

/// Point-in-time seasonal imputation using only prior values from the same
/// minute bucket. The returned MAD uncertainty is research-only by default.
pub fn seasonal_median(history: &[f64], minimum_samples: usize) -> AuditedValue {
    seasonal_median_with_policy(history, minimum_samples, None)
}

/// Seasonal imputation with an explicit fixed live uncertainty threshold.
///
/// Callers must choose the threshold outside the test period. Critical fields
/// remain ineligible regardless of this value.
pub fn seasonal_median_with_live_limit(
    history: &[f64],
    minimum_samples: usize,
    live_uncertainty_limit: f64,
) -> AuditedValue {
    seasonal_median_with_policy(history, minimum_samples, Some(live_uncertainty_limit))
}

fn median_of_sorted(values: &[f64]) -> f64 {
    let middle = values.len() / 2;
    if values.len().is_multiple_of(2) {
        (values[middle - 1] + values[middle]) / 2.0
    } else {
        values[middle]
    }
}

fn seasonal_median_with_policy(
    history: &[f64],
    minimum_samples: usize,
    live_uncertainty_limit: Option<f64>,
) -> AuditedValue {
    if minimum_samples == 0 {
        return AuditedValue::missing("INVALID_MINIMUM_SAMPLES");
    }
    let mut values = history
        .iter()
        .copied()
        .filter(|value| value.is_finite())
        .collect::<Vec<_>>();
    if values.len() < minimum_samples {
        return AuditedValue::missing("INSUFFICIENT_PRIOR_SEASONAL_HISTORY");
    }
    values.sort_by(f64::total_cmp);
    let median = median_of_sorted(&values);
    let mut deviations = values
        .iter()
        .map(|value| (value - median).abs())
        .collect::<Vec<_>>();
    deviations.sort_by(f64::total_cmp);
    let uncertainty = 1.4826 * median_of_sorted(&deviations);
    AuditedValue::imputed_with_live_policy(
        median,
        ImputationMethod::SeasonalTimeOfDayMedian,
        uncertainty,
        live_uncertainty_limit,
    )
}

pub fn live_qualification_reasons(
    fields: &BTreeMap<String, AuditedValue>,
    critical_fields: &[&str],
) -> Vec<String> {
    let mut reasons = critical_fields
        .iter()
        .filter_map(|field| match fields.get(*field) {
            Some(value) if value.value_observed && value.eligible_for_live_qualification => None,
            Some(value) if value.value_imputed => Some(format!("CRITICAL_FIELD_IMPUTED:{field}")),
            Some(_) => Some(format!("CRITICAL_FIELD_UNOBSERVED:{field}")),
            None => Some(format!("CRITICAL_FIELD_ABSENT:{field}")),
        })
        .collect::<Vec<_>>();
    reasons.sort();
    reasons.dedup();
    reasons
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use super::{
        AuditedValue, ImputationMethod, audit_ablation, live_qualification_reasons,
        seasonal_median, seasonal_median_with_live_limit,
    };

    #[test]
    fn critical_market_values_cannot_hide_imputation() {
        let mut fields = BTreeMap::new();
        fields.insert("price".into(), AuditedValue::observed(100.0));
        fields.insert("volume".into(), seasonal_median(&[10.0, 11.0, 12.0], 3));
        assert_eq!(
            live_qualification_reasons(&fields, &["price", "volume"]),
            vec!["CRITICAL_FIELD_IMPUTED:volume"]
        );
    }

    #[test]
    fn ablation_marks_method_sensitive_results_unstable() {
        let result = audit_ablation(Some(0.1), Some(0.11), Some(0.3), 0.05);
        assert!(!result.stable_across_methods);
        assert_eq!(result.status, "UNSTABLE_IMPUTATION_SENSITIVE");
    }

    #[test]
    fn invalid_imputation_inputs_never_become_live_eligible() {
        let negative_uncertainty =
            AuditedValue::imputed(1.0, ImputationMethod::ForwardFill, -0.1, 0.2);
        assert_eq!(
            negative_uncertainty.original_availability_status,
            "INVALID_IMPUTATION_INPUT"
        );
        assert!(negative_uncertainty.value.is_none());
        assert!(!negative_uncertainty.eligible_for_live_qualification);

        let nan_limit = AuditedValue::imputed(1.0, ImputationMethod::ForwardFill, 0.1, f64::NAN);
        assert!(!nan_limit.eligible_for_live_qualification);
        assert_eq!(
            nan_limit.original_availability_status,
            "INVALID_IMPUTATION_INPUT"
        );

        let no_method = AuditedValue::imputed(1.0, ImputationMethod::None, 0.1, 0.2);
        assert_eq!(
            no_method.original_availability_status,
            "INVALID_IMPUTATION_INPUT"
        );
    }

    #[test]
    fn seasonal_imputation_requires_an_explicit_live_policy() {
        let research_only = seasonal_median(&[10.0, 11.0, 12.0], 3);
        assert!(!research_only.eligible_for_live_qualification);

        let live = seasonal_median_with_live_limit(&[10.0, 11.0, 12.0], 3, 2.0);
        assert!(live.eligible_for_live_qualification);
        assert_eq!(live.value, Some(11.0));
    }

    #[test]
    fn seasonal_imputation_rejects_zero_minimum_samples() {
        let result = seasonal_median(&[], 0);
        assert_eq!(
            result.original_availability_status,
            "INVALID_MINIMUM_SAMPLES"
        );
    }

    #[test]
    fn ablation_rejects_non_finite_metrics_and_tolerance() {
        let bad_metric = audit_ablation(Some(0.1), Some(f64::NAN), Some(0.2), 0.05);
        assert_eq!(bad_metric.status, "INVALID_ABLATION_INPUT");
        assert!(bad_metric.simple_imputation_metric.is_none());
        assert!(bad_metric.maximum_metric_spread.is_none());

        let bad_tolerance = audit_ablation(Some(0.1), Some(0.1), Some(0.1), -0.01);
        assert_eq!(bad_tolerance.status, "INVALID_ABLATION_INPUT");
        assert!(!bad_tolerance.stable_across_methods);
    }
}

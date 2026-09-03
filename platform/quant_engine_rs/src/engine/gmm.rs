//! Point-in-time Gaussian-mixture regime description.
//!
//! This module intentionally does not expose a transition forecast. A GMM
//! treats observations as conditionally independent; temporal forecasting
//! belongs to the HMM layer in `engine::regime`.

use anyhow::{Context, Result, bail};
use serde::{Deserialize, Serialize};

const VARIANCE_FLOOR: f64 = 1.0e-4;
const WEIGHT_FLOOR: f64 = 1.0e-12;

/// Public 17-factor schema described in Two Sigma's 2021 regime paper. Axio
/// does not claim this data is available until a point-in-time factor archive
/// has passed its own data-capability checks.
pub const PUBLIC_GMM4_FACTOR_SCHEMA: [&str; 17] = [
    "global_equity",
    "interest_rates",
    "credit",
    "commodities",
    "emerging_markets",
    "foreign_currency",
    "local_inflation",
    "local_equity",
    "equity_short_volatility",
    "fixed_income_carry",
    "fx_carry",
    "trend_following",
    "low_risk",
    "momentum",
    "quality",
    "value",
    "small_cap",
];

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GaussianMixture {
    pub components: usize,
    pub dimensions: usize,
    pub weights: Vec<f64>,
    pub means: Vec<Vec<f64>>,
    pub variances: Vec<Vec<f64>>,
    pub center: Vec<f64>,
    pub scale: Vec<f64>,
    pub log_likelihood: f64,
    pub bic: f64,
    pub training_likelihoods: Vec<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GmmCandidateScore {
    pub components: usize,
    pub training_bic: Option<f64>,
    pub validation_average_log_likelihood: Option<f64>,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GmmSelectionReport {
    pub selected_components: usize,
    pub selection_criterion: String,
    pub candidate_scores: Vec<GmmCandidateScore>,
    pub semantics: String,
}

fn validate_observations(observations: &[Vec<f64>]) -> Result<usize> {
    let dimensions = observations
        .first()
        .map(Vec::len)
        .context("GMM requires observations")?;
    if dimensions == 0
        || observations
            .iter()
            .any(|row| row.len() != dimensions || row.iter().any(|value| !value.is_finite()))
    {
        bail!("GMM observations must be finite and rectangular");
    }
    Ok(dimensions)
}

fn standardization(observations: &[Vec<f64>], dimensions: usize) -> (Vec<f64>, Vec<f64>) {
    let count = observations.len() as f64;
    let mut center = vec![0.0; dimensions];
    for row in observations {
        for (column, value) in row.iter().enumerate() {
            center[column] += value;
        }
    }
    for value in &mut center {
        *value /= count;
    }
    let mut scale = vec![0.0; dimensions];
    for row in observations {
        for column in 0..dimensions {
            scale[column] += (row[column] - center[column]).powi(2);
        }
    }
    for value in &mut scale {
        *value = (*value / count).sqrt().max(1.0e-8);
    }
    (center, scale)
}

fn standardized(observations: &[Vec<f64>], center: &[f64], scale: &[f64]) -> Vec<Vec<f64>> {
    observations
        .iter()
        .map(|row| {
            row.iter()
                .enumerate()
                .map(|(column, value)| (value - center[column]) / scale[column])
                .collect()
        })
        .collect()
}

fn log_sum_exp(values: &[f64]) -> f64 {
    let maximum = values.iter().copied().fold(f64::NEG_INFINITY, f64::max);
    if !maximum.is_finite() {
        return f64::NEG_INFINITY;
    }
    maximum
        + values
            .iter()
            .map(|value| (*value - maximum).exp())
            .sum::<f64>()
            .max(WEIGHT_FLOOR)
            .ln()
}

impl GaussianMixture {
    pub fn fit(
        observations: &[Vec<f64>],
        components: usize,
        max_iterations: usize,
        restarts: usize,
    ) -> Result<Self> {
        if !(2..=12).contains(&components) {
            bail!("GMM components must be between 2 and 12");
        }
        let dimensions = validate_observations(observations)?;
        if observations.len() < components * 8 {
            bail!("GMM needs at least eight observations per component");
        }
        let (center, scale) = standardization(observations, dimensions);
        let normalized = standardized(observations, &center, &scale);
        let mut best = None;
        for restart in 0..restarts.max(1) {
            let mut model = Self::initialized(
                &normalized,
                components,
                dimensions,
                restart,
                center.clone(),
                scale.clone(),
            );
            let mut previous = f64::NEG_INFINITY;
            for _ in 0..max_iterations.max(1) {
                let (responsibilities, _) = model.expectation(&normalized);
                model.maximization(&normalized, &responsibilities);
                let (_, likelihood) = model.expectation(&normalized);
                if !likelihood.is_finite() {
                    break;
                }
                model.log_likelihood = likelihood;
                model.training_likelihoods.push(likelihood);
                if (likelihood - previous).abs() <= 1.0e-6 * (1.0 + likelihood.abs()) {
                    break;
                }
                previous = likelihood;
            }
            let parameters = (components - 1) + components * dimensions + components * dimensions;
            model.bic =
                parameters as f64 * (observations.len() as f64).ln() - 2.0 * model.log_likelihood;
            if model.log_likelihood.is_finite()
                && best
                    .as_ref()
                    .is_none_or(|current: &Self| model.log_likelihood > current.log_likelihood)
            {
                best = Some(model);
            }
        }
        best.context("GMM optimization did not produce a finite model")
    }

    fn initialized(
        observations: &[Vec<f64>],
        components: usize,
        dimensions: usize,
        restart: usize,
        center: Vec<f64>,
        scale: Vec<f64>,
    ) -> Self {
        let mut ordered = observations.iter().collect::<Vec<_>>();
        ordered.sort_by(|left, right| left[0].total_cmp(&right[0]));
        let means = (0..components)
            .map(|component| {
                let shifted = (component + restart) % components;
                let rank =
                    ((shifted + 1) * ordered.len() / (components + 1)).min(ordered.len() - 1);
                ordered[rank].clone()
            })
            .collect();
        Self {
            components,
            dimensions,
            weights: vec![1.0 / components as f64; components],
            means,
            variances: vec![vec![1.0; dimensions]; components],
            center,
            scale,
            log_likelihood: f64::NEG_INFINITY,
            bic: f64::INFINITY,
            training_likelihoods: Vec::new(),
        }
    }

    fn component_log_probability(&self, observation: &[f64], component: usize) -> f64 {
        self.weights[component].max(WEIGHT_FLOOR).ln()
            + (0..self.dimensions)
                .map(|column| {
                    let variance = self.variances[component][column].max(VARIANCE_FLOOR);
                    -0.5 * ((2.0 * std::f64::consts::PI * variance).ln()
                        + (observation[column] - self.means[component][column]).powi(2) / variance)
                })
                .sum::<f64>()
    }

    fn expectation(&self, observations: &[Vec<f64>]) -> (Vec<Vec<f64>>, f64) {
        let mut likelihood = 0.0;
        let responsibilities = observations
            .iter()
            .map(|observation| {
                let logs = (0..self.components)
                    .map(|component| self.component_log_probability(observation, component))
                    .collect::<Vec<_>>();
                let normalizer = log_sum_exp(&logs);
                likelihood += normalizer;
                logs.iter()
                    .map(|value| (*value - normalizer).exp())
                    .collect::<Vec<_>>()
            })
            .collect();
        (responsibilities, likelihood)
    }

    fn maximization(&mut self, observations: &[Vec<f64>], responsibilities: &[Vec<f64>]) {
        let count = observations.len() as f64;
        for component in 0..self.components {
            let component_weight = responsibilities
                .iter()
                .map(|row| row[component])
                .sum::<f64>()
                .max(WEIGHT_FLOOR);
            self.weights[component] = component_weight / count;
            for column in 0..self.dimensions {
                let mean = observations
                    .iter()
                    .zip(responsibilities)
                    .map(|(row, responsibility)| row[column] * responsibility[component])
                    .sum::<f64>()
                    / component_weight;
                self.means[component][column] = mean;
                self.variances[component][column] = observations
                    .iter()
                    .zip(responsibilities)
                    .map(|(row, responsibility)| {
                        responsibility[component] * (row[column] - mean).powi(2)
                    })
                    .sum::<f64>()
                    / component_weight;
                self.variances[component][column] =
                    self.variances[component][column].max(VARIANCE_FLOOR);
            }
        }
        let total = self.weights.iter().sum::<f64>().max(WEIGHT_FLOOR);
        for weight in &mut self.weights {
            *weight /= total;
        }
    }

    pub fn posterior_probabilities(&self, raw_observation: &[f64]) -> Result<Vec<f64>> {
        if raw_observation.len() != self.dimensions
            || raw_observation.iter().any(|value| !value.is_finite())
        {
            bail!("GMM inference observation is invalid");
        }
        let observation = raw_observation
            .iter()
            .enumerate()
            .map(|(column, value)| (value - self.center[column]) / self.scale[column])
            .collect::<Vec<_>>();
        let logs = (0..self.components)
            .map(|component| self.component_log_probability(&observation, component))
            .collect::<Vec<_>>();
        let normalizer = log_sum_exp(&logs);
        Ok(logs
            .iter()
            .map(|value| (*value - normalizer).exp())
            .collect())
    }

    pub fn average_log_likelihood(&self, observations: &[Vec<f64>]) -> Result<f64> {
        let dimensions = validate_observations(observations)?;
        if dimensions != self.dimensions {
            bail!("GMM evaluation dimensions do not match the fitted model");
        }
        let normalized = standardized(observations, &self.center, &self.scale);
        let (_, likelihood) = self.expectation(&normalized);
        Ok(likelihood / observations.len() as f64)
    }
}

/// Chronologically score each K on a held-out suffix, then refit the winning
/// component count on all historical observations. This detects the current
/// mixture component; it does not forecast a future state.
pub fn select_and_refit(
    fit_observations: &[Vec<f64>],
    validation_observations: &[Vec<f64>],
    candidate_components: &[usize],
    max_iterations: usize,
    restarts: usize,
) -> Result<(GaussianMixture, GmmSelectionReport)> {
    if candidate_components.is_empty() {
        bail!("GMM selection requires component candidates");
    }
    let use_validation = !validation_observations.is_empty();
    let mut selected: Option<(usize, f64)> = None;
    let mut scores = Vec::new();
    for components in candidate_components {
        match GaussianMixture::fit(fit_observations, *components, max_iterations, restarts) {
            Ok(model) => {
                let validation_score = use_validation
                    .then(|| model.average_log_likelihood(validation_observations).ok())
                    .flatten();
                let criterion = validation_score.unwrap_or(-model.bic);
                if selected
                    .as_ref()
                    .is_none_or(|(current_components, current_score)| {
                        criterion > *current_score + 1.0e-12
                            || ((criterion - *current_score).abs() <= 1.0e-12
                                && *components < *current_components)
                    })
                {
                    selected = Some((*components, criterion));
                }
                scores.push(GmmCandidateScore {
                    components: *components,
                    training_bic: model.bic.is_finite().then_some(model.bic),
                    validation_average_log_likelihood: validation_score,
                    status: if validation_score.is_some() {
                        "CHRONOLOGICAL_VALIDATION_SCORED"
                    } else {
                        "BIC_FALLBACK"
                    }
                    .into(),
                });
            }
            Err(_) => scores.push(GmmCandidateScore {
                components: *components,
                training_bic: None,
                validation_average_log_likelihood: None,
                status: "FIT_FAILED_OR_INSUFFICIENT_OBSERVATIONS".into(),
            }),
        }
    }
    let selected_components = selected
        .map(|(components, _)| components)
        .context("no GMM candidate produced a finite score")?;
    let mut all = fit_observations.to_vec();
    all.extend_from_slice(validation_observations);
    let model = GaussianMixture::fit(&all, selected_components, max_iterations, restarts)?;
    Ok((
        model,
        GmmSelectionReport {
            selected_components,
            selection_criterion: if use_validation {
                "MAX_CHRONOLOGICAL_HELD_OUT_AVERAGE_LOG_LIKELIHOOD"
            } else {
                "MIN_BIC_FALLBACK"
            }
            .into(),
            candidate_scores: scores,
            semantics: "CURRENT_STATE_DESCRIPTION_ONLY; IID_MIXTURE; NO_TRANSITION_FORECAST".into(),
        },
    ))
}

#[cfg(test)]
mod tests {
    use super::{GaussianMixture, select_and_refit};

    fn observations() -> Vec<Vec<f64>> {
        (0..240)
            .map(|index| {
                let cluster = if index % 2 == 0 { -2.0 } else { 2.0 };
                vec![
                    cluster + (index % 7) as f64 * 0.01,
                    0.5 * cluster + (index % 5) as f64 * 0.02,
                ]
            })
            .collect()
    }

    #[test]
    fn posterior_is_normalized_and_separates_clusters() {
        let rows = observations();
        let model = GaussianMixture::fit(&rows, 2, 50, 3).unwrap();
        let left = model.posterior_probabilities(&[-2.0, -1.0]).unwrap();
        let right = model.posterior_probabilities(&[2.0, 1.0]).unwrap();
        assert!((left.iter().sum::<f64>() - 1.0).abs() < 1.0e-9);
        assert!((right.iter().sum::<f64>() - 1.0).abs() < 1.0e-9);
        assert_ne!(
            left.iter()
                .enumerate()
                .max_by(|a, b| a.1.total_cmp(b.1))
                .unwrap()
                .0,
            right
                .iter()
                .enumerate()
                .max_by(|a, b| a.1.total_cmp(b.1))
                .unwrap()
                .0
        );
    }

    #[test]
    fn selection_evaluates_four_and_eight_without_forcing_either() {
        let rows = observations();
        let (model, report) =
            select_and_refit(&rows[..180], &rows[180..], &[2, 4, 8], 30, 2).unwrap();
        assert!(matches!(model.components, 2 | 4 | 8));
        assert_eq!(report.candidate_scores.len(), 3);
        assert!(
            report
                .candidate_scores
                .iter()
                .any(|score| score.components == 4)
        );
        assert!(
            report
                .candidate_scores
                .iter()
                .any(|score| score.components == 8)
        );
        assert!(report.semantics.contains("NO_TRANSITION_FORECAST"));
    }
}

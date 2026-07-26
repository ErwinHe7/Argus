use anyhow::{Context, Result, bail};
use serde::{Deserialize, Serialize};

use super::regime::GaussianHmm;

const PROBABILITY_FLOOR: f64 = 1.0e-300;
const STANDARDIZATION_FLOOR: f64 = 1.0e-8;
const VARIANCE_FLOOR: f64 = 1.0e-4;

/// Training controls for the time-varying-transition-probability (TVTP)
/// challenger. The model is intentionally a challenger: fitting it does not
/// authorize promotion into a live forecast committee.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TvtpFitConfig {
    pub max_iterations: usize,
    pub learning_rate: f64,
    pub l2_penalty: f64,
    pub convergence_tolerance: f64,
    pub minimum_row_effective_weight: f64,
    pub maximum_online_covariate_zscore: f64,
}

impl Default for TvtpFitConfig {
    fn default() -> Self {
        Self {
            max_iterations: 75,
            learning_rate: 0.08,
            l2_penalty: 1.0e-3,
            convergence_tolerance: 1.0e-7,
            minimum_row_effective_weight: 20.0,
            maximum_online_covariate_zscore: 6.0,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TvtpFilterResult {
    /// Causal filtering probabilities P(S_t | X_1:t, Z_1:t-1).
    pub filtered_probabilities: Vec<Vec<f64>>,
    /// Matrix used to move from t to t+1. The final observation has no
    /// outgoing matrix and therefore the vector has length T-1.
    pub transition_matrices: Vec<Vec<Vec<f64>>>,
    pub log_likelihood: f64,
    pub maximum_absolute_covariate_zscore: f64,
    pub probability_semantics: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TvtpValidationComparison {
    pub homogeneous_average_log_likelihood: Option<f64>,
    pub tvtp_average_log_likelihood: Option<f64>,
    pub improvement_per_observation: Option<f64>,
    pub selected_for_shadow: bool,
    pub validation_flags: Vec<String>,
    pub selection_semantics: String,
}

/// A non-homogeneous Gaussian HMM challenger.
///
/// Emission parameters remain those of a train-fitted Gaussian HMM. Only the
/// transition rows become time-varying:
///
/// P(S_{t+1}=j | S_t=i, z_t) = softmax_j(beta[i,j]' [1, z_t]).
///
/// Coefficients are estimated from train-only Baum-Welch soft transition
/// counts. Validation and live filtering use forward probabilities only.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct NonHomogeneousGaussianHmm {
    pub emission_model: GaussianHmm,
    /// [from_state][to_state][intercept + covariates]. The final destination
    /// is the reference category and is held at zero for identifiability.
    pub transition_coefficients: Vec<Vec<Vec<f64>>>,
    pub covariate_center: Vec<f64>,
    pub covariate_scale: Vec<f64>,
    pub row_effective_transition_weight: Vec<f64>,
    pub training_cross_entropy: f64,
    pub training_iterations: usize,
    pub fit_config: TvtpFitConfig,
    pub model_semantics: String,
}

fn normalize(values: &mut [f64]) -> f64 {
    let sum = values.iter().sum::<f64>();
    if !sum.is_finite() || sum <= PROBABILITY_FLOOR {
        let uniform = 1.0 / values.len().max(1) as f64;
        values.fill(uniform);
        return PROBABILITY_FLOOR;
    }
    for value in values {
        *value /= sum;
    }
    sum
}

fn softmax(logits: &[f64]) -> Vec<f64> {
    let maximum = logits.iter().copied().fold(f64::NEG_INFINITY, f64::max);
    let mut probabilities = logits
        .iter()
        .map(|value| (value - maximum).exp())
        .collect::<Vec<_>>();
    normalize(&mut probabilities);
    probabilities
}

fn validate_sequences(
    observations: &[Vec<Vec<f64>>],
    covariates: &[Vec<Vec<f64>>],
    observation_dimensions: usize,
) -> Result<usize> {
    if observations.is_empty() || observations.len() != covariates.len() {
        bail!("TVTP observations and covariates require the same nonzero session count");
    }
    let covariate_dimensions = covariates
        .iter()
        .flatten()
        .next()
        .context("TVTP requires transition covariates")?
        .len();
    if covariate_dimensions == 0 {
        bail!("TVTP transition covariates cannot be empty");
    }
    for (observation_session, covariate_session) in observations.iter().zip(covariates) {
        if observation_session.is_empty()
            || observation_session.len() != covariate_session.len()
            || observation_session.iter().any(|row| {
                row.len() != observation_dimensions || row.iter().any(|value| !value.is_finite())
            })
            || covariate_session.iter().any(|row| {
                row.len() != covariate_dimensions || row.iter().any(|value| !value.is_finite())
            })
        {
            bail!("TVTP sessions must be finite, rectangular, and index aligned");
        }
    }
    Ok(covariate_dimensions)
}

fn covariate_standardization(
    covariates: &[Vec<Vec<f64>>],
    dimensions: usize,
) -> Result<(Vec<f64>, Vec<f64>)> {
    let mut center = vec![0.0; dimensions];
    let mut count = 0.0;
    // z_t explains the transition t -> t+1. The final row in each session is
    // deliberately excluded because it has no observed outgoing transition.
    for row in covariates
        .iter()
        .flat_map(|session| session.iter().take(session.len().saturating_sub(1)))
    {
        for (column, value) in row.iter().enumerate() {
            center[column] += value;
        }
        count += 1.0;
    }
    if count < 2.0 {
        bail!("TVTP requires at least two observed transitions");
    }
    for value in &mut center {
        *value /= count;
    }
    let mut scale = vec![0.0; dimensions];
    for row in covariates
        .iter()
        .flat_map(|session| session.iter().take(session.len().saturating_sub(1)))
    {
        for column in 0..dimensions {
            scale[column] += (row[column] - center[column]).powi(2);
        }
    }
    for value in &mut scale {
        *value = (*value / count).sqrt().max(STANDARDIZATION_FLOOR);
    }
    Ok((center, scale))
}

fn standardized_features(row: &[f64], center: &[f64], scale: &[f64]) -> Vec<f64> {
    let mut features = Vec::with_capacity(row.len() + 1);
    features.push(1.0);
    features.extend(
        row.iter()
            .enumerate()
            .map(|(column, value)| (value - center[column]) / scale[column]),
    );
    features
}

impl NonHomogeneousGaussianHmm {
    pub fn fit(
        emission_model: GaussianHmm,
        observations: &[Vec<Vec<f64>>],
        covariates: &[Vec<Vec<f64>>],
        fit_config: TvtpFitConfig,
    ) -> Result<Self> {
        if fit_config.max_iterations == 0
            || !fit_config.learning_rate.is_finite()
            || fit_config.learning_rate <= 0.0
            || !fit_config.l2_penalty.is_finite()
            || fit_config.l2_penalty < 0.0
            || !fit_config.maximum_online_covariate_zscore.is_finite()
            || fit_config.maximum_online_covariate_zscore <= 0.0
        {
            bail!("invalid TVTP fit configuration");
        }
        let covariate_dimensions =
            validate_sequences(observations, covariates, emission_model.dimensions)?;
        let (covariate_center, covariate_scale) =
            covariate_standardization(covariates, covariate_dimensions)?;
        let states = emission_model.states;
        let feature_dimensions = covariate_dimensions + 1;

        // The last destination state is the reference category. Initialize the
        // remaining intercepts from the homogeneous transition matrix.
        let reference = states - 1;
        let mut coefficients = vec![vec![vec![0.0; feature_dimensions]; states]; states];
        for (from, transition_row) in emission_model.transition.iter().enumerate() {
            let reference_probability = transition_row[reference].max(1.0e-12);
            for to in 0..reference {
                coefficients[from][to][0] =
                    (transition_row[to].max(1.0e-12) / reference_probability).ln();
            }
        }

        #[derive(Debug)]
        struct SoftTransitionExample {
            features: Vec<f64>,
            targets: Vec<Vec<f64>>,
        }

        let mut examples = Vec::new();
        let mut row_effective_transition_weight = vec![0.0; states];
        for ((observation_session, covariate_session), session_index) in
            observations.iter().zip(covariates).zip(0_usize..)
        {
            let posterior = emission_model
                .posterior_diagnostics(observation_session)
                .with_context(|| {
                    format!("TVTP posterior diagnostics for session {session_index}")
                })?;
            for (time, xi) in posterior.xi.into_iter().enumerate() {
                let features = standardized_features(
                    &covariate_session[time],
                    &covariate_center,
                    &covariate_scale,
                );
                for from in 0..states {
                    row_effective_transition_weight[from] += xi[from].iter().sum::<f64>();
                }
                examples.push(SoftTransitionExample {
                    features,
                    targets: xi,
                });
            }
        }
        if examples.is_empty() {
            bail!("TVTP fit has no observed transitions");
        }

        let mut previous_loss = f64::INFINITY;
        let mut final_loss = f64::INFINITY;
        let mut training_iterations = 0;
        for iteration in 0..fit_config.max_iterations {
            let mut gradient = vec![vec![vec![0.0; feature_dimensions]; reference]; states];
            let mut loss = 0.0;
            let mut total_weight = 0.0;
            for example in &examples {
                for from in 0..states {
                    let logits = (0..states)
                        .map(|to| {
                            coefficients[from][to]
                                .iter()
                                .zip(&example.features)
                                .map(|(coefficient, feature)| coefficient * feature)
                                .sum::<f64>()
                        })
                        .collect::<Vec<_>>();
                    let probabilities = softmax(&logits);
                    let row_weight = example.targets[from].iter().sum::<f64>();
                    if row_weight <= 1.0e-12 {
                        continue;
                    }
                    total_weight += row_weight;
                    for to in 0..states {
                        let target = example.targets[from][to];
                        if target > 0.0 {
                            loss -= target * probabilities[to].max(PROBABILITY_FLOOR).ln();
                        }
                        if to < reference {
                            let error = row_weight * probabilities[to] - target;
                            for (column, feature) in example.features.iter().copied().enumerate() {
                                gradient[from][to][column] += error * feature;
                            }
                        }
                    }
                }
            }
            if total_weight <= 0.0 || !total_weight.is_finite() {
                bail!("TVTP effective transition weight is invalid");
            }
            for from in 0..states {
                for to in 0..reference {
                    for column in 0..feature_dimensions {
                        let regularization = if column == 0 {
                            0.0
                        } else {
                            fit_config.l2_penalty * coefficients[from][to][column]
                        };
                        gradient[from][to][column] =
                            gradient[from][to][column] / total_weight + regularization;
                        coefficients[from][to][column] -= fit_config.learning_rate
                            * gradient[from][to][column].clamp(-10.0, 10.0);
                    }
                }
            }
            final_loss = loss / total_weight;
            training_iterations = iteration + 1;
            if !final_loss.is_finite() {
                bail!("TVTP optimization produced a non-finite loss");
            }
            if (previous_loss - final_loss).abs()
                <= fit_config.convergence_tolerance * (1.0 + previous_loss.abs())
            {
                break;
            }
            previous_loss = final_loss;
        }

        Ok(Self {
            emission_model,
            transition_coefficients: coefficients,
            covariate_center,
            covariate_scale,
            row_effective_transition_weight,
            training_cross_entropy: final_loss,
            training_iterations,
            fit_config,
            model_semantics:
                "TVTP_NH_HMM_CHALLENGER; TRAIN_SOFT_XI_ONLY; VALIDATION_AND_LIVE_FORWARD_FILTER_ONLY"
                    .into(),
        })
    }

    pub fn transition_matrix(&self, raw_covariates: &[f64]) -> Result<Vec<Vec<f64>>> {
        if raw_covariates.len() != self.covariate_center.len()
            || raw_covariates.iter().any(|value| !value.is_finite())
        {
            bail!("TVTP transition covariates are non-finite or wrong-dimensional");
        }
        let features = standardized_features(
            raw_covariates,
            &self.covariate_center,
            &self.covariate_scale,
        );
        Ok(self
            .transition_coefficients
            .iter()
            .map(|row| {
                let logits = row
                    .iter()
                    .map(|coefficients| {
                        coefficients
                            .iter()
                            .zip(&features)
                            .map(|(coefficient, feature)| coefficient * feature)
                            .sum::<f64>()
                    })
                    .collect::<Vec<_>>();
                softmax(&logits)
            })
            .collect())
    }

    fn emission_probabilities(&self, raw_observation: &[f64]) -> Result<(Vec<f64>, f64)> {
        if raw_observation.len() != self.emission_model.dimensions
            || raw_observation.iter().any(|value| !value.is_finite())
        {
            bail!("TVTP emission observation is non-finite or wrong-dimensional");
        }
        let standardized = raw_observation
            .iter()
            .enumerate()
            .map(|(column, value)| {
                (value - self.emission_model.center[column]) / self.emission_model.scale[column]
            })
            .collect::<Vec<_>>();
        let log_probabilities = (0..self.emission_model.states)
            .map(|state| {
                (0..self.emission_model.dimensions)
                    .map(|column| {
                        let variance =
                            self.emission_model.variances[state][column].max(VARIANCE_FLOOR);
                        -0.5 * ((2.0 * std::f64::consts::PI * variance).ln()
                            + (standardized[column] - self.emission_model.means[state][column])
                                .powi(2)
                                / variance)
                    })
                    .sum::<f64>()
            })
            .collect::<Vec<_>>();
        let maximum = log_probabilities
            .iter()
            .copied()
            .fold(f64::NEG_INFINITY, f64::max);
        let probabilities = log_probabilities
            .iter()
            .map(|value| (value - maximum).exp().max(PROBABILITY_FLOOR))
            .collect();
        Ok((probabilities, maximum))
    }

    pub fn maximum_absolute_covariate_zscore(&self, raw_covariates: &[f64]) -> Result<f64> {
        if raw_covariates.len() != self.covariate_center.len()
            || raw_covariates.iter().any(|value| !value.is_finite())
        {
            bail!("TVTP covariates are non-finite or wrong-dimensional");
        }
        Ok(raw_covariates
            .iter()
            .enumerate()
            .map(|(column, value)| {
                ((value - self.covariate_center[column]) / self.covariate_scale[column]).abs()
            })
            .fold(0.0, f64::max))
    }

    pub fn filter(
        &self,
        observations: &[Vec<f64>],
        covariates: &[Vec<f64>],
    ) -> Result<TvtpFilterResult> {
        if observations.is_empty()
            || observations.len() != covariates.len()
            || covariates.iter().any(|row| {
                row.len() != self.covariate_center.len()
                    || row.iter().any(|value| !value.is_finite())
            })
        {
            bail!("TVTP filter inputs must be nonempty, finite, and index aligned");
        }
        let maximum_absolute_covariate_zscore = covariates
            .iter()
            .map(|row| self.maximum_absolute_covariate_zscore(row))
            .collect::<Result<Vec<_>>>()?
            .into_iter()
            .fold(0.0, f64::max);
        let mut filtered: Vec<Vec<f64>> = Vec::with_capacity(observations.len());
        let mut transition_matrices = Vec::with_capacity(observations.len().saturating_sub(1));
        let mut log_likelihood = 0.0;
        for (time, observation) in observations.iter().enumerate() {
            let (emissions, emission_log_offset) = self.emission_probabilities(observation)?;
            let prior = if time == 0 {
                self.emission_model.initial.clone()
            } else {
                let matrix = self.transition_matrix(&covariates[time - 1])?;
                let previous = filtered
                    .last()
                    .context("TVTP filter is missing its previous probability vector")?;
                let next = (0..self.emission_model.states)
                    .map(|to| {
                        (0..self.emission_model.states)
                            .map(|from| previous[from] * matrix[from][to])
                            .sum::<f64>()
                    })
                    .collect::<Vec<_>>();
                transition_matrices.push(matrix);
                next
            };
            let mut alpha = prior
                .iter()
                .zip(emissions)
                .map(|(probability, emission)| probability * emission)
                .collect::<Vec<_>>();
            let scale = normalize(&mut alpha);
            log_likelihood += scale.max(PROBABILITY_FLOOR).ln() + emission_log_offset;
            filtered.push(alpha);
        }
        Ok(TvtpFilterResult {
            filtered_probabilities: filtered,
            transition_matrices,
            log_likelihood,
            maximum_absolute_covariate_zscore,
            probability_semantics:
                "FORWARD_FILTERED_P_ST_GIVEN_X_1_TO_T_AND_Z_1_TO_T_MINUS_1; NO_SMOOTHING".into(),
        })
    }

    pub fn average_log_likelihood(
        &self,
        observations: &[Vec<Vec<f64>>],
        covariates: &[Vec<Vec<f64>>],
    ) -> Result<f64> {
        validate_sequences(observations, covariates, self.emission_model.dimensions)?;
        let mut total = 0.0;
        let mut count = 0_usize;
        for (observation_session, covariate_session) in observations.iter().zip(covariates) {
            total += self
                .filter(observation_session, covariate_session)?
                .log_likelihood;
            count += observation_session.len();
        }
        if count == 0 {
            bail!("TVTP validation has no observations");
        }
        Ok(total / count as f64)
    }

    /// Forecast with an explicit future transition-covariate path. Callers may
    /// repeat the current covariates, but must then report the frozen-covariate
    /// assumption rather than presenting the path as observed future data.
    pub fn horizon_state_probabilities(
        &self,
        current_probabilities: &[f64],
        future_transition_covariates: &[Vec<f64>],
    ) -> Result<Vec<f64>> {
        if current_probabilities.len() != self.emission_model.states
            || current_probabilities.iter().any(|value| !value.is_finite())
        {
            bail!("TVTP current probability vector is invalid");
        }
        let mut probabilities = current_probabilities.to_vec();
        normalize(&mut probabilities);
        for covariates in future_transition_covariates {
            let matrix = self.transition_matrix(covariates)?;
            probabilities = (0..self.emission_model.states)
                .map(|to| {
                    (0..self.emission_model.states)
                        .map(|from| probabilities[from] * matrix[from][to])
                        .sum::<f64>()
                })
                .collect();
            normalize(&mut probabilities);
        }
        Ok(probabilities)
    }

    pub fn validation_comparison(
        &self,
        validation_observations: &[Vec<Vec<f64>>],
        validation_covariates: &[Vec<Vec<f64>>],
        minimum_improvement_per_observation: f64,
    ) -> TvtpValidationComparison {
        let homogeneous = self
            .emission_model
            .average_log_likelihood(validation_observations)
            .ok();
        let tvtp = self
            .average_log_likelihood(validation_observations, validation_covariates)
            .ok();
        let improvement = homogeneous
            .zip(tvtp)
            .map(|(baseline, challenger)| challenger - baseline);
        let mut validation_flags = Vec::new();
        if homogeneous.is_none() || tvtp.is_none() {
            validation_flags.push("TVTP_VALIDATION_SCORING_FAILED".into());
        }
        if self
            .row_effective_transition_weight
            .iter()
            .any(|weight| *weight < self.fit_config.minimum_row_effective_weight)
        {
            validation_flags.push("NH_HMM_TRANSITION_ROW_UNIDENTIFIED".into());
        }
        if improvement.is_some_and(|value| value < minimum_improvement_per_observation) {
            validation_flags.push("NH_HMM_DID_NOT_BEAT_HOMOGENEOUS_BASELINE".into());
        }
        let selected_for_shadow = validation_flags.is_empty()
            && improvement.is_some_and(|value| value >= minimum_improvement_per_observation);
        TvtpValidationComparison {
            homogeneous_average_log_likelihood: homogeneous,
            tvtp_average_log_likelihood: tvtp,
            improvement_per_observation: improvement,
            selected_for_shadow,
            validation_flags,
            selection_semantics:
                "CHRONOLOGICAL_HELD_OUT_PREQUENTIAL_LOG_LIKELIHOOD; SHADOW_ONLY_UNTIL_OUTER_TEST"
                    .into(),
        }
    }

    pub fn online_validation_flags(&self, raw_covariates: &[f64]) -> Vec<String> {
        let mut flags = Vec::new();
        match self.maximum_absolute_covariate_zscore(raw_covariates) {
            Ok(value) if value > self.fit_config.maximum_online_covariate_zscore => {
                flags.push("NH_HMM_TRANSITION_COVARIATE_OOD".into());
            }
            Err(_) => flags.push("NH_HMM_TRANSITION_COVARIATE_INVALID".into()),
            _ => {}
        }
        if self
            .row_effective_transition_weight
            .iter()
            .any(|weight| *weight < self.fit_config.minimum_row_effective_weight)
        {
            flags.push("NH_HMM_TRANSITION_ROW_UNIDENTIFIED".into());
        }
        flags
    }
}

#[cfg(test)]
mod tests {
    use approx::assert_abs_diff_eq;

    use super::{NonHomogeneousGaussianHmm, TvtpFitConfig};
    use crate::engine::regime::GaussianHmm;

    type SessionMatrix = Vec<Vec<Vec<f64>>>;

    fn baseline() -> GaussianHmm {
        GaussianHmm {
            states: 2,
            dimensions: 1,
            initial: vec![0.5, 0.5],
            transition: vec![vec![0.85, 0.15], vec![0.15, 0.85]],
            means: vec![vec![-1.0], vec![1.0]],
            variances: vec![vec![0.20], vec![0.20]],
            center: vec![0.0],
            scale: vec![1.0],
            log_likelihood: 0.0,
            bic: 0.0,
            training_likelihoods: Vec::new(),
            state_permutation: vec![0, 1],
        }
    }

    fn training_data() -> (SessionMatrix, SessionMatrix) {
        let mut observations = Vec::new();
        let mut covariates = Vec::new();
        for session in 0..6 {
            let mut observation_session = Vec::new();
            let mut covariate_session = Vec::new();
            let mut state = session % 2;
            for time in 0..40 {
                let covariate = if (time / 5 + session) % 2 == 0 {
                    -1.0
                } else {
                    1.0
                };
                observation_session.push(vec![if state == 0 { -1.0 } else { 1.0 }]);
                covariate_session.push(vec![covariate]);
                if covariate > 0.0 {
                    state = 1;
                } else {
                    state = 0;
                }
            }
            observations.push(observation_session);
            covariates.push(covariate_session);
        }
        (observations, covariates)
    }

    fn fitted() -> NonHomogeneousGaussianHmm {
        let (observations, covariates) = training_data();
        NonHomogeneousGaussianHmm::fit(
            baseline(),
            &observations,
            &covariates,
            TvtpFitConfig {
                max_iterations: 120,
                learning_rate: 0.20,
                minimum_row_effective_weight: 2.0,
                ..TvtpFitConfig::default()
            },
        )
        .unwrap()
    }

    #[test]
    fn transition_rows_are_probability_simplexes_and_vary_with_covariates() {
        let model = fitted();
        let negative = model.transition_matrix(&[-1.0]).unwrap();
        let positive = model.transition_matrix(&[1.0]).unwrap();
        for matrix in [&negative, &positive] {
            for row in matrix {
                assert_abs_diff_eq!(row.iter().sum::<f64>(), 1.0, epsilon = 1.0e-10);
                assert!(row.iter().all(|value| *value >= 0.0 && *value <= 1.0));
            }
        }
        assert!(
            negative
                .iter()
                .flatten()
                .zip(positive.iter().flatten())
                .any(|(left, right)| (left - right).abs() > 1.0e-3)
        );
    }

    #[test]
    fn causal_prefix_filter_is_unchanged_by_future_rows() {
        let model = fitted();
        let observations = vec![vec![-1.0], vec![-1.0], vec![1.0], vec![1.0], vec![-1.0]];
        let covariates = vec![vec![-1.0], vec![1.0], vec![1.0], vec![-1.0], vec![50.0]];
        let prefix = model.filter(&observations[..4], &covariates[..4]).unwrap();
        let full = model.filter(&observations, &covariates).unwrap();
        assert_eq!(
            prefix.filtered_probabilities,
            full.filtered_probabilities[..4]
        );
    }

    #[test]
    fn explicit_horizon_path_preserves_probability_mass() {
        let model = fitted();
        let probabilities = model
            .horizon_state_probabilities(
                &[0.7, 0.3],
                &[vec![1.0], vec![1.0], vec![-1.0], vec![-1.0]],
            )
            .unwrap();
        assert_abs_diff_eq!(probabilities.iter().sum::<f64>(), 1.0, epsilon = 1.0e-10);
    }

    #[test]
    fn online_covariate_ood_fails_closed() {
        let model = fitted();
        assert!(
            model
                .online_validation_flags(&[100.0])
                .contains(&"NH_HMM_TRANSITION_COVARIATE_OOD".to_string())
        );
    }

    #[test]
    fn wrong_dimension_is_rejected() {
        let model = fitted();
        assert!(model.transition_matrix(&[]).is_err());
        assert!(model.filter(&[vec![0.0]], &[]).is_err());
    }
}

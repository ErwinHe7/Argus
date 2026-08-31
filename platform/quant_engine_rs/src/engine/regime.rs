use std::collections::BTreeSet;

use anyhow::{Result, bail};
use serde::{Deserialize, Serialize};

const VARIANCE_FLOOR: f64 = 1.0e-4;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct GaussianHmm {
    pub states: usize,
    pub dimensions: usize,
    pub initial: Vec<f64>,
    pub transition: Vec<Vec<f64>>,
    pub means: Vec<Vec<f64>>,
    pub variances: Vec<Vec<f64>>,
    pub center: Vec<f64>,
    pub scale: Vec<f64>,
    pub log_likelihood: f64,
    pub bic: f64,
    pub training_likelihoods: Vec<f64>,
    /// Canonical state index -> original fitted state index. Computed only
    /// from train-period emission and persistence properties.
    pub state_permutation: Vec<usize>,
}

#[derive(Debug, Clone, PartialEq)]
struct ForwardBackward {
    log_alpha: Vec<Vec<f64>>,
    log_beta: Vec<Vec<f64>>,
    log_emissions: Vec<Vec<f64>>,
    log_likelihood: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PosteriorDiagnostics {
    pub gamma: Vec<Vec<f64>>,
    pub xi: Vec<Vec<Vec<f64>>>,
    pub log_likelihood: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct StateOccupancyDiagnostics {
    pub observation_count: usize,
    pub expected_observations_by_state: Vec<f64>,
    pub fractions_by_state: Vec<f64>,
    pub minimum_expected_observations: f64,
    pub minimum_fraction: f64,
    pub semantics: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HmmCandidateAssessment {
    pub state_count: usize,
    pub training_bic: Option<f64>,
    pub validation_average_log_likelihood: Option<f64>,
    pub fit_minimum_state_occupancy_fraction: Option<f64>,
    pub validation_minimum_state_occupancy_fraction: Option<f64>,
    pub fit_minimum_state_expected_observations: Option<f64>,
    pub validation_minimum_state_expected_observations: Option<f64>,
    pub eligible: bool,
    pub status: String,
}

#[derive(Debug, Clone)]
pub struct HmmCandidateSelection {
    pub model: GaussianHmm,
    pub selected_state_count: usize,
    pub candidate_assessments: Vec<HmmCandidateAssessment>,
    pub selection_method: &'static str,
    pub validation_used_for_selection: bool,
    pub selected_at_candidate_boundary: bool,
}

fn normalize(values: &mut [f64]) -> Result<f64> {
    if values.is_empty()
        || values
            .iter()
            .any(|value| !value.is_finite() || *value < 0.0)
    {
        bail!("probability vector must be finite, non-negative, and non-empty");
    }
    let sum = values.iter().sum::<f64>();
    if !sum.is_finite() || sum <= 0.0 {
        bail!("probability vector has no finite positive mass");
    }
    for value in values {
        *value /= sum;
    }
    Ok(sum)
}

pub(crate) fn log_sum_exp(values: &[f64]) -> f64 {
    if values.is_empty() || values.iter().any(|value| value.is_nan()) {
        return f64::NAN;
    }
    let maximum = values.iter().copied().fold(f64::NEG_INFINITY, f64::max);
    if maximum == f64::NEG_INFINITY {
        return f64::NEG_INFINITY;
    }
    if maximum == f64::INFINITY {
        return f64::INFINITY;
    }
    maximum
        + values
            .iter()
            .map(|value| (value - maximum).exp())
            .sum::<f64>()
            .ln()
}

pub(crate) fn log_probability(value: f64) -> Result<f64> {
    if !value.is_finite() || value < 0.0 {
        bail!("HMM probability parameter must be finite and non-negative");
    }
    Ok(if value == 0.0 {
        f64::NEG_INFINITY
    } else {
        value.ln()
    })
}

fn normalized_log_weights(values: &[f64]) -> Result<Vec<f64>> {
    let denominator = log_sum_exp(values);
    if !denominator.is_finite() {
        bail!("HMM log weights have no finite normalizing constant");
    }
    let mut probabilities = values
        .iter()
        .map(|value| (value - denominator).exp())
        .collect::<Vec<_>>();
    normalize(&mut probabilities)?;
    Ok(probabilities)
}

fn standardization(sequences: &[Vec<Vec<f64>>], dimensions: usize) -> (Vec<f64>, Vec<f64>) {
    let mut center = vec![0.0; dimensions];
    let mut count = 0.0;
    for observation in sequences.iter().flatten() {
        for (column, value) in observation.iter().enumerate() {
            center[column] += value;
        }
        count += 1.0;
    }
    for value in &mut center {
        *value /= count;
    }
    let mut scale = vec![0.0; dimensions];
    for observation in sequences.iter().flatten() {
        for column in 0..dimensions {
            scale[column] += (observation[column] - center[column]).powi(2);
        }
    }
    for value in &mut scale {
        *value = (*value / count).sqrt().max(1.0e-8);
    }
    (center, scale)
}

fn standardized(sequences: &[Vec<Vec<f64>>], center: &[f64], scale: &[f64]) -> Vec<Vec<Vec<f64>>> {
    sequences
        .iter()
        .map(|sequence| {
            sequence
                .iter()
                .map(|observation| {
                    observation
                        .iter()
                        .enumerate()
                        .map(|(column, value)| (value - center[column]) / scale[column])
                        .collect()
                })
                .collect()
        })
        .collect()
}

impl GaussianHmm {
    pub fn fit(
        sequences: &[Vec<Vec<f64>>],
        states: usize,
        max_iterations: usize,
        restarts: usize,
    ) -> Result<Self> {
        if !(2..=12).contains(&states) {
            bail!("HMM states must be between 2 and 12");
        }
        let first = sequences
            .iter()
            .flatten()
            .next()
            .ok_or_else(|| anyhow::anyhow!("HMM requires observations"))?;
        let dimensions = first.len();
        if dimensions == 0
            || sequences
                .iter()
                .flatten()
                .any(|row| row.len() != dimensions || row.iter().any(|value| !value.is_finite()))
        {
            bail!("HMM observations must be finite and rectangular");
        }
        let total_observations = sequences.iter().map(Vec::len).sum::<usize>();
        if total_observations < states * 8 {
            bail!("HMM needs at least eight observations per state");
        }
        let (center, scale) = standardization(sequences, dimensions);
        let normalized_sequences = standardized(sequences, &center, &scale);
        let mut best: Option<Self> = None;
        for restart in 0..restarts.max(1) {
            let mut model = Self::initialized(
                &normalized_sequences,
                states,
                dimensions,
                restart,
                center.clone(),
                scale.clone(),
            );
            if model
                .optimize_restart(&normalized_sequences, max_iterations)
                .is_err()
            {
                continue;
            }
            let parameters = (states - 1) + states * (states - 1) + 2 * states * dimensions;
            model.bic =
                parameters as f64 * (total_observations as f64).ln() - 2.0 * model.log_likelihood;
            if model.log_likelihood.is_finite()
                && model.bic.is_finite()
                && best
                    .as_ref()
                    .is_none_or(|current| model.log_likelihood > current.log_likelihood)
            {
                best = Some(model);
            }
        }
        best.ok_or_else(|| anyhow::anyhow!("HMM optimization did not produce a finite model"))
    }

    fn optimize_restart(
        &mut self,
        normalized_sequences: &[Vec<Vec<f64>>],
        max_iterations: usize,
    ) -> Result<()> {
        let mut previous = f64::NEG_INFINITY;
        for _ in 0..max_iterations.max(1) {
            // Any failed E- or M-step invalidates the whole restart. Continuing
            // would allow partially updated parameters to retain an older score.
            self.em_step(normalized_sequences)?;
            let likelihood = self.normalized_training_log_likelihood(normalized_sequences)?;
            self.log_likelihood = likelihood;
            self.training_likelihoods.push(likelihood);
            if (likelihood - previous).abs() <= 1.0e-6 * (1.0 + likelihood.abs()) {
                break;
            }
            previous = likelihood;
        }

        // Score the exact final parameter set. `em_step` evaluates the model
        // before its M-step, so that value must never be used for BIC or restart
        // selection after the parameters have changed.
        self.log_likelihood = self.normalized_training_log_likelihood(normalized_sequences)?;
        if let Some(last) = self.training_likelihoods.last_mut() {
            *last = self.log_likelihood;
        }
        Ok(())
    }

    fn normalized_training_log_likelihood(
        &self,
        normalized_sequences: &[Vec<Vec<f64>>],
    ) -> Result<f64> {
        let mut total = 0.0;
        let mut observations = 0_usize;
        for sequence in normalized_sequences
            .iter()
            .filter(|sequence| !sequence.is_empty())
        {
            total += self.forward_backward(sequence)?.log_likelihood;
            observations += sequence.len();
        }
        if observations == 0 || !total.is_finite() {
            bail!("HMM final training log likelihood is non-finite or empty");
        }
        Ok(total)
    }

    fn initialized(
        sequences: &[Vec<Vec<f64>>],
        states: usize,
        dimensions: usize,
        restart: usize,
        center: Vec<f64>,
        scale: Vec<f64>,
    ) -> Self {
        let observations = sequences.iter().flatten().collect::<Vec<_>>();
        let mut ordered = observations.clone();
        ordered.sort_by(|left, right| left[0].total_cmp(&right[0]));
        let means = (0..states)
            .map(|state| {
                let rank = ((state + 1) * ordered.len() / (states + 1)).min(ordered.len() - 1);
                (0..dimensions)
                    .map(|column| {
                        ordered[rank][column] + ((state + restart) % states) as f64 * 1.0e-3
                    })
                    .collect::<Vec<_>>()
            })
            .collect::<Vec<_>>();
        let persistence = (0.82 + 0.02 * (restart % 5) as f64).min(0.94);
        let transition = (0..states)
            .map(|from| {
                (0..states)
                    .map(|to| {
                        if from == to {
                            persistence
                        } else {
                            (1.0 - persistence) / (states - 1) as f64
                        }
                    })
                    .collect()
            })
            .collect();
        Self {
            states,
            dimensions,
            initial: vec![1.0 / states as f64; states],
            transition,
            means,
            variances: vec![vec![1.0; dimensions]; states],
            center,
            scale,
            log_likelihood: f64::NEG_INFINITY,
            bic: f64::INFINITY,
            training_likelihoods: Vec::new(),
            state_permutation: (0..states).collect(),
        }
    }

    fn log_emission(&self, observation: &[f64], state: usize) -> Result<f64> {
        let log_probability = (0..self.dimensions)
            .map(|column| -> Result<f64> {
                let raw_variance = self.variances[state][column];
                if !raw_variance.is_finite() || raw_variance <= 0.0 {
                    bail!("HMM emission variance must be finite and strictly positive");
                }
                let variance = raw_variance.max(VARIANCE_FLOOR);
                Ok(-0.5
                    * ((2.0 * std::f64::consts::PI * variance).ln()
                        + (observation[column] - self.means[state][column]).powi(2) / variance))
            })
            .collect::<Result<Vec<_>>>()?
            .into_iter()
            .sum::<f64>();
        if !log_probability.is_finite() {
            bail!("HMM emission log density is non-finite");
        }
        Ok(log_probability)
    }

    fn forward_backward(&self, sequence: &[Vec<f64>]) -> Result<ForwardBackward> {
        if sequence.is_empty() {
            bail!("HMM forward-backward requires observations");
        }
        let length = sequence.len();
        let log_emissions = sequence
            .iter()
            .map(|observation| {
                (0..self.states)
                    .map(|state| self.log_emission(observation, state))
                    .collect::<Result<Vec<_>>>()
            })
            .collect::<Result<Vec<_>>>()?;
        let log_initial = self
            .initial
            .iter()
            .map(|value| log_probability(*value))
            .collect::<Result<Vec<_>>>()?;
        let log_transition = self
            .transition
            .iter()
            .map(|row| {
                row.iter()
                    .map(|value| log_probability(*value))
                    .collect::<Result<Vec<_>>>()
            })
            .collect::<Result<Vec<_>>>()?;
        let mut log_alpha = vec![vec![f64::NEG_INFINITY; self.states]; length];
        for state in 0..self.states {
            log_alpha[0][state] = log_initial[state] + log_emissions[0][state];
        }
        if !log_sum_exp(&log_alpha[0]).is_finite() {
            bail!("HMM initial forward row has no finite probability mass");
        }
        for time in 1..length {
            for to in 0..self.states {
                let incoming = (0..self.states)
                    .map(|from| log_alpha[time - 1][from] + log_transition[from][to])
                    .collect::<Vec<_>>();
                log_alpha[time][to] = log_emissions[time][to] + log_sum_exp(&incoming);
            }
            if !log_sum_exp(&log_alpha[time]).is_finite() {
                bail!("HMM forward row has no finite probability mass");
            }
        }
        let mut log_beta = vec![vec![0.0; self.states]; length];
        for time in (0..length.saturating_sub(1)).rev() {
            for from in 0..self.states {
                let outgoing = (0..self.states)
                    .map(|to| {
                        log_transition[from][to]
                            + log_emissions[time + 1][to]
                            + log_beta[time + 1][to]
                    })
                    .collect::<Vec<_>>();
                log_beta[time][from] = log_sum_exp(&outgoing);
                if !log_beta[time][from].is_finite() {
                    bail!("HMM backward row has no finite probability mass");
                }
            }
        }
        let log_likelihood = log_sum_exp(&log_alpha[length - 1]);
        if !log_likelihood.is_finite() {
            bail!("HMM sequence log likelihood is non-finite");
        }
        Ok(ForwardBackward {
            log_alpha,
            log_beta,
            log_emissions,
            log_likelihood,
        })
    }

    fn em_step(&mut self, sequences: &[Vec<Vec<f64>>]) -> Result<f64> {
        let mut initial = vec![0.0; self.states];
        let mut transitions = vec![vec![0.0; self.states]; self.states];
        let mut transition_denominator = vec![0.0; self.states];
        let mut state_weight = vec![0.0; self.states];
        let mut sums = vec![vec![0.0; self.dimensions]; self.states];
        let mut squares = vec![vec![0.0; self.dimensions]; self.states];
        let mut total_likelihood = 0.0;
        for sequence in sequences.iter().filter(|sequence| !sequence.is_empty()) {
            let fb = self.forward_backward(sequence)?;
            total_likelihood += fb.log_likelihood;
            let mut gamma = vec![vec![0.0; self.states]; sequence.len()];
            for (time, gamma_row) in gamma.iter_mut().enumerate() {
                let log_weights = (0..self.states)
                    .map(|state| fb.log_alpha[time][state] + fb.log_beta[time][state])
                    .collect::<Vec<_>>();
                *gamma_row = normalized_log_weights(&log_weights)?;
                for (state, weight) in gamma_row.iter().copied().enumerate() {
                    state_weight[state] += weight;
                    for column in 0..self.dimensions {
                        sums[state][column] += weight * sequence[time][column];
                        squares[state][column] += weight * sequence[time][column].powi(2);
                    }
                }
            }
            for (state, value) in initial.iter_mut().enumerate() {
                *value += gamma[0][state];
            }
            for (time, gamma_row) in gamma
                .iter()
                .enumerate()
                .take(sequence.len().saturating_sub(1))
            {
                let mut log_xi = Vec::with_capacity(self.states * self.states);
                for from in 0..self.states {
                    for to in 0..self.states {
                        log_xi.push(
                            fb.log_alpha[time][from]
                                + log_probability(self.transition[from][to])?
                                + fb.log_emissions[time + 1][to]
                                + fb.log_beta[time + 1][to],
                        );
                    }
                }
                let xi = normalized_log_weights(&log_xi)?;
                for (from, transition_row) in transitions.iter_mut().enumerate() {
                    transition_denominator[from] += gamma_row[from];
                    for (to, transition_value) in transition_row.iter_mut().enumerate() {
                        *transition_value += xi[from * self.states + to];
                    }
                }
            }
        }
        normalize(&mut initial)?;
        self.initial = initial;
        for (from, transition_counts) in transitions.iter().enumerate() {
            if transition_denominator[from] > 1.0e-8 {
                for (to, transition_count) in transition_counts.iter().copied().enumerate() {
                    self.transition[from][to] = transition_count / transition_denominator[from];
                }
                normalize(&mut self.transition[from])?;
            }
            if state_weight[from] > 1.0e-8 {
                for column in 0..self.dimensions {
                    let mean = sums[from][column] / state_weight[from];
                    self.means[from][column] = mean;
                    self.variances[from][column] = (squares[from][column] / state_weight[from]
                        - mean * mean)
                        .max(VARIANCE_FLOOR);
                }
            }
        }
        if !total_likelihood.is_finite() {
            bail!("HMM EM step produced a non-finite likelihood");
        }
        Ok(total_likelihood)
    }

    pub fn filtered_probabilities(&self, raw_sequence: &[Vec<f64>]) -> Result<Vec<Vec<f64>>> {
        if raw_sequence.is_empty()
            || raw_sequence.iter().any(|row| {
                row.len() != self.dimensions || row.iter().any(|value| !value.is_finite())
            })
        {
            bail!("HMM filter input must be finite and rectangular");
        }
        let sequence = raw_sequence
            .iter()
            .map(|row| {
                row.iter()
                    .enumerate()
                    .map(|(column, value)| (value - self.center[column]) / self.scale[column])
                    .collect::<Vec<_>>()
            })
            .collect::<Vec<_>>();
        let fb = self.forward_backward(&sequence)?;
        fb.log_alpha
            .iter()
            .map(|row| normalized_log_weights(row))
            .collect()
    }

    fn normalize_raw_sequence(&self, raw_sequence: &[Vec<f64>]) -> Result<Vec<Vec<f64>>> {
        if raw_sequence.is_empty()
            || raw_sequence.iter().any(|row| {
                row.len() != self.dimensions || row.iter().any(|value| !value.is_finite())
            })
        {
            bail!("HMM input must be finite and rectangular");
        }
        Ok(raw_sequence
            .iter()
            .map(|row| {
                row.iter()
                    .enumerate()
                    .map(|(column, value)| (value - self.center[column]) / self.scale[column])
                    .collect()
            })
            .collect())
    }

    pub fn sequence_log_likelihood(&self, raw_sequence: &[Vec<f64>]) -> Result<f64> {
        let sequence = self.normalize_raw_sequence(raw_sequence)?;
        Ok(self.forward_backward(&sequence)?.log_likelihood)
    }

    /// Full-sequence posterior for training diagnostics and Baum-Welch tests.
    /// It must never be used as a validation/test/live feature.
    pub fn posterior_diagnostics(&self, raw_sequence: &[Vec<f64>]) -> Result<PosteriorDiagnostics> {
        let sequence = self.normalize_raw_sequence(raw_sequence)?;
        let fb = self.forward_backward(&sequence)?;
        let mut gamma = vec![vec![0.0; self.states]; sequence.len()];
        for (time, row) in gamma.iter_mut().enumerate() {
            let log_weights = (0..self.states)
                .map(|state| fb.log_alpha[time][state] + fb.log_beta[time][state])
                .collect::<Vec<_>>();
            *row = normalized_log_weights(&log_weights)?;
        }
        let mut xi =
            vec![vec![vec![0.0; self.states]; self.states]; sequence.len().saturating_sub(1)];
        for (time, xi_time) in xi.iter_mut().enumerate() {
            let mut log_weights = Vec::with_capacity(self.states * self.states);
            for from in 0..self.states {
                for to in 0..self.states {
                    log_weights.push(
                        fb.log_alpha[time][from]
                            + log_probability(self.transition[from][to])?
                            + fb.log_emissions[time + 1][to]
                            + fb.log_beta[time + 1][to],
                    );
                }
            }
            let probabilities = normalized_log_weights(&log_weights)?;
            for (from, row) in xi_time.iter_mut().enumerate() {
                for (to, value) in row.iter_mut().enumerate() {
                    *value = probabilities[from * self.states + to];
                }
            }
        }
        Ok(PosteriorDiagnostics {
            gamma,
            xi,
            log_likelihood: fb.log_likelihood,
        })
    }

    /// Most likely offline state path. Log-space with explicit backpointers.
    pub fn viterbi_path(&self, raw_sequence: &[Vec<f64>]) -> Result<Vec<usize>> {
        let sequence = self.normalize_raw_sequence(raw_sequence)?;
        let length = sequence.len();
        let mut score = vec![vec![f64::NEG_INFINITY; self.states]; length];
        let mut back = vec![vec![0_usize; self.states]; length];
        for (state, value) in score[0].iter_mut().enumerate() {
            *value =
                log_probability(self.initial[state])? + self.log_emission(&sequence[0], state)?;
        }
        for time in 1..length {
            for to in 0..self.states {
                let candidates = (0..self.states)
                    .map(|from| {
                        Ok((
                            from,
                            score[time - 1][from] + log_probability(self.transition[from][to])?,
                        ))
                    })
                    .collect::<Result<Vec<_>>>()?;
                let (from, best) = candidates
                    .into_iter()
                    .max_by(|left, right| left.1.total_cmp(&right.1))
                    .expect("HMM has states");
                score[time][to] = best + self.log_emission(&sequence[time], to)?;
                back[time][to] = from;
            }
        }
        let mut path = vec![0_usize; length];
        path[length - 1] = (0..self.states)
            .max_by(|left, right| score[length - 1][*left].total_cmp(&score[length - 1][*right]))
            .expect("HMM has states");
        for time in (1..length).rev() {
            path[time - 1] = back[time][path[time]];
        }
        Ok(path)
    }

    /// Canonicalize label-switched folds using train-only state properties:
    /// total emission variance, mean of dimension zero, then persistence.
    pub fn canonicalized(&self) -> (Self, Vec<usize>) {
        let mut permutation = (0..self.states).collect::<Vec<_>>();
        permutation.sort_by(|left, right| {
            let left_vol = self.variances[*left].iter().sum::<f64>();
            let right_vol = self.variances[*right].iter().sum::<f64>();
            left_vol
                .total_cmp(&right_vol)
                .then(self.means[*left][0].total_cmp(&self.means[*right][0]))
                .then(self.transition[*right][*right].total_cmp(&self.transition[*left][*left]))
        });
        let mut output = self.clone();
        output.initial = permutation
            .iter()
            .map(|state| self.initial[*state])
            .collect();
        output.means = permutation
            .iter()
            .map(|state| self.means[*state].clone())
            .collect();
        output.variances = permutation
            .iter()
            .map(|state| self.variances[*state].clone())
            .collect();
        output.transition = permutation
            .iter()
            .map(|from| {
                permutation
                    .iter()
                    .map(|to| self.transition[*from][*to])
                    .collect()
            })
            .collect();
        output.state_permutation = permutation.clone();
        (output, permutation)
    }

    /// Average predictive log likelihood under fixed train-period parameters.
    /// Each supplied session starts from the train-fitted initial distribution.
    pub fn average_log_likelihood(&self, raw_sequences: &[Vec<Vec<f64>>]) -> Result<f64> {
        let mut total = 0.0;
        let mut observations = 0_usize;
        for raw_sequence in raw_sequences.iter().filter(|sequence| !sequence.is_empty()) {
            if raw_sequence.iter().any(|row| {
                row.len() != self.dimensions || row.iter().any(|value| !value.is_finite())
            }) {
                bail!("HMM evaluation input must be finite and rectangular");
            }
            let sequence = raw_sequence
                .iter()
                .map(|row| {
                    row.iter()
                        .enumerate()
                        .map(|(column, value)| (value - self.center[column]) / self.scale[column])
                        .collect::<Vec<_>>()
                })
                .collect::<Vec<_>>();
            total += self.forward_backward(&sequence)?.log_likelihood;
            observations += sequence.len();
        }
        if observations == 0 {
            bail!("HMM evaluation requires observations");
        }
        Ok(total / observations as f64)
    }

    /// Causal expected state usage under the same filtered posterior exposed at
    /// inference time. This is a soft expected mass, not a hard Viterbi count.
    pub fn filtered_state_occupancy(
        &self,
        raw_sequences: &[Vec<Vec<f64>>],
    ) -> Result<StateOccupancyDiagnostics> {
        let mut expected = vec![0.0; self.states];
        let mut observation_count = 0_usize;
        for sequence in raw_sequences.iter().filter(|sequence| !sequence.is_empty()) {
            for row in self.filtered_probabilities(sequence)? {
                for (state, probability) in row.into_iter().enumerate() {
                    expected[state] += probability;
                }
                observation_count += 1;
            }
        }
        if observation_count == 0 {
            bail!("HMM occupancy requires observations");
        }
        let fractions = expected
            .iter()
            .map(|value| value / observation_count as f64)
            .collect::<Vec<_>>();
        let minimum_expected_observations = expected.iter().copied().fold(f64::INFINITY, f64::min);
        let minimum_fraction = fractions.iter().copied().fold(f64::INFINITY, f64::min);
        if !minimum_expected_observations.is_finite() || !minimum_fraction.is_finite() {
            bail!("HMM occupancy is non-finite");
        }
        Ok(StateOccupancyDiagnostics {
            observation_count,
            expected_observations_by_state: expected,
            fractions_by_state: fractions,
            minimum_expected_observations,
            minimum_fraction,
            semantics: "CAUSAL_FILTERED_POSTERIOR_EXPECTED_MASS_NOT_HARD_STATE_COUNT".into(),
        })
    }

    pub fn next_state_probabilities(&self, filtered: &[f64]) -> Result<Vec<f64>> {
        let probability_sum = filtered.iter().sum::<f64>();
        if filtered.len() != self.states
            || filtered
                .iter()
                .any(|value| !value.is_finite() || *value < 0.0)
            || !probability_sum.is_finite()
            || (probability_sum - 1.0).abs() > 1.0e-8
        {
            bail!("filtered state vector must be a normalized probability simplex");
        }
        let mut next = (0..self.states)
            .map(|to| {
                (0..self.states)
                    .map(|from| filtered[from] * self.transition[from][to])
                    .sum::<f64>()
            })
            .collect::<Vec<_>>();
        normalize(&mut next)?;
        Ok(next)
    }

    pub fn horizon_state_probabilities(
        &self,
        filtered: &[f64],
        transitions: usize,
        crosses_session_boundary: bool,
    ) -> Result<Vec<f64>> {
        if crosses_session_boundary {
            bail!("HMM_SESSION_BOUNDARY_REQUIRES_RESET_OR_EXPLICIT_OVERNIGHT_MODEL");
        }
        let mut result = filtered.to_vec();
        if transitions == 0 {
            normalize(&mut result)?;
            return Ok(result);
        }
        for _ in 0..transitions {
            result = self.next_state_probabilities(&result)?;
        }
        Ok(result)
    }

    pub fn state_entropy(probabilities: &[f64]) -> Result<f64> {
        if probabilities.is_empty()
            || probabilities
                .iter()
                .any(|value| !value.is_finite() || *value < 0.0)
        {
            bail!("invalid state probabilities");
        }
        Ok(-probabilities
            .iter()
            .filter(|value| **value > 0.0)
            .map(|value| value * value.ln())
            .sum::<f64>())
    }
}

fn validate_occupancy_thresholds(
    minimum_fraction: f64,
    minimum_expected_observations: f64,
) -> Result<()> {
    if !minimum_fraction.is_finite()
        || !(0.0..=0.5).contains(&minimum_fraction)
        || minimum_fraction == 0.0
        || !minimum_expected_observations.is_finite()
        || minimum_expected_observations <= 0.0
    {
        bail!("HMM occupancy thresholds must be finite and positive");
    }
    Ok(())
}

fn occupancy_passes(
    diagnostics: &StateOccupancyDiagnostics,
    minimum_fraction: f64,
    minimum_expected_observations: f64,
) -> bool {
    diagnostics.minimum_fraction + 1.0e-12 >= minimum_fraction
        && diagnostics.minimum_expected_observations + 1.0e-12 >= minimum_expected_observations
}

pub fn validate_hmm_state_occupancy(
    model: &GaussianHmm,
    sequences: &[Vec<Vec<f64>>],
    minimum_fraction: f64,
    minimum_expected_observations: f64,
) -> Result<StateOccupancyDiagnostics> {
    validate_occupancy_thresholds(minimum_fraction, minimum_expected_observations)?;
    let diagnostics = model.filtered_state_occupancy(sequences)?;
    if !occupancy_passes(
        &diagnostics,
        minimum_fraction,
        minimum_expected_observations,
    ) {
        bail!(
            "HMM state occupancy is below the configured floor: fraction={} expected_observations={}",
            diagnostics.minimum_fraction,
            diagnostics.minimum_expected_observations
        );
    }
    Ok(diagnostics)
}

/// Canonical state-count selection shared by frozen training, regime-family
/// competition, CLI fitting, and purged forward folds. Returned parameters are
/// fit only on `fit_sequences`; callers that explicitly refit must validate the
/// refitted model's occupancy again.
#[allow(clippy::too_many_arguments)]
pub fn select_hmm_candidates(
    fit_sequences: &[Vec<Vec<f64>>],
    validation_sequences: Option<&[Vec<Vec<f64>>]>,
    candidates: &[usize],
    max_iterations: usize,
    restarts: usize,
    minimum_state_occupancy_fraction: f64,
    minimum_state_expected_observations: f64,
) -> Result<HmmCandidateSelection> {
    validate_occupancy_thresholds(
        minimum_state_occupancy_fraction,
        minimum_state_expected_observations,
    )?;
    if fit_sequences.iter().all(Vec::is_empty) {
        bail!("HMM candidate selection requires fit observations");
    }
    if candidates.is_empty() {
        bail!("HMM candidate selection requires at least one state count");
    }
    let unique = candidates.iter().copied().collect::<BTreeSet<_>>();
    if unique.len() != candidates.len()
        || candidates.iter().any(|states| !(2..=12).contains(states))
    {
        bail!("HMM candidate state counts must be unique and within 2..=12");
    }
    if validation_sequences.is_some_and(|sequences| sequences.iter().all(Vec::is_empty)) {
        bail!("HMM validation selection requires validation observations");
    }

    let validation_used_for_selection = validation_sequences.is_some();
    let selection_method = if validation_used_for_selection {
        "MAX_VALIDATION_AVERAGE_LOG_LIKELIHOOD_AMONG_OCCUPANCY_ELIGIBLE_CANDIDATES"
    } else {
        "MIN_TRAIN_BIC_AMONG_OCCUPANCY_ELIGIBLE_CANDIDATES"
    };
    let mut assessments = Vec::with_capacity(candidates.len());
    let mut selected = None::<(usize, f64, GaussianHmm)>;

    for state_count in candidates {
        let Ok(model) = GaussianHmm::fit(fit_sequences, *state_count, max_iterations, restarts)
        else {
            assessments.push(HmmCandidateAssessment {
                state_count: *state_count,
                training_bic: None,
                validation_average_log_likelihood: None,
                fit_minimum_state_occupancy_fraction: None,
                validation_minimum_state_occupancy_fraction: None,
                fit_minimum_state_expected_observations: None,
                validation_minimum_state_expected_observations: None,
                eligible: false,
                status: "FIT_FAILED_OR_INSUFFICIENT_OBSERVATIONS".into(),
            });
            continue;
        };
        let training_bic = model.bic.is_finite().then_some(model.bic);
        let fit_occupancy = model.filtered_state_occupancy(fit_sequences).ok();
        let validation_average_log_likelihood = validation_sequences
            .and_then(|sequences| model.average_log_likelihood(sequences).ok())
            .filter(|score| score.is_finite());
        let validation_occupancy = validation_sequences
            .and_then(|sequences| model.filtered_state_occupancy(sequences).ok());
        let fit_eligible = fit_occupancy.as_ref().is_some_and(|diagnostics| {
            occupancy_passes(
                diagnostics,
                minimum_state_occupancy_fraction,
                minimum_state_expected_observations,
            )
        });
        let validation_eligible = validation_sequences.is_none()
            || validation_occupancy.as_ref().is_some_and(|diagnostics| {
                occupancy_passes(
                    diagnostics,
                    minimum_state_occupancy_fraction,
                    minimum_state_expected_observations,
                )
            });
        let selection_score = if validation_used_for_selection {
            validation_average_log_likelihood
        } else {
            training_bic.map(|bic| -bic)
        };
        let eligible = fit_eligible && validation_eligible && selection_score.is_some();
        let status = if fit_occupancy.is_none() {
            "FIT_OCCUPANCY_EVALUATION_FAILED"
        } else if !fit_eligible {
            "REJECTED_LOW_FIT_STATE_OCCUPANCY"
        } else if validation_used_for_selection && validation_average_log_likelihood.is_none() {
            "VALIDATION_SCORING_FAILED_NOT_SELECTABLE"
        } else if validation_used_for_selection && validation_occupancy.is_none() {
            "VALIDATION_OCCUPANCY_EVALUATION_FAILED"
        } else if !validation_eligible {
            "REJECTED_LOW_VALIDATION_STATE_OCCUPANCY"
        } else if selection_score.is_none() {
            "NONFINITE_SELECTION_SCORE"
        } else if validation_used_for_selection {
            "ELIGIBLE_VALIDATION_SCORED"
        } else {
            "ELIGIBLE_TRAIN_BIC_FALLBACK"
        };

        if eligible
            && let Some(score) = selection_score
            && selected
                .as_ref()
                .is_none_or(|(selected_states, selected_score, _)| {
                    score > *selected_score + 1.0e-12
                        || ((score - *selected_score).abs() <= 1.0e-12
                            && *state_count < *selected_states)
                })
        {
            selected = Some((*state_count, score, model.clone()));
        }
        assessments.push(HmmCandidateAssessment {
            state_count: *state_count,
            training_bic,
            validation_average_log_likelihood,
            fit_minimum_state_occupancy_fraction: fit_occupancy
                .as_ref()
                .map(|diagnostics| diagnostics.minimum_fraction),
            validation_minimum_state_occupancy_fraction: validation_occupancy
                .as_ref()
                .map(|diagnostics| diagnostics.minimum_fraction),
            fit_minimum_state_expected_observations: fit_occupancy
                .as_ref()
                .map(|diagnostics| diagnostics.minimum_expected_observations),
            validation_minimum_state_expected_observations: validation_occupancy
                .as_ref()
                .map(|diagnostics| diagnostics.minimum_expected_observations),
            eligible,
            status: status.into(),
        });
    }

    let (selected_state_count, _, model) = selected.ok_or_else(|| {
        anyhow::anyhow!("no occupancy-eligible HMM candidate produced a finite selection score")
    })?;
    let selected_at_candidate_boundary = candidates
        .iter()
        .max()
        .is_some_and(|maximum| *maximum == selected_state_count);
    Ok(HmmCandidateSelection {
        model,
        selected_state_count,
        candidate_assessments: assessments,
        selection_method,
        validation_used_for_selection,
        selected_at_candidate_boundary,
    })
}

#[cfg(test)]
mod tests {
    use super::{GaussianHmm, select_hmm_candidates};

    fn tiny_model() -> GaussianHmm {
        GaussianHmm {
            states: 2,
            dimensions: 1,
            initial: vec![0.6, 0.4],
            transition: vec![vec![0.7, 0.3], vec![0.2, 0.8]],
            means: vec![vec![-1.0], vec![1.0]],
            variances: vec![vec![0.5], vec![0.5]],
            center: vec![0.0],
            scale: vec![1.0],
            log_likelihood: 0.0,
            bic: 0.0,
            training_likelihoods: vec![],
            state_permutation: vec![0, 1],
        }
    }

    fn extreme_four_dimensional_model() -> GaussianHmm {
        GaussianHmm {
            states: 2,
            dimensions: 4,
            initial: vec![0.5, 0.5],
            transition: vec![vec![0.9, 0.1], vec![0.1, 0.9]],
            means: vec![vec![0.0; 4], vec![0.0; 4]],
            variances: vec![vec![1.0e-4; 4], vec![1.0e-4; 4]],
            center: vec![0.0; 4],
            scale: vec![1.0; 4],
            log_likelihood: 0.0,
            bic: 0.0,
            training_likelihoods: vec![],
            state_permutation: vec![0, 1],
        }
    }

    fn fixture() -> Vec<Vec<Vec<f64>>> {
        (0..12)
            .map(|session| {
                (0..40)
                    .map(|minute| {
                        let regime = if minute < 20 { -1.0 } else { 1.0 };
                        vec![
                            regime + session as f64 * 0.002,
                            0.5 * regime + (minute % 3) as f64 * 0.01,
                        ]
                    })
                    .collect()
            })
            .collect()
    }

    #[test]
    fn fit_is_finite_deterministic_and_filter_is_causal() {
        let data = fixture();
        let first = GaussianHmm::fit(&data, 2, 50, 3).unwrap();
        let second = GaussianHmm::fit(&data, 2, 50, 3).unwrap();
        assert!(first.log_likelihood.is_finite());
        assert!(first.bic.is_finite());
        assert_eq!(first, second);
        let prefix = &data[0][..15];
        let filtered = first.filtered_probabilities(prefix).unwrap();
        assert_eq!(filtered.len(), prefix.len());
        assert!((filtered.last().unwrap().iter().sum::<f64>() - 1.0).abs() < 1.0e-9);
        let next = first
            .next_state_probabilities(filtered.last().unwrap())
            .unwrap();
        assert!((next.iter().sum::<f64>() - 1.0).abs() < 1.0e-9);
        assert!(
            first
                .training_likelihoods
                .windows(2)
                .all(|pair| pair[1] + 1e-7 >= pair[0])
        );
    }

    #[test]
    fn fitted_likelihood_and_bic_score_the_final_parameters() {
        let data = fixture();
        let model = GaussianHmm::fit(&data, 2, 1, 1).unwrap();
        let recomputed = data
            .iter()
            .map(|sequence| model.sequence_log_likelihood(sequence).unwrap())
            .sum::<f64>();
        let tolerance = 1.0e-10 * (1.0 + recomputed.abs());
        assert!((model.log_likelihood - recomputed).abs() <= tolerance);
        assert!((model.training_likelihoods.last().unwrap() - recomputed).abs() <= tolerance);

        let parameters = (model.states - 1)
            + model.states * (model.states - 1)
            + 2 * model.states * model.dimensions;
        let observations = data.iter().map(Vec::len).sum::<usize>();
        let expected_bic = parameters as f64 * (observations as f64).ln() - 2.0 * recomputed;
        assert!((model.bic - expected_bic).abs() <= tolerance);
    }

    #[test]
    fn failed_em_restart_is_not_scoreable() {
        let data = fixture();
        let (center, scale) = super::standardization(&data, 2);
        let normalized = super::standardized(&data, &center, &scale);
        let mut model = GaussianHmm::initialized(&normalized, 2, 2, 0, center, scale);
        model.variances[0][0] = f64::NAN;

        let error = model.optimize_restart(&normalized, 2).unwrap_err();
        assert!(error.to_string().contains("variance"));
        assert_eq!(model.log_likelihood, f64::NEG_INFINITY);
        assert!(model.training_likelihoods.is_empty());
    }

    #[test]
    fn invalid_emission_variance_fails_closed() {
        for invalid in [f64::NAN, f64::INFINITY, 0.0, -1.0] {
            let mut model = tiny_model();
            model.variances[0][0] = invalid;
            let error = model.sequence_log_likelihood(&[vec![0.0]]).unwrap_err();
            assert!(error.to_string().contains("variance"));
        }
    }

    #[test]
    fn candidate_selection_uses_one_global_scoring_mode() {
        let data = fixture();
        let fit = &data[..10];
        let validation = &data[10..];
        let held_out =
            select_hmm_candidates(fit, Some(validation), &[2], 12, 1, 0.001, 1.0).unwrap();
        assert!(held_out.validation_used_for_selection);
        assert_eq!(
            held_out.selection_method,
            "MAX_VALIDATION_AVERAGE_LOG_LIKELIHOOD_AMONG_OCCUPANCY_ELIGIBLE_CANDIDATES"
        );
        assert_eq!(
            held_out.candidate_assessments[0].status,
            "ELIGIBLE_VALIDATION_SCORED"
        );

        let bic = select_hmm_candidates(fit, None, &[2], 12, 1, 0.001, 1.0).unwrap();
        assert!(!bic.validation_used_for_selection);
        assert_eq!(
            bic.selection_method,
            "MIN_TRAIN_BIC_AMONG_OCCUPANCY_ELIGIBLE_CANDIDATES"
        );
        assert!(
            bic.candidate_assessments[0]
                .validation_average_log_likelihood
                .is_none()
        );
    }

    #[test]
    fn state_occupancy_gate_rejects_infeasible_candidate_fail_closed() {
        let data = fixture();
        let error = select_hmm_candidates(&data, None, &[3], 12, 1, 0.34, 1.0).unwrap_err();
        assert!(
            error
                .to_string()
                .contains("no occupancy-eligible HMM candidate")
        );
    }

    #[test]
    fn state_occupancy_gate_keeps_eligible_lower_k() {
        let data = fixture();
        let selection =
            select_hmm_candidates(&data[..10], Some(&data[10..]), &[2, 3], 12, 1, 0.34, 1.0)
                .unwrap();
        assert_eq!(selection.selected_state_count, 2);
        let rejected = selection
            .candidate_assessments
            .iter()
            .find(|assessment| assessment.state_count == 3)
            .unwrap();
        assert!(!rejected.eligible);
        assert!(rejected.status.contains("OCCUPANCY"));
    }

    #[test]
    fn forward_backward_gamma_xi_are_normalized_and_consistent() {
        let model = tiny_model();
        let sequence = vec![vec![-0.8], vec![0.9], vec![1.1]];
        let posterior = model.posterior_diagnostics(&sequence).unwrap();
        assert!(posterior.log_likelihood.is_finite());
        for gamma in &posterior.gamma {
            assert!((gamma.iter().sum::<f64>() - 1.0).abs() < 1e-10);
        }
        for (time, xi) in posterior.xi.iter().enumerate() {
            let total = xi.iter().flatten().sum::<f64>();
            assert!((total - 1.0).abs() < 1e-10);
            for (from, row) in xi.iter().enumerate().take(model.states) {
                assert!((row.iter().sum::<f64>() - posterior.gamma[time][from]).abs() < 1e-8);
            }
        }
        assert!(
            (model.sequence_log_likelihood(&sequence).unwrap() - posterior.log_likelihood).abs()
                < 1e-12
        );
    }

    #[test]
    fn extreme_gaussian_log_density_is_not_clamped() {
        let model = extreme_four_dimensional_model();
        for residual in [0.2_f64, 1.0] {
            let sequence = vec![vec![residual; 4]];
            let actual = model.sequence_log_likelihood(&sequence).unwrap();
            let expected = 4.0
                * -0.5
                * ((2.0 * std::f64::consts::PI * 1.0e-4).ln() + residual.powi(2) / 1.0e-4);
            assert!((actual - expected).abs() < 1.0e-9);
        }
        assert!(model.sequence_log_likelihood(&[vec![0.2; 4]]).unwrap() < -700.0);
    }

    #[test]
    fn extremely_unlikely_mid_sequence_observation_preserves_filter_history() {
        let model = GaussianHmm {
            states: 2,
            dimensions: 1,
            initial: vec![0.99, 0.01],
            transition: vec![vec![0.99, 0.01], vec![0.01, 0.99]],
            means: vec![vec![-1.0], vec![1.0]],
            variances: vec![vec![1.0e-4], vec![1.0e-4]],
            center: vec![0.0],
            scale: vec![1.0],
            log_likelihood: 0.0,
            bic: 0.0,
            training_likelihoods: vec![],
            state_permutation: vec![0, 1],
        };
        let filtered = model
            .filtered_probabilities(&[vec![-1.0], vec![0.0]])
            .unwrap();
        assert!(
            filtered[1][0] > 0.98,
            "posterior was reset: {:?}",
            filtered[1]
        );
        assert!((filtered[1].iter().sum::<f64>() - 1.0).abs() < 1.0e-12);
    }

    #[test]
    fn non_representable_log_density_fails_closed() {
        let model = extreme_four_dimensional_model();
        let error = model
            .sequence_log_likelihood(&[vec![f64::MAX; 4]])
            .unwrap_err();
        assert!(error.to_string().contains("non-finite"));
    }

    #[test]
    fn viterbi_matches_bruteforce_tiny_model() {
        let model = tiny_model();
        let sequence = vec![vec![-1.0], vec![0.8], vec![1.2]];
        let path = model.viterbi_path(&sequence).unwrap();
        let mut best = (f64::NEG_INFINITY, Vec::new());
        for bits in 0..8 {
            let candidate = (0..3).map(|idx| (bits >> idx) & 1).collect::<Vec<_>>();
            let mut score = model.initial[candidate[0]].ln();
            for time in 0..3 {
                let state = candidate[time];
                let variance = model.variances[state][0];
                score += -0.5
                    * ((2.0 * std::f64::consts::PI * variance).ln()
                        + (sequence[time][0] - model.means[state][0]).powi(2) / variance);
                if time > 0 {
                    score += model.transition[candidate[time - 1]][state].ln();
                }
            }
            if score > best.0 {
                best = (score, candidate);
            }
        }
        assert_eq!(path, best.1);
    }

    #[test]
    fn next_state_rejects_non_probability_inputs() {
        let model = tiny_model();
        assert!(model.next_state_probabilities(&[0.8, 0.8]).is_err());
        assert!(model.next_state_probabilities(&[-0.1, 1.1]).is_err());
        assert!(model.next_state_probabilities(&[f64::NAN, 0.0]).is_err());
    }

    #[test]
    fn state_canonicalization_and_horizon_are_deterministic() {
        let model = tiny_model();
        let (first, permutation) = model.canonicalized();
        let (second, again) = model.canonicalized();
        assert_eq!(first, second);
        assert_eq!(permutation, again);
        let two = first
            .horizon_state_probabilities(&[0.25, 0.75], 2, false)
            .unwrap();
        assert!((two.iter().sum::<f64>() - 1.0).abs() < 1e-10);
        assert!(
            first
                .horizon_state_probabilities(&[0.25, 0.75], 2, true)
                .is_err()
        );
    }
}

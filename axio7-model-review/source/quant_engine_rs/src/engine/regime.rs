use anyhow::{Result, bail};
use serde::{Deserialize, Serialize};

const PROBABILITY_FLOOR: f64 = 1.0e-300;
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
    alpha: Vec<Vec<f64>>,
    beta: Vec<Vec<f64>>,
    emissions: Vec<Vec<f64>>,
    scales: Vec<f64>,
    log_likelihood: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PosteriorDiagnostics {
    pub gamma: Vec<Vec<f64>>,
    pub xi: Vec<Vec<Vec<f64>>>,
    pub log_likelihood: f64,
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
            let mut previous = f64::NEG_INFINITY;
            for _ in 0..max_iterations.max(1) {
                let likelihood = model.em_step(&normalized_sequences);
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
            let parameters = (states - 1) + states * (states - 1) + 2 * states * dimensions;
            model.bic =
                parameters as f64 * (total_observations as f64).ln() - 2.0 * model.log_likelihood;
            if model.log_likelihood.is_finite()
                && best
                    .as_ref()
                    .is_none_or(|current| model.log_likelihood > current.log_likelihood)
            {
                best = Some(model);
            }
        }
        best.ok_or_else(|| anyhow::anyhow!("HMM optimization did not produce a finite model"))
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

    fn emission(&self, observation: &[f64], state: usize) -> f64 {
        let log_probability = (0..self.dimensions)
            .map(|column| {
                let variance = self.variances[state][column].max(VARIANCE_FLOOR);
                -0.5 * ((2.0 * std::f64::consts::PI * variance).ln()
                    + (observation[column] - self.means[state][column]).powi(2) / variance)
            })
            .sum::<f64>();
        log_probability.exp().max(PROBABILITY_FLOOR)
    }

    fn forward_backward(&self, sequence: &[Vec<f64>]) -> ForwardBackward {
        let length = sequence.len();
        let emissions = sequence
            .iter()
            .map(|observation| {
                (0..self.states)
                    .map(|state| self.emission(observation, state))
                    .collect::<Vec<_>>()
            })
            .collect::<Vec<_>>();
        let mut alpha = vec![vec![0.0; self.states]; length];
        let mut scales = vec![0.0; length];
        for state in 0..self.states {
            alpha[0][state] = self.initial[state] * emissions[0][state];
        }
        scales[0] = normalize(&mut alpha[0]);
        for time in 1..length {
            for to in 0..self.states {
                alpha[time][to] = emissions[time][to]
                    * (0..self.states)
                        .map(|from| alpha[time - 1][from] * self.transition[from][to])
                        .sum::<f64>();
            }
            scales[time] = normalize(&mut alpha[time]);
        }
        let mut beta = vec![vec![1.0; self.states]; length];
        for time in (0..length.saturating_sub(1)).rev() {
            for from in 0..self.states {
                beta[time][from] = (0..self.states)
                    .map(|to| {
                        self.transition[from][to] * emissions[time + 1][to] * beta[time + 1][to]
                    })
                    .sum::<f64>()
                    / scales[time + 1].max(PROBABILITY_FLOOR);
            }
        }
        ForwardBackward {
            alpha,
            beta,
            emissions,
            log_likelihood: scales.iter().map(|value| value.ln()).sum(),
            scales,
        }
    }

    fn em_step(&mut self, sequences: &[Vec<Vec<f64>>]) -> f64 {
        let mut initial = vec![0.0; self.states];
        let mut transitions = vec![vec![0.0; self.states]; self.states];
        let mut transition_denominator = vec![0.0; self.states];
        let mut state_weight = vec![0.0; self.states];
        let mut sums = vec![vec![0.0; self.dimensions]; self.states];
        let mut squares = vec![vec![0.0; self.dimensions]; self.states];
        let mut total_likelihood = 0.0;
        for sequence in sequences.iter().filter(|sequence| !sequence.is_empty()) {
            let fb = self.forward_backward(sequence);
            total_likelihood += fb.log_likelihood;
            let mut gamma = vec![vec![0.0; self.states]; sequence.len()];
            for (time, gamma_row) in gamma.iter_mut().enumerate() {
                for (state, gamma_value) in gamma_row.iter_mut().enumerate() {
                    *gamma_value = fb.alpha[time][state] * fb.beta[time][state];
                }
                normalize(gamma_row);
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
                let mut denominator = 0.0;
                for from in 0..self.states {
                    for to in 0..self.states {
                        denominator += fb.alpha[time][from]
                            * self.transition[from][to]
                            * fb.emissions[time + 1][to]
                            * fb.beta[time + 1][to];
                    }
                }
                denominator = denominator.max(PROBABILITY_FLOOR);
                for (from, transition_row) in transitions.iter_mut().enumerate() {
                    transition_denominator[from] += gamma_row[from];
                    for (to, transition_value) in transition_row.iter_mut().enumerate() {
                        *transition_value += fb.alpha[time][from]
                            * self.transition[from][to]
                            * fb.emissions[time + 1][to]
                            * fb.beta[time + 1][to]
                            / denominator;
                    }
                }
            }
            debug_assert!(fb.scales.iter().all(|value| value.is_finite()));
        }
        normalize(&mut initial);
        self.initial = initial;
        for (from, transition_counts) in transitions.iter().enumerate() {
            if transition_denominator[from] > 1.0e-8 {
                for (to, transition_count) in transition_counts.iter().copied().enumerate() {
                    self.transition[from][to] = transition_count / transition_denominator[from];
                }
                normalize(&mut self.transition[from]);
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
        total_likelihood
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
        Ok(self.forward_backward(&sequence).alpha)
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
        Ok(self.forward_backward(&sequence).log_likelihood)
    }

    /// Full-sequence posterior for training diagnostics and Baum-Welch tests.
    /// It must never be used as a validation/test/live feature.
    pub fn posterior_diagnostics(&self, raw_sequence: &[Vec<f64>]) -> Result<PosteriorDiagnostics> {
        let sequence = self.normalize_raw_sequence(raw_sequence)?;
        let fb = self.forward_backward(&sequence);
        let mut gamma = vec![vec![0.0; self.states]; sequence.len()];
        for (time, row) in gamma.iter_mut().enumerate() {
            for (state, value) in row.iter_mut().enumerate() {
                *value = fb.alpha[time][state] * fb.beta[time][state];
            }
            normalize(row);
        }
        let mut xi =
            vec![vec![vec![0.0; self.states]; self.states]; sequence.len().saturating_sub(1)];
        for (time, xi_time) in xi.iter_mut().enumerate() {
            let mut denominator = 0.0;
            for (from, xi_row) in xi_time.iter_mut().enumerate() {
                for (to, xi_value) in xi_row.iter_mut().enumerate() {
                    let value = fb.alpha[time][from]
                        * self.transition[from][to]
                        * fb.emissions[time + 1][to]
                        * fb.beta[time + 1][to];
                    *xi_value = value;
                    denominator += value;
                }
            }
            for row in xi_time {
                for value in row {
                    *value /= denominator.max(PROBABILITY_FLOOR);
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
            *value = self.initial[state].max(PROBABILITY_FLOOR).ln()
                + self.emission(&sequence[0], state).ln();
        }
        for time in 1..length {
            for to in 0..self.states {
                let (from, best) = (0..self.states)
                    .map(|from| {
                        (
                            from,
                            score[time - 1][from]
                                + self.transition[from][to].max(PROBABILITY_FLOOR).ln(),
                        )
                    })
                    .max_by(|left, right| left.1.total_cmp(&right.1))
                    .expect("HMM has states");
                score[time][to] = best + self.emission(&sequence[time], to).ln();
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
            total += self.forward_backward(&sequence).log_likelihood;
            observations += sequence.len();
        }
        if observations == 0 {
            bail!("HMM evaluation requires observations");
        }
        Ok(total / observations as f64)
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
        normalize(&mut next);
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
            normalize(&mut result);
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

#[cfg(test)]
mod tests {
    use super::GaussianHmm;

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

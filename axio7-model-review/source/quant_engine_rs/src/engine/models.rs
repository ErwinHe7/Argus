use std::collections::HashMap;

use chrono::{DateTime, Duration, Utc};

use crate::domain::{MarketState, Outcome};

const FEATURES: usize = MarketState::FEATURE_COUNT;

#[derive(Debug, Clone)]
pub struct Standardizer {
    mean: [f64; FEATURES],
    scale: [f64; FEATURES],
}

impl Standardizer {
    pub fn fit(rows: &[[f64; FEATURES]]) -> Self {
        let mut mean = [0.0; FEATURES];
        let mut scale = [1.0; FEATURES];
        if rows.is_empty() {
            return Self { mean, scale };
        }
        for j in 0..FEATURES {
            mean[j] = rows.iter().map(|row| row[j]).sum::<f64>() / rows.len() as f64;
            let variance = rows
                .iter()
                .map(|row| (row[j] - mean[j]).powi(2))
                .sum::<f64>()
                / rows.len().max(2) as f64;
            scale[j] = variance.sqrt().max(1e-9);
        }
        Self { mean, scale }
    }

    pub fn transform(&self, row: [f64; FEATURES]) -> [f64; FEATURES] {
        std::array::from_fn(|j| (row[j] - self.mean[j]) / self.scale[j])
    }
}

fn sigmoid(value: f64) -> f64 {
    if value >= 0.0 {
        1.0 / (1.0 + (-value).exp())
    } else {
        let exp = value.exp();
        exp / (1.0 + exp)
    }
}

#[derive(Debug, Clone)]
pub struct LogisticRegression {
    weights: [f64; FEATURES],
    intercept: f64,
    standardizer: Standardizer,
}

impl LogisticRegression {
    pub fn fit(
        rows: &[[f64; FEATURES]],
        targets: &[f64],
        epochs: usize,
        learning_rate: f64,
        l2: f64,
    ) -> Self {
        let standardizer = Standardizer::fit(rows);
        let scaled: Vec<_> = rows
            .iter()
            .map(|row| standardizer.transform(*row))
            .collect();
        let mut weights = [0.0; FEATURES];
        let base = targets.iter().sum::<f64>() / targets.len().max(1) as f64;
        let mut intercept =
            (base.clamp(1e-5, 1.0 - 1e-5) / (1.0 - base.clamp(1e-5, 1.0 - 1e-5))).ln();
        for epoch in 0..epochs {
            let rate = learning_rate / (1.0 + epoch as f64 * 0.01);
            let mut grad = [0.0; FEATURES];
            let mut grad_intercept = 0.0;
            for (row, target) in scaled.iter().zip(targets) {
                let score = intercept + weights.iter().zip(row).map(|(w, x)| w * x).sum::<f64>();
                let error = sigmoid(score) - target;
                grad_intercept += error;
                for j in 0..FEATURES {
                    grad[j] += error * row[j];
                }
            }
            let n = rows.len().max(1) as f64;
            intercept -= rate * grad_intercept / n;
            for j in 0..FEATURES {
                weights[j] -= rate * (grad[j] / n + l2 * weights[j]);
            }
        }
        Self {
            weights,
            intercept,
            standardizer,
        }
    }

    pub fn score(&self, row: [f64; FEATURES]) -> f64 {
        let scaled = self.standardizer.transform(row);
        self.intercept
            + self
                .weights
                .iter()
                .zip(scaled)
                .map(|(w, x)| w * x)
                .sum::<f64>()
    }

    pub fn probability(&self, row: [f64; FEATURES]) -> f64 {
        sigmoid(self.score(row))
    }
}

#[derive(Debug, Clone)]
pub struct PlattCalibrator {
    slope: f64,
    intercept: f64,
}

impl PlattCalibrator {
    pub fn fit(scores: &[f64], targets: &[f64]) -> Self {
        let mut slope = 1.0;
        let mut intercept = 0.0;
        for epoch in 0..250 {
            let rate = 0.05 / (1.0 + epoch as f64 * 0.01);
            let mut grad_slope = 0.0;
            let mut grad_intercept = 0.0;
            for (score, target) in scores.iter().zip(targets) {
                let error = sigmoid(slope * score + intercept) - target;
                grad_slope += error * score;
                grad_intercept += error;
            }
            let n = scores.len().max(1) as f64;
            slope -= rate * grad_slope / n;
            intercept -= rate * grad_intercept / n;
        }
        Self { slope, intercept }
    }

    pub fn calibrate(&self, score: f64) -> f64 {
        sigmoid(self.slope * score + self.intercept)
    }
}

#[derive(Debug, Clone)]
struct MultiOutputStump {
    feature: usize,
    threshold: f64,
    left: [f64; 3],
    right: [f64; 3],
}

impl MultiOutputStump {
    fn predict(&self, row: &[f64; FEATURES]) -> [f64; 3] {
        if row[self.feature] <= self.threshold {
            self.left
        } else {
            self.right
        }
    }
}

#[derive(Debug, Clone)]
pub struct GradientBoostedHeads {
    base: [f64; 3],
    learning_rate: f64,
    stumps: Vec<MultiOutputStump>,
}

impl GradientBoostedHeads {
    pub fn fit(
        rows: &[[f64; FEATURES]],
        targets: &[[f64; 3]],
        estimators: usize,
        learning_rate: f64,
    ) -> Self {
        let mut base = [0.0; 3];
        for head in 0..3 {
            base[head] =
                targets.iter().map(|row| row[head]).sum::<f64>() / targets.len().max(1) as f64;
        }
        let mut predictions = vec![base; rows.len()];
        let mut stumps = Vec::new();
        for _ in 0..estimators {
            let residuals: Vec<[f64; 3]> = targets
                .iter()
                .zip(&predictions)
                .map(|(target, predicted)| {
                    std::array::from_fn(|head| target[head] - predicted[head])
                })
                .collect();
            let mut best: Option<(f64, MultiOutputStump)> = None;
            for feature in 0..FEATURES {
                let mut values: Vec<f64> = rows.iter().map(|row| row[feature]).collect();
                values.sort_by(f64::total_cmp);
                for q in [0.2, 0.4, 0.6, 0.8] {
                    let threshold = values[((values.len().saturating_sub(1)) as f64 * q) as usize];
                    let mut left_sum = [0.0; 3];
                    let mut right_sum = [0.0; 3];
                    let mut left_n = 0_usize;
                    let mut right_n = 0_usize;
                    for (row, residual) in rows.iter().zip(&residuals) {
                        let (sum, count) = if row[feature] <= threshold {
                            (&mut left_sum, &mut left_n)
                        } else {
                            (&mut right_sum, &mut right_n)
                        };
                        *count += 1;
                        for head in 0..3 {
                            sum[head] += residual[head];
                        }
                    }
                    if left_n == 0 || right_n == 0 {
                        continue;
                    }
                    let left = std::array::from_fn(|head| left_sum[head] / left_n as f64);
                    let right = std::array::from_fn(|head| right_sum[head] / right_n as f64);
                    let stump = MultiOutputStump {
                        feature,
                        threshold,
                        left,
                        right,
                    };
                    let loss = rows
                        .iter()
                        .zip(&residuals)
                        .map(|(row, residual)| {
                            let leaf = stump.predict(row);
                            (0..3)
                                .map(|head| (residual[head] - leaf[head]).powi(2))
                                .sum::<f64>()
                        })
                        .sum::<f64>();
                    if best.as_ref().is_none_or(|(best_loss, _)| loss < *best_loss) {
                        best = Some((loss, stump));
                    }
                }
            }
            let Some((_, stump)) = best else {
                break;
            };
            for (row, prediction) in rows.iter().zip(&mut predictions) {
                let leaf = stump.predict(row);
                for head in 0..3 {
                    prediction[head] += learning_rate * leaf[head];
                }
            }
            stumps.push(stump);
        }
        Self {
            base,
            learning_rate,
            stumps,
        }
    }

    pub fn predict(&self, row: [f64; FEATURES]) -> [f64; 3] {
        let mut output = self.base;
        for stump in &self.stumps {
            let leaf = stump.predict(&row);
            for head in 0..3 {
                output[head] += self.learning_rate * leaf[head];
            }
        }
        output
    }
}

#[derive(Debug, Clone)]
pub struct SupervisedPrediction {
    pub expected_return: f64,
    pub win_probability: f64,
    pub predicted_mfe: f64,
    pub predicted_mae: f64,
    pub validation_brier: f64,
}

#[derive(Debug, Clone)]
pub struct SupervisedBundle {
    logistic: LogisticRegression,
    calibrator: PlattCalibrator,
    boosted: GradientBoostedHeads,
    validation_brier: f64,
}

impl SupervisedBundle {
    pub fn fit_before(
        states: &[MarketState],
        outcomes: &[Outcome],
        cutoff: DateTime<Utc>,
    ) -> Option<Self> {
        let outcome_map: HashMap<usize, &Outcome> =
            outcomes.iter().map(|row| (row.state_index, row)).collect();
        let mut eligible: Vec<(usize, &Outcome)> = (0..states.len())
            .filter_map(|idx| {
                let outcome = outcome_map.get(&idx).copied()?;
                let end =
                    outcome.entry_timestamp + Duration::minutes(outcome.horizon_minutes as i64);
                (end < cutoff).then_some((idx, outcome))
            })
            .collect();
        if eligible.len() < 100 {
            return None;
        }
        if eligible.len() > 5_000 {
            eligible = eligible.split_off(eligible.len() - 5_000);
        }
        let split = (eligible.len() as f64 * 0.8) as usize;
        let (train, validation) = eligible.split_at(split.max(50).min(eligible.len() - 20));
        let train_x: Vec<_> = train
            .iter()
            .map(|(idx, _)| states[*idx].feature_vector())
            .collect();
        let train_y: Vec<_> = train
            .iter()
            .map(|(_, o)| (o.directional_return > 0.0) as u8 as f64)
            .collect();
        let logistic = LogisticRegression::fit(&train_x, &train_y, 100, 0.08, 0.002);
        let validation_scores: Vec<_> = validation
            .iter()
            .map(|(idx, _)| logistic.score(states[*idx].feature_vector()))
            .collect();
        let validation_y: Vec<_> = validation
            .iter()
            .map(|(_, o)| (o.directional_return > 0.0) as u8 as f64)
            .collect();
        let calibrator = PlattCalibrator::fit(&validation_scores, &validation_y);
        let validation_brier = validation_scores
            .iter()
            .zip(&validation_y)
            .map(|(score, target)| (calibrator.calibrate(*score) - target).powi(2))
            .sum::<f64>()
            / validation_y.len().max(1) as f64;
        let all_x: Vec<_> = eligible
            .iter()
            .map(|(idx, _)| states[*idx].feature_vector())
            .collect();
        let all_targets: Vec<_> = eligible
            .iter()
            .map(|(_, outcome)| [outcome.directional_return, outcome.mfe, outcome.mae])
            .collect();
        let boosted = GradientBoostedHeads::fit(&all_x, &all_targets, 20, 0.08);
        Some(Self {
            logistic,
            calibrator,
            boosted,
            validation_brier,
        })
    }

    pub fn predict(&self, state: &MarketState, direction: i8) -> SupervisedPrediction {
        let score = self.logistic.score(state.feature_vector());
        let long_probability = self.calibrator.calibrate(score);
        let heads = self.boosted.predict(state.feature_vector());
        let is_long = direction > 0;
        SupervisedPrediction {
            expected_return: if is_long { heads[0] } else { -heads[0] },
            win_probability: if is_long {
                long_probability
            } else {
                1.0 - long_probability
            },
            predicted_mfe: if is_long { heads[1] } else { heads[2] },
            predicted_mae: if is_long { heads[2] } else { heads[1] },
            validation_brier: self.validation_brier,
        }
    }
}

use std::collections::{BTreeMap, HashMap};

use crate::domain::{AnalogCase, MarketState, Outcome, Prediction};

const ANALOG_DIMENSIONS: usize = 12;

fn core_features(state: &MarketState) -> [f64; ANALOG_DIMENSIONS] {
    [
        state.ret_1m,
        state.ret_5m,
        state.ret_15m,
        state.dist_vwap,
        state.rolling_realized_vol,
        state.normalized_range,
        state.volume_zscore,
        state.rvol_same_minute,
        state.session_range_position,
        state.cross_asset_breadth_score,
        state.slope_15m,
        state.minutes_from_open as f64 / 390.0,
    ]
}

fn quantile(mut values: Vec<f64>, probability: f64) -> f64 {
    if values.is_empty() {
        return 0.0;
    }
    values.sort_by(f64::total_cmp);
    let location = probability * (values.len() - 1) as f64;
    let left = location.floor() as usize;
    let right = location.ceil() as usize;
    let fraction = location - left as f64;
    values[left] * (1.0 - fraction) + values[right] * fraction
}

fn weighted_quantile(mut values: Vec<(f64, f64)>, probability: f64) -> f64 {
    if values.is_empty() {
        return 0.0;
    }
    values.sort_by(|a, b| a.0.total_cmp(&b.0));
    let total = values.iter().map(|(_, weight)| *weight).sum::<f64>();
    let target = probability * total;
    let mut cumulative = 0.0;
    for (value, weight) in &values {
        cumulative += weight;
        if cumulative >= target {
            return *value;
        }
    }
    values.last().map(|row| row.0).unwrap_or_default()
}

/// Point-in-time historical analog distribution.
///
/// The distance is a robust diagonal shrinkage-Mahalanobis approximation over
/// twelve predeclared dimensions. The closest observation per trading day is
/// retained before kNN weighting so overlapping minutes cannot masquerade as
/// independent evidence. The furthest retained neighbor defines an adaptive
/// bandwidth; `bandwidth_multiplier` only scales that train-time rule.
pub fn predict(
    states: &[MarketState],
    outcomes: &[Outcome],
    query_index: usize,
    direction: i8,
    neighbors: usize,
    bandwidth_multiplier: f64,
) -> Option<Prediction> {
    let query = states.get(query_index)?;
    let outcome_map: HashMap<usize, &Outcome> =
        outcomes.iter().map(|row| (row.state_index, row)).collect();
    let eligible: Vec<(usize, &Outcome)> = (0..query_index)
        .filter_map(|idx| {
            if states[idx].bucket_5m != query.bucket_5m {
                return None;
            }
            let outcome = outcome_map.get(&idx).copied()?;
            let outcome_end =
                outcome.entry_timestamp + chrono::Duration::minutes(outcome.horizon_minutes as i64);
            (outcome_end < query.timestamp && states[idx].session_date < query.session_date)
                .then_some((idx, outcome))
        })
        .collect();
    if eligible.len() < 20 {
        return None;
    }

    let mut medians = [0.0; ANALOG_DIMENSIONS];
    let mut scales = [1.0; ANALOG_DIMENSIONS];
    for feature in 0..ANALOG_DIMENSIONS {
        let values = eligible
            .iter()
            .map(|(idx, _)| core_features(&states[*idx])[feature])
            .collect::<Vec<_>>();
        medians[feature] = quantile(values.clone(), 0.5);
        let deviations = values
            .iter()
            .map(|value| (value - medians[feature]).abs())
            .collect::<Vec<_>>();
        // MAD plus 10% unit shrinkage prevents unstable inverse variances.
        scales[feature] = (1.4826 * quantile(deviations, 0.5)).max(1e-9) * 0.9 + 1e-9 * 0.1;
    }

    let query_features = core_features(query);
    let mut best_by_day = BTreeMap::new();
    for (idx, outcome) in eligible {
        let features = core_features(&states[idx]);
        let squared = (0..ANALOG_DIMENSIONS)
            .map(|feature| {
                let delta = (features[feature] - query_features[feature]) / scales[feature];
                delta * delta
            })
            .sum::<f64>()
            / ANALOG_DIMENSIONS as f64;
        let distance = squared.sqrt();
        best_by_day
            .entry(states[idx].session_date)
            .and_modify(|current: &mut (usize, &Outcome, f64)| {
                if distance < current.2 {
                    *current = (idx, outcome, distance);
                }
            })
            .or_insert((idx, outcome, distance));
    }
    let mut distances = best_by_day.into_values().collect::<Vec<_>>();
    distances.sort_by(|a, b| a.2.total_cmp(&b.2));
    distances.truncate(neighbors.min(distances.len()));
    if distances.len() < 10 {
        return None;
    }
    let adaptive_bandwidth = distances.last()?.2.max(1e-6) * bandwidth_multiplier.clamp(0.25, 4.0);
    let raw_weights = distances
        .iter()
        .map(|(_, _, distance)| (-0.5 * (distance / adaptive_bandwidth).powi(2)).exp())
        .collect::<Vec<_>>();
    let weight_sum = raw_weights.iter().sum::<f64>().max(1e-12);
    let weights = raw_weights
        .into_iter()
        .map(|weight| weight / weight_sum)
        .collect::<Vec<_>>();
    let effective_sample_size = 1.0
        / weights
            .iter()
            .map(|weight| weight * weight)
            .sum::<f64>()
            .max(1e-12);
    let max_day_weight = weights.iter().copied().fold(0.0, f64::max);
    let concentration_penalty = ((max_day_weight - 0.30) / 0.30).max(0.0);

    let signed = direction as f64;
    let returns = distances
        .iter()
        .map(|(_, outcome, _)| signed * outcome.directional_return)
        .collect::<Vec<_>>();
    let mfes = distances
        .iter()
        .map(|(_, outcome, _)| {
            if direction > 0 {
                outcome.mfe
            } else {
                outcome.mae
            }
        })
        .collect::<Vec<_>>();
    let maes = distances
        .iter()
        .map(|(_, outcome, _)| {
            if direction > 0 {
                outcome.mae
            } else {
                outcome.mfe
            }
        })
        .collect::<Vec<_>>();
    let expected_return = returns
        .iter()
        .zip(&weights)
        .map(|(v, w)| v * w)
        .sum::<f64>();
    let predicted_mfe = mfes.iter().zip(&weights).map(|(v, w)| v * w).sum::<f64>();
    let predicted_mae = maes.iter().zip(&weights).map(|(v, w)| v * w).sum::<f64>();
    let uncertainty = returns
        .iter()
        .zip(&weights)
        .map(|(value, weight)| weight * (value - expected_return).powi(2))
        .sum::<f64>()
        .sqrt()
        * (1.0 + concentration_penalty);
    let win_probability = returns
        .iter()
        .zip(&weights)
        .filter(|(value, _)| **value > 0.0)
        .map(|(_, weight)| *weight)
        .sum::<f64>();
    let median_return = weighted_quantile(
        returns
            .iter()
            .copied()
            .zip(weights.iter().copied())
            .collect(),
        0.5,
    );
    let analogs = distances
        .iter()
        .zip(&weights)
        .enumerate()
        .map(|(rank, ((idx, outcome, distance), weight))| AnalogCase {
            rank: rank + 1,
            analog_timestamp: states[*idx].timestamp,
            distance: *distance,
            similarity: *weight,
            forward_return: signed * outcome.directional_return,
            mfe: if direction > 0 {
                outcome.mfe
            } else {
                outcome.mae
            },
            mae: if direction > 0 {
                outcome.mae
            } else {
                outcome.mfe
            },
        })
        .collect::<Vec<_>>();
    let similarity_score = analogs
        .first()
        .map(|row| (-row.distance).exp())
        .unwrap_or_default();
    Some(Prediction {
        expected_return,
        median_return,
        win_probability,
        predicted_mfe,
        predicted_mae,
        neighbor_count: analogs.len(),
        similarity_score,
        uncertainty,
        effective_sample_size,
        max_day_weight,
        concentration_penalty,
        analogs,
    })
}

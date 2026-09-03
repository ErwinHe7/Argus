//! Causal discrete-time hazard model for the first observed closing
//! short-cover confirmation.
//!
//! The legacy positive-ramp rule remains an event confirmation definition. It
//! is never used as a contemporaneous predictor feature. The hazard model is
//! fit only on sessions strictly before the query session and predicts the
//! first future confirmation within 5/10/15 minutes while the process remains
//! at risk.

use std::collections::{BTreeMap, BTreeSet};

use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::domain::MarketState;

const FEATURE_COUNT: usize = 12;
const FEATURE_NAMES: [&str; FEATURE_COUNT] = [
    "prior_30m_drawdown",
    "below_vwap_extension",
    "below_session_open_extension",
    "sell_pressure_deceleration",
    "lower_session_range_location",
    "cross_asset_breadth",
    "risk_rotation",
    "volume_zscore",
    "relative_volume",
    "realized_volatility",
    "normalized_range",
    "minutes_to_close",
];

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ClosingShortCoverHazardConfig {
    pub lookback_sessions: usize,
    pub closing_window_minutes: i32,
    pub validation_fraction_sessions: f64,
    pub minimum_training_sessions: usize,
    pub minimum_training_rows: usize,
    pub minimum_training_events: usize,
    pub minimum_validation_rows: usize,
    pub minimum_validation_events: usize,
    pub minimum_brier_improvement: f64,
    pub l2_penalty: f64,
    pub learning_rate: f64,
    pub epochs: usize,
}

impl Default for ClosingShortCoverHazardConfig {
    fn default() -> Self {
        Self {
            lookback_sessions: 120,
            closing_window_minutes: 60,
            validation_fraction_sessions: 0.20,
            minimum_training_sessions: 20,
            minimum_training_rows: 500,
            minimum_training_events: 15,
            minimum_validation_rows: 100,
            minimum_validation_events: 3,
            minimum_brier_improvement: 0.0,
            l2_penalty: 0.01,
            learning_rate: 0.04,
            epochs: 300,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HazardHorizonProbability {
    pub horizon_minutes: usize,
    pub first_confirmation_probability: f64,
    pub survival_probability: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HazardValidationMetrics {
    pub sample_count: usize,
    pub event_count: usize,
    pub brier_score: f64,
    pub base_rate_brier_score: f64,
    pub brier_improvement: f64,
    pub log_loss: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ClosingShortCoverHazardForecast {
    pub status: String,
    pub as_of: Option<DateTime<Utc>>,
    pub symbol: Option<String>,
    pub at_risk: bool,
    pub confirmation_observed: bool,
    pub confirmation_score: Option<f64>,
    pub event_definition: String,
    pub horizons: Vec<HazardHorizonProbability>,
    pub one_minute_hazard_path: Vec<f64>,
    pub training_session_count: usize,
    pub training_row_count: usize,
    pub training_event_count: usize,
    pub trained_through: Option<NaiveDate>,
    pub validation_metrics: Option<HazardValidationMetrics>,
    pub model_hash: Option<String>,
    pub feature_names: Vec<String>,
    pub rejection_reasons: Vec<String>,
    pub probability_semantics: String,
    pub affects_decision: bool,
}

impl Default for ClosingShortCoverHazardForecast {
    fn default() -> Self {
        Self {
            status: "NOT_EVALUATED".into(),
            as_of: None,
            symbol: None,
            at_risk: false,
            confirmation_observed: false,
            confirmation_score: None,
            event_definition: "FIRST_FUTURE_LEGACY_POSITIVE_RAMP_CONFIRMATION_IN_CLOSING_WINDOW"
                .into(),
            horizons: Vec::new(),
            one_minute_hazard_path: Vec::new(),
            training_session_count: 0,
            training_row_count: 0,
            training_event_count: 0,
            trained_through: None,
            validation_metrics: None,
            model_hash: None,
            feature_names: FEATURE_NAMES.iter().map(|name| (*name).into()).collect(),
            rejection_reasons: Vec::new(),
            probability_semantics: "DISCRETE_TIME_FIRST_EVENT_CUMULATIVE_INCIDENCE; RESEARCH_ONLY"
                .into(),
            affects_decision: false,
        }
    }
}

/// This is the old positive-ramp setup. It is retained solely as the
/// observable event/confirmation definition for hazard labels and reporting.
/// It must not be described as a pre-event forecast.
pub fn is_positive_ramp_confirmation(state: &MarketState) -> bool {
    state.minutes_to_close <= 30
        && state.minutes_to_close >= 10
        && state.closing_short_cover_score >= 2.25
        && state.ret_5m > 0.0
}

fn hazard_features(state: &MarketState, minutes_to_close: i32) -> [f64; FEATURE_COUNT] {
    [
        (-state.ret_30m).max(0.0),
        (-state.dist_vwap).max(0.0),
        (-state.dist_session_open).max(0.0),
        state.return_acceleration.max(0.0),
        (0.5 - state.session_range_position).max(0.0),
        state.cross_asset_breadth_score,
        state.risk_rotation_score,
        state.volume_zscore,
        state.rvol_same_minute,
        state.rolling_realized_vol,
        state.normalized_range,
        minutes_to_close as f64 / 60.0,
    ]
}

#[derive(Debug, Clone)]
struct HazardRow {
    session_date: NaiveDate,
    features: [f64; FEATURE_COUNT],
    event_next_minute: f64,
}

fn training_rows(
    states: &[MarketState],
    query_index: usize,
    config: &ClosingShortCoverHazardConfig,
) -> (Vec<HazardRow>, Vec<NaiveDate>) {
    let Some(query) = states.get(query_index) else {
        return (Vec::new(), Vec::new());
    };
    let prior_dates = states[..=query_index]
        .iter()
        .filter(|state| state.symbol == query.symbol && state.session_date < query.session_date)
        .map(|state| state.session_date)
        .collect::<BTreeSet<_>>();
    let retained_dates = prior_dates
        .iter()
        .rev()
        .take(config.lookback_sessions)
        .copied()
        .collect::<BTreeSet<_>>();
    let mut sessions = BTreeMap::<NaiveDate, Vec<&MarketState>>::new();
    for state in &states[..=query_index] {
        if state.symbol == query.symbol && retained_dates.contains(&state.session_date) {
            sessions.entry(state.session_date).or_default().push(state);
        }
    }
    let mut rows = Vec::new();
    for (session_date, mut session) in sessions {
        session.sort_by_key(|state| state.timestamp);
        let first_confirmation = session
            .iter()
            .position(|state| is_positive_ramp_confirmation(state));
        for index in 0..session.len().saturating_sub(1) {
            let state = session[index];
            let next = session[index + 1];
            if state.minutes_to_close > config.closing_window_minutes
                || state.minutes_to_close <= 0
                || next.timestamp != state.timestamp + chrono::Duration::minutes(1)
                || first_confirmation.is_some_and(|event_index| index >= event_index)
            {
                continue;
            }
            let event_next_minute = if first_confirmation == Some(index + 1) {
                1.0
            } else {
                0.0
            };
            let features = hazard_features(state, state.minutes_to_close);
            if features.iter().all(|value| value.is_finite()) {
                rows.push(HazardRow {
                    session_date,
                    features,
                    event_next_minute,
                });
            }
        }
    }
    (rows, retained_dates.into_iter().collect())
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct FeatureScaler {
    mean: [f64; FEATURE_COUNT],
    scale: [f64; FEATURE_COUNT],
}

impl FeatureScaler {
    fn fit(rows: &[HazardRow]) -> Self {
        let mut mean = [0.0; FEATURE_COUNT];
        for row in rows {
            for (index, value) in row.features.iter().enumerate() {
                mean[index] += value;
            }
        }
        for value in &mut mean {
            *value /= rows.len().max(1) as f64;
        }
        let mut scale = [0.0; FEATURE_COUNT];
        for row in rows {
            for index in 0..FEATURE_COUNT {
                scale[index] += (row.features[index] - mean[index]).powi(2);
            }
        }
        for value in &mut scale {
            *value = (*value / rows.len().max(1) as f64).sqrt().max(1.0e-8);
        }
        Self { mean, scale }
    }

    fn transform(&self, features: &[f64; FEATURE_COUNT]) -> [f64; FEATURE_COUNT] {
        std::array::from_fn(|index| {
            ((features[index] - self.mean[index]) / self.scale[index]).clamp(-8.0, 8.0)
        })
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct LogisticHazardModel {
    scaler: FeatureScaler,
    intercept: f64,
    weights: [f64; FEATURE_COUNT],
}

fn sigmoid(score: f64) -> f64 {
    if score >= 0.0 {
        1.0 / (1.0 + (-score).exp())
    } else {
        let exponential = score.exp();
        exponential / (1.0 + exponential)
    }
}

impl LogisticHazardModel {
    fn fit(rows: &[HazardRow], config: &ClosingShortCoverHazardConfig) -> Self {
        let scaler = FeatureScaler::fit(rows);
        let positives = rows
            .iter()
            .filter(|row| row.event_next_minute > 0.5)
            .count()
            .max(1);
        let base_rate = positives as f64 / rows.len().max(1) as f64;
        let mut model = Self {
            scaler,
            intercept: (base_rate.clamp(1.0e-6, 1.0 - 1.0e-6)
                / (1.0 - base_rate.clamp(1.0e-6, 1.0 - 1.0e-6)))
            .ln(),
            weights: [0.0; FEATURE_COUNT],
        };
        for epoch in 0..config.epochs {
            let mut intercept_gradient = 0.0;
            let mut gradients = [0.0; FEATURE_COUNT];
            for row in rows {
                let transformed = model.scaler.transform(&row.features);
                let probability = model.probability_transformed(&transformed);
                // An unweighted Bernoulli likelihood is intentional: class
                // weighting would turn the score into a ranking statistic and
                // destroy its discrete-time hazard probability semantics.
                let error = probability - row.event_next_minute;
                intercept_gradient += error;
                for index in 0..FEATURE_COUNT {
                    gradients[index] += error * transformed[index];
                }
            }
            let rate = config.learning_rate / (1.0 + epoch as f64 / 100.0);
            let denominator = rows.len().max(1) as f64;
            model.intercept -= rate * intercept_gradient / denominator;
            for (index, weight) in model.weights.iter_mut().enumerate() {
                *weight -= rate * (gradients[index] / denominator + config.l2_penalty * *weight);
            }
        }
        model
    }

    fn probability_transformed(&self, features: &[f64; FEATURE_COUNT]) -> f64 {
        let score = self
            .weights
            .iter()
            .zip(features)
            .fold(self.intercept, |accumulator, (weight, value)| {
                accumulator + weight * value
            });
        sigmoid(score).clamp(1.0e-6, 1.0 - 1.0e-6)
    }

    fn probability(&self, features: &[f64; FEATURE_COUNT]) -> f64 {
        self.probability_transformed(&self.scaler.transform(features))
    }
}

fn validation_metrics(
    model: &LogisticHazardModel,
    validation: &[HazardRow],
    train_base_rate: f64,
) -> HazardValidationMetrics {
    let mut brier = 0.0;
    let mut base_brier = 0.0;
    let mut log_loss = 0.0;
    let mut event_count = 0_usize;
    for row in validation {
        let probability = model.probability(&row.features);
        brier += (probability - row.event_next_minute).powi(2);
        base_brier += (train_base_rate - row.event_next_minute).powi(2);
        log_loss -= row.event_next_minute * probability.ln()
            + (1.0 - row.event_next_minute) * (1.0 - probability).ln();
        event_count += usize::from(row.event_next_minute > 0.5);
    }
    let count = validation.len().max(1) as f64;
    let brier_score = brier / count;
    let base_rate_brier_score = base_brier / count;
    HazardValidationMetrics {
        sample_count: validation.len(),
        event_count,
        brier_score,
        base_rate_brier_score,
        brier_improvement: base_rate_brier_score - brier_score,
        log_loss: log_loss / count,
    }
}

fn prior_confirmation_observed(
    states: &[MarketState],
    query_index: usize,
    query: &MarketState,
) -> bool {
    states[..query_index].iter().any(|state| {
        state.symbol == query.symbol
            && state.session_date == query.session_date
            && is_positive_ramp_confirmation(state)
    })
}

pub fn forecast(
    states: &[MarketState],
    query_index: usize,
    observation_cutoff: DateTime<Utc>,
    config: &ClosingShortCoverHazardConfig,
) -> ClosingShortCoverHazardForecast {
    let mut output = ClosingShortCoverHazardForecast {
        as_of: Some(observation_cutoff),
        ..ClosingShortCoverHazardForecast::default()
    };
    let Some(query) = states.get(query_index) else {
        output.status = "QUERY_UNAVAILABLE".into();
        output
            .rejection_reasons
            .push("QUERY_INDEX_OUT_OF_RANGE".into());
        return output;
    };
    output.symbol = Some(query.symbol.clone());
    output.confirmation_score = Some(query.closing_short_cover_score);
    output.confirmation_observed = is_positive_ramp_confirmation(query);

    if output.confirmation_observed || prior_confirmation_observed(states, query_index, query) {
        output.status = "EVENT_ALREADY_CONFIRMED_NOT_AT_RISK".into();
        output
            .rejection_reasons
            .push("POSITIVE_RAMP_IS_CONFIRMATION_NOT_FORECAST".into());
        return output;
    }
    if query.minutes_to_close > config.closing_window_minutes || query.minutes_to_close <= 0 {
        output.status = "OUTSIDE_CLOSING_HAZARD_WINDOW".into();
        output
            .rejection_reasons
            .push("QUERY_NOT_IN_PREDECLARED_CLOSING_WINDOW".into());
        return output;
    }
    output.at_risk = true;

    let (rows, retained_dates) = training_rows(states, query_index, config);
    output.training_session_count = retained_dates.len();
    output.training_row_count = rows.len();
    output.training_event_count = rows
        .iter()
        .filter(|row| row.event_next_minute > 0.5)
        .count();
    output.trained_through = retained_dates.last().copied();
    if retained_dates.len() < config.minimum_training_sessions {
        output.status = "INSUFFICIENT_TRAINING_SESSIONS".into();
        output
            .rejection_reasons
            .push("MINIMUM_PRIOR_SESSION_COUNT_NOT_MET".into());
        return output;
    }

    let requested_validation =
        (retained_dates.len() as f64 * config.validation_fraction_sessions).ceil() as usize;
    let validation_sessions = requested_validation.clamp(1, retained_dates.len().saturating_sub(1));
    let split = retained_dates.len().saturating_sub(validation_sessions);
    let training_dates = retained_dates[..split]
        .iter()
        .copied()
        .collect::<BTreeSet<_>>();
    let validation_dates = retained_dates[split..]
        .iter()
        .copied()
        .collect::<BTreeSet<_>>();
    let training = rows
        .iter()
        .filter(|row| training_dates.contains(&row.session_date))
        .cloned()
        .collect::<Vec<_>>();
    let validation = rows
        .iter()
        .filter(|row| validation_dates.contains(&row.session_date))
        .cloned()
        .collect::<Vec<_>>();
    let training_events = training
        .iter()
        .filter(|row| row.event_next_minute > 0.5)
        .count();
    let validation_events = validation
        .iter()
        .filter(|row| row.event_next_minute > 0.5)
        .count();
    if training.len() < config.minimum_training_rows
        || training_events < config.minimum_training_events
        || validation.len() < config.minimum_validation_rows
        || validation_events < config.minimum_validation_events
    {
        output.status = "INSUFFICIENT_EVENT_EVIDENCE".into();
        output.rejection_reasons.push(format!(
            "TRAIN_ROWS={};TRAIN_EVENTS={};VALIDATION_ROWS={};VALIDATION_EVENTS={}",
            training.len(),
            training_events,
            validation.len(),
            validation_events
        ));
        return output;
    }

    let validation_model = LogisticHazardModel::fit(&training, config);
    let train_base_rate = training_events as f64 / training.len() as f64;
    let metrics = validation_metrics(&validation_model, &validation, train_base_rate);
    output.validation_metrics = Some(metrics.clone());
    if metrics.brier_improvement <= config.minimum_brier_improvement {
        output.status = "FAILED_CHRONOLOGICAL_VALIDATION".into();
        output.rejection_reasons.push(format!(
            "Brier improvement {:.8} <= required {:.8}",
            metrics.brier_improvement, config.minimum_brier_improvement
        ));
        return output;
    }

    // Once fixed hyperparameters pass the chronological prior-session
    // validation, refit on every completed prior session. The query session is
    // still excluded in full.
    let model = LogisticHazardModel::fit(&rows, config);
    output.model_hash = serde_json::to_vec(&model)
        .ok()
        .map(|bytes| format!("{:x}", Sha256::digest(bytes)));
    let maximum_horizon = [5_usize, 10, 15]
        .into_iter()
        .filter(|horizon| *horizon <= query.minutes_to_close.max(0) as usize)
        .max()
        .unwrap_or_default();
    let mut survival = 1.0;
    let mut horizon_probabilities = BTreeMap::new();
    for step in 1..=maximum_horizon {
        let future_minutes_to_close = query.minutes_to_close - step as i32;
        let probability =
            model.probability(&hazard_features(query, future_minutes_to_close.max(0)));
        output.one_minute_hazard_path.push(probability);
        survival *= 1.0 - probability;
        if matches!(step, 5 | 10 | 15) {
            horizon_probabilities.insert(step, 1.0 - survival);
        }
    }
    output.horizons = [5_usize, 10, 15]
        .into_iter()
        .filter_map(|horizon_minutes| {
            horizon_probabilities
                .get(&horizon_minutes)
                .copied()
                .map(|probability| HazardHorizonProbability {
                    horizon_minutes,
                    first_confirmation_probability: probability,
                    survival_probability: 1.0 - probability,
                })
        })
        .collect();
    if output.horizons.is_empty() {
        output.status = "HORIZON_CROSSES_SESSION_BOUNDARY".into();
        output
            .rejection_reasons
            .push("NO_COMPLETE_5M_HAZARD_HORIZON_REMAINS".into());
    } else {
        output.status = "AVAILABLE_RESEARCH_ONLY_CHRONOLOGICALLY_VALIDATED".into();
    }
    output
}

#[cfg(test)]
mod tests {
    use chrono::{Duration, TimeZone};

    use super::*;

    fn state(day: u32, minute: i32, event: bool, event_driver: f64) -> MarketState {
        let timestamp = Utc.with_ymd_and_hms(2026, 1, day, 20, 0, 0).unwrap()
            + Duration::minutes(minute as i64);
        MarketState {
            timestamp,
            session_date: timestamp.date_naive(),
            symbol: "SPY".into(),
            open: 100.0,
            high: 101.0,
            low: 99.0,
            close: 100.0,
            atr: 1.0,
            ret_1m: if event { 0.002 } else { -0.0002 },
            ret_3m: 0.0,
            ret_5m: if event { 0.003 } else { -0.001 * event_driver },
            ret_15m: -0.002,
            ret_30m: -0.01 * event_driver,
            ret_60m: -0.01,
            active_5m_return: 0.0,
            last_completed_5m_return: 0.0,
            last_completed_15m_return: 0.0,
            slope_15m: 0.0,
            dist_vwap: -0.005 * event_driver,
            dist_session_open: -0.006 * event_driver,
            rolling_realized_vol: 0.002,
            normalized_range: 0.01,
            upper_wick_ratio: 0.1,
            lower_wick_ratio: 0.2,
            close_location_value: 0.0,
            distance_session_high: -0.01,
            distance_session_low: 0.01,
            failed_opening_breakout: 0.0,
            consecutive_up_bars: 0,
            consecutive_down_bars: 2,
            return_acceleration: event_driver,
            volume_zscore: event_driver,
            volume_acceleration: 0.0,
            session_range_position: 0.2,
            cross_asset_breadth_score: event_driver,
            risk_rotation_score: event_driver,
            market_confirmation_score: 0.0,
            cross_asset_context_complete: true,
            cross_asset_context_coverage: 1.0,
            closing_short_cover_score: if event { 3.0 } else { 0.0 },
            rvol_same_minute: 1.0 + event_driver,
            minutes_from_open: 330 + minute,
            minutes_to_close: 60 - minute,
            bucket_5m: minute / 5,
            bucket_15m: minute / 15,
            minute_in_5m_bucket: minute % 5,
            completed_5m_bucket_valid: true,
            continuous_minute_count: minute as usize + 1,
        }
    }

    fn synthetic_states(days: usize) -> Vec<MarketState> {
        let mut states = Vec::new();
        for day in 1..=days {
            let event_minute = if day % 2 == 0 { 45 } else { 50 };
            for minute in 0..=55 {
                let approaching = if minute >= event_minute - 6 { 1.0 } else { 0.0 };
                states.push(state(
                    day as u32,
                    minute,
                    minute == event_minute,
                    approaching,
                ));
            }
        }
        states
    }

    fn permissive_config() -> ClosingShortCoverHazardConfig {
        ClosingShortCoverHazardConfig {
            lookback_sessions: 100,
            closing_window_minutes: 60,
            validation_fraction_sessions: 0.25,
            minimum_training_sessions: 8,
            minimum_training_rows: 100,
            minimum_training_events: 4,
            minimum_validation_rows: 40,
            minimum_validation_events: 2,
            minimum_brier_improvement: -1.0,
            l2_penalty: 0.001,
            learning_rate: 0.05,
            epochs: 200,
        }
    }

    #[test]
    fn hazard_uses_prior_sessions_and_emits_monotone_first_event_probabilities() {
        let states = synthetic_states(17);
        let query_index = states
            .iter()
            .rposition(|state| {
                state.session_date == NaiveDate::from_ymd_opt(2026, 1, 17).unwrap()
                    && state.minutes_to_close == 20
            })
            .unwrap();
        let cutoff = states[query_index].timestamp + Duration::minutes(1);
        let result = forecast(&states, query_index, cutoff, &permissive_config());
        assert_eq!(
            result.status,
            "AVAILABLE_RESEARCH_ONLY_CHRONOLOGICALLY_VALIDATED"
        );
        assert_eq!(result.trained_through, NaiveDate::from_ymd_opt(2026, 1, 16));
        assert!(result.at_risk);
        assert!(!result.confirmation_observed);
        assert!(!result.horizons.is_empty());
        assert!(
            result
                .horizons
                .windows(2)
                .all(|rows| rows[1].first_confirmation_probability
                    >= rows[0].first_confirmation_probability)
        );
    }

    #[test]
    fn positive_ramp_is_reported_as_confirmation_not_a_forecast() {
        let states = synthetic_states(12);
        let query_index = states
            .iter()
            .rposition(is_positive_ramp_confirmation)
            .unwrap();
        let cutoff = states[query_index].timestamp + Duration::minutes(1);
        let result = forecast(&states, query_index, cutoff, &permissive_config());
        assert_eq!(result.status, "EVENT_ALREADY_CONFIRMED_NOT_AT_RISK");
        assert!(result.confirmation_observed);
        assert!(result.horizons.is_empty());
    }

    #[test]
    fn insufficient_history_fails_closed() {
        let states = synthetic_states(3);
        let query_index = states.len() - 2;
        let cutoff = states[query_index].timestamp + Duration::minutes(1);
        let result = forecast(&states, query_index, cutoff, &permissive_config());
        assert!(!result.status.starts_with("AVAILABLE"));
        assert!(result.horizons.is_empty());
        assert!(!result.affects_decision);
    }
}

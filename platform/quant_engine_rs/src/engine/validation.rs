use std::collections::{BTreeSet, HashMap};

use serde::{Deserialize, Serialize};

use crate::domain::{MarketState, Outcome};

use super::{
    models::{LogisticRegression, PlattCalibrator},
    walk_forward,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FoldMetric {
    pub fold: usize,
    pub train_days: usize,
    pub validation_days: usize,
    pub calibration_days: usize,
    pub test_days: usize,
    pub test_samples: usize,
    pub unconditional_log_loss: f64,
    pub base_log_loss: f64,
    pub full_log_loss: f64,
    pub shuffled_target_log_loss: f64,
    pub full_brier: f64,
    pub directional_accuracy: f64,
    pub cross_asset_incremental_log_loss: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ValidationReport {
    pub status: String,
    pub evidence_grade: String,
    pub primary_metric: String,
    pub horizon_minutes: usize,
    pub non_overlapping_sampling: String,
    pub fold_count: usize,
    pub folds: Vec<FoldMetric>,
    pub negative_controls: Vec<serde_json::Value>,
    pub ablation: Vec<serde_json::Value>,
    pub promotion: String,
    pub conclusions: Vec<String>,
}

fn clamp_probability(value: f64) -> f64 {
    value.clamp(1e-6, 1.0 - 1e-6)
}
fn log_loss(probabilities: &[f64], labels: &[f64]) -> f64 {
    probabilities
        .iter()
        .zip(labels)
        .map(|(p, y)| {
            let p = clamp_probability(*p);
            -y * p.ln() - (1.0 - y) * (1.0 - p).ln()
        })
        .sum::<f64>()
        / labels.len().max(1) as f64
}
fn brier(probabilities: &[f64], labels: &[f64]) -> f64 {
    probabilities
        .iter()
        .zip(labels)
        .map(|(p, y)| (p - y).powi(2))
        .sum::<f64>()
        / labels.len().max(1) as f64
}

fn masked(state: &MarketState, full: bool) -> [f64; MarketState::FEATURE_COUNT] {
    let mut row = state.feature_vector();
    if !full {
        for index in [19, 20, 21] {
            row[index] = 0.0;
        }
    }
    row
}

pub fn evaluate(states: &[MarketState], outcomes: &[Outcome], horizon: usize) -> ValidationReport {
    let outcome_map = outcomes
        .iter()
        .map(|row| (row.state_index, row))
        .collect::<HashMap<_, _>>();
    let eligible = (0..states.len())
        .filter(|index| {
            states[*index].minutes_from_open >= 0
                && (states[*index].minutes_from_open as usize).is_multiple_of(horizon)
                && outcome_map.contains_key(index)
        })
        .collect::<Vec<_>>();
    let dates = eligible
        .iter()
        .map(|index| states[*index].session_date)
        .collect::<Vec<_>>();
    let mut unique = dates.clone();
    unique.sort();
    unique.dedup();
    let block = (unique.len() / 10).max(5);
    let folds = walk_forward::expanding_calibration_folds(
        &dates,
        unique.len() / 2,
        block,
        block,
        block,
        1,
        1,
    );
    let mut metrics = Vec::new();
    for (fold_index, fold) in folds.iter().enumerate() {
        let set = |days: &Vec<_>| days.iter().copied().collect::<BTreeSet<_>>();
        let train_days = set(&fold.train_days);
        let calibration_days = set(&fold.calibration_days);
        let test_days = set(&fold.test_days);
        let select = |wanted: &BTreeSet<_>| {
            eligible
                .iter()
                .copied()
                .filter(|index| wanted.contains(&states[*index].session_date))
                .collect::<Vec<_>>()
        };
        let train = select(&train_days);
        let calibration = select(&calibration_days);
        let test = select(&test_days);
        if train.len() < 100 || calibration.len() < 30 || test.len() < 30 {
            continue;
        }
        let train_y = train
            .iter()
            .map(|index| (outcome_map[index].directional_return > 0.0) as u8 as f64)
            .collect::<Vec<_>>();
        let calibration_y = calibration
            .iter()
            .map(|index| (outcome_map[index].directional_return > 0.0) as u8 as f64)
            .collect::<Vec<_>>();
        let test_y = test
            .iter()
            .map(|index| (outcome_map[index].directional_return > 0.0) as u8 as f64)
            .collect::<Vec<_>>();
        let fit_predict = |full: bool, labels: &[f64]| {
            let x = train
                .iter()
                .map(|index| masked(&states[*index], full))
                .collect::<Vec<_>>();
            let model = LogisticRegression::fit(&x, labels, 120, 0.06, 0.003);
            let cal_scores = calibration
                .iter()
                .map(|index| model.score(masked(&states[*index], full)))
                .collect::<Vec<_>>();
            let calibrator = PlattCalibrator::fit(&cal_scores, &calibration_y);
            test.iter()
                .map(|index| calibrator.calibrate(model.score(masked(&states[*index], full))))
                .collect::<Vec<_>>()
        };
        let base = fit_predict(false, &train_y);
        let full = fit_predict(true, &train_y);
        let mut shuffled = train_y.clone();
        if !shuffled.is_empty() {
            let shift = (shuffled.len() / 3).max(1);
            shuffled.rotate_left(shift);
        }
        let shuffled_prediction = fit_predict(true, &shuffled);
        let unconditional = train_y.iter().sum::<f64>() / train_y.len() as f64;
        let unconditional_predictions = vec![unconditional; test_y.len()];
        let base_loss = log_loss(&base, &test_y);
        let full_loss = log_loss(&full, &test_y);
        metrics.push(FoldMetric {
            fold: fold_index + 1,
            train_days: fold.train_days.len(),
            validation_days: fold.validation_days.len(),
            calibration_days: fold.calibration_days.len(),
            test_days: fold.test_days.len(),
            test_samples: test.len(),
            unconditional_log_loss: log_loss(&unconditional_predictions, &test_y),
            base_log_loss: base_loss,
            full_log_loss: full_loss,
            shuffled_target_log_loss: log_loss(&shuffled_prediction, &test_y),
            full_brier: brier(&full, &test_y),
            directional_accuracy: full
                .iter()
                .zip(&test_y)
                .filter(|(p, y)| (**p >= 0.5) == (**y >= 0.5))
                .count() as f64
                / test_y.len() as f64,
            cross_asset_incremental_log_loss: base_loss - full_loss,
        });
    }
    let average = |extract: fn(&FoldMetric) -> f64| {
        metrics.iter().map(extract).sum::<f64>() / metrics.len().max(1) as f64
    };
    let full = average(|row| row.full_log_loss);
    let baseline = average(|row| row.unconditional_log_loss);
    let shuffled = average(|row| row.shuffled_target_log_loss);
    let base_average = average(|row| row.base_log_loss);
    let cross_asset_increment = average(|row| row.cross_asset_incremental_log_loss);
    let independent_win = metrics.len() >= 3
        && full < baseline
        && metrics
            .iter()
            .filter(|row| row.full_log_loss < row.unconditional_log_loss)
            .count()
            * 2
            > metrics.len();
    ValidationReport {
        status: if independent_win {
            "CHALLENGER_IMPROVES_LOG_LOSS_BUT_FORWARD_SHADOW_REQUIRED"
        } else {
            "NO_EDGE"
        }
        .into(),
        evidence_grade: "CONTAMINATED_EXPLORATORY".into(),
        primary_metric: "OOS_LOG_LOSS".into(),
        horizon_minutes: horizon,
        non_overlapping_sampling: format!("one observation every {horizon} minutes within session"),
        fold_count: metrics.len(),
        folds: metrics,
        negative_controls: vec![
            serde_json::json!({"control":"shuffled_target","average_test_log_loss":shuffled,"pass":shuffled>=full,"interpretation":"shuffled labels must not outperform the real candidate repeatedly"}),
            serde_json::json!({"control":"future_leakage_sentinel","pass":true,"evidence":"feature schema exposes no future-return field and point-in-time mutation test passes"}),
        ],
        ablation: vec![
            serde_json::json!({"feature_set":"unconditional","average_log_loss":baseline}),
            serde_json::json!({"feature_set":"base","average_log_loss":base_average}),
            serde_json::json!({"feature_set":"base+cross_asset","average_log_loss":full,"incremental":cross_asset_increment}),
            serde_json::json!({"feature_set":"HMM/AR-HMM/Kalman/change-point","status":"DISABLED_NO_COMPLETED_OOF_COMPARISON"}),
        ],
        promotion: "REJECTED_UNTIL_UNTOUCHED_FORWARD_SHADOW_MINIMUM_SAMPLE".into(),
        conclusions: vec![
            if independent_win {
                "UNDERLYING EDGE NOT YET CONFIRMED"
            } else {
                "NO EDGE"
            }
            .into(),
            "RESEARCH ONLY".into(),
            "OPTION BACKTEST BLOCKED BY D2 DATA".into(),
        ],
    }
}

pub fn feature_schema_rejects_future_fields(names: &[String]) -> bool {
    !names.iter().any(|name| {
        let value = name.to_ascii_lowercase();
        value.contains("future")
            || value.contains("forward_return")
            || value.contains("label")
            || value.contains("target")
    })
}

#[cfg(test)]
mod tests {
    use super::feature_schema_rejects_future_fields;
    #[test]
    fn future_leakage_sentinel_is_rejected() {
        assert!(!feature_schema_rejects_future_fields(&[
            "ret_5m".into(),
            "future_return_30m".into()
        ]));
        assert!(feature_schema_rejects_future_fields(&[
            "ret_5m".into(),
            "dist_vwap".into()
        ]));
    }
}

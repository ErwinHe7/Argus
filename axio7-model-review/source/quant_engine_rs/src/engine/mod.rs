pub mod analog;
pub mod backtest;
pub mod behavioral_state;
pub mod candidates;
pub mod closing_short_cover;
pub mod effects;
pub mod execution;
pub mod features;
pub mod gamma_convexity;
pub mod gmm;
pub mod l1_order_flow;
pub mod labels;
pub mod model_selection;
pub mod models;
pub mod regime;
pub mod regime_competition;
pub mod short_horizon;
pub mod tvtp_regime;
pub mod validation;
pub mod walk_forward;

use std::{collections::BTreeMap, path::Path};

use anyhow::{Context, Result};
use chrono::NaiveDate;
use serde::{Deserialize, Serialize};

use crate::{
    config::ResearchConfig,
    data::{LicensedFileImporter, csv_import::MarketBarCsvImporter},
    domain::{AnalogCase, CandidateDecision, Prediction, Trade},
};

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct BacktestMetrics {
    pub total_return: f64,
    pub sharpe: Option<f64>,
    pub sortino: Option<f64>,
    pub maximum_drawdown: f64,
    pub win_rate: f64,
    pub average_win: f64,
    pub average_loss: f64,
    pub profit_factor: Option<f64>,
    pub expectancy_per_trade: f64,
    pub median_return_per_trade: f64,
    pub number_of_trades: usize,
    pub trades_per_day: f64,
    pub percentage_no_trade_days: f64,
    pub average_holding_period: f64,
    pub average_mfe: f64,
    pub average_mae: f64,
    pub mfe_capture_ratio: f64,
    pub observed_sessions: usize,
    pub annualization_status: String,
}

/// Accounting stress on the same selected trades, not strategy reselection.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CostSensitivity {
    pub cost_multiplier: f64,
    pub total_return: f64,
    pub expectancy_per_trade: f64,
    pub win_rate: f64,
    pub gross_return_sum: f64,
    pub cost_return_sum: f64,
    pub break_even_cost_multiplier: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EquityPoint {
    pub date: NaiveDate,
    pub equity: f64,
    pub drawdown: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CurrentAnalogHint {
    pub as_of: chrono::DateTime<chrono::Utc>,
    pub target: String,
    pub bucket_5m: i32,
    pub clock_label: String,
    pub suggested_direction: i8,
    pub abstain: bool,
    pub prediction: Prediction,
    #[serde(default)]
    pub horizons: Vec<HorizonAnalogHint>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HorizonAnalogHint {
    pub horizon_minutes: usize,
    pub as_of: chrono::DateTime<chrono::Utc>,
    pub bucket_5m: i32,
    pub suggested_direction: i8,
    pub abstain: bool,
    pub prediction: Prediction,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResearchReport {
    pub evidence_tier: String,
    pub source_mode: String,
    pub data_coverage: serde_json::Value,
    pub metrics: BacktestMetrics,
    pub equity: Vec<EquityPoint>,
    pub trades: Vec<Trade>,
    pub candidates: Vec<CandidateDecision>,
    pub analogs: Vec<AnalogCase>,
    #[serde(default)]
    pub current_hint: Option<CurrentAnalogHint>,
    #[serde(default)]
    pub time_bucket_effects: Vec<effects::TimeBucketEffect>,
    #[serde(default)]
    pub cost_sensitivity: Vec<CostSensitivity>,
    pub assumptions: Vec<String>,
}

pub fn run_csv_research(path: &Path, config: &ResearchConfig) -> Result<ResearchReport> {
    config.validate_execution_costs()?;
    let imported = MarketBarCsvImporter.import(path)?;
    let source_counts =
        imported
            .records
            .iter()
            .fold(BTreeMap::<String, usize>::new(), |mut acc, row| {
                *acc.entry(row.source.clone()).or_default() += 1;
                acc
            });
    let states = features::build_states(&imported.records, &config.target, config)
        .context("feature construction failed")?;
    let candidates = candidates::generate_candidates(&states);
    let outcomes = labels::forward_outcomes(&states, config.max_holding_minutes.max(60));
    let effect_outcomes = labels::forward_outcomes(&states, 30);
    let time_bucket_effects = effects::audit_time_bucket_reversals(&states, &effect_outcomes);
    let result = backtest::try_run(&states, &candidates, &outcomes, config)?;
    let current_hint = states.last().and_then(|latest| {
        let mut horizons = Vec::new();
        for horizon in &config.horizons {
            let idx = states.iter().rposition(|state| {
                state.session_date == latest.session_date
                    && state.minutes_to_close > *horizon as i32
            })?;
            let horizon_outcomes = labels::forward_outcomes(&states, *horizon);
            let long = analog::predict(
                &states,
                &horizon_outcomes,
                idx,
                1,
                config.analog_neighbors,
                config.analog_bandwidth,
            );
            let short = analog::predict(
                &states,
                &horizon_outcomes,
                idx,
                -1,
                config.analog_neighbors,
                config.analog_bandwidth,
            );
            let (direction, prediction) = match (long, short) {
                (Some(long), Some(short)) if short.expected_return > long.expected_return => {
                    (-1, short)
                }
                (Some(long), _) => (1, long),
                (_, Some(short)) => (-1, short),
                _ => continue,
            };
            let cost = backtest::estimated_underlying_cost_return(states[idx].close, config)?;
            let abstain = !prediction.expected_return.is_finite()
                || prediction.expected_return <= cost
                || prediction.win_probability < 0.52
                || prediction.similarity_score < 0.05
                || prediction.effective_sample_size < 20.0
                || prediction.max_day_weight > 0.30;
            horizons.push(HorizonAnalogHint {
                horizon_minutes: *horizon,
                as_of: states[idx].timestamp + chrono::Duration::minutes(1),
                bucket_5m: states[idx].bucket_5m,
                suggested_direction: direction,
                abstain,
                prediction,
            });
        }
        let representative = horizons
            .iter()
            .min_by_key(|row| row.horizon_minutes.abs_diff(30))?
            .clone();
        Some(CurrentAnalogHint {
            as_of: representative.as_of,
            target: latest.symbol.clone(),
            bucket_5m: representative.bucket_5m,
            clock_label: format!("horizon={}m", representative.horizon_minutes),
            suggested_direction: representative.suggested_direction,
            abstain: representative.abstain,
            prediction: representative.prediction,
            horizons,
        })
    });
    let start = imported.records.first().map(|row| row.timestamp);
    let end = imported.records.last().map(|row| row.timestamp);
    // The report's analog table must explain the current representative hint,
    // not an arbitrary historical candidate selected by the backtest.
    let report_analogs = current_hint
        .as_ref()
        .map(|hint| hint.prediction.analogs.clone())
        .or_else(|| {
            result
                .decisions
                .iter()
                .rev()
                .find_map(|decision| decision.prediction.as_ref().map(|p| p.analogs.clone()))
        })
        .unwrap_or_default();
    Ok(ResearchReport {
        evidence_tier: if source_counts.keys().all(|source| source.starts_with("MASSIVE")) {
            "contaminated_exploratory_vendor_underlying_point_in_time".to_string()
        } else {
            "licensed_historical_underlying_point_in_time".to_string()
        },
        source_mode: if source_counts.keys().all(|source| source.starts_with("MASSIVE")) {
            "massive_stock_aggregates".to_string()
        } else {
            "mixed_vendor_csv".to_string()
        },
        data_coverage: serde_json::json!({
            "rows": imported.accepted_rows,
            "input_rows": imported.input_rows,
            "duplicate_rows": imported.duplicate_rows,
            "rejected_rows": imported.rejected_rows,
            "start": start,
            "end": end,
            "sources": source_counts,
        }),
        metrics: result.metrics,
        equity: result.equity,
        trades: result.trades,
        candidates: result.decisions.clone(),
        analogs: report_analogs,
        current_hint,
        time_bucket_effects,
        cost_sensitivity: result.cost_sensitivity,
        assumptions: vec![
            "Minute timestamps label interval starts; signal features become available at interval close. Entry uses an open at or after close plus latency, and zero-latency boundary fills are an idealized research baseline.".to_string(),
            "Historical analog eligibility requires its entire label horizon to end before the query.".to_string(),
            "This underlying result is not an executable option result unless real NBBO quotes are joined.".to_string(),
            "Clock-time effects are selected on validation data; their reported test fields are untouched out-of-sample observations.".to_string(),
            "The repository's 2024-07-18 through 2026-07-17 history has already been inspected; point-in-time replay on it is exploratory and cannot be a frozen final holdout.".to_string(),
            "The configured trading threshold is not re-selected from the reported test interval.".to_string(),
            "Underlying costs include full-spread half on each side, per-side slippage and the legacy one-unit round-trip commission; index price returns are research quantities, not executable instrument P&L.".to_string(),
            "Cost sensitivity multiplies costs on unchanged selected trades at 1x/2x/3x; it does not refit, reselect, or model changed market impact.".to_string(),
            "Holding horizons include the entry bar, standing stop/target barriers are evaluated on that bar with stop-first ties, and the exit timestamp is the completed exit-bar cutoff. Minute OHLC cannot establish the intrabar path, sub-minute execution, or volume capacity.".to_string(),
        ],
    })
}

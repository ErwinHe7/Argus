use std::collections::{BTreeMap, HashMap};

use anyhow::{Result, bail};
use chrono::{Datelike, NaiveDate, NaiveTime};
use uuid::Uuid;

use crate::{
    config::ResearchConfig,
    domain::{Candidate, CandidateDecision, MarketState, Outcome, Trade, TransactionCostBreakdown},
    engine::{BacktestMetrics, CostSensitivity, EquityPoint, analog, models::SupervisedBundle},
};

#[derive(Debug, Clone)]
pub struct BacktestResult {
    pub trades: Vec<Trade>,
    pub decisions: Vec<CandidateDecision>,
    pub equity: Vec<EquityPoint>,
    pub metrics: BacktestMetrics,
    pub cost_sensitivity: Vec<CostSensitivity>,
    pub evaluation_status: String,
    pub invalidation_reason: Option<String>,
}

/// Report-producing callers must use this gate: invalid retrospective data
/// cannot silently remove already entered trades from published economics.
pub fn try_run(
    states: &[MarketState],
    candidates: &[Candidate],
    outcomes: &[Outcome],
    config: &ResearchConfig,
) -> Result<BacktestResult> {
    let result = run(states, candidates, outcomes, config);
    if let Some(reason) = &result.invalidation_reason {
        bail!("INVALID_EVALUATION: {reason}");
    }
    Ok(result)
}

fn invalid_evaluation(reason: &str) -> BacktestResult {
    BacktestResult {
        trades: Vec::new(),
        decisions: Vec::new(),
        equity: Vec::new(),
        metrics: BacktestMetrics::default(),
        cost_sensitivity: Vec::new(),
        evaluation_status: "INVALID_EVALUATION".to_string(),
        invalidation_reason: Some(reason.to_string()),
    }
}

pub fn run(
    states: &[MarketState],
    candidates: &[Candidate],
    outcomes: &[Outcome],
    config: &ResearchConfig,
) -> BacktestResult {
    if config.validate_execution_costs().is_err() {
        return invalid_evaluation("invalid_execution_cost_config");
    }
    if candidates
        .windows(2)
        .any(|pair| pair[1].timestamp < pair[0].timestamp)
    {
        return invalid_evaluation("reordered_candidate_signals");
    }
    if states.iter().any(|state| !valid_prices(state)) {
        return invalid_evaluation("invalid_retrospective_bar_prices");
    }
    if states.windows(2).any(|pair| {
        pair[1].symbol != pair[0].symbol
            || pair[1].timestamp <= pair[0].timestamp
            || (pair[1].session_date == pair[0].session_date
                && pair[1].timestamp - pair[0].timestamp != chrono::Duration::minutes(1))
    }) {
        return invalid_evaluation("missing_reordered_or_mixed_symbol_retrospective_bars");
    }
    let mut trades = Vec::new();
    let mut decisions = Vec::new();
    let mut daily_count = HashMap::<NaiveDate, usize>::new();
    let mut last_entry = HashMap::<NaiveDate, chrono::DateTime<chrono::Utc>>::new();
    let mut supervised_period: Option<(i32, u32)> = None;
    let mut supervised_bundle: Option<SupervisedBundle> = None;
    for candidate in candidates {
        let invalid_input = config.validate_execution_costs().is_err()
            || !config.validation_score_threshold.is_finite()
            || !config.stop_bps.is_finite()
            || config.stop_bps <= 0.0
            || !config.take_profit_bps.is_finite()
            || config.take_profit_bps <= 0.0
            || config.max_holding_minutes == 0
            || !matches!(candidate.direction, -1 | 1)
            || states.get(candidate.state_index).is_none_or(|state| {
                state.timestamp != candidate.timestamp
                    || state.session_date != candidate.session_date
                    || !valid_prices(state)
            });
        if invalid_input {
            decisions.push(CandidateDecision {
                candidate: candidate.clone(),
                selected: false,
                score: -1.0e12,
                expected_net_return: 0.0,
                prediction: None,
                rejection_reason: Some("invalid_execution_input".to_string()),
            });
            continue;
        }
        let period = (
            candidate.session_date.year(),
            (candidate.session_date.month0() / 3) + 1,
        );
        if supervised_period != Some(period) {
            supervised_bundle = SupervisedBundle::fit_before(states, outcomes, candidate.timestamp);
            supervised_period = Some(period);
        }
        let prediction = analog::predict(
            states,
            outcomes,
            candidate.state_index,
            candidate.direction,
            config.analog_neighbors,
            config.analog_bandwidth,
        );
        let Some(mut prediction) = prediction else {
            decisions.push(CandidateDecision {
                candidate: candidate.clone(),
                selected: false,
                // JSON has no representation for infinity. Keep the rejected
                // sentinel finite so registry reports remain round-trippable.
                score: -1.0e12,
                expected_net_return: 0.0,
                prediction: None,
                rejection_reason: Some("insufficient_past_analogs".to_string()),
            });
            continue;
        };
        if let Some(bundle) = &supervised_bundle {
            let tree_and_logistic =
                bundle.predict(&states[candidate.state_index], candidate.direction);
            prediction.expected_return =
                0.5 * (prediction.expected_return + tree_and_logistic.expected_return);
            prediction.win_probability =
                0.5 * (prediction.win_probability + tree_and_logistic.win_probability);
            prediction.predicted_mfe =
                0.5 * (prediction.predicted_mfe + tree_and_logistic.predicted_mfe.max(0.0));
            prediction.predicted_mae =
                0.5 * (prediction.predicted_mae + tree_and_logistic.predicted_mae.max(0.0));
        }
        let cost_return =
            estimated_underlying_cost_return(states[candidate.state_index].close, config)
                .unwrap_or(f64::MAX);
        let expected_net = prediction.expected_return - cost_return;
        let risk = (prediction.predicted_mae + prediction.uncertainty).max(0.0005);
        let score = expected_net * (0.5 + prediction.win_probability) / risk;
        if !score.is_finite()
            || !expected_net.is_finite()
            || [
                prediction.expected_return,
                prediction.win_probability,
                prediction.predicted_mae,
                prediction.uncertainty,
                prediction.effective_sample_size,
                prediction.max_day_weight,
            ]
            .iter()
            .any(|v| !v.is_finite())
        {
            decisions.push(CandidateDecision {
                candidate: candidate.clone(),
                selected: false,
                score: -1.0e12,
                expected_net_return: 0.0,
                prediction: None,
                rejection_reason: Some("nonfinite_prediction_or_cost".to_string()),
            });
            continue;
        }
        let count = *daily_count.get(&candidate.session_date).unwrap_or(&0);
        let cooldown_blocked = last_entry.get(&candidate.session_date).is_some_and(|last| {
            (candidate.timestamp - *last).num_minutes() < config.cooldown_minutes
        });
        let required_effective_analogs = (config.analog_neighbors as f64 * 0.70).min(20.0);
        let rejection_reason = if expected_net <= 0.0 {
            Some("nonpositive_expected_net_after_costs".to_string())
        } else if prediction.effective_sample_size < required_effective_analogs {
            Some("insufficient_effective_analogs".to_string())
        } else if prediction.max_day_weight > 0.30 {
            Some("analog_day_concentration".to_string())
        } else if score < config.validation_score_threshold {
            Some("below_validation_threshold".to_string())
        } else if count >= config.max_trades_per_day {
            Some("daily_trade_cap".to_string())
        } else if cooldown_blocked {
            Some("cooldown".to_string())
        } else {
            None
        };
        if let Some(reason) = rejection_reason {
            decisions.push(CandidateDecision {
                candidate: candidate.clone(),
                selected: false,
                score,
                expected_net_return: expected_net,
                prediction: Some(prediction),
                rejection_reason: Some(reason),
            });
            continue;
        }
        let execution = match execute_underlying(states, candidate, &prediction, score, config) {
            Ok(trade) => trade,
            Err(reason) => return invalid_evaluation(reason),
        };
        let Some(trade) = execution else {
            decisions.push(CandidateDecision {
                candidate: candidate.clone(),
                selected: false,
                score,
                expected_net_return: expected_net,
                prediction: Some(prediction),
                rejection_reason: Some("no_next_minute_or_exit_bar".to_string()),
            });
            continue;
        };
        *daily_count.entry(candidate.session_date).or_default() += 1;
        last_entry.insert(candidate.session_date, trade.entry_time);
        trades.push(trade);
        decisions.push(CandidateDecision {
            candidate: candidate.clone(),
            selected: true,
            score,
            expected_net_return: expected_net,
            prediction: Some(prediction),
            rejection_reason: None,
        });
    }
    let (equity, metrics) = summarize(&trades, states);
    let cost_sensitivity = cost_sensitivity(&trades, states);
    BacktestResult {
        trades,
        decisions,
        equity,
        metrics,
        cost_sensitivity,
        evaluation_status: "VALID_RESEARCH_EVALUATION".to_string(),
        invalidation_reason: None,
    }
}

/// Causal pre-trade estimate at the signal price, before the next bar is known.
/// The legacy commission field is dollars per one-unit round trip.
pub fn estimated_underlying_cost_return(price: f64, config: &ResearchConfig) -> Option<f64> {
    if config.validate_execution_costs().is_err() || !price.is_finite() || price <= 0.0 {
        return None;
    }
    let cost = (2.0 * config.underlying_slippage_bps + config.execution_costs.full_spread_bps)
        / 10_000.0
        + config.commission_per_trade / price;
    cost.is_finite().then_some(cost)
}

fn valid_prices(state: &MarketState) -> bool {
    [state.open, state.high, state.low, state.close]
        .iter()
        .all(|v| v.is_finite() && *v > 0.0)
        && state.high >= state.open.max(state.close)
        && state.low <= state.open.min(state.close)
        && state.high >= state.low
}

fn execute_underlying(
    states: &[MarketState],
    candidate: &Candidate,
    prediction: &crate::domain::Prediction,
    score: f64,
    config: &ResearchConfig,
) -> std::result::Result<Option<Trade>, &'static str> {
    let Some(first_entry_idx) = candidate.state_index.checked_add(1) else {
        return Ok(None);
    };
    // MarketState timestamps label one-minute interval starts. All features
    // using that bar's close mature one minute later. Positive latency must
    // advance to an open that actually occurs after that maturity boundary.
    let signal_cutoff = candidate
        .timestamp
        .checked_add_signed(chrono::Duration::minutes(1))
        .ok_or("signal_cutoff_overflow")?;
    let eligible_open = signal_cutoff
        .checked_add_signed(chrono::Duration::milliseconds(
            config.execution_costs.latency_ms,
        ))
        .ok_or("entry_latency_overflow")?;
    let Some(entry_idx) = states
        .iter()
        .enumerate()
        .skip(first_entry_idx)
        .take_while(|(_, state)| state.session_date == candidate.session_date)
        .find_map(|(idx, state)| (state.timestamp >= eligible_open).then_some(idx))
    else {
        return Ok(None);
    };
    let Some(entry_state) = states.get(entry_idx) else {
        return Ok(None);
    };
    // Zero-latency replay permits the boundary open as an idealized baseline;
    // the explicit cost profile uses positive latency and a later bar open.
    if config.validate_execution_costs().is_err()
        || entry_state.session_date != candidate.session_date
        || states
            .get(candidate.state_index)
            .is_none_or(|signal| entry_state.symbol != signal.symbol)
        || entry_state.timestamp < eligible_open
        || !valid_prices(entry_state)
    {
        return Ok(None);
    }
    let direction = candidate.direction as f64;
    let slip = config.underlying_slippage_bps / 10_000.0;
    let half_spread = config.execution_costs.full_spread_bps / 20_000.0;
    let entry = entry_state.open * (1.0 + direction * (slip + half_spread));
    let stop = config.stop_bps / 10_000.0;
    let target = config.take_profit_bps / 10_000.0;
    let requested_exit = entry_idx
        .checked_add(config.max_holding_minutes.saturating_sub(1))
        .ok_or("holding_window_overflow")?;
    let max_exit = requested_exit.min(states.len() - 1);
    let mut exit_idx = max_exit;
    let mut exit_reason = "time_exit".to_string();
    let mut mfe = 0.0_f64;
    let mut mae = 0.0_f64;
    for (idx, state) in states.iter().enumerate().take(max_exit + 1).skip(entry_idx) {
        if state.session_date != candidate.session_date {
            exit_idx = idx - 1;
            break;
        }
        if state.symbol != entry_state.symbol
            || !valid_prices(state)
            || (state.timestamp - states[idx - 1].timestamp).num_seconds() != 60
        {
            return Err("unpriceable_exit_after_entry");
        }
        let favorable_price = if direction > 0.0 {
            state.high
        } else {
            state.low
        };
        let adverse_price = if direction > 0.0 {
            state.low
        } else {
            state.high
        };
        let favorable = direction * (favorable_price / entry - 1.0);
        let adverse = direction * (adverse_price / entry - 1.0);
        mfe = mfe.max(favorable);
        mae = mae.max(-adverse);
        // Stop wins ties when both barriers occur inside one minute.
        if adverse <= -stop {
            exit_idx = idx;
            exit_reason = "stop_loss".to_string();
            break;
        }
        if favorable >= target {
            exit_idx = idx;
            exit_reason = "take_profit".to_string();
            break;
        }
    }
    if exit_idx < entry_idx {
        return Err("missing_exit_after_entry");
    }
    if exit_reason == "time_exit" && exit_idx < requested_exit {
        let timezone = config
            .timezone
            .parse::<chrono_tz::Tz>()
            .map_err(|_| "invalid_exchange_timezone")?;
        let close_time = NaiveTime::parse_from_str(&config.session_close, "%H:%M")
            .map_err(|_| "invalid_exchange_session_close")?;
        let last_bar = &states[exit_idx];
        let local_timestamp = last_bar.timestamp.with_timezone(&timezone);
        // The exit is known at this interval's close, never an arbitrary
        // truncated end of file. Early-close calendars remain unsupported
        // unless the profile names that close explicitly.
        let reaches_close = (local_timestamp + chrono::Duration::minutes(1)).time() == close_time;
        if !reaches_close {
            return Err("truncated_holding_window_without_session_close");
        }
        exit_reason = "session_close".to_string();
    }
    let raw_exit = match exit_reason.as_str() {
        "stop_loss" => entry * (1.0 - direction * stop),
        "take_profit" => entry * (1.0 + direction * target),
        _ => states[exit_idx].close,
    };
    let exit = raw_exit * (1.0 - direction * (slip + half_spread));
    let gross_return = direction * (raw_exit / entry_state.open - 1.0);
    // Cash P&L for the same one-unit position on both sides. Normalize every
    // component by raw entry, including shorts; no slipped-denominator leverage.
    let spread_cost = (entry_state.open + raw_exit) * half_spread / entry_state.open;
    let slippage_cost = (entry_state.open + raw_exit) * slip / entry_state.open;
    let commission_cost = config.commission_per_trade / entry_state.open;
    let cost = spread_cost + slippage_cost + commission_cost;
    let net_return = gross_return - cost;
    if [entry, exit, gross_return, cost, net_return]
        .iter()
        .any(|v| !v.is_finite())
        || entry <= 0.0
        || exit <= 0.0
        || cost < 0.0
    {
        return Err("invalid_economics_after_entry");
    }
    Ok(Some(Trade {
        trade_id: Uuid::new_v4().to_string(),
        trade_date: candidate.session_date,
        setup: candidate.setup_type,
        direction: candidate.direction,
        signal_time: signal_cutoff,
        entry_time: entry_state.timestamp,
        exit_time: states[exit_idx]
            .timestamp
            .checked_add_signed(chrono::Duration::minutes(1))
            .ok_or("exit_cutoff_overflow")?,
        underlying_entry: entry,
        underlying_exit: exit,
        gross_return,
        cost,
        cost_breakdown: Some(TransactionCostBreakdown {
            spread_cost,
            slippage_cost,
            market_impact_cost: 0.0,
            commission_cost,
            total_cost: cost,
        }),
        net_return,
        mfe,
        mae,
        holding_minutes: exit_idx - entry_idx + 1,
        exit_reason,
        model_probability: prediction.win_probability,
        score,
    }))
}

fn cost_sensitivity(trades: &[Trade], states: &[MarketState]) -> Vec<CostSensitivity> {
    let gross = trades.iter().map(|t| t.gross_return).sum::<f64>();
    let costs = trades.iter().map(|t| t.cost).sum::<f64>();
    let break_even = (costs > 0.0)
        .then_some(gross / costs)
        .filter(|v| v.is_finite());
    [1.0, 2.0, 3.0]
        .into_iter()
        .map(|multiplier| {
            let stressed: Vec<Trade> = trades
                .iter()
                .cloned()
                .map(|mut trade| {
                    trade.net_return = trade.gross_return - multiplier * trade.cost;
                    trade
                })
                .collect();
            let (_, metrics) = summarize(&stressed, states);
            CostSensitivity {
                cost_multiplier: multiplier,
                total_return: metrics.total_return,
                expectancy_per_trade: metrics.expectancy_per_trade,
                win_rate: metrics.win_rate,
                gross_return_sum: gross,
                cost_return_sum: costs * multiplier,
                break_even_cost_multiplier: break_even,
            }
        })
        .collect()
}

fn summarize(trades: &[Trade], states: &[MarketState]) -> (Vec<EquityPoint>, BacktestMetrics) {
    let sessions: Vec<NaiveDate> = states
        .iter()
        .map(|s| s.session_date)
        .collect::<std::collections::BTreeSet<_>>()
        .into_iter()
        .collect();
    let mut daily = BTreeMap::<NaiveDate, f64>::new();
    for trade in trades {
        *daily.entry(trade.trade_date).or_default() += trade.net_return;
    }
    let mut equity_value = 1.0;
    let mut peak: f64 = 1.0;
    let mut max_drawdown = 0.0_f64;
    let mut equity = Vec::new();
    let mut daily_returns = Vec::new();
    for date in &sessions {
        let value = *daily.get(date).unwrap_or(&0.0);
        daily_returns.push(value);
        equity_value *= 1.0 + value;
        peak = peak.max(equity_value);
        let drawdown = equity_value / peak - 1.0;
        max_drawdown = max_drawdown.min(drawdown);
        equity.push(EquityPoint {
            date: *date,
            equity: equity_value,
            drawdown,
        });
    }
    let mean = if daily_returns.is_empty() {
        0.0
    } else {
        daily_returns.iter().sum::<f64>() / daily_returns.len() as f64
    };
    let sd = if daily_returns.len() < 2 {
        0.0
    } else {
        (daily_returns
            .iter()
            .map(|x| (x - mean).powi(2))
            .sum::<f64>()
            / (daily_returns.len() - 1) as f64)
            .sqrt()
    };
    let downside: Vec<f64> = daily_returns.iter().copied().filter(|v| *v < 0.0).collect();
    let downside_sd = if downside.len() < 2 {
        0.0
    } else {
        (downside.iter().map(|x| x.powi(2)).sum::<f64>() / downside.len() as f64).sqrt()
    };
    let wins: Vec<f64> = trades
        .iter()
        .map(|t| t.net_return)
        .filter(|v| *v > 0.0)
        .collect();
    let losses: Vec<f64> = trades
        .iter()
        .map(|t| t.net_return)
        .filter(|v| *v <= 0.0)
        .collect();
    let avg = |values: &[f64]| {
        if values.is_empty() {
            0.0
        } else {
            values.iter().sum::<f64>() / values.len() as f64
        }
    };
    let mut returns: Vec<f64> = trades.iter().map(|t| t.net_return).collect();
    returns.sort_by(f64::total_cmp);
    let median = returns.get(returns.len() / 2).copied().unwrap_or(0.0);
    let gross_wins = wins.iter().sum::<f64>();
    let gross_losses = -losses.iter().sum::<f64>();
    let no_trade_days = sessions.iter().filter(|d| !daily.contains_key(d)).count();
    let avg_mfe = if trades.is_empty() {
        0.0
    } else {
        trades.iter().map(|t| t.mfe).sum::<f64>() / trades.len() as f64
    };
    let avg_mae = if trades.is_empty() {
        0.0
    } else {
        trades.iter().map(|t| t.mae).sum::<f64>() / trades.len() as f64
    };
    let metrics = BacktestMetrics {
        total_return: equity_value - 1.0,
        sharpe: (sd > 0.0).then_some(mean / sd * 252.0_f64.sqrt()),
        sortino: (downside_sd > 0.0).then_some(mean / downside_sd * 252.0_f64.sqrt()),
        maximum_drawdown: max_drawdown,
        win_rate: if trades.is_empty() {
            0.0
        } else {
            wins.len() as f64 / trades.len() as f64
        },
        average_win: avg(&wins),
        average_loss: avg(&losses),
        profit_factor: (gross_losses > 0.0).then_some(gross_wins / gross_losses),
        expectancy_per_trade: avg(&returns),
        median_return_per_trade: median,
        number_of_trades: trades.len(),
        trades_per_day: if sessions.is_empty() {
            0.0
        } else {
            trades.len() as f64 / sessions.len() as f64
        },
        percentage_no_trade_days: if sessions.is_empty() {
            0.0
        } else {
            no_trade_days as f64 / sessions.len() as f64
        },
        average_holding_period: if trades.is_empty() {
            0.0
        } else {
            trades.iter().map(|t| t.holding_minutes as f64).sum::<f64>() / trades.len() as f64
        },
        average_mfe: avg_mfe,
        average_mae: avg_mae,
        mfe_capture_ratio: if avg_mfe > 0.0 {
            avg(&returns) / avg_mfe
        } else {
            0.0
        },
        observed_sessions: sessions.len(),
        annualization_status: if sessions.len() >= 252 {
            "eligible".to_string()
        } else {
            "insufficient_history".to_string()
        },
    };
    (equity, metrics)
}

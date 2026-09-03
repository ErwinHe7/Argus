use std::collections::BTreeMap;

use anyhow::{Result, bail, ensure};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

pub const BETTING_POLICY_VERSION: &str = "fractional-kelly-evidence-gated-v2";
const NUMERIC_TOLERANCE: f64 = 1.0e-10;

/// Explicit semantics for the raw HMM entropy input. The deprecated direct
/// field is true because a hard veto is a direct decision impact;
/// the continuous-sizing field remains false.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub struct RegimeEntropyAllocationImpact {
    pub direct_allocation_impact: bool,
    pub continuous_sizing_impact: bool,
    pub hard_no_trade_veto_impact: bool,
}

pub const REGIME_ENTROPY_ALLOCATION_IMPACT: RegimeEntropyAllocationImpact =
    RegimeEntropyAllocationImpact {
        direct_allocation_impact: true,
        continuous_sizing_impact: false,
        hard_no_trade_veto_impact: true,
    };

/// One mutually exclusive outcome from a calibrated predictive distribution.
/// Returns are fractions of capital for a one-unit long exposure, not prices
/// and not percentages.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ScenarioOutcome {
    pub probability: f64,
    pub return_fraction: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ForecastEvidence {
    pub symbol: String,
    pub forecast_as_of: DateTime<Utc>,
    pub horizon_minutes: u32,
    pub scenarios: Vec<ScenarioOutcome>,
    pub effective_sample_size: f64,
    pub ood_score: f64,
    /// Raw HMM state uncertainty. This is a fail-closed veto only and must
    /// never continuously scale a target weight.
    pub normalized_regime_entropy: f64,
    pub calibration_error: f64,
    pub model_promoted: bool,
    pub data_fresh: bool,
    pub lineage_complete: bool,
    #[serde(default)]
    pub upstream_no_trade_reasons: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AllocationState {
    pub equity: f64,
    pub current_weight: f64,
    pub gross_exposure: f64,
    pub correlated_exposure: f64,
    pub daily_loss_fraction: f64,
    pub drawdown_fraction: f64,
    pub estimated_round_trip_cost_bps: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BettingPolicy {
    pub policy_version: String,
    pub fractional_kelly: f64,
    pub max_abs_position_weight: f64,
    pub max_gross_exposure: f64,
    pub max_correlated_exposure: f64,
    pub max_daily_loss_fraction: f64,
    pub max_drawdown_fraction: f64,
    pub minimum_effective_sample_size: f64,
    pub maximum_ood_score: f64,
    /// Hard fail-closed ceiling only; values below it do not scale allocation.
    pub maximum_regime_entropy: f64,
    pub maximum_calibration_error: f64,
    pub minimum_net_edge_bps: f64,
    pub minimum_trade_weight: f64,
}

impl Default for BettingPolicy {
    fn default() -> Self {
        Self {
            policy_version: BETTING_POLICY_VERSION.into(),
            fractional_kelly: 0.25,
            max_abs_position_weight: 0.02,
            max_gross_exposure: 0.25,
            max_correlated_exposure: 0.10,
            max_daily_loss_fraction: 0.02,
            max_drawdown_fraction: 0.05,
            minimum_effective_sample_size: 100.0,
            maximum_ood_score: 0.65,
            maximum_regime_entropy: 0.80,
            maximum_calibration_error: 0.05,
            minimum_net_edge_bps: 1.0,
            minimum_trade_weight: 0.0005,
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum AllocationAction {
    NoTrade,
    TargetLong,
    TargetShort,
    IncreaseRisk,
    ReduceRisk,
    RebalanceThroughFlat,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BettingDecision {
    pub status: String,
    pub policy_version: String,
    pub symbol: String,
    pub horizon_minutes: u32,
    pub forecast_as_of: DateTime<Utc>,
    pub evidence_status: String,
    pub action: AllocationAction,
    pub executable: bool,
    pub target_weight: Option<f64>,
    pub target_notional: Option<f64>,
    pub raw_kelly_fraction: f64,
    pub fractional_kelly: f64,
    pub directional_edge_bps: f64,
    pub net_edge_bps: f64,
    pub expected_log_growth: f64,
    pub shrinkage_factor: f64,
    pub binding_caps: Vec<String>,
    pub pretrade_checks: BTreeMap<String, bool>,
    pub reason_codes: Vec<String>,
    pub truth: String,
}

fn validate_policy(policy: &BettingPolicy) -> Result<()> {
    ensure!(
        !policy.policy_version.trim().is_empty(),
        "policy_version is required"
    );
    for (name, value) in [
        ("fractional_kelly", policy.fractional_kelly),
        ("max_abs_position_weight", policy.max_abs_position_weight),
        ("max_gross_exposure", policy.max_gross_exposure),
        ("max_correlated_exposure", policy.max_correlated_exposure),
        ("max_daily_loss_fraction", policy.max_daily_loss_fraction),
        ("max_drawdown_fraction", policy.max_drawdown_fraction),
        (
            "minimum_effective_sample_size",
            policy.minimum_effective_sample_size,
        ),
        ("maximum_ood_score", policy.maximum_ood_score),
        ("maximum_regime_entropy", policy.maximum_regime_entropy),
        (
            "maximum_calibration_error",
            policy.maximum_calibration_error,
        ),
        ("minimum_net_edge_bps", policy.minimum_net_edge_bps),
        ("minimum_trade_weight", policy.minimum_trade_weight),
    ] {
        ensure!(value.is_finite() && value >= 0.0, "invalid {name}");
    }
    ensure!(
        policy.fractional_kelly > 0.0 && policy.fractional_kelly <= 1.0,
        "fractional Kelly must be in (0,1]"
    );
    ensure!(
        policy.max_abs_position_weight > 0.0
            && policy.max_abs_position_weight <= policy.max_gross_exposure
            && policy.max_abs_position_weight <= policy.max_correlated_exposure,
        "position cap must fit within gross and correlated caps"
    );
    ensure!(
        policy.maximum_ood_score > 0.0
            && policy.maximum_regime_entropy > 0.0
            && policy.maximum_calibration_error > 0.0
            && policy.minimum_effective_sample_size > 0.0,
        "evidence thresholds must be positive"
    );
    Ok(())
}

fn validate_input(evidence: &ForecastEvidence, state: &AllocationState) -> Result<()> {
    ensure!(!evidence.symbol.trim().is_empty(), "symbol is required");
    ensure!(evidence.horizon_minutes > 0, "horizon must be positive");
    ensure!(
        evidence.scenarios.len() >= 2,
        "at least two forecast scenarios are required"
    );
    let probability_sum = evidence
        .scenarios
        .iter()
        .map(|row| {
            ensure!(
                row.probability.is_finite() && row.probability > 0.0,
                "scenario probability is invalid"
            );
            ensure!(
                row.return_fraction.is_finite() && row.return_fraction > -1.0,
                "scenario return is invalid"
            );
            Ok(row.probability)
        })
        .collect::<Result<Vec<_>>>()?
        .into_iter()
        .sum::<f64>();
    ensure!(
        (probability_sum - 1.0).abs() <= 1.0e-8,
        "scenario probabilities must sum to one"
    );
    ensure!(
        evidence
            .scenarios
            .iter()
            .any(|row| row.return_fraction > 0.0)
            && evidence
                .scenarios
                .iter()
                .any(|row| row.return_fraction < 0.0),
        "forecast distribution must contain gains and losses"
    );
    for (name, value) in [
        ("effective_sample_size", evidence.effective_sample_size),
        ("ood_score", evidence.ood_score),
        (
            "normalized_regime_entropy",
            evidence.normalized_regime_entropy,
        ),
        ("calibration_error", evidence.calibration_error),
        ("equity", state.equity),
        ("current_weight", state.current_weight),
        ("gross_exposure", state.gross_exposure),
        ("correlated_exposure", state.correlated_exposure),
        ("daily_loss_fraction", state.daily_loss_fraction),
        ("drawdown_fraction", state.drawdown_fraction),
        (
            "estimated_round_trip_cost_bps",
            state.estimated_round_trip_cost_bps,
        ),
    ] {
        ensure!(value.is_finite(), "{name} must be finite");
    }
    ensure!(state.equity > 0.0, "equity must be positive");
    ensure!(
        evidence.effective_sample_size >= 0.0
            && (0.0..=1.0).contains(&evidence.ood_score)
            && (0.0..=1.0).contains(&evidence.normalized_regime_entropy)
            && evidence.calibration_error >= 0.0,
        "forecast evidence diagnostics are outside their domains"
    );
    ensure!(
        state.gross_exposure >= 0.0
            && state.correlated_exposure >= 0.0
            && state.daily_loss_fraction >= 0.0
            && state.drawdown_fraction >= 0.0
            && state.estimated_round_trip_cost_bps >= 0.0,
        "allocation state contains a negative risk measure"
    );
    ensure!(
        state.gross_exposure + NUMERIC_TOLERANCE >= state.current_weight.abs(),
        "gross exposure cannot be below current symbol exposure"
    );
    ensure!(
        state.correlated_exposure + NUMERIC_TOLERANCE >= state.current_weight.abs(),
        "correlated exposure cannot be below current symbol exposure"
    );
    Ok(())
}

fn log_growth(
    scenarios: &[ScenarioOutcome],
    direction: f64,
    fraction: f64,
    round_trip_cost_fraction: f64,
) -> f64 {
    scenarios
        .iter()
        .map(|row| {
            let net_directed_return = direction * row.return_fraction - round_trip_cost_fraction;
            let wealth = 1.0 + fraction * net_directed_return;
            if wealth <= 0.0 {
                f64::NEG_INFINITY
            } else {
                row.probability * wealth.ln()
            }
        })
        .sum()
}

/// Solves the one-period log-growth problem for a fixed direction. The
/// derivative is monotone, so bisection is deterministic and cannot jump to a
/// spurious local optimum.
fn optimal_fraction(
    scenarios: &[ScenarioOutcome],
    direction: f64,
    round_trip_cost_fraction: f64,
) -> (f64, f64) {
    let derivative = |fraction: f64| {
        scenarios
            .iter()
            .map(|row| {
                let directed_return = direction * row.return_fraction - round_trip_cost_fraction;
                row.probability * directed_return / (1.0 + fraction * directed_return)
            })
            .sum::<f64>()
    };
    if derivative(0.0) <= 0.0 {
        return (0.0, 0.0);
    }
    let insolvency_bound = scenarios
        .iter()
        .map(|row| direction * row.return_fraction - round_trip_cost_fraction)
        .filter(|value| *value < 0.0)
        .map(|value| 0.999 / -value)
        .fold(1.0_f64, f64::min)
        .min(1.0);
    if derivative(insolvency_bound) >= 0.0 {
        return (
            insolvency_bound,
            log_growth(
                scenarios,
                direction,
                insolvency_bound,
                round_trip_cost_fraction,
            ),
        );
    }
    let mut low = 0.0;
    let mut high = insolvency_bound;
    for _ in 0..100 {
        let midpoint = (low + high) / 2.0;
        if derivative(midpoint) > 0.0 {
            low = midpoint;
        } else {
            high = midpoint;
        }
    }
    let fraction = (low + high) / 2.0;
    (
        fraction,
        log_growth(scenarios, direction, fraction, round_trip_cost_fraction),
    )
}

fn action_for(current: f64, target: f64, minimum_trade_weight: f64) -> AllocationAction {
    if (target - current).abs() < minimum_trade_weight {
        return AllocationAction::NoTrade;
    }
    if current.abs() < minimum_trade_weight {
        return if target > 0.0 {
            AllocationAction::TargetLong
        } else {
            AllocationAction::TargetShort
        };
    }
    if target.abs() < minimum_trade_weight {
        return AllocationAction::ReduceRisk;
    }
    if current.signum() != target.signum() {
        return AllocationAction::RebalanceThroughFlat;
    }
    if target.abs() > current.abs() {
        AllocationAction::IncreaseRisk
    } else {
        AllocationAction::ReduceRisk
    }
}

#[derive(Debug, Clone, Copy)]
struct DecisionDiagnostics {
    raw_kelly_fraction: f64,
    expected_log_growth: f64,
    directional_edge_bps: f64,
    net_edge_bps: f64,
}

fn blocked_decision(
    evidence: &ForecastEvidence,
    policy: &BettingPolicy,
    checks: BTreeMap<String, bool>,
    reasons: Vec<String>,
    diagnostics: DecisionDiagnostics,
) -> BettingDecision {
    BettingDecision {
        status: "NO_TRADE".to_string(),
        policy_version: policy.policy_version.clone(),
        symbol: evidence.symbol.clone(),
        horizon_minutes: evidence.horizon_minutes,
        forecast_as_of: evidence.forecast_as_of,
        evidence_status: "BLOCKED".to_string(),
        action: AllocationAction::NoTrade,
        executable: false,
        target_weight: None,
        target_notional: None,
        raw_kelly_fraction: diagnostics.raw_kelly_fraction,
        fractional_kelly: policy.fractional_kelly,
        directional_edge_bps: diagnostics.directional_edge_bps,
        net_edge_bps: diagnostics.net_edge_bps,
        expected_log_growth: diagnostics.expected_log_growth,
        shrinkage_factor: 0.0,
        binding_caps: Vec::new(),
        pretrade_checks: checks,
        reason_codes: reasons,
        truth: "Kelly sizes an already validated distribution; raw regime entropy is a fail-closed veto, never a sizing multiplier. Existing positions require an independent risk decision."
            .to_string(),
    }
}

/// Converts a calibrated scenario distribution into a bounded target weight.
/// Every evidence and portfolio check is fail-closed. Raw regime entropy may
/// veto an uncertain state, but it never continuously sizes the target. This
/// function creates no order and has no broker side effects.
pub fn decide_bet(
    evidence: &ForecastEvidence,
    state: &AllocationState,
    policy: &BettingPolicy,
) -> Result<BettingDecision> {
    validate_policy(policy)?;
    validate_input(evidence, state)?;

    let round_trip_cost_fraction = state.estimated_round_trip_cost_bps / 10_000.0;
    let (long_fraction, long_growth) =
        optimal_fraction(&evidence.scenarios, 1.0, round_trip_cost_fraction);
    let (short_fraction, short_growth) =
        optimal_fraction(&evidence.scenarios, -1.0, round_trip_cost_fraction);
    let (direction, raw_kelly_fraction, expected_log_growth) = if long_growth >= short_growth {
        (1.0, long_fraction, long_growth)
    } else {
        (-1.0, short_fraction, short_growth)
    };
    let mean_return = evidence
        .scenarios
        .iter()
        .map(|row| row.probability * row.return_fraction)
        .sum::<f64>();
    let directional_edge_bps = direction * mean_return * 10_000.0;
    let net_edge_bps = directional_edge_bps - state.estimated_round_trip_cost_bps;

    let checks = BTreeMap::from([
        ("MODEL_PROMOTED".to_string(), evidence.model_promoted),
        ("DATA_FRESH".to_string(), evidence.data_fresh),
        ("LINEAGE_COMPLETE".to_string(), evidence.lineage_complete),
        (
            "EFFECTIVE_SAMPLE_SIZE".to_string(),
            evidence.effective_sample_size >= policy.minimum_effective_sample_size,
        ),
        (
            "OOD_WITHIN_POLICY".to_string(),
            evidence.ood_score <= policy.maximum_ood_score,
        ),
        (
            "REGIME_ENTROPY_WITHIN_POLICY".to_string(),
            evidence.normalized_regime_entropy <= policy.maximum_regime_entropy,
        ),
        (
            "CALIBRATION_WITHIN_POLICY".to_string(),
            evidence.calibration_error <= policy.maximum_calibration_error,
        ),
        (
            "DAILY_LOSS_WITHIN_POLICY".to_string(),
            state.daily_loss_fraction < policy.max_daily_loss_fraction,
        ),
        (
            "DRAWDOWN_WITHIN_POLICY".to_string(),
            state.drawdown_fraction < policy.max_drawdown_fraction,
        ),
        (
            "EDGE_EXCEEDS_COST".to_string(),
            net_edge_bps >= policy.minimum_net_edge_bps,
        ),
        (
            "UPSTREAM_ELIGIBLE".to_string(),
            evidence.upstream_no_trade_reasons.is_empty(),
        ),
    ]);
    let mut reasons = checks
        .iter()
        .filter_map(|(name, passed)| (!passed).then_some(name.clone()))
        .collect::<Vec<_>>();
    reasons.extend(evidence.upstream_no_trade_reasons.iter().cloned());
    reasons.sort();
    reasons.dedup();
    if !reasons.is_empty() || raw_kelly_fraction <= NUMERIC_TOLERANCE {
        if raw_kelly_fraction <= NUMERIC_TOLERANCE {
            reasons.push("NON_POSITIVE_LOG_GROWTH".to_string());
        }
        return Ok(blocked_decision(
            evidence,
            policy,
            checks,
            reasons,
            DecisionDiagnostics {
                raw_kelly_fraction,
                expected_log_growth,
                directional_edge_bps,
                net_edge_bps,
            },
        ));
    }

    let calibration_factor =
        (1.0 - evidence.calibration_error / policy.maximum_calibration_error).clamp(0.0, 1.0);
    let ood_factor = (1.0 - evidence.ood_score / policy.maximum_ood_score).clamp(0.0, 1.0);
    let sample_factor = (evidence.effective_sample_size
        / (4.0 * policy.minimum_effective_sample_size))
        .sqrt()
        .clamp(0.0, 1.0);
    let shrinkage_factor = calibration_factor * ood_factor * sample_factor;
    let unconstrained_target =
        direction * raw_kelly_fraction * policy.fractional_kelly * shrinkage_factor;

    let non_symbol_gross = (state.gross_exposure - state.current_weight.abs()).max(0.0);
    let gross_headroom = (policy.max_gross_exposure - non_symbol_gross).max(0.0);
    let non_symbol_correlated = (state.correlated_exposure - state.current_weight.abs()).max(0.0);
    let correlated_headroom = (policy.max_correlated_exposure - non_symbol_correlated).max(0.0);
    let cap = policy
        .max_abs_position_weight
        .min(gross_headroom)
        .min(correlated_headroom);
    let target_weight = unconstrained_target.clamp(-cap, cap);
    let mut binding_caps = Vec::new();
    if unconstrained_target.abs() > policy.max_abs_position_weight + NUMERIC_TOLERANCE {
        binding_caps.push("POSITION_CAP".to_string());
    }
    if unconstrained_target.abs() > gross_headroom + NUMERIC_TOLERANCE {
        binding_caps.push("GROSS_EXPOSURE_CAP".to_string());
    }
    if unconstrained_target.abs() > correlated_headroom + NUMERIC_TOLERANCE {
        binding_caps.push("CORRELATED_EXPOSURE_CAP".to_string());
    }
    if target_weight.abs() < policy.minimum_trade_weight
        && state.current_weight.abs() < policy.minimum_trade_weight
    {
        return Ok(blocked_decision(
            evidence,
            policy,
            checks,
            vec!["TARGET_BELOW_MINIMUM_TRADE_WEIGHT".to_string()],
            DecisionDiagnostics {
                raw_kelly_fraction,
                expected_log_growth,
                directional_edge_bps,
                net_edge_bps,
            },
        ));
    }
    let action = action_for(
        state.current_weight,
        target_weight,
        policy.minimum_trade_weight,
    );
    if action == AllocationAction::NoTrade {
        return Ok(blocked_decision(
            evidence,
            policy,
            checks,
            vec!["TURNOVER_BELOW_MINIMUM_TRADE_WEIGHT".to_string()],
            DecisionDiagnostics {
                raw_kelly_fraction,
                expected_log_growth,
                directional_edge_bps,
                net_edge_bps,
            },
        ));
    }
    if !target_weight.is_finite() || !shrinkage_factor.is_finite() {
        bail!("allocation produced a non-finite result");
    }
    Ok(BettingDecision {
        status: "TARGET_PROPOSED".to_string(),
        policy_version: policy.policy_version.clone(),
        symbol: evidence.symbol.clone(),
        horizon_minutes: evidence.horizon_minutes,
        forecast_as_of: evidence.forecast_as_of,
        evidence_status: "ELIGIBLE".to_string(),
        action,
        executable: false,
        target_weight: Some(target_weight),
        target_notional: Some(target_weight * state.equity),
        raw_kelly_fraction,
        fractional_kelly: policy.fractional_kelly,
        directional_edge_bps,
        net_edge_bps,
        expected_log_growth,
        shrinkage_factor,
        binding_caps,
        pretrade_checks: checks,
        reason_codes: vec!["ORDER_ROUTING_REQUIRES_SEPARATE_RISK_APPROVAL".to_string()],
        truth: "Research allocation only: raw regime entropy is a veto, never a sizing multiplier; a separate portfolio-risk decision and order-state machine must approve any paper order."
            .to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    fn evidence() -> ForecastEvidence {
        ForecastEvidence {
            symbol: "SPY".into(),
            forecast_as_of: Utc.with_ymd_and_hms(2026, 7, 21, 15, 0, 0).unwrap(),
            horizon_minutes: 15,
            scenarios: vec![
                ScenarioOutcome {
                    probability: 0.35,
                    return_fraction: -0.01,
                },
                ScenarioOutcome {
                    probability: 0.65,
                    return_fraction: 0.012,
                },
            ],
            effective_sample_size: 400.0,
            ood_score: 0.1,
            normalized_regime_entropy: 0.2,
            calibration_error: 0.01,
            model_promoted: true,
            data_fresh: true,
            lineage_complete: true,
            upstream_no_trade_reasons: Vec::new(),
        }
    }

    fn state() -> AllocationState {
        AllocationState {
            equity: 100_000.0,
            current_weight: 0.0,
            gross_exposure: 0.0,
            correlated_exposure: 0.0,
            daily_loss_fraction: 0.0,
            drawdown_fraction: 0.0,
            estimated_round_trip_cost_bps: 2.0,
        }
    }

    #[test]
    fn eligible_distribution_proposes_bounded_target_without_execution() {
        let decision = decide_bet(&evidence(), &state(), &BettingPolicy::default()).unwrap();
        assert_eq!(decision.status, "TARGET_PROPOSED");
        assert_eq!(decision.action, AllocationAction::TargetLong);
        assert!(!decision.executable);
        assert!(decision.target_weight.unwrap() > 0.0);
        assert!(decision.target_weight.unwrap() <= 0.02);
    }

    #[test]
    fn regime_entropy_impact_metadata_separates_sizing_from_veto() {
        let impact = std::hint::black_box(REGIME_ENTROPY_ALLOCATION_IMPACT);
        assert!(impact.direct_allocation_impact);
        assert!(!impact.continuous_sizing_impact);
        assert!(impact.hard_no_trade_veto_impact);
    }

    #[test]
    fn in_policy_regime_entropy_does_not_change_target_weight() {
        let policy = BettingPolicy::default();
        let mut low_entropy = evidence();
        low_entropy.normalized_regime_entropy = 0.0;
        let mut high_entropy = low_entropy.clone();
        high_entropy.normalized_regime_entropy = policy.maximum_regime_entropy;

        let low = decide_bet(&low_entropy, &state(), &policy).unwrap();
        let high = decide_bet(&high_entropy, &state(), &policy).unwrap();

        assert_eq!(low.status, "TARGET_PROPOSED");
        assert_eq!(high.status, "TARGET_PROPOSED");
        assert_eq!(low.target_weight, high.target_weight);
        assert_eq!(low.target_notional, high.target_notional);
        assert_eq!(low.shrinkage_factor, high.shrinkage_factor);
    }

    #[test]
    fn excessive_regime_entropy_remains_fail_closed_no_trade() {
        let policy = BettingPolicy::default();
        let mut input = evidence();
        input.normalized_regime_entropy = policy.maximum_regime_entropy + 0.01;

        let decision = decide_bet(&input, &state(), &policy).unwrap();

        assert_eq!(decision.status, "NO_TRADE");
        assert_eq!(decision.action, AllocationAction::NoTrade);
        assert!(decision.target_weight.is_none());
        assert!(
            decision
                .reason_codes
                .contains(&"REGIME_ENTROPY_WITHIN_POLICY".to_string())
        );
    }

    #[test]
    fn unpromoted_model_is_always_no_trade() {
        let mut input = evidence();
        input.model_promoted = false;
        let decision = decide_bet(&input, &state(), &BettingPolicy::default()).unwrap();
        assert_eq!(decision.action, AllocationAction::NoTrade);
        assert!(decision.target_weight.is_none());
        assert!(
            decision
                .reason_codes
                .contains(&"MODEL_PROMOTED".to_string())
        );
    }

    #[test]
    fn upstream_rejection_cannot_be_overridden_by_kelly() {
        let mut input = evidence();
        input
            .upstream_no_trade_reasons
            .push("INSUFFICIENT_EFFECTIVE_SAMPLE".into());
        let decision = decide_bet(&input, &state(), &BettingPolicy::default()).unwrap();
        assert_eq!(decision.status, "NO_TRADE");
        assert!(
            decision
                .reason_codes
                .contains(&"INSUFFICIENT_EFFECTIVE_SAMPLE".to_string())
        );
    }

    #[test]
    fn daily_loss_gate_fails_closed() {
        let mut risk = state();
        risk.daily_loss_fraction = 0.02;
        let decision = decide_bet(&evidence(), &risk, &BettingPolicy::default()).unwrap();
        assert_eq!(decision.action, AllocationAction::NoTrade);
        assert!(
            decision
                .reason_codes
                .contains(&"DAILY_LOSS_WITHIN_POLICY".to_string())
        );
    }

    #[test]
    fn cost_can_remove_apparent_edge() {
        let mut risk = state();
        risk.estimated_round_trip_cost_bps = 100.0;
        let decision = decide_bet(&evidence(), &risk, &BettingPolicy::default()).unwrap();
        assert_eq!(decision.status, "NO_TRADE");
        assert!(
            decision
                .reason_codes
                .contains(&"EDGE_EXCEEDS_COST".to_string())
        );
    }

    #[test]
    fn invalid_probability_distribution_is_rejected() {
        let mut input = evidence();
        input.scenarios[0].probability = 0.5;
        assert!(decide_bet(&input, &state(), &BettingPolicy::default()).is_err());
    }

    #[test]
    fn non_finite_diagnostics_are_rejected() {
        let mut input = evidence();
        input.ood_score = f64::NAN;
        assert!(decide_bet(&input, &state(), &BettingPolicy::default()).is_err());
    }

    #[test]
    fn correlated_headroom_caps_target() {
        let mut risk = state();
        risk.correlated_exposure = 0.099;
        let decision = decide_bet(&evidence(), &risk, &BettingPolicy::default()).unwrap();
        assert!(decision.target_weight.unwrap() <= 0.001 + NUMERIC_TOLERANCE);
        assert!(
            decision
                .binding_caps
                .contains(&"CORRELATED_EXPOSURE_CAP".to_string())
        );
    }

    #[test]
    fn transaction_cost_is_inside_kelly_objective_not_only_an_edge_gate() {
        let no_cost = decide_bet(&evidence(), &state(), &BettingPolicy::default()).unwrap();
        let mut costly_state = state();
        costly_state.estimated_round_trip_cost_bps = 42.5;
        let with_cost = decide_bet(&evidence(), &costly_state, &BettingPolicy::default()).unwrap();
        assert!(with_cost.raw_kelly_fraction < no_cost.raw_kelly_fraction);
    }

    #[test]
    fn zero_target_reduces_an_existing_position_instead_of_becoming_no_trade() {
        let mut risk = state();
        risk.current_weight = 0.01;
        risk.gross_exposure = 0.26;
        risk.correlated_exposure = 0.11;
        let decision = decide_bet(&evidence(), &risk, &BettingPolicy::default()).unwrap();
        assert_eq!(decision.status, "TARGET_PROPOSED");
        assert_eq!(decision.action, AllocationAction::ReduceRisk);
        assert_eq!(decision.target_weight, Some(0.0));
        assert!(!decision.executable);
    }
}

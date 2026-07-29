use std::collections::{BTreeMap, BTreeSet};

use anyhow::{Result, ensure};
use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};

pub const PORTFOLIO_RISK_POLICY_VERSION: &str = "independent-portfolio-risk-v2";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PositionRiskInput {
    pub symbol: String,
    pub market_value: f64,
    #[serde(default)]
    pub observed_at: Option<DateTime<Utc>>,
    #[serde(default)]
    pub source_content_sha256: Option<String>,
    pub average_daily_dollar_volume: f64,
    #[serde(default)]
    pub adv_as_of: Option<DateTime<Utc>>,
    #[serde(default)]
    pub adv_source_content_sha256: Option<String>,
    pub beta: f64,
    #[serde(default)]
    pub factor_loadings: BTreeMap<String, f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct StressScenario {
    pub name: String,
    #[serde(default)]
    pub asset_shocks: BTreeMap<String, f64>,
    #[serde(default)]
    pub factor_shocks: BTreeMap<String, f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PortfolioRiskInput {
    pub as_of: DateTime<Utc>,
    #[serde(default)]
    pub observed_at: Option<DateTime<Utc>>,
    #[serde(default)]
    pub source_content_sha256: Option<String>,
    pub equity: f64,
    pub peak_equity: f64,
    pub day_start_equity: f64,
    pub positions: Vec<PositionRiskInput>,
    /// Point-in-time portfolio returns produced by the same position/risk
    /// definition. Current component returns cannot be substituted here.
    pub historical_portfolio_returns: Vec<f64>,
    #[serde(default)]
    pub history_as_of: Option<DateTime<Utc>>,
    #[serde(default)]
    pub history_source_content_sha256: Option<String>,
    pub stress_scenarios: Vec<StressScenario>,
    #[serde(default)]
    pub stress_scenarios_as_of: Option<DateTime<Utc>>,
    #[serde(default)]
    pub stress_source_content_sha256: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PortfolioRiskPolicy {
    pub policy_version: String,
    pub maximum_gross_exposure: f64,
    pub maximum_net_exposure: f64,
    pub maximum_position_weight: f64,
    pub maximum_abs_beta_exposure: f64,
    pub maximum_abs_factor_exposure: f64,
    pub maximum_daily_loss_fraction: f64,
    pub maximum_drawdown_fraction: f64,
    pub var_confidence: f64,
    pub maximum_expected_shortfall_fraction: f64,
    pub maximum_stress_loss_fraction: f64,
    pub minimum_return_history: usize,
    pub minimum_tail_loss_observations: usize,
    pub minimum_usable_stress_scenarios: usize,
    pub maximum_liquidation_days: f64,
    pub maximum_adv_participation: f64,
    pub maximum_snapshot_age_seconds: i64,
    pub maximum_position_age_seconds: i64,
    pub maximum_history_age_seconds: i64,
    pub maximum_adv_age_seconds: i64,
    pub maximum_stress_scenario_age_seconds: i64,
}

impl Default for PortfolioRiskPolicy {
    fn default() -> Self {
        Self {
            policy_version: PORTFOLIO_RISK_POLICY_VERSION.into(),
            maximum_gross_exposure: 0.25,
            maximum_net_exposure: 0.15,
            maximum_position_weight: 0.05,
            maximum_abs_beta_exposure: 0.15,
            maximum_abs_factor_exposure: 0.15,
            maximum_daily_loss_fraction: 0.02,
            maximum_drawdown_fraction: 0.05,
            var_confidence: 0.99,
            maximum_expected_shortfall_fraction: 0.03,
            maximum_stress_loss_fraction: 0.05,
            minimum_return_history: 250,
            minimum_tail_loss_observations: 5,
            minimum_usable_stress_scenarios: 3,
            maximum_liquidation_days: 2.0,
            maximum_adv_participation: 0.10,
            maximum_snapshot_age_seconds: 5 * 60,
            maximum_position_age_seconds: 5 * 60,
            maximum_history_age_seconds: 7 * 24 * 60 * 60,
            maximum_adv_age_seconds: 35 * 24 * 60 * 60,
            maximum_stress_scenario_age_seconds: 35 * 24 * 60 * 60,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PositionLiquidityRisk {
    pub symbol: String,
    pub market_value: f64,
    pub average_daily_dollar_volume: f64,
    pub estimated_liquidation_days: Option<f64>,
    pub within_policy: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct StressResult {
    pub name: String,
    pub pnl: f64,
    pub loss_fraction: f64,
    pub usable: bool,
    pub covered_nonzero_positions: usize,
    pub total_nonzero_positions: usize,
    pub reason_codes: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PortfolioRiskReport {
    pub status: String,
    pub policy_version: String,
    pub as_of: DateTime<Utc>,
    pub new_risk_allowed: bool,
    pub kill_switch_recommended: bool,
    pub gross_exposure: f64,
    pub net_exposure: f64,
    pub max_position_weight: f64,
    pub concentration_hhi: f64,
    pub portfolio_beta: f64,
    pub historical_var_fraction: Option<f64>,
    pub expected_shortfall_fraction: Option<f64>,
    pub worst_stress_loss_fraction: Option<f64>,
    pub drawdown_fraction: f64,
    pub daily_loss_fraction: f64,
    pub factor_exposures: BTreeMap<String, f64>,
    pub liquidity: Vec<PositionLiquidityRisk>,
    pub stress_results: Vec<StressResult>,
    pub checks: BTreeMap<String, bool>,
    pub reason_codes: Vec<String>,
    pub truth: String,
}

fn validate_policy(policy: &PortfolioRiskPolicy) -> Result<()> {
    ensure!(
        !policy.policy_version.trim().is_empty(),
        "policy_version is required"
    );
    for (name, value) in [
        ("maximum_gross_exposure", policy.maximum_gross_exposure),
        ("maximum_net_exposure", policy.maximum_net_exposure),
        ("maximum_position_weight", policy.maximum_position_weight),
        (
            "maximum_abs_factor_exposure",
            policy.maximum_abs_factor_exposure,
        ),
        (
            "maximum_abs_beta_exposure",
            policy.maximum_abs_beta_exposure,
        ),
        (
            "maximum_daily_loss_fraction",
            policy.maximum_daily_loss_fraction,
        ),
        (
            "maximum_drawdown_fraction",
            policy.maximum_drawdown_fraction,
        ),
        ("var_confidence", policy.var_confidence),
        (
            "maximum_expected_shortfall_fraction",
            policy.maximum_expected_shortfall_fraction,
        ),
        (
            "maximum_stress_loss_fraction",
            policy.maximum_stress_loss_fraction,
        ),
        ("maximum_liquidation_days", policy.maximum_liquidation_days),
        (
            "maximum_adv_participation",
            policy.maximum_adv_participation,
        ),
    ] {
        ensure!(value.is_finite() && value > 0.0, "invalid {name}");
    }
    ensure!(
        policy.maximum_position_weight <= policy.maximum_gross_exposure,
        "position cap cannot exceed gross cap"
    );
    ensure!(
        policy.var_confidence > 0.5 && policy.var_confidence < 1.0,
        "VaR confidence must be in (0.5,1)"
    );
    ensure!(
        policy.maximum_adv_participation <= 1.0,
        "ADV participation cannot exceed one"
    );
    ensure!(
        policy.minimum_return_history >= 30,
        "risk history must contain at least 30 observations"
    );
    ensure!(
        policy.minimum_tail_loss_observations > 0
            && policy.minimum_tail_loss_observations <= policy.minimum_return_history,
        "tail loss observation requirement is invalid"
    );
    ensure!(
        policy.minimum_usable_stress_scenarios >= 3,
        "at least three usable stress scenarios are required"
    );
    ensure!(
        policy.maximum_snapshot_age_seconds > 0
            && policy.maximum_position_age_seconds > 0
            && policy.maximum_history_age_seconds > 0
            && policy.maximum_adv_age_seconds > 0
            && policy.maximum_stress_scenario_age_seconds > 0,
        "risk input freshness limits must be positive"
    );
    Ok(())
}

fn canonical_symbol(value: &str) -> String {
    value.trim().to_ascii_uppercase()
}

fn canonical_factor(value: &str) -> String {
    value.trim().to_ascii_lowercase()
}

fn unique_canonical_names<'a>(
    values: impl IntoIterator<Item = &'a str>,
    canonicalize: fn(&str) -> String,
) -> bool {
    let mut observed = BTreeSet::new();
    values
        .into_iter()
        .all(|value| observed.insert(canonicalize(value)))
}

fn valid_sha256(value: Option<&str>) -> bool {
    value.is_some_and(|hash| {
        hash.len() == 64
            && hash.bytes().all(|byte| byte.is_ascii_hexdigit())
            && hash.bytes().any(|byte| byte != b'0')
    })
}

fn timestamp_is_fresh(
    decision_as_of: DateTime<Utc>,
    observed_at: Option<DateTime<Utc>>,
    maximum_age_seconds: i64,
) -> bool {
    observed_at.is_some_and(|timestamp| {
        timestamp <= decision_as_of
            && decision_as_of.signed_duration_since(timestamp)
                <= Duration::seconds(maximum_age_seconds)
    })
}

fn validate_input(input: &PortfolioRiskInput) -> Result<()> {
    for (name, value) in [
        ("equity", input.equity),
        ("peak_equity", input.peak_equity),
        ("day_start_equity", input.day_start_equity),
    ] {
        ensure!(value.is_finite() && value > 0.0, "invalid {name}");
    }
    ensure!(
        input.peak_equity + f64::EPSILON >= input.equity,
        "peak equity cannot be below current equity"
    );
    ensure!(
        input.peak_equity + f64::EPSILON >= input.day_start_equity,
        "peak equity cannot be below day-start equity"
    );
    let mut symbols = BTreeSet::new();
    for position in &input.positions {
        ensure!(
            !position.symbol.trim().is_empty(),
            "position symbol is empty"
        );
        ensure!(
            symbols.insert(canonical_symbol(&position.symbol)),
            "duplicate portfolio position"
        );
        ensure!(
            position.market_value.is_finite()
                && position.average_daily_dollar_volume.is_finite()
                && position.average_daily_dollar_volume >= 0.0
                && position.beta.is_finite(),
            "position contains an invalid numeric value"
        );
        ensure!(
            position
                .factor_loadings
                .iter()
                .all(|(name, value)| !name.trim().is_empty() && value.is_finite()),
            "position contains an invalid factor loading"
        );
        ensure!(
            unique_canonical_names(
                position.factor_loadings.keys().map(String::as_str),
                canonical_factor
            ),
            "position contains duplicate canonical factor loadings"
        );
    }
    ensure!(
        input
            .historical_portfolio_returns
            .iter()
            .all(|value| value.is_finite() && *value > -1.0),
        "historical portfolio returns contain an invalid value"
    );
    let mut stress_names = BTreeSet::new();
    for scenario in &input.stress_scenarios {
        let canonical_name = scenario.name.trim().to_ascii_lowercase();
        ensure!(
            !canonical_name.is_empty() && stress_names.insert(canonical_name),
            "stress scenario names must be unique and non-empty"
        );
        ensure!(
            scenario
                .asset_shocks
                .iter()
                .chain(&scenario.factor_shocks)
                .all(|(name, value)| !name.trim().is_empty() && value.is_finite() && *value > -1.0),
            "stress scenario contains an invalid shock"
        );
        ensure!(
            unique_canonical_names(
                scenario.asset_shocks.keys().map(String::as_str),
                canonical_symbol
            ),
            "stress scenario contains duplicate canonical asset shocks"
        );
        ensure!(
            unique_canonical_names(
                scenario.factor_shocks.keys().map(String::as_str),
                canonical_factor
            ),
            "stress scenario contains duplicate canonical factor shocks"
        );
    }
    Ok(())
}

fn historical_tail_risk(
    returns: &[f64],
    confidence: f64,
    minimum_tail_loss_observations: usize,
) -> Option<(f64, f64)> {
    if returns
        .iter()
        .filter(|value| **value < -f64::EPSILON)
        .count()
        < minimum_tail_loss_observations
    {
        return None;
    }
    let mut losses = returns.iter().map(|value| -*value).collect::<Vec<_>>();
    losses.sort_by(f64::total_cmp);
    let index = ((losses.len() - 1) as f64 * confidence).ceil() as usize;
    let var = losses[index.min(losses.len() - 1)].max(0.0);
    let tail = losses
        .iter()
        .copied()
        .filter(|loss| *loss + f64::EPSILON >= var)
        .collect::<Vec<_>>();
    let expected_shortfall = (tail.iter().sum::<f64>() / tail.len() as f64).max(var);
    Some((var, expected_shortfall))
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct StressCoverageSummary {
    any_usable_scenario: bool,
    every_scenario_usable: bool,
    all_nonzero_positions_covered: bool,
    usable_scenario_count: usize,
    adverse_scenario_count: usize,
}

fn stress_results(input: &PortfolioRiskInput) -> (Vec<StressResult>, StressCoverageSummary) {
    let total_nonzero_positions = input
        .positions
        .iter()
        .filter(|position| position.market_value.abs() > f64::EPSILON)
        .count();
    let results = input
        .stress_scenarios
        .iter()
        .map(|scenario| {
            let asset_shocks = scenario
                .asset_shocks
                .iter()
                .map(|(symbol, shock)| (canonical_symbol(symbol), *shock))
                .collect::<BTreeMap<_, _>>();
            let factor_shocks = scenario
                .factor_shocks
                .iter()
                .map(|(factor, shock)| (canonical_factor(factor), *shock))
                .collect::<BTreeMap<_, _>>();
            let definition_is_empty = asset_shocks.is_empty() && factor_shocks.is_empty();
            let has_nonzero_shock = asset_shocks
                .values()
                .chain(factor_shocks.values())
                .any(|shock| shock.abs() > f64::EPSILON);
            let mut pnl = 0.0;
            let mut covered_nonzero_positions = 0;
            for position in &input.positions {
                if position.market_value.abs() <= f64::EPSILON {
                    continue;
                }
                let asset_shock = asset_shocks
                    .get(&canonical_symbol(&position.symbol))
                    .copied()
                    .filter(|shock| shock.abs() > f64::EPSILON);
                let mut factor_shock = 0.0;
                let mut factor_covered = false;
                for (factor, loading) in &position.factor_loadings {
                    if loading.abs() <= f64::EPSILON {
                        continue;
                    }
                    if let Some(shock) = factor_shocks
                        .get(&canonical_factor(factor))
                        .copied()
                        .filter(|shock| shock.abs() > f64::EPSILON)
                    {
                        factor_shock += loading * shock;
                        factor_covered = true;
                    }
                }
                if asset_shock.is_some() || factor_covered {
                    covered_nonzero_positions += 1;
                    pnl += position.market_value * (asset_shock.unwrap_or(0.0) + factor_shock);
                }
            }
            let usable = has_nonzero_shock && covered_nonzero_positions > 0;
            let mut reason_codes = Vec::new();
            if definition_is_empty {
                reason_codes.push("EMPTY_STRESS_DEFINITION".to_string());
            } else if !has_nonzero_shock {
                reason_codes.push("NO_NONZERO_STRESS_SHOCK".to_string());
            }
            if covered_nonzero_positions == 0 {
                reason_codes.push("NO_PORTFOLIO_EXPOSURE_INTERSECTION".to_string());
            } else if covered_nonzero_positions < total_nonzero_positions {
                reason_codes.push("PARTIAL_PORTFOLIO_COVERAGE".to_string());
            }
            StressResult {
                name: scenario.name.clone(),
                pnl,
                loss_fraction: (-pnl / input.equity).max(0.0),
                usable,
                covered_nonzero_positions,
                total_nonzero_positions,
                reason_codes,
            }
        })
        .collect::<Vec<_>>();
    let summary = StressCoverageSummary {
        any_usable_scenario: results.iter().any(|result| result.usable),
        every_scenario_usable: !results.is_empty() && results.iter().all(|result| result.usable),
        // Coverage is required inside every scenario. A fragmented library in
        // which scenario A covers one position and scenario B covers another
        // must not be mistaken for a fully stressed portfolio.
        all_nonzero_positions_covered: total_nonzero_positions > 0
            && !results.is_empty()
            && results
                .iter()
                .all(|result| result.covered_nonzero_positions == total_nonzero_positions),
        usable_scenario_count: results.iter().filter(|result| result.usable).count(),
        adverse_scenario_count: results
            .iter()
            .filter(|result| result.usable && result.loss_fraction > f64::EPSILON)
            .count(),
    };
    (results, summary)
}

/// Independent portfolio risk analysis. It consumes positions and realized
/// portfolio history, never forecast confidence. Missing tail, stress, or
/// liquidity evidence blocks new risk instead of becoming zero risk.
pub fn analyze_portfolio(
    input: &PortfolioRiskInput,
    policy: &PortfolioRiskPolicy,
) -> Result<PortfolioRiskReport> {
    analyze_portfolio_at(input, policy, input.as_of)
}

/// Evaluates a risk snapshot at an explicit decision time. Production callers
/// must pass their current request/decision timestamp so an internally
/// consistent but old file cannot remain approved indefinitely.
pub fn analyze_portfolio_at(
    input: &PortfolioRiskInput,
    policy: &PortfolioRiskPolicy,
    evaluation_as_of: DateTime<Utc>,
) -> Result<PortfolioRiskReport> {
    validate_policy(policy)?;
    validate_input(input)?;

    let risk_as_of_fresh_at_evaluation = timestamp_is_fresh(
        evaluation_as_of,
        Some(input.as_of),
        policy.maximum_snapshot_age_seconds,
    );
    let active_positions = input
        .positions
        .iter()
        .filter(|position| position.market_value.abs() > f64::EPSILON)
        .collect::<Vec<_>>();
    let portfolio_snapshot_fresh = timestamp_is_fresh(
        input.as_of,
        input.observed_at,
        policy.maximum_snapshot_age_seconds,
    );
    let portfolio_lineage_available = valid_sha256(input.source_content_sha256.as_deref());
    let history_fresh = timestamp_is_fresh(
        input.as_of,
        input.history_as_of,
        policy.maximum_history_age_seconds,
    );
    let history_lineage_available = valid_sha256(input.history_source_content_sha256.as_deref());
    let stress_library_fresh = timestamp_is_fresh(
        input.as_of,
        input.stress_scenarios_as_of,
        policy.maximum_stress_scenario_age_seconds,
    );
    let stress_lineage_available = valid_sha256(input.stress_source_content_sha256.as_deref());
    let position_snapshots_fresh = active_positions.iter().all(|position| {
        timestamp_is_fresh(
            input.as_of,
            position.observed_at,
            policy.maximum_position_age_seconds,
        )
    });
    let position_lineage_available = active_positions
        .iter()
        .all(|position| valid_sha256(position.source_content_sha256.as_deref()));
    let adv_fresh = active_positions.iter().all(|position| {
        timestamp_is_fresh(
            input.as_of,
            position.adv_as_of,
            policy.maximum_adv_age_seconds,
        )
    });
    let adv_lineage_available = active_positions
        .iter()
        .all(|position| valid_sha256(position.adv_source_content_sha256.as_deref()));

    let weights = input
        .positions
        .iter()
        .map(|position| position.market_value / input.equity)
        .collect::<Vec<_>>();
    let gross_exposure = weights.iter().map(|weight| weight.abs()).sum::<f64>();
    let net_exposure = weights.iter().sum::<f64>();
    let max_position_weight = weights
        .iter()
        .map(|weight| weight.abs())
        .fold(0.0_f64, f64::max);
    let concentration_hhi = weights.iter().map(|weight| weight.powi(2)).sum::<f64>();
    let portfolio_beta = input
        .positions
        .iter()
        .zip(&weights)
        .map(|(position, weight)| position.beta * weight)
        .sum::<f64>();

    let mut factor_exposures = BTreeMap::<String, f64>::new();
    for (position, weight) in input.positions.iter().zip(&weights) {
        for (factor, loading) in &position.factor_loadings {
            *factor_exposures
                .entry(canonical_factor(factor))
                .or_default() += weight * loading;
        }
    }
    let maximum_factor_exposure = factor_exposures
        .values()
        .map(|value| value.abs())
        .fold(0.0_f64, f64::max);

    let liquidity = input
        .positions
        .iter()
        .map(|position| {
            let estimated_liquidation_days = if position.market_value == 0.0 {
                Some(0.0)
            } else if position.average_daily_dollar_volume > 0.0 {
                Some(
                    position.market_value.abs()
                        / (position.average_daily_dollar_volume * policy.maximum_adv_participation),
                )
            } else {
                None
            };
            PositionLiquidityRisk {
                symbol: position.symbol.clone(),
                market_value: position.market_value,
                average_daily_dollar_volume: position.average_daily_dollar_volume,
                within_policy: estimated_liquidation_days
                    .is_some_and(|days| days <= policy.maximum_liquidation_days),
                estimated_liquidation_days,
            }
        })
        .collect::<Vec<_>>();
    let liquidity_within_policy = liquidity.iter().all(|row| row.within_policy);

    let tail_risk = (input.historical_portfolio_returns.len() >= policy.minimum_return_history)
        .then(|| {
            historical_tail_risk(
                &input.historical_portfolio_returns,
                policy.var_confidence,
                policy.minimum_tail_loss_observations,
            )
        })
        .flatten();
    let (historical_var_fraction, expected_shortfall_fraction) = tail_risk
        .map(|(var, expected_shortfall)| (Some(var), Some(expected_shortfall)))
        .unwrap_or((None, None));
    let (stress_results, stress_coverage) = stress_results(input);
    let worst_stress_loss_fraction = stress_results
        .iter()
        .filter(|row| row.usable)
        .map(|row| row.loss_fraction)
        .max_by(f64::total_cmp);
    let drawdown_fraction = ((input.peak_equity - input.equity) / input.peak_equity).max(0.0);
    let daily_loss_fraction =
        ((input.day_start_equity - input.equity) / input.day_start_equity).max(0.0);

    let checks = BTreeMap::from([
        (
            "RISK_AS_OF_FRESH_AT_EVALUATION".to_string(),
            risk_as_of_fresh_at_evaluation,
        ),
        (
            "PORTFOLIO_SNAPSHOT_FRESH".to_string(),
            portfolio_snapshot_fresh,
        ),
        (
            "PORTFOLIO_SOURCE_LINEAGE_AVAILABLE".to_string(),
            portfolio_lineage_available,
        ),
        ("HISTORY_FRESH".to_string(), history_fresh),
        (
            "HISTORY_SOURCE_LINEAGE_AVAILABLE".to_string(),
            history_lineage_available,
        ),
        (
            "POSITION_SNAPSHOTS_FRESH".to_string(),
            position_snapshots_fresh,
        ),
        (
            "POSITION_SOURCE_LINEAGE_AVAILABLE".to_string(),
            position_lineage_available,
        ),
        ("ADV_FRESH".to_string(), adv_fresh),
        (
            "ADV_SOURCE_LINEAGE_AVAILABLE".to_string(),
            adv_lineage_available,
        ),
        ("STRESS_LIBRARY_FRESH".to_string(), stress_library_fresh),
        (
            "STRESS_SOURCE_LINEAGE_AVAILABLE".to_string(),
            stress_lineage_available,
        ),
        (
            "GROSS_EXPOSURE_WITHIN_POLICY".to_string(),
            gross_exposure <= policy.maximum_gross_exposure,
        ),
        (
            "NET_EXPOSURE_WITHIN_POLICY".to_string(),
            net_exposure.abs() <= policy.maximum_net_exposure,
        ),
        (
            "POSITION_CONCENTRATION_WITHIN_POLICY".to_string(),
            max_position_weight <= policy.maximum_position_weight,
        ),
        (
            "FACTOR_EXPOSURE_WITHIN_POLICY".to_string(),
            maximum_factor_exposure <= policy.maximum_abs_factor_exposure,
        ),
        (
            "BETA_EXPOSURE_WITHIN_POLICY".to_string(),
            portfolio_beta.abs() <= policy.maximum_abs_beta_exposure,
        ),
        (
            "DAILY_LOSS_WITHIN_POLICY".to_string(),
            daily_loss_fraction < policy.maximum_daily_loss_fraction,
        ),
        (
            "DRAWDOWN_WITHIN_POLICY".to_string(),
            drawdown_fraction < policy.maximum_drawdown_fraction,
        ),
        ("TAIL_HISTORY_AVAILABLE".to_string(), tail_risk.is_some()),
        (
            "EXPECTED_SHORTFALL_WITHIN_POLICY".to_string(),
            expected_shortfall_fraction
                .is_some_and(|value| value <= policy.maximum_expected_shortfall_fraction),
        ),
        (
            "STRESS_SCENARIOS_AVAILABLE".to_string(),
            stress_coverage.any_usable_scenario,
        ),
        (
            "STRESS_SCENARIO_DEFINITIONS_USABLE".to_string(),
            stress_coverage.every_scenario_usable,
        ),
        (
            "MINIMUM_USABLE_STRESS_SCENARIOS".to_string(),
            stress_coverage.usable_scenario_count >= policy.minimum_usable_stress_scenarios,
        ),
        (
            "ADVERSE_STRESS_SCENARIO_AVAILABLE".to_string(),
            stress_coverage.adverse_scenario_count > 0,
        ),
        (
            "STRESS_POSITION_COVERAGE_COMPLETE".to_string(),
            stress_coverage.all_nonzero_positions_covered,
        ),
        (
            "STRESS_LOSS_WITHIN_POLICY".to_string(),
            worst_stress_loss_fraction
                .is_some_and(|value| value <= policy.maximum_stress_loss_fraction),
        ),
        (
            "LIQUIDITY_WITHIN_POLICY".to_string(),
            liquidity_within_policy,
        ),
    ]);
    let reason_codes = checks
        .iter()
        .filter_map(|(name, passed)| (!passed).then_some(name.clone()))
        .collect::<Vec<_>>();
    let severe_failure = !checks["DAILY_LOSS_WITHIN_POLICY"]
        || !checks["DRAWDOWN_WITHIN_POLICY"]
        || (checks["STRESS_SCENARIOS_AVAILABLE"] && !checks["STRESS_LOSS_WITHIN_POLICY"]);
    let new_risk_allowed = reason_codes.is_empty();
    let status = if severe_failure {
        "KILL_SWITCH_RECOMMENDED"
    } else if new_risk_allowed {
        "PASS"
    } else {
        "BLOCK_NEW_RISK"
    };

    Ok(PortfolioRiskReport {
        status: status.to_string(),
        policy_version: policy.policy_version.clone(),
        as_of: input.as_of,
        new_risk_allowed,
        kill_switch_recommended: severe_failure,
        gross_exposure,
        net_exposure,
        max_position_weight,
        concentration_hhi,
        portfolio_beta,
        historical_var_fraction,
        expected_shortfall_fraction,
        worst_stress_loss_fraction,
        drawdown_fraction,
        daily_loss_fraction,
        factor_exposures,
        liquidity,
        stress_results,
        checks,
        reason_codes,
        truth: "Independent risk gate: stale or untraceable inputs, missing history, ineffective stress coverage, or unavailable liquidity are unknown risk and block new exposure; they are never interpreted as zero."
            .to_string(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{Duration, TimeZone};

    fn history() -> Vec<f64> {
        (0..300)
            .map(|index| if index % 17 == 0 { -0.012 } else { 0.001 })
            .collect()
    }

    fn hash(fill: char) -> String {
        fill.to_string().repeat(64)
    }

    fn input() -> PortfolioRiskInput {
        let as_of = Utc.with_ymd_and_hms(2026, 7, 21, 15, 30, 0).unwrap();
        PortfolioRiskInput {
            as_of,
            observed_at: Some(as_of - Duration::seconds(30)),
            source_content_sha256: Some(hash('a')),
            equity: 100_000.0,
            peak_equity: 100_000.0,
            day_start_equity: 100_000.0,
            positions: vec![PositionRiskInput {
                symbol: "SPY".into(),
                market_value: 5_000.0,
                observed_at: Some(as_of - Duration::seconds(30)),
                source_content_sha256: Some(hash('b')),
                average_daily_dollar_volume: 10_000_000.0,
                adv_as_of: Some(as_of - Duration::days(1)),
                adv_source_content_sha256: Some(hash('c')),
                beta: 1.0,
                factor_loadings: BTreeMap::from([("market".into(), 1.0)]),
            }],
            historical_portfolio_returns: history(),
            history_as_of: Some(as_of - Duration::days(1)),
            history_source_content_sha256: Some(hash('d')),
            stress_scenarios: vec![
                StressScenario {
                    name: "market_down_10pct".into(),
                    asset_shocks: BTreeMap::new(),
                    factor_shocks: BTreeMap::from([("market".into(), -0.10)]),
                },
                StressScenario {
                    name: "spy_gap_down_5pct".into(),
                    asset_shocks: BTreeMap::from([("SPY".into(), -0.05)]),
                    factor_shocks: BTreeMap::new(),
                },
                StressScenario {
                    name: "market_down_15pct".into(),
                    asset_shocks: BTreeMap::new(),
                    factor_shocks: BTreeMap::from([("market".into(), -0.15)]),
                },
            ],
            stress_scenarios_as_of: Some(as_of - Duration::days(1)),
            stress_source_content_sha256: Some(hash('e')),
        }
    }

    #[test]
    fn complete_risk_evidence_can_pass() {
        let report = analyze_portfolio(&input(), &PortfolioRiskPolicy::default()).unwrap();
        assert_eq!(report.status, "PASS");
        assert!(report.new_risk_allowed);
        assert_eq!(report.gross_exposure, 0.05);
        assert!(report.expected_shortfall_fraction.is_some());
        assert!(report.checks["STRESS_POSITION_COVERAGE_COMPLETE"]);
        assert!(report.stress_results[0].usable);
    }

    #[test]
    fn missing_tail_history_blocks_new_risk() {
        let mut value = input();
        value.historical_portfolio_returns.clear();
        let report = analyze_portfolio(&value, &PortfolioRiskPolicy::default()).unwrap();
        assert_eq!(report.status, "BLOCK_NEW_RISK");
        assert!(report.historical_var_fraction.is_none());
        assert!(
            report
                .reason_codes
                .contains(&"TAIL_HISTORY_AVAILABLE".to_string())
        );
    }

    #[test]
    fn drawdown_triggers_kill_switch_recommendation() {
        let mut value = input();
        value.equity = 94_000.0;
        let report = analyze_portfolio(&value, &PortfolioRiskPolicy::default()).unwrap();
        assert_eq!(report.status, "KILL_SWITCH_RECOMMENDED");
        assert!(report.kill_switch_recommended);
    }

    #[test]
    fn absent_adv_is_unknown_not_zero_liquidity_risk() {
        let mut value = input();
        value.positions[0].average_daily_dollar_volume = 0.0;
        let report = analyze_portfolio(&value, &PortfolioRiskPolicy::default()).unwrap();
        assert_eq!(report.status, "BLOCK_NEW_RISK");
        assert!(report.liquidity[0].estimated_liquidation_days.is_none());
    }

    #[test]
    fn factor_concentration_is_aggregated_across_positions() {
        let mut value = input();
        let mut second = value.positions[0].clone();
        second.symbol = "QQQ".into();
        second.beta = 1.1;
        second.factor_loadings = BTreeMap::from([("market".into(), 3.0)]);
        value.positions.push(second);
        let report = analyze_portfolio(&value, &PortfolioRiskPolicy::default()).unwrap();
        assert_eq!(report.factor_exposures["market"], 0.2);
        assert!(
            report
                .reason_codes
                .contains(&"FACTOR_EXPOSURE_WITHIN_POLICY".to_string())
        );
    }

    #[test]
    fn empty_stress_definition_blocks_new_risk() {
        let mut value = input();
        value.stress_scenarios[0].asset_shocks.clear();
        value.stress_scenarios[0].factor_shocks.clear();
        let report = analyze_portfolio(&value, &PortfolioRiskPolicy::default()).unwrap();
        assert_eq!(report.status, "BLOCK_NEW_RISK");
        assert!(report.worst_stress_loss_fraction.is_some());
        assert!(report.checks["STRESS_SCENARIOS_AVAILABLE"]);
        assert!(!report.checks["STRESS_SCENARIO_DEFINITIONS_USABLE"]);
        assert!(
            report.stress_results[0]
                .reason_codes
                .contains(&"EMPTY_STRESS_DEFINITION".to_string())
        );
    }

    #[test]
    fn irrelevant_asset_and_factor_shocks_are_not_coverage() {
        let mut value = input();
        value.stress_scenarios[0].asset_shocks = BTreeMap::from([("QQQ".into(), -0.10)]);
        value.stress_scenarios[0].factor_shocks = BTreeMap::from([("size".into(), -0.10)]);
        let report = analyze_portfolio(&value, &PortfolioRiskPolicy::default()).unwrap();
        assert_eq!(report.status, "BLOCK_NEW_RISK");
        assert!(!report.stress_results[0].usable);
        assert!(!report.checks["STRESS_SCENARIO_DEFINITIONS_USABLE"]);
        assert!(!report.checks["MINIMUM_USABLE_STRESS_SCENARIOS"]);
        assert!(
            report.stress_results[0]
                .reason_codes
                .contains(&"NO_PORTFOLIO_EXPOSURE_INTERSECTION".to_string())
        );
    }

    #[test]
    fn asset_symbol_matching_is_case_and_whitespace_insensitive() {
        let mut value = input();
        value.stress_scenarios[0].asset_shocks = BTreeMap::from([(" spy ".into(), -0.10)]);
        value.stress_scenarios[0].factor_shocks.clear();
        let report = analyze_portfolio(&value, &PortfolioRiskPolicy::default()).unwrap();
        assert_eq!(report.status, "PASS");
        assert_eq!(report.stress_results[0].pnl, -500.0);
        assert!(report.stress_results[0].usable);
    }

    #[test]
    fn partial_position_coverage_blocks_new_risk() {
        let mut value = input();
        let mut second = value.positions[0].clone();
        second.symbol = "QQQ".into();
        second.factor_loadings = BTreeMap::from([("size".into(), 1.0)]);
        value.positions.push(second);
        value.stress_scenarios[0].asset_shocks = BTreeMap::from([("SPY".into(), -0.10)]);
        value.stress_scenarios[0].factor_shocks.clear();
        let report = analyze_portfolio(&value, &PortfolioRiskPolicy::default()).unwrap();
        assert_eq!(report.status, "BLOCK_NEW_RISK");
        assert!(report.stress_results[0].usable);
        assert_eq!(report.stress_results[0].covered_nonzero_positions, 1);
        assert!(!report.checks["STRESS_POSITION_COVERAGE_COMPLETE"]);
    }

    #[test]
    fn fragmented_coverage_across_scenarios_is_not_complete_coverage() {
        let mut value = input();
        let mut second = value.positions[0].clone();
        second.symbol = "QQQ".into();
        second.factor_loadings = BTreeMap::from([("size".into(), 1.0)]);
        value.positions.push(second);
        value.stress_scenarios = vec![
            StressScenario {
                name: "market_only_down".into(),
                asset_shocks: BTreeMap::new(),
                factor_shocks: BTreeMap::from([("market".into(), -0.10)]),
            },
            StressScenario {
                name: "size_only_down".into(),
                asset_shocks: BTreeMap::new(),
                factor_shocks: BTreeMap::from([("size".into(), -0.10)]),
            },
            StressScenario {
                name: "market_only_gap".into(),
                asset_shocks: BTreeMap::from([("SPY".into(), -0.05)]),
                factor_shocks: BTreeMap::new(),
            },
        ];
        let report = analyze_portfolio(&value, &PortfolioRiskPolicy::default()).unwrap();
        assert_eq!(report.status, "BLOCK_NEW_RISK");
        assert!(report.stress_results.iter().all(|result| result.usable));
        assert!(!report.checks["STRESS_POSITION_COVERAGE_COMPLETE"]);
    }

    #[test]
    fn missing_or_stale_lineage_contract_blocks_new_risk() {
        let mut missing = input();
        missing.source_content_sha256 = None;
        let report = analyze_portfolio(&missing, &PortfolioRiskPolicy::default()).unwrap();
        assert_eq!(report.status, "BLOCK_NEW_RISK");
        assert!(!report.checks["PORTFOLIO_SOURCE_LINEAGE_AVAILABLE"]);

        let mut stale = input();
        stale.positions[0].adv_as_of = Some(stale.as_of - Duration::days(36));
        let report = analyze_portfolio(&stale, &PortfolioRiskPolicy::default()).unwrap();
        assert_eq!(report.status, "BLOCK_NEW_RISK");
        assert!(!report.checks["ADV_FRESH"]);
    }

    #[test]
    fn future_dated_observations_block_new_risk() {
        let mut value = input();
        value.observed_at = Some(value.as_of + Duration::seconds(1));
        let report = analyze_portfolio(&value, &PortfolioRiskPolicy::default()).unwrap();
        assert_eq!(report.status, "BLOCK_NEW_RISK");
        assert!(!report.checks["PORTFOLIO_SNAPSHOT_FRESH"]);
    }

    #[test]
    fn internally_consistent_but_old_file_cannot_remain_approved() {
        let value = input();
        let report = analyze_portfolio_at(
            &value,
            &PortfolioRiskPolicy::default(),
            value.as_of + Duration::minutes(6),
        )
        .unwrap();
        assert_eq!(report.status, "BLOCK_NEW_RISK");
        assert!(!report.checks["RISK_AS_OF_FRESH_AT_EVALUATION"]);
    }

    #[test]
    fn duplicate_symbols_are_rejected() {
        let mut value = input();
        value.positions.push(value.positions[0].clone());
        assert!(analyze_portfolio(&value, &PortfolioRiskPolicy::default()).is_err());
    }

    #[test]
    fn non_finite_returns_are_rejected() {
        let mut value = input();
        value.historical_portfolio_returns[0] = f64::NAN;
        assert!(analyze_portfolio(&value, &PortfolioRiskPolicy::default()).is_err());
    }

    #[test]
    fn all_nonnegative_history_is_not_treated_as_zero_tail_risk() {
        let mut value = input();
        value.historical_portfolio_returns = vec![0.001; 300];
        let report = analyze_portfolio(&value, &PortfolioRiskPolicy::default()).unwrap();
        assert_eq!(report.status, "BLOCK_NEW_RISK");
        assert!(report.historical_var_fraction.is_none());
        assert!(!report.checks["TAIL_HISTORY_AVAILABLE"]);
    }

    #[test]
    fn positive_only_stress_library_does_not_claim_adverse_coverage() {
        let mut value = input();
        for scenario in &mut value.stress_scenarios {
            for shock in scenario.asset_shocks.values_mut() {
                *shock = shock.abs();
            }
            for shock in scenario.factor_shocks.values_mut() {
                *shock = shock.abs();
            }
        }
        let report = analyze_portfolio(&value, &PortfolioRiskPolicy::default()).unwrap();
        assert_eq!(report.status, "BLOCK_NEW_RISK");
        assert!(!report.checks["ADVERSE_STRESS_SCENARIO_AVAILABLE"]);
    }
}

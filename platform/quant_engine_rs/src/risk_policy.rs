use std::{
    fs,
    path::{Path, PathBuf},
};

use anyhow::{Context, Result, bail};
use serde::{Deserialize, Serialize};

use crate::{allocation::BettingPolicy, portfolio_risk::PortfolioRiskPolicy};

pub const DEFAULT_RISK_POLICY_PATH: &str = "risk_policy.yaml";

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct UnifiedRiskPolicy {
    pub risk_policy_version: String,
    pub fractional_kelly: f64,
    pub max_single_name_pct: f64,
    pub max_total_gross_pct: f64,
    pub max_net_exposure_pct: f64,
    pub max_correlated_cluster_pct: f64,
    pub max_abs_beta_exposure_pct: f64,
    pub max_abs_factor_exposure_pct: f64,
    pub max_daily_loss_pct: f64,
    pub max_drawdown_pct: f64,
    pub max_trades_per_day: usize,
    pub minimum_effective_sample_size: f64,
    pub maximum_ood_score: f64,
    /// Hard fail-closed ceiling only; values below it do not scale allocation.
    pub maximum_regime_entropy: f64,
    pub maximum_calibration_error: f64,
    pub minimum_net_edge_bps: f64,
    pub minimum_trade_weight: f64,
    pub var_confidence: f64,
    pub maximum_expected_shortfall_pct: f64,
    pub maximum_stress_loss_pct: f64,
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

impl Default for UnifiedRiskPolicy {
    fn default() -> Self {
        Self {
            risk_policy_version: "2026-07-26-v2".into(),
            fractional_kelly: 0.25,
            max_single_name_pct: 0.02,
            max_total_gross_pct: 0.10,
            max_net_exposure_pct: 0.10,
            max_correlated_cluster_pct: 0.04,
            max_abs_beta_exposure_pct: 0.10,
            max_abs_factor_exposure_pct: 0.10,
            max_daily_loss_pct: 0.01,
            max_drawdown_pct: 0.05,
            max_trades_per_day: 3,
            minimum_effective_sample_size: 100.0,
            maximum_ood_score: 0.65,
            maximum_regime_entropy: 0.80,
            maximum_calibration_error: 0.05,
            minimum_net_edge_bps: 1.0,
            minimum_trade_weight: 0.0005,
            var_confidence: 0.99,
            maximum_expected_shortfall_pct: 0.03,
            maximum_stress_loss_pct: 0.05,
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

impl UnifiedRiskPolicy {
    pub fn load(path: impl AsRef<Path>) -> Result<Self> {
        let path = path.as_ref();
        let bytes = fs::read(path)
            .with_context(|| format!("failed reading risk policy {}", path.display()))?;
        let policy: Self = serde_yaml::from_slice(&bytes)
            .with_context(|| format!("invalid risk policy YAML {}", path.display()))?;
        policy.validate()?;
        Ok(policy)
    }

    pub fn resolve(config_path: &Path, configured_path: &Path) -> PathBuf {
        if configured_path.is_absolute() {
            configured_path.to_path_buf()
        } else {
            config_path
                .parent()
                .unwrap_or_else(|| Path::new("."))
                .join(configured_path)
        }
    }

    pub fn validate(&self) -> Result<()> {
        if self.risk_policy_version.trim().is_empty() {
            bail!("risk_policy_version is required");
        }
        for (name, value) in [
            ("fractional_kelly", self.fractional_kelly),
            ("max_single_name_pct", self.max_single_name_pct),
            ("max_total_gross_pct", self.max_total_gross_pct),
            ("max_net_exposure_pct", self.max_net_exposure_pct),
            (
                "max_correlated_cluster_pct",
                self.max_correlated_cluster_pct,
            ),
            ("max_abs_beta_exposure_pct", self.max_abs_beta_exposure_pct),
            (
                "max_abs_factor_exposure_pct",
                self.max_abs_factor_exposure_pct,
            ),
            ("max_daily_loss_pct", self.max_daily_loss_pct),
            ("max_drawdown_pct", self.max_drawdown_pct),
            (
                "minimum_effective_sample_size",
                self.minimum_effective_sample_size,
            ),
            ("maximum_ood_score", self.maximum_ood_score),
            ("maximum_regime_entropy", self.maximum_regime_entropy),
            ("maximum_calibration_error", self.maximum_calibration_error),
            ("minimum_net_edge_bps", self.minimum_net_edge_bps),
            ("minimum_trade_weight", self.minimum_trade_weight),
            ("var_confidence", self.var_confidence),
            (
                "maximum_expected_shortfall_pct",
                self.maximum_expected_shortfall_pct,
            ),
            ("maximum_stress_loss_pct", self.maximum_stress_loss_pct),
            ("maximum_liquidation_days", self.maximum_liquidation_days),
            ("maximum_adv_participation", self.maximum_adv_participation),
        ] {
            if !value.is_finite() || value <= 0.0 {
                bail!("{name} must be finite and positive");
            }
        }
        if self.fractional_kelly > 1.0
            || self.max_single_name_pct > self.max_correlated_cluster_pct
            || self.max_correlated_cluster_pct > self.max_total_gross_pct
            || self.max_net_exposure_pct > self.max_total_gross_pct
            || self.max_abs_beta_exposure_pct > self.max_total_gross_pct
            || self.max_abs_factor_exposure_pct > self.max_total_gross_pct
            || self.max_total_gross_pct > 1.0
            || self.max_daily_loss_pct >= 1.0
            || self.max_drawdown_pct >= 1.0
            || !(0.5..1.0).contains(&self.var_confidence)
            || self.maximum_adv_participation > 1.0
            || self.max_trades_per_day == 0
            || self.minimum_return_history == 0
            || self.minimum_tail_loss_observations == 0
            || self.minimum_usable_stress_scenarios == 0
            || self.maximum_snapshot_age_seconds <= 0
            || self.maximum_position_age_seconds <= 0
            || self.maximum_history_age_seconds <= 0
            || self.maximum_adv_age_seconds <= 0
            || self.maximum_stress_scenario_age_seconds <= 0
        {
            bail!("unified risk policy limits are inconsistent");
        }
        Ok(())
    }

    pub fn betting_policy(&self) -> BettingPolicy {
        BettingPolicy {
            policy_version: self.risk_policy_version.clone(),
            fractional_kelly: self.fractional_kelly,
            max_abs_position_weight: self.max_single_name_pct,
            max_gross_exposure: self.max_total_gross_pct,
            max_correlated_exposure: self.max_correlated_cluster_pct,
            max_daily_loss_fraction: self.max_daily_loss_pct,
            max_drawdown_fraction: self.max_drawdown_pct,
            minimum_effective_sample_size: self.minimum_effective_sample_size,
            maximum_ood_score: self.maximum_ood_score,
            maximum_regime_entropy: self.maximum_regime_entropy,
            maximum_calibration_error: self.maximum_calibration_error,
            minimum_net_edge_bps: self.minimum_net_edge_bps,
            minimum_trade_weight: self.minimum_trade_weight,
        }
    }

    pub fn portfolio_risk_policy(&self) -> PortfolioRiskPolicy {
        PortfolioRiskPolicy {
            policy_version: self.risk_policy_version.clone(),
            maximum_gross_exposure: self.max_total_gross_pct,
            maximum_net_exposure: self.max_net_exposure_pct,
            maximum_position_weight: self.max_single_name_pct,
            maximum_abs_beta_exposure: self.max_abs_beta_exposure_pct,
            maximum_abs_factor_exposure: self.max_abs_factor_exposure_pct,
            maximum_daily_loss_fraction: self.max_daily_loss_pct,
            maximum_drawdown_fraction: self.max_drawdown_pct,
            var_confidence: self.var_confidence,
            maximum_expected_shortfall_fraction: self.maximum_expected_shortfall_pct,
            maximum_stress_loss_fraction: self.maximum_stress_loss_pct,
            minimum_return_history: self.minimum_return_history,
            minimum_tail_loss_observations: self.minimum_tail_loss_observations,
            minimum_usable_stress_scenarios: self.minimum_usable_stress_scenarios,
            maximum_liquidation_days: self.maximum_liquidation_days,
            maximum_adv_participation: self.maximum_adv_participation,
            maximum_snapshot_age_seconds: self.maximum_snapshot_age_seconds,
            maximum_position_age_seconds: self.maximum_position_age_seconds,
            maximum_history_age_seconds: self.maximum_history_age_seconds,
            maximum_adv_age_seconds: self.maximum_adv_age_seconds,
            maximum_stress_scenario_age_seconds: self.maximum_stress_scenario_age_seconds,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_policy_maps_to_all_consumers_without_limit_drift() {
        let unified = UnifiedRiskPolicy::default();
        unified.validate().unwrap();
        let betting = unified.betting_policy();
        let portfolio = unified.portfolio_risk_policy();
        assert_eq!(betting.policy_version, unified.risk_policy_version);
        assert_eq!(portfolio.policy_version, unified.risk_policy_version);
        assert_eq!(
            betting.max_abs_position_weight,
            portfolio.maximum_position_weight
        );
        assert_eq!(betting.max_gross_exposure, portfolio.maximum_gross_exposure);
        assert_eq!(
            betting.max_daily_loss_fraction,
            portfolio.maximum_daily_loss_fraction
        );
    }
}

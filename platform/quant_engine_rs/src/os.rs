use std::{collections::BTreeMap, sync::Arc};

use chrono::{Datelike, Utc, Weekday};
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};

use crate::{
    config::QuantOsConfig,
    os_domain::{
        AuditEvent, EventMeta, Fill, ModelVersion, Order, OrderIntent, OrderStatus,
        PortfolioSnapshot, RiskDecision, stable_id,
    },
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuntimeStatus {
    pub mode: String,
    pub market_status: String,
    pub paper_running: bool,
    pub kill_switch_active: bool,
    pub new_orders_allowed: bool,
    pub event_lag_ms: u64,
    pub last_error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RiskStatus {
    pub kill_switch_active: bool,
    pub daily_trades: usize,
    pub max_daily_trades: usize,
    pub daily_loss_used: f64,
    pub daily_loss_limit: f64,
    pub drawdown: f64,
    pub drawdown_limit: f64,
    pub last_decision: Option<RiskDecision>,
}

#[derive(Debug)]
struct RuntimeInner {
    paper_running: bool,
    kill_switch_active: bool,
    orders: Vec<Order>,
    fills: Vec<Fill>,
    audit: Vec<AuditEvent>,
    last_risk: Option<RiskDecision>,
    daily_trades: usize,
    realized_pnl: f64,
    last_error: Option<String>,
    authoritative_portfolio: Option<PortfolioSnapshot>,
    authoritative_portfolio_source: Option<String>,
}

#[derive(Debug)]
pub struct QuantRuntime {
    config: QuantOsConfig,
    inner: RwLock<RuntimeInner>,
}

impl QuantRuntime {
    pub fn new(config: QuantOsConfig) -> Arc<Self> {
        Arc::new(Self {
            config,
            inner: RwLock::new(RuntimeInner {
                paper_running: false,
                kill_switch_active: true,
                orders: Vec::new(),
                fills: Vec::new(),
                audit: Vec::new(),
                last_risk: None,
                daily_trades: 0,
                realized_pnl: 0.0,
                last_error: None,
                authoritative_portfolio: None,
                authoritative_portfolio_source: None,
            }),
        })
    }

    pub fn market_status() -> &'static str {
        match Utc::now().weekday() {
            Weekday::Sat | Weekday::Sun => "MARKET_CLOSED",
            _ => "UNKNOWN_UNTIL_FRESH_BAR",
        }
    }

    pub fn status(&self) -> RuntimeStatus {
        let state = self.inner.read();
        RuntimeStatus {
            mode: "PAPER".to_string(),
            market_status: Self::market_status().to_string(),
            paper_running: state.paper_running,
            kill_switch_active: state.kill_switch_active,
            new_orders_allowed: state.paper_running && !state.kill_switch_active,
            event_lag_ms: 0,
            last_error: state.last_error.clone(),
        }
    }

    pub fn risk_status(&self) -> RiskStatus {
        let state = self.inner.read();
        RiskStatus {
            kill_switch_active: state.kill_switch_active,
            daily_trades: state.daily_trades,
            max_daily_trades: self.config.max_daily_trades,
            daily_loss_used: (-state.realized_pnl / self.config.starting_capital).max(0.0),
            daily_loss_limit: self.config.max_daily_loss,
            drawdown: 0.0,
            drawdown_limit: self.config.max_drawdown,
            last_decision: state.last_risk.clone(),
        }
    }

    fn audit(&self, action: &str, outcome: &str, details: BTreeMap<String, String>) {
        let now = Utc::now();
        let correlation = stable_id(&[action, &now.timestamp_millis().to_string()]);
        self.inner.write().audit.push(AuditEvent {
            meta: EventMeta::deterministic("audit", "SYSTEM", now, "quantd", &correlation),
            category: "control".to_string(),
            action: action.to_string(),
            outcome: outcome.to_string(),
            details,
        });
    }

    pub fn start_paper(&self) -> Result<RuntimeStatus, String> {
        {
            let mut state = self.inner.write();
            if state.kill_switch_active {
                state.last_error = Some("kill_switch_active".to_string());
                drop(state);
                self.audit(
                    "paper_start",
                    "rejected",
                    BTreeMap::from([("reason".into(), "kill_switch_active".into())]),
                );
                return Err("kill switch is active; resume risk before paper start".to_string());
            }
            state.paper_running = true;
            state.last_error = None;
        }
        self.audit("paper_start", "accepted", BTreeMap::new());
        Ok(self.status())
    }

    pub fn stop_paper(&self) -> RuntimeStatus {
        self.inner.write().paper_running = false;
        self.audit("paper_stop", "accepted", BTreeMap::new());
        self.status()
    }

    pub fn activate_kill_switch(&self, cancel_open: bool) -> RuntimeStatus {
        {
            let mut state = self.inner.write();
            state.kill_switch_active = true;
            if cancel_open {
                for order in &mut state.orders {
                    if matches!(
                        order.status,
                        OrderStatus::Created | OrderStatus::Approved | OrderStatus::Submitted
                    ) {
                        order.status = OrderStatus::Cancelled;
                    }
                }
            }
        }
        self.audit(
            "kill_switch",
            "active",
            BTreeMap::from([("cancel_open".into(), cancel_open.to_string())]),
        );
        self.status()
    }

    pub fn resume_risk(&self) -> RuntimeStatus {
        self.inner.write().kill_switch_active = false;
        self.audit("kill_switch", "resumed", BTreeMap::new());
        self.status()
    }

    pub fn evaluate_intent(
        &self,
        intent: OrderIntent,
        model_promoted: bool,
        data_fresh: bool,
        sample_count: usize,
        confidence: f64,
    ) -> Order {
        let state = self.inner.read();
        let checks = BTreeMap::from([
            ("paper_running".to_string(), state.paper_running),
            ("kill_switch_clear".to_string(), !state.kill_switch_active),
            ("model_promoted".to_string(), model_promoted),
            ("fresh_data".to_string(), data_fresh),
            (
                "minimum_samples".to_string(),
                sample_count >= self.config.minimum_samples,
            ),
            (
                "confidence".to_string(),
                confidence >= self.config.confidence_threshold,
            ),
            (
                "daily_trade_limit".to_string(),
                state.daily_trades < self.config.max_daily_trades,
            ),
        ]);
        drop(state);
        let rejection_reasons: Vec<String> = checks
            .iter()
            .filter_map(|(name, passed)| (!passed).then_some(name.clone()))
            .collect();
        let approved = rejection_reasons.is_empty();
        let mut meta = intent.meta.clone();
        meta.causation_id = Some(intent.meta.event_id.clone());
        let decision = RiskDecision {
            meta,
            approved,
            checks,
            rejection_reasons: rejection_reasons.clone(),
        };
        let order_id = stable_id(&["order", &intent.meta.event_id]);
        let order = Order {
            order_id,
            intent,
            status: if approved {
                OrderStatus::Approved
            } else {
                OrderStatus::RiskRejected
            },
            filled_quantity: 0.0,
            rejection_reason: (!approved).then(|| rejection_reasons.join("|")),
        };
        let mut state = self.inner.write();
        state.last_risk = Some(decision);
        state.orders.push(order.clone());
        order
    }

    pub fn replay_rejection(&self, symbol: &str) -> Order {
        let time = Utc::now();
        let correlation = stable_id(&["replay", symbol, &time.date_naive().to_string()]);
        let intent = OrderIntent {
            meta: EventMeta::deterministic(
                "order_intent",
                symbol,
                time,
                "deterministic_replay",
                &correlation,
            ),
            side: "NO_TRADE".to_string(),
            quantity: 0.0,
            order_type: "MARKET".to_string(),
            limit_price: None,
        };
        let order = self.evaluate_intent(intent, false, false, 28, 0.0);
        self.audit(
            "replay",
            "risk_rejected",
            BTreeMap::from([("order_id".into(), order.order_id.clone())]),
        );
        order
    }

    pub fn orders(&self) -> Vec<Order> {
        self.inner.read().orders.clone()
    }

    pub fn fills(&self) -> Vec<Fill> {
        self.inner.read().fills.clone()
    }

    pub fn audit_events(&self) -> Vec<AuditEvent> {
        self.inner.read().audit.clone()
    }

    pub fn portfolio(&self) -> PortfolioSnapshot {
        let state = self.inner.read();
        if let Some(portfolio) = &state.authoritative_portfolio {
            return portfolio.clone();
        }
        PortfolioSnapshot {
            as_of: Utc::now(),
            cash: self.config.starting_capital + state.realized_pnl,
            equity: self.config.starting_capital + state.realized_pnl,
            gross_exposure: 0.0,
            net_exposure: 0.0,
            positions: Vec::new(),
        }
    }

    pub fn portfolio_is_authoritative(&self) -> bool {
        self.inner.read().authoritative_portfolio.is_some()
    }

    pub fn update_authoritative_portfolio(&self, portfolio: PortfolioSnapshot, source: String) {
        let mut state = self.inner.write();
        state.authoritative_portfolio = Some(portfolio);
        state.authoritative_portfolio_source = Some(source);
    }

    pub fn clear_authoritative_portfolio(&self) {
        let mut state = self.inner.write();
        state.authoritative_portfolio = None;
        state.authoritative_portfolio_source = None;
    }

    pub fn authoritative_portfolio_source(&self) -> Option<String> {
        self.inner.read().authoritative_portfolio_source.clone()
    }

    pub fn models() -> Vec<ModelVersion> {
        vec![
            ModelVersion {
                model_id: "baseline_logistic_analog_boosted".to_string(),
                version: "baseline-2026-07-19".to_string(),
                status: "REJECTED".to_string(),
                feature_schema_version: "market-state-v1".to_string(),
                training_period: "chronological expanding".to_string(),
                validation_period: "purged validation".to_string(),
                test_period: "untouched OOS baseline".to_string(),
                metrics: BTreeMap::from([
                    ("win_rate".to_string(), 0.14285714285714285),
                    ("total_return".to_string(), -0.033414522865677476),
                    ("profit_factor".to_string(), 0.2155241488012407),
                ]),
                calibration_status: "FAILED_OVERCONFIDENT".to_string(),
            },
            ModelVersion {
                model_id: "behavioral_microstructure_ensemble".to_string(),
                version: "candidate-0.1.0".to_string(),
                status: "REJECTED".to_string(),
                feature_schema_version: "point-in-time-v2".to_string(),
                training_period: "chronological expanding".to_string(),
                validation_period: "purged validation".to_string(),
                test_period: "exploratory OOS; baseline test already observed by researcher"
                    .to_string(),
                metrics: BTreeMap::from([
                    ("win_rate".to_string(), 0.3103448275862069),
                    ("total_return".to_string(), -0.02005750736633427),
                    ("profit_factor".to_string(), 0.4538469785925916),
                ]),
                calibration_status: "FAILED_EDGE_GATE".to_string(),
            },
        ]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn intent() -> OrderIntent {
        let now = Utc::now();
        OrderIntent {
            meta: EventMeta::deterministic("intent", "SPY", now, "test", "corr"),
            side: "LONG".to_string(),
            quantity: 10.0,
            order_type: "MARKET".to_string(),
            limit_price: None,
        }
    }

    #[test]
    fn kill_switch_and_unpromoted_model_are_independent_rejections() {
        let runtime = QuantRuntime::new(QuantOsConfig::default());
        let rejected = runtime.evaluate_intent(intent(), false, true, 500, 0.8);
        let reason = rejected.rejection_reason.unwrap();
        assert!(reason.contains("kill_switch_clear"));
        assert!(reason.contains("model_promoted"));
    }

    #[test]
    fn deterministic_replay_produces_stable_order_identity() {
        let runtime = QuantRuntime::new(QuantOsConfig::default());
        let now = Utc::now();
        let meta = EventMeta::deterministic("intent", "SPY", now, "test", "same");
        let make = || OrderIntent {
            meta: meta.clone(),
            side: "LONG".into(),
            quantity: 1.0,
            order_type: "MARKET".into(),
            limit_price: None,
        };
        let one = runtime.evaluate_intent(make(), false, false, 0, 0.0);
        let two = runtime.evaluate_intent(make(), false, false, 0, 0.0);
        assert_eq!(one.order_id, two.order_id);
    }
}

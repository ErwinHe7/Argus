use anyhow::{Result, ensure};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Account {
    pub account_id: String,
    pub environment: String,
    pub currency: String,
}

impl Account {
    pub fn validate(&self) -> Result<()> {
        ensure!(
            self.environment == "SIMULATE" && self.currency == "USD",
            "paper_us_account_required"
        );
        ensure!(
            !self.account_id.is_empty() && self.account_id.bytes().all(|c| c.is_ascii_digit()),
            "invalid_account_identity"
        );
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Deployment {
    pub id: String,
    pub mandate_version: u64,
    pub configuration_hash: String,
    pub strategy_version: Value,
    pub account_id: String,
    pub mode: String,
    pub state: String,
    #[serde(default)]
    pub lease_generation: u64,
    pub lease_expires_at: Option<DateTime<Utc>>,
    #[serde(default)]
    pub symbols: Vec<String>,
    #[serde(default)]
    pub configuration: Value,
}

impl Deployment {
    pub fn validate(&self) -> Result<()> {
        ensure!(
            matches!(self.mode.as_str(), "dry_run" | "paper"),
            "real_mode_prohibited"
        );
        ensure!(
            matches!(self.state.as_str(), "running" | "paused" | "retired"),
            "invalid_deployment_state"
        );
        ensure!(
            self.mandate_version > 0
                && self.configuration_hash.len() == 64
                && self
                    .configuration_hash
                    .bytes()
                    .all(|c| c.is_ascii_hexdigit()),
            "invalid_mandate"
        );
        ensure!(
            !self.id.is_empty() && !self.account_id.is_empty(),
            "missing_deployment_identity"
        );
        Ok(())
    }

    pub fn strategy(&self) -> Result<&str> {
        let value = self
            .strategy_version
            .as_str()
            .or_else(|| {
                self.strategy_version
                    .get("strategyId")
                    .and_then(Value::as_str)
            })
            .or_else(|| {
                self.strategy_version
                    .get("strategy")
                    .and_then(Value::as_str)
            });
        let strategy = value.unwrap_or("");
        ensure!(
            matches!(strategy, "MR-v1" | "MOM-v1"),
            "unsupported_strategy_version"
        );
        Ok(strategy)
    }

    pub fn selected_symbols(&self) -> Vec<String> {
        if !self.symbols.is_empty() {
            return self.symbols.clone();
        }
        if let Some(symbol) = self.strategy_version.get("symbol").and_then(Value::as_str) {
            return vec![symbol.to_string()];
        }
        self.configuration
            .get("symbols")
            .and_then(Value::as_array)
            .map(|v| {
                v.iter()
                    .filter_map(Value::as_str)
                    .map(str::to_owned)
                    .collect()
            })
            .unwrap_or_default()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Control {
    #[serde(alias = "id")]
    pub control_id: String,
    pub deployment_id: String,
    #[serde(alias = "action")]
    pub kind: String,
    pub mandate_version: u64,
    pub configuration_hash: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Ack {
    pub control_id: String,
    pub status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PollResponse {
    pub server_time: DateTime<Utc>,
    pub lease_expires_at: DateTime<Utc>,
    #[serde(default)]
    pub lease_generation: u64,
    pub deployments: Vec<Deployment>,
    #[serde(default)]
    pub controls: Vec<Control>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Event {
    pub schema_version: String,
    pub id: String,
    pub deployment_id: String,
    pub kind: String,
    pub occurred_at: DateTime<Utc>,
    pub sequence: u64,
    pub payload: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BrokerOrder {
    pub id: String,
    pub client_id: String,
    pub symbol: String,
    pub side: String,
    pub quantity: String,
    pub filled_quantity: String,
    pub average_fill_price: Option<String>,
    pub status: String,
    pub terminal: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Position {
    pub symbol: String,
    pub quantity: String,
    pub available_quantity: String,
    pub market_value: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Snapshot {
    pub account_id: String,
    pub environment: String,
    pub observed_at: DateTime<Utc>,
    pub cash: String,
    pub equity: String,
    pub positions: Vec<Position>,
    pub orders: Vec<BrokerOrder>,
    pub history_complete: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Quote {
    pub symbol: String,
    pub observed_at: DateTime<Utc>,
    pub bid: String,
    pub ask: String,
    pub market_open: bool,
    pub source: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OrderIntent {
    pub client_id: String,
    pub deployment_id: String,
    pub decision_id: String,
    pub account_id: String,
    pub symbol: String,
    pub side: String,
    pub quantity: String,
    pub limit_price: Option<String>,
    pub order_type: String,
    pub strategy: String,
    pub signal_atr: Option<String>,
    pub configuration_hash: String,
    pub mandate_version: u64,
    pub reason: String,
    pub created_at: DateTime<Utc>,
}

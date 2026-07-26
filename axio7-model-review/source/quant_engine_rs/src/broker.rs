use std::{collections::BTreeMap, fs, path::Path, sync::Arc, time::Duration as StdDuration};

use anyhow::{Context, Result, bail, ensure};
use chrono::{DateTime, Datelike, Timelike, Utc, Weekday};
use chrono_tz::America::New_York;
use parking_lot::{Mutex, RwLock};
use reqwest::StatusCode;
use rusqlite::{Connection, OptionalExtension, params};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};

use crate::{
    allocation::BettingDecision,
    config::ExecutionConfig,
    os::{QuantRuntime, RiskStatus, RuntimeStatus},
    os_domain::{PortfolioSnapshot, Position, stable_id},
    predictor::ForecastContract,
};

const OMS_SCHEMA: &str = r#"
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS broker_snapshots (
  snapshot_id TEXT PRIMARY KEY,
  as_of TEXT NOT NULL,
  source TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  recorded_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS execution_intents (
  client_order_id TEXT PRIMARY KEY,
  prediction_id TEXT NOT NULL,
  symbol TEXT NOT NULL,
  side TEXT NOT NULL,
  quantity REAL NOT NULL,
  limit_price REAL NOT NULL,
  status TEXT NOT NULL,
  payload_hash TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  broker_order_id TEXT,
  rejection_reason TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS broker_orders (
  broker_order_id TEXT PRIMARY KEY,
  client_order_id TEXT,
  status TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS broker_fills (
  fill_id TEXT PRIMARY KEY,
  broker_order_id TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  recorded_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS execution_events (
  event_id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  source_id TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);
"#;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GatewayHealth {
    pub status: String,
    pub provider: String,
    pub mode: String,
    pub trade_environment: String,
    pub account_id: u64,
    pub loopback_only: bool,
    pub real_orders_armed: bool,
    pub sdk_version: String,
    pub server_time: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BrokerAccountSnapshot {
    pub account_id: u64,
    pub cash: f64,
    pub equity: f64,
    pub buying_power: f64,
    pub market_value: f64,
    pub currency: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BrokerPositionSnapshot {
    pub symbol: String,
    pub quantity: f64,
    pub available_quantity: f64,
    pub average_price: f64,
    pub mark_price: f64,
    pub market_value: f64,
    pub realized_pnl: f64,
    pub unrealized_pnl: f64,
    pub position_side: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BrokerOrderSnapshot {
    pub broker_order_id: String,
    pub client_order_id: String,
    pub symbol: String,
    pub side: String,
    pub order_type: String,
    pub status: String,
    pub quantity: f64,
    pub filled_quantity: f64,
    pub limit_price: f64,
    pub average_fill_price: f64,
    pub created_at: String,
    pub updated_at: String,
    pub last_error: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BrokerFillSnapshot {
    pub fill_id: String,
    pub broker_order_id: String,
    pub symbol: String,
    pub side: String,
    pub quantity: f64,
    pub price: f64,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BrokerSnapshot {
    pub snapshot_id: String,
    pub as_of: DateTime<Utc>,
    pub source: String,
    pub authoritative: bool,
    pub mode: String,
    pub account: BrokerAccountSnapshot,
    pub positions: Vec<BrokerPositionSnapshot>,
    pub orders: Vec<BrokerOrderSnapshot>,
    pub fills: Vec<BrokerFillSnapshot>,
}

impl BrokerSnapshot {
    pub fn validate(&self, config: &ExecutionConfig, now: DateTime<Utc>) -> Result<()> {
        ensure!(self.authoritative, "broker snapshot is not authoritative");
        ensure!(
            self.source == "MOOMOO_OPEND_TRADE_API",
            "unexpected broker snapshot source"
        );
        ensure!(
            self.mode == config.mode,
            "broker mode does not match config"
        );
        if let Some(account_id) = config.account_id {
            ensure!(
                self.account.account_id == account_id,
                "broker account does not match pinned account"
            );
        }
        let age = now.signed_duration_since(self.as_of).num_seconds();
        ensure!(
            age >= 0 && age <= config.max_snapshot_age_seconds,
            "broker snapshot is stale or future-dated"
        );
        ensure!(
            self.account.equity.is_finite() && self.account.equity > 0.0,
            "broker equity is unavailable"
        );
        ensure!(
            self.account.cash.is_finite() && self.account.buying_power.is_finite(),
            "broker account values are non-finite"
        );
        for position in &self.positions {
            ensure!(
                !position.symbol.is_empty()
                    && position.quantity.is_finite()
                    && position.mark_price.is_finite()
                    && position.market_value.is_finite(),
                "broker position is invalid"
            );
        }
        Ok(())
    }

    pub fn portfolio(&self) -> PortfolioSnapshot {
        let equity = self.account.equity;
        let gross_notional = self
            .positions
            .iter()
            .map(|row| row.market_value.abs())
            .sum::<f64>();
        let net_notional = self
            .positions
            .iter()
            .map(|row| row.market_value)
            .sum::<f64>();
        PortfolioSnapshot {
            as_of: self.as_of,
            cash: self.account.cash,
            equity,
            gross_exposure: gross_notional / equity,
            net_exposure: net_notional / equity,
            positions: self
                .positions
                .iter()
                .map(|row| Position {
                    symbol: row.symbol.trim_start_matches("US.").to_string(),
                    quantity: row.quantity,
                    average_price: row.average_price,
                    mark_price: row.mark_price,
                    realized_pnl: row.realized_pnl,
                    unrealized_pnl: row.unrealized_pnl,
                })
                .collect(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BrokerOrderRequest {
    pub client_order_id: String,
    pub symbol: String,
    pub side: String,
    pub quantity: f64,
    pub limit_price: f64,
    pub order_type: String,
    pub time_in_force: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BrokerOrderResponse {
    pub idempotent_replay: bool,
    pub order: BrokerOrderSnapshot,
}

pub struct MoomooBrokerClient {
    http: reqwest::Client,
    base_url: String,
    gateway_token: String,
    live_arm_token: Option<String>,
}

impl MoomooBrokerClient {
    pub fn from_config(config: &ExecutionConfig) -> Result<Self> {
        config.validate()?;
        let gateway_token = std::env::var(&config.gateway_token_env)
            .with_context(|| format!("{} is not configured", config.gateway_token_env))?;
        ensure!(
            gateway_token.len() >= 32,
            "broker gateway token must contain at least 32 characters"
        );
        let live_arm_token = std::env::var(&config.live_arm_token_env)
            .ok()
            .filter(|value| value.len() >= 32);
        if config.mode == "real" {
            ensure!(
                config.allow_real_orders && live_arm_token.is_some(),
                "real execution is not armed"
            );
        }
        Ok(Self {
            http: reqwest::Client::builder()
                .connect_timeout(StdDuration::from_secs(2))
                .timeout(StdDuration::from_secs(8))
                .build()?,
            base_url: config.gateway_url.trim_end_matches('/').to_string(),
            gateway_token,
            live_arm_token,
        })
    }

    fn request(&self, method: reqwest::Method, path: &str) -> reqwest::RequestBuilder {
        let mut request = self
            .http
            .request(method, format!("{}{}", self.base_url, path))
            .bearer_auth(&self.gateway_token)
            .header("accept", "application/json");
        if let Some(token) = &self.live_arm_token {
            request = request.header("x-axio-live-arm", token);
        }
        request
    }

    async fn decode<T: for<'de> Deserialize<'de>>(response: reqwest::Response) -> Result<T> {
        let status = response.status();
        let bytes = response.bytes().await?;
        if !status.is_success() {
            let detail = serde_json::from_slice::<Value>(&bytes)
                .ok()
                .and_then(|value| {
                    value
                        .get("detail")
                        .and_then(Value::as_str)
                        .map(str::to_string)
                })
                .unwrap_or_else(|| String::from_utf8_lossy(&bytes).to_string());
            bail!("broker gateway returned {status}: {detail}");
        }
        serde_json::from_slice(&bytes).context("invalid broker gateway response")
    }

    pub async fn health(&self) -> Result<GatewayHealth> {
        Self::decode(self.request(reqwest::Method::GET, "/health").send().await?).await
    }

    pub async fn snapshot(&self) -> Result<BrokerSnapshot> {
        Self::decode(
            self.request(reqwest::Method::GET, "/v1/snapshot")
                .send()
                .await?,
        )
        .await
    }

    pub async fn place_order(&self, order: &BrokerOrderRequest) -> Result<BrokerOrderResponse> {
        Self::decode(
            self.request(reqwest::Method::POST, "/v1/orders")
                .json(order)
                .send()
                .await?,
        )
        .await
    }

    pub async fn cancel_order(&self, broker_order_id: &str) -> Result<BrokerOrderSnapshot> {
        ensure!(
            !broker_order_id.is_empty()
                && broker_order_id
                    .bytes()
                    .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_')),
            "invalid broker order ID"
        );
        Self::decode(
            self.request(
                reqwest::Method::POST,
                &format!("/v1/orders/{broker_order_id}/cancel"),
            )
            .json(&serde_json::json!({"reason":"AXIO_KILL_OR_OPERATOR_CANCEL"}))
            .send()
            .await?,
        )
        .await
    }
}

pub struct ExecutionStore {
    connection: Mutex<Connection>,
}

impl ExecutionStore {
    pub fn open(path: &Path) -> Result<Arc<Self>> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        let connection = Connection::open(path)
            .with_context(|| format!("cannot open execution OMS {}", path.display()))?;
        connection.execute_batch(OMS_SCHEMA)?;
        Ok(Arc::new(Self {
            connection: Mutex::new(connection),
        }))
    }

    pub fn reconcile(&self, snapshot: &BrokerSnapshot) -> Result<()> {
        let now = Utc::now().to_rfc3339();
        let payload = serde_json::to_string(snapshot)?;
        let mut connection = self.connection.lock();
        let transaction = connection.transaction()?;
        transaction.execute(
            "INSERT OR IGNORE INTO broker_snapshots
             (snapshot_id,as_of,source,payload_json,recorded_at) VALUES (?1,?2,?3,?4,?5)",
            params![
                snapshot.snapshot_id,
                snapshot.as_of.to_rfc3339(),
                snapshot.source,
                payload,
                now
            ],
        )?;
        for order in &snapshot.orders {
            if order.broker_order_id.is_empty() {
                continue;
            }
            transaction.execute(
                "INSERT INTO broker_orders
                 (broker_order_id,client_order_id,status,payload_json,updated_at)
                 VALUES (?1,?2,?3,?4,?5)
                 ON CONFLICT(broker_order_id) DO UPDATE SET
                   client_order_id=excluded.client_order_id,
                   status=excluded.status,
                   payload_json=excluded.payload_json,
                   updated_at=excluded.updated_at",
                params![
                    order.broker_order_id,
                    order.client_order_id,
                    order.status,
                    serde_json::to_string(order)?,
                    now
                ],
            )?;
            if !order.client_order_id.is_empty() {
                transaction.execute(
                    "UPDATE execution_intents SET status=?1, broker_order_id=?2,
                     rejection_reason=CASE WHEN ?3='' THEN rejection_reason ELSE ?3 END,
                     updated_at=?4 WHERE client_order_id=?5",
                    params![
                        order.status,
                        order.broker_order_id,
                        order.last_error,
                        now,
                        order.client_order_id
                    ],
                )?;
            }
        }
        for fill in &snapshot.fills {
            if fill.fill_id.is_empty() || fill.broker_order_id.is_empty() {
                continue;
            }
            transaction.execute(
                "INSERT OR IGNORE INTO broker_fills
                 (fill_id,broker_order_id,payload_json,recorded_at) VALUES (?1,?2,?3,?4)",
                params![
                    fill.fill_id,
                    fill.broker_order_id,
                    serde_json::to_string(fill)?,
                    now
                ],
            )?;
        }
        let event_id = stable_id(&["broker_snapshot", &snapshot.snapshot_id]);
        transaction.execute(
            "INSERT OR IGNORE INTO execution_events
             (event_id,event_type,source_id,payload_json,created_at) VALUES (?1,?2,?3,?4,?5)",
            params![
                event_id,
                "BROKER_RECONCILED",
                snapshot.snapshot_id,
                serde_json::to_string(&serde_json::json!({
                    "orders":snapshot.orders.len(),"fills":snapshot.fills.len()
                }))?,
                now
            ],
        )?;
        transaction.commit()?;
        Ok(())
    }

    pub fn record_intent(&self, intent: &ExecutionIntent, status: &str) -> Result<bool> {
        let payload = serde_json::to_vec(intent)?;
        let payload_hash = format!("{:x}", Sha256::digest(&payload));
        let now = Utc::now().to_rfc3339();
        let connection = self.connection.lock();
        let inserted = connection.execute(
            "INSERT OR IGNORE INTO execution_intents
             (client_order_id,prediction_id,symbol,side,quantity,limit_price,status,
              payload_hash,payload_json,created_at,updated_at)
             VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?10)",
            params![
                intent.client_order_id,
                intent.prediction_id,
                intent.order.symbol,
                intent.order.side,
                intent.order.quantity,
                intent.order.limit_price,
                status,
                payload_hash,
                String::from_utf8(payload)?,
                now
            ],
        )?;
        let existing: Option<String> = connection
            .query_row(
                "SELECT payload_hash FROM execution_intents WHERE client_order_id=?1",
                params![intent.client_order_id],
                |row| row.get(0),
            )
            .optional()?;
        ensure!(
            existing.as_deref() == Some(payload_hash.as_str()),
            "client order ID collision with a different intent"
        );
        Ok(inserted == 1)
    }

    pub fn record_submission(
        &self,
        client_order_id: &str,
        response: &BrokerOrderResponse,
    ) -> Result<()> {
        let now = Utc::now().to_rfc3339();
        let connection = self.connection.lock();
        connection.execute(
            "UPDATE execution_intents SET status=?1,broker_order_id=?2,updated_at=?3
             WHERE client_order_id=?4",
            params![
                response.order.status,
                response.order.broker_order_id,
                now,
                client_order_id
            ],
        )?;
        connection.execute(
            "INSERT INTO broker_orders
             (broker_order_id,client_order_id,status,payload_json,updated_at)
             VALUES (?1,?2,?3,?4,?5)
             ON CONFLICT(broker_order_id) DO UPDATE SET status=excluded.status,
             payload_json=excluded.payload_json,updated_at=excluded.updated_at",
            params![
                response.order.broker_order_id,
                client_order_id,
                response.order.status,
                serde_json::to_string(&response.order)?,
                now
            ],
        )?;
        Ok(())
    }

    pub fn record_rejection(&self, intent: &ExecutionIntent, reason: &str) -> Result<()> {
        self.record_intent(intent, "RISK_REJECTED")?;
        self.connection.lock().execute(
            "UPDATE execution_intents SET status='RISK_REJECTED',rejection_reason=?1,
             updated_at=?2 WHERE client_order_id=?3",
            params![reason, Utc::now().to_rfc3339(), intent.client_order_id],
        )?;
        Ok(())
    }

    pub fn record_submission_unknown(&self, client_order_id: &str, reason: &str) -> Result<()> {
        self.connection.lock().execute(
            "UPDATE execution_intents SET status='SUBMISSION_UNKNOWN',rejection_reason=?1,
             updated_at=?2 WHERE client_order_id=?3",
            params![reason, Utc::now().to_rfc3339(), client_order_id],
        )?;
        Ok(())
    }

    pub fn latest_snapshot(&self) -> Result<Option<BrokerSnapshot>> {
        let payload: Option<String> = self
            .connection
            .lock()
            .query_row(
                "SELECT payload_json FROM broker_snapshots ORDER BY as_of DESC LIMIT 1",
                [],
                |row| row.get(0),
            )
            .optional()?;
        payload
            .map(|value| serde_json::from_str(&value).context("invalid stored broker snapshot"))
            .transpose()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ExecutionIntent {
    pub client_order_id: String,
    pub prediction_id: String,
    pub model_id: String,
    pub model_hash: String,
    pub feature_hash: String,
    pub data_manifest_hash: String,
    pub forecast_as_of: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub target_weight: f64,
    pub target_notional: f64,
    pub order: BrokerOrderRequest,
    pub checks: BTreeMap<String, bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ExecutionPlan {
    pub approved: bool,
    pub reason_codes: Vec<String>,
    pub intent: Option<ExecutionIntent>,
}

fn canonical_symbol(symbol: &str) -> String {
    format!(
        "US.{}",
        symbol.trim_start_matches("US.").to_ascii_uppercase()
    )
}

fn regular_session(now: DateTime<Utc>) -> bool {
    let local = now.with_timezone(&New_York);
    !matches!(local.weekday(), Weekday::Sat | Weekday::Sun)
        && (local.hour(), local.minute()) >= (9, 30)
        && (local.hour(), local.minute()) < (15, 55)
}

pub fn plan_order(
    allocation: &BettingDecision,
    forecast: &ForecastContract,
    snapshot: &BrokerSnapshot,
    runtime: &RuntimeStatus,
    risk: &RiskStatus,
    config: &ExecutionConfig,
    now: DateTime<Utc>,
) -> ExecutionPlan {
    let symbol = canonical_symbol(&allocation.symbol);
    let forecast_symbol = canonical_symbol(&forecast.symbol);
    let age = now
        .signed_duration_since(forecast.decision_as_of)
        .num_seconds();
    let target_notional = allocation.target_notional.unwrap_or(0.0);
    let target_weight = allocation.target_weight.unwrap_or(0.0);
    let reference_price = forecast.reference_price;
    let current_quantity = snapshot
        .positions
        .iter()
        .find(|row| canonical_symbol(&row.symbol) == symbol)
        .map_or(0.0, |row| row.quantity);
    let desired_quantity = if reference_price > 0.0 {
        (target_notional / reference_price).trunc()
    } else {
        0.0
    };
    let delta = desired_quantity - current_quantity;
    let side = if delta > 0.0 { "BUY" } else { "SELL" };
    let collar = config.limit_price_collar_bps / 10_000.0;
    let limit_price = if side == "BUY" {
        reference_price * (1.0 + collar)
    } else {
        reference_price * (1.0 - collar)
    };
    let limit_price = (limit_price * 100.0).round() / 100.0;
    let order_notional = delta.abs() * limit_price;
    let projected_gross = snapshot
        .positions
        .iter()
        .filter(|row| canonical_symbol(&row.symbol) != symbol)
        .map(|row| row.market_value.abs())
        .sum::<f64>()
        + target_notional.abs();
    let allocation_checks_pass = allocation.pretrade_checks.values().all(|passed| *passed);
    let routing_only_reason =
        allocation.reason_codes.as_slice() == ["ORDER_ROUTING_REQUIRES_SEPARATE_RISK_APPROVAL"];
    let snapshot_valid = snapshot.validate(config, now).is_ok();
    let checks: BTreeMap<String, bool> = BTreeMap::from([
        ("EXECUTION_ENABLED".into(), config.enabled),
        (
            "ALLOCATION_TARGET_PROPOSED".into(),
            allocation.status == "TARGET_PROPOSED"
                && allocation.evidence_status == "ELIGIBLE"
                && !allocation.executable
                && routing_only_reason,
        ),
        ("ALLOCATION_CHECKS_PASS".into(), allocation_checks_pass),
        (
            "FORECAST_IDENTITY_MATCH".into(),
            symbol == forecast_symbol
                && allocation.horizon_minutes == forecast.horizon_minutes as u32
                && allocation.forecast_as_of == forecast.decision_as_of,
        ),
        (
            "FORECAST_PROMOTED_AND_ELIGIBLE".into(),
            forecast.decision.eligible
                && matches!(
                    forecast.calibration_status.as_str(),
                    "PROMOTED_OOS" | "OOS_CALIBRATED"
                )
                && forecast.decision.no_trade_reasons.is_empty(),
        ),
        (
            "SIGNAL_FRESH".into(),
            age >= 0 && age <= config.max_signal_age_seconds,
        ),
        ("REGULAR_SESSION".into(), regular_session(now)),
        (
            "SYMBOL_ALLOWED".into(),
            config
                .allowed_symbols
                .iter()
                .any(|allowed| canonical_symbol(allowed) == symbol),
        ),
        ("SNAPSHOT_AUTHORITATIVE_FRESH".into(), snapshot_valid),
        ("RUNTIME_RUNNING".into(), runtime.paper_running),
        ("KILL_SWITCH_CLEAR".into(), !runtime.kill_switch_active),
        (
            "DAILY_LOSS_WITHIN_LIMIT".into(),
            risk.daily_loss_used < config.max_daily_loss,
        ),
        (
            "DAILY_TRADE_LIMIT".into(),
            risk.daily_trades < risk.max_daily_trades,
        ),
        (
            "REFERENCE_PRICE_VALID".into(),
            reference_price.is_finite() && reference_price > 0.0,
        ),
        (
            "TARGET_WITHIN_POSITION_CAP".into(),
            target_notional.is_finite() && target_notional.abs() <= config.max_position_notional,
        ),
        (
            "ORDER_WITHIN_NOTIONAL_CAP".into(),
            delta != 0.0
                && order_notional.is_finite()
                && order_notional <= config.max_order_notional,
        ),
        (
            "GROSS_EXPOSURE_WITHIN_CAP".into(),
            projected_gross / snapshot.account.equity <= config.max_gross_exposure,
        ),
        (
            "LONG_ONLY".into(),
            !config.long_only
                || (desired_quantity >= 0.0 && !(side == "SELL" && delta.abs() > current_quantity)),
        ),
        (
            "BUYING_POWER".into(),
            side != "BUY" || order_notional <= snapshot.account.buying_power,
        ),
    ]);
    let mut reason_codes = checks
        .iter()
        .filter_map(|(name, passed)| (!passed).then_some(name.clone()))
        .collect::<Vec<_>>();
    reason_codes.sort();
    if !reason_codes.is_empty() {
        return ExecutionPlan {
            approved: false,
            reason_codes,
            intent: None,
        };
    }
    let quantity = delta.abs();
    let id = stable_id(&[
        "broker_order",
        &forecast.prediction_id,
        &format!("{target_weight:.10}"),
        side,
    ]);
    let order = BrokerOrderRequest {
        client_order_id: id.clone(),
        symbol,
        side: side.into(),
        quantity,
        limit_price,
        order_type: "LIMIT".into(),
        time_in_force: "DAY".into(),
    };
    ExecutionPlan {
        approved: true,
        reason_codes: Vec::new(),
        intent: Some(ExecutionIntent {
            client_order_id: id,
            prediction_id: forecast.prediction_id.clone(),
            model_id: forecast.model_id.clone(),
            model_hash: forecast.model_hash.clone(),
            feature_hash: forecast.feature_hash.clone(),
            data_manifest_hash: forecast.data_manifest_hash.clone(),
            forecast_as_of: forecast.decision_as_of,
            expires_at: forecast.decision_as_of
                + chrono::Duration::seconds(config.max_signal_age_seconds),
            target_weight,
            target_notional,
            order,
            checks,
        }),
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReconciliationStatus {
    pub configured: bool,
    pub connected: bool,
    pub mode: String,
    pub account_id: Option<u64>,
    pub last_success: Option<DateTime<Utc>>,
    pub last_snapshot_id: Option<String>,
    pub last_error: Option<String>,
}

#[derive(Debug)]
pub struct BrokerMonitor {
    inner: RwLock<ReconciliationStatus>,
}

impl BrokerMonitor {
    pub fn new(config: &ExecutionConfig) -> Arc<Self> {
        Arc::new(Self {
            inner: RwLock::new(ReconciliationStatus {
                configured: config.enabled,
                connected: false,
                mode: config.mode.clone(),
                account_id: config.account_id,
                last_success: None,
                last_snapshot_id: None,
                last_error: None,
            }),
        })
    }

    pub fn status(&self) -> ReconciliationStatus {
        self.inner.read().clone()
    }

    fn success(&self, snapshot: &BrokerSnapshot) {
        let mut status = self.inner.write();
        status.connected = true;
        status.account_id = Some(snapshot.account.account_id);
        status.last_success = Some(Utc::now());
        status.last_snapshot_id = Some(snapshot.snapshot_id.clone());
        status.last_error = None;
    }

    fn failure(&self, error: impl std::fmt::Display) {
        let mut status = self.inner.write();
        status.connected = false;
        status.last_error = Some(error.to_string());
    }
}

pub async fn reconcile_once(
    config: &ExecutionConfig,
    runtime: &Arc<QuantRuntime>,
    monitor: &Arc<BrokerMonitor>,
) -> Result<BrokerSnapshot> {
    let client = MoomooBrokerClient::from_config(config)?;
    let health = client.health().await?;
    ensure!(health.status == "READY", "broker gateway is not ready");
    ensure!(health.mode == config.mode, "gateway mode mismatch");
    if let Some(account_id) = config.account_id {
        ensure!(health.account_id == account_id, "gateway account mismatch");
    }
    let mut snapshot = client.snapshot().await?;
    snapshot.validate(config, Utc::now())?;
    if runtime.status().kill_switch_active {
        let open_axio_orders = snapshot
            .orders
            .iter()
            .filter(|order| {
                order.client_order_id.starts_with("axio_")
                    && matches!(
                        order.status.as_str(),
                        "WAITING_SUBMIT"
                            | "SUBMITTING"
                            | "SUBMITTED"
                            | "SUBMITTED_UNKNOWN"
                            | "FILLED_PART"
                    )
            })
            .map(|order| order.broker_order_id.clone())
            .collect::<Vec<_>>();
        for broker_order_id in open_axio_orders {
            client
                .cancel_order(&broker_order_id)
                .await
                .with_context(|| {
                    format!("kill switch failed to cancel broker order {broker_order_id}")
                })?;
        }
        snapshot = client.snapshot().await?;
        snapshot.validate(config, Utc::now())?;
    }
    let store = ExecutionStore::open(&config.oms_path)?;
    store.reconcile(&snapshot)?;
    runtime.update_authoritative_portfolio(snapshot.portfolio(), snapshot.source.clone());
    monitor.success(&snapshot);
    Ok(snapshot)
}

pub async fn run_reconciliation_loop(
    config: ExecutionConfig,
    runtime: Arc<QuantRuntime>,
    monitor: Arc<BrokerMonitor>,
) {
    loop {
        if let Err(error) = reconcile_once(&config, &runtime, &monitor).await {
            monitor.failure(error);
            runtime.clear_authoritative_portfolio();
        }
        tokio::time::sleep(StdDuration::from_millis(config.reconcile_interval_ms)).await;
    }
}

pub fn gateway_http_status(error: &anyhow::Error) -> StatusCode {
    let message = error.to_string();
    if message.contains("401") || message.contains("UNAUTHORIZED") {
        StatusCode::UNAUTHORIZED
    } else if message.contains("NOT_ARMED") || message.contains("403") {
        StatusCode::FORBIDDEN
    } else if message.contains("RISK_REJECTED") || message.contains("422") {
        StatusCode::UNPROCESSABLE_ENTITY
    } else {
        StatusCode::SERVICE_UNAVAILABLE
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        allocation::{AllocationAction, BettingPolicy},
        config::ExecutionConfig,
        predictor::{BarrierProbabilities, DecisionPolicyResult},
    };
    use chrono::TimeZone;
    use tempfile::tempdir;

    fn snapshot(now: DateTime<Utc>) -> BrokerSnapshot {
        BrokerSnapshot {
            snapshot_id: "snap-1".into(),
            as_of: now,
            source: "MOOMOO_OPEND_TRADE_API".into(),
            authoritative: true,
            mode: "simulate".into(),
            account: BrokerAccountSnapshot {
                account_id: 123,
                cash: 100_000.0,
                equity: 100_000.0,
                buying_power: 100_000.0,
                market_value: 0.0,
                currency: "USD".into(),
            },
            positions: Vec::new(),
            orders: Vec::new(),
            fills: Vec::new(),
        }
    }

    fn allocation(now: DateTime<Utc>) -> BettingDecision {
        BettingDecision {
            status: "TARGET_PROPOSED".into(),
            policy_version: "test".into(),
            symbol: "SPY".into(),
            horizon_minutes: 15,
            forecast_as_of: now,
            evidence_status: "ELIGIBLE".into(),
            action: AllocationAction::TargetLong,
            executable: false,
            target_weight: Some(0.005),
            target_notional: Some(500.0),
            raw_kelly_fraction: 0.1,
            fractional_kelly: BettingPolicy::default().fractional_kelly,
            directional_edge_bps: 4.0,
            net_edge_bps: 3.0,
            expected_log_growth: 0.1,
            shrinkage_factor: 0.2,
            binding_caps: Vec::new(),
            pretrade_checks: BTreeMap::from([("MODEL_PROMOTED".into(), true)]),
            reason_codes: vec!["ORDER_ROUTING_REQUIRES_SEPARATE_RISK_APPROVAL".into()],
            truth: "test".into(),
        }
    }

    fn forecast(now: DateTime<Utc>) -> ForecastContract {
        ForecastContract {
            prediction_id: "prediction-1".into(),
            created_at: now,
            observation_cutoff: now,
            as_of: now,
            decision_as_of: now,
            latest_input_available_at: now,
            earliest_executable_time: now,
            symbol: "SPY".into(),
            timeframe: "1m".into(),
            horizon_minutes: 15,
            label_start: now,
            label_end: now + chrono::Duration::minutes(15),
            session: "2026-07-22".into(),
            timezone: "America/New_York".into(),
            reference_price: 100.0,
            reference_price_source: "test".into(),
            expected_return: 0.001,
            expected_price: Some(100.1),
            return_definition: "SIMPLE_RETURN".into(),
            current_close_reference_scenario_expected_price: 0.0,
            current_close_reference_scenario_price_quantiles: Vec::new(),
            current_close_reference_scenario_basis: String::new(),
            current_close_reference_scenario_status: String::new(),
            current_close_reference_scenario_semantics: String::new(),
            median_return: 0.001,
            return_quantiles: Vec::new(),
            price_quantiles: Vec::new(),
            p_up: Some(0.7),
            p_down: None,
            p_flat: None,
            raw_analog_up_frequency: 0.7,
            raw_analog_down_frequency: 0.2,
            raw_analog_flat_frequency: 0.1,
            calibrated_probability_up: Some(0.7),
            probability_calibration: Default::default(),
            suggested_direction: 1,
            strategy_win_probability: Some(0.7),
            kernel_regression: Default::default(),
            outcome_prediction_intervals: Vec::new(),
            expected_volatility: 0.01,
            expected_absolute_move: 0.01,
            mfe_distribution: Vec::new(),
            mae_distribution: Vec::new(),
            barrier_probabilities: BarrierProbabilities {
                upper_first: None,
                lower_first: None,
                neither: None,
                status: "test".into(),
            },
            filtered_state_probabilities: vec![1.0],
            predicted_state_probabilities: vec![1.0],
            state_entropy: Some(0.0),
            dominant_regime_state: Some(0),
            dominant_regime_probability: Some(1.0),
            regime_model_selection: None,
            stochastic_research_layer: Default::default(),
            epistemic_uncertainty: 0.0,
            ood_score: 0.1,
            market_snapshot_id: None,
            snapshot_link_status: "test".into(),
            top_analogs: Vec::new(),
            analog_effective_sample_size: 200.0,
            analog_similarity_score: 0.9,
            analog_max_day_weight: 0.1,
            analog_concentration_penalty: 0.0,
            analog_engine_status: "OK".into(),
            analog_metric: "test".into(),
            analog_bandwidth: 1.0,
            analog_diagnostics: None,
            analog_sensitivity: Vec::new(),
            model_id: "promoted".into(),
            model_hash: "a".repeat(64),
            feature_version: "v1".into(),
            feature_hash: "b".repeat(64),
            data_source: "test".into(),
            data_capability_level: "D1".into(),
            market_coverage: "test".into(),
            model_trained_through: "2026-07-21".into(),
            target_status: "UNDERLYING".into(),
            data_manifest_hash: "c".repeat(64),
            evidence_grade: "FORWARD".into(),
            evidence_kind: "live_shadow_prediction".into(),
            sample_size: 200,
            calibration_status: "PROMOTED_OOS".into(),
            availability_semantics: "test".into(),
            decision: DecisionPolicyResult {
                action: "PAPER_LONG_CANDIDATE".into(),
                eligible: true,
                expected_edge_after_cost: 0.001,
                no_trade_reasons: Vec::new(),
                policy_version: "test".into(),
            },
        }
    }

    #[test]
    fn oms_is_idempotent_and_preserves_intent_identity() {
        let dir = tempdir().unwrap();
        let store = ExecutionStore::open(&dir.path().join("oms.sqlite3")).unwrap();
        let now = Utc::now();
        let intent = ExecutionIntent {
            client_order_id: "axio_order_1".into(),
            prediction_id: "p1".into(),
            model_id: "m".into(),
            model_hash: "a".repeat(64),
            feature_hash: "b".repeat(64),
            data_manifest_hash: "c".repeat(64),
            forecast_as_of: now,
            expires_at: now + chrono::Duration::seconds(30),
            target_weight: 0.001,
            target_notional: 100.0,
            order: BrokerOrderRequest {
                client_order_id: "axio_order_1".into(),
                symbol: "US.SPY".into(),
                side: "BUY".into(),
                quantity: 1.0,
                limit_price: 100.0,
                order_type: "LIMIT".into(),
                time_in_force: "DAY".into(),
            },
            checks: BTreeMap::new(),
        };
        assert!(store.record_intent(&intent, "APPROVED").unwrap());
        assert!(!store.record_intent(&intent, "APPROVED").unwrap());
    }

    #[test]
    fn order_plan_fails_closed_when_kill_switch_is_active() {
        let now = Utc.with_ymd_and_hms(2026, 7, 22, 14, 0, 0).unwrap();
        let runtime = RuntimeStatus {
            mode: "PAPER".into(),
            market_status: "OPEN".into(),
            paper_running: true,
            kill_switch_active: true,
            new_orders_allowed: false,
            event_lag_ms: 0,
            last_error: None,
        };
        let risk = RiskStatus {
            kill_switch_active: true,
            daily_trades: 0,
            max_daily_trades: 3,
            daily_loss_used: 0.0,
            daily_loss_limit: 0.01,
            drawdown: 0.0,
            drawdown_limit: 0.05,
            last_decision: None,
        };
        let config = ExecutionConfig {
            enabled: true,
            ..ExecutionConfig::default()
        };
        let plan = plan_order(
            &allocation(now),
            &forecast(now),
            &snapshot(now),
            &runtime,
            &risk,
            &config,
            now,
        );
        assert!(!plan.approved);
        assert!(plan.reason_codes.contains(&"KILL_SWITCH_CLEAR".into()));
    }

    #[test]
    fn real_mode_requires_pinned_account_and_explicit_enable() {
        let mut config = ExecutionConfig {
            mode: "real".into(),
            provider: "moomoo".into(),
            ..ExecutionConfig::default()
        };
        assert!(config.validate().is_err());
        config.allow_real_orders = true;
        config.account_id = Some(123);
        assert!(config.validate().is_ok());
    }
}

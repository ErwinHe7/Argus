//! STUB — 见 `src/data/mod.rs`。
//!
//! 字段与类型全部从调用点反推，逐条注明依据。
//!
//! `RealtimeStockTapeEvent` 是唯一能够**精确**还原的类型：
//! `src/engine/l1_order_flow.rs:283-310` 的测试里有它的完整结构体字面量。
//! 其余类型只还原了被引用到的字段，原类型很可能更宽。

use std::path::{Path, PathBuf};

use anyhow::Result;
use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use tokio::sync::mpsc::Sender;

use crate::{
    config::{LiveConfig, MassiveConfig},
    domain::{CallPut, MarketBar, OptionQuote},
};

/// 依据：`src/market_query.rs:1070` 与 `src/api.rs:1489` 都拿它和
/// `snapshot.schema_version`（String）比较。
///
/// ⚠️ 这个**字符串字面量的值是不可恢复的**，只能靠猜。
/// 它在幸存代码里只被比较、从不被打印，review package 里也没有随附任何
/// option chain 样本 artifact。
///
/// 后果：在原始值被恢复之前，任何真实的 chain artifact 都会在
/// `api.rs:1489`、`market_query.rs:1070`、`quantctl.rs:586` 三处
/// `schema_version != OPTION_CHAIN_SCHEMA_VERSION` 的门控上被拒绝，
/// 表现为 `OPTION_CHAIN_SCHEMA_INCOMPATIBLE`。
/// 这是 fail-closed 行为，不会产生错误结果，但会让人误以为是数据问题。
pub const OPTION_CHAIN_SCHEMA_VERSION: &str = "massive.full_option_chain.v1";

/// 精确还原自 `src/engine/l1_order_flow.rs:283-310` 的结构体字面量。
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RealtimeStockTapeEvent {
    pub schema_version: String,
    pub provider: String,
    pub event_type: String,
    pub symbol: String,
    pub provider_timestamp: Option<DateTime<Utc>>,
    pub received_at: DateTime<Utc>,
    pub sequence: Option<u64>,
    pub trade_price: Option<f64>,
    pub trade_size_provider_units: Option<f64>,
    pub bid: Option<f64>,
    pub bid_size_provider_units: Option<f64>,
    pub ask: Option<f64>,
    pub ask_size_provider_units: Option<f64>,
    pub open: Option<f64>,
    pub high: Option<f64>,
    pub low: Option<f64>,
    pub close: Option<f64>,
    pub volume: Option<f64>,
    pub size_semantics: String,
    pub entitlement: String,
    pub delayed: bool,
    pub stale: bool,
    pub future_timestamp: bool,
    pub model_eligible: bool,
    pub payload_sha256: String,
    pub raw: serde_json::Value,
}

/// 依据：`src/market_query.rs:812-826` 从 json 反序列化后访问
/// `delayed`/`stale`/`entitlement`/`bar`/`finalized_at`/`provider`。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RealtimeMarketBarEnvelope {
    pub bar: MarketBar,
    pub finalized_at: DateTime<Utc>,
    pub received_at: DateTime<Utc>,
    pub bar_start: DateTime<Utc>,
    pub provider: String,
    pub entitlement: String,
    pub delayed: bool,
    pub stale: bool,
}

/// 依据：`src/market_query.rs:1099-1102` `snapshot.coverage.fresh_quote_coverage`
/// 与 f64 比较。
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct OptionChainCoverage {
    pub fresh_quote_coverage: f64,
    pub open_interest_coverage: f64,
    pub model_eligible_contracts: usize,
}

/// 依据：`src/market_query.rs:1068-1105`、`src/api.rs:1487-1636`。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MassiveFullOptionChain {
    pub schema_version: String,
    pub underlying: String,
    pub source: String,
    pub captured_at: DateTime<Utc>,
    pub latest_quote_at: Option<DateTime<Utc>>,
    pub greeks_available_at: DateTime<Utc>,
    pub oi_available_at: DateTime<Utc>,
    pub open_interest_semantics: String,
    pub realtime_required: bool,
    pub coverage: OptionChainCoverage,
    pub chain_complete: bool,
    pub model_ready: bool,
    pub blockers: Vec<String>,
    pub contracts: Vec<MassiveOptionContract>,
    pub contracts_sha256: String,
}

/// 依据：`src/api.rs:1366-1420`（`call_put` 与 `CallPut` 比较、`open_interest?`、
/// `volume.unwrap_or(0)`、`strike` 参与算术）、`src/api.rs:1571`
/// （`.filter_map(|contract| contract.as_option_quote())` → 返回 Option）。
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MassiveOptionContract {
    pub option_symbol: String,
    pub expiry: NaiveDate,
    pub dte: i32,
    pub strike: f64,
    pub call_put: CallPut,
    pub bid: Option<f64>,
    pub ask: Option<f64>,
    pub open_interest: Option<u64>,
    pub volume: Option<u64>,
    pub underlying_price: Option<f64>,
}

impl MassiveOptionContract {
    pub fn as_option_quote(&self) -> Option<OptionQuote> {
        unimplemented!("stub: MassiveOptionContract::as_option_quote —— 原模块被 .gitignore 排除")
    }
}

/// 依据：`src/bin/quantctl.rs:1857-1865` `.await?` 后访问
/// `report.production_ready`（bool）与 `report.blockers.join("; ")`。
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct RealtimeEntitlementReport {
    pub production_ready: bool,
    pub blockers: Vec<String>,
}

pub async fn check_realtime_entitlements(
    _massive: &MassiveConfig,
    _live: &LiveConfig,
) -> Result<RealtimeEntitlementReport> {
    unimplemented!("stub: check_realtime_entitlements —— 原模块被 .gitignore 排除")
}

/// 依据：`src/bin/quantctl.rs:1885-1893` 与 `2010-2018`，
/// 第五个参数在两处分别是 `max_finalized`（`Option<usize>`，一处传 `None`），
/// 第六个是 `Option<Sender<_>>`（`quantctl.rs:2004` 用的是有界 `mpsc::channel(4096)`，
/// 不是 unbounded）。
pub async fn run_stock_stream(
    _massive: &MassiveConfig,
    _live: &LiveConfig,
    _output: &Path,
    _status: &Path,
    _max_finalized: Option<u64>,
    _sender: Option<Sender<RealtimeMarketBarEnvelope>>,
) -> Result<()> {
    unimplemented!("stub: run_stock_stream —— 原模块被 .gitignore 排除")
}

/// 依据：`src/bin/quantctl.rs:2198-2207`，`fetch` 是 async 且返回 chain，
/// `persist` 不是 async 且返回路径。
pub async fn fetch_full_option_chain(
    _massive: &MassiveConfig,
    _live: &LiveConfig,
    _underlying: &str,
) -> Result<MassiveFullOptionChain> {
    unimplemented!("stub: fetch_full_option_chain —— 原模块被 .gitignore 排除")
}

pub fn persist_full_option_chain(
    _massive: &MassiveConfig,
    _snapshot: &MassiveFullOptionChain,
) -> Result<PathBuf> {
    unimplemented!("stub: persist_full_option_chain —— 原模块被 .gitignore 排除")
}

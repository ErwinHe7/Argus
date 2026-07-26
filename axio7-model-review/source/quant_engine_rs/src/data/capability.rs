//! STUB — 见 `src/data/mod.rs`。
//!
//! 推断依据：
//! - `src/api.rs:447` `inspect(&state.config.data)` 后 `map_err(ApiError::internal)?`
//!   → 返回 `Result<DataCapabilityReport>`；
//! - `src/api.rs:852-862` `inspect(config).ok().is_some_and(|capability| ...)`
//!   访问 `capability.manifest_hashes`（可 `.iter()`）与
//!   `capability.normalized_file_sha256`（可 `.as_deref()` → `Option<String>`）；
//! - `src/api.rs:448` `capability_audit(&state.config.data)` 同样是 Result，
//!   结果被 `serde_json::json!` 直接嵌入 → 必须 `Serialize`；
//! - `src/predictor.rs:2147` `capability.highest_level == "NONE"` → `String`；
//! - `src/predictor.rs:2371-2377` `capability.source.clone()`、
//!   `capability.evidence_grade.clone()` → 均为 `String`。

use anyhow::Result;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::config::DataConfig;

/// 字段集**精确**还原自 `src/predictor.rs:2890-2912` 测试代码里的完整结构体
/// 字面量，不是推测。字段顺序与该字面量一致。
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct DataCapabilityReport {
    pub generated_at: DateTime<Utc>,
    pub highest_level: String,
    pub d0_underlying_bars: bool,
    pub d1_trades_quotes: bool,
    pub d2_option_nbbo: bool,
    pub d3_option_analytics: bool,
    pub symbols: Vec<String>,
    pub coverage_start: Option<DateTime<Utc>>,
    pub coverage_end: Option<DateTime<Utc>>,
    pub row_count: usize,
    pub timestamp_precision: String,
    pub source: String,
    pub adjusted_status: String,
    pub context_status: String,
    pub context_observation_count: usize,
    pub context_model_eligible_fields: Vec<String>,
    pub normalized_file_sha256: Option<String>,
    pub manifest_hashes: Vec<String>,
    pub evidence_grade: String,
    pub allowed_claims: Vec<String>,
    pub prohibited_claims: Vec<String>,
    pub missing_data: Vec<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CapabilityAudit {
    pub findings: Vec<String>,
}

pub fn inspect(_config: &DataConfig) -> Result<DataCapabilityReport> {
    unimplemented!("stub: crate::data::capability::inspect —— 原模块被 .gitignore 排除")
}

/// 依据：`src/bin/quantctl.rs:1581` `capability::report_hash(&report)?` 嵌入 json。
pub fn report_hash(_report: &DataCapabilityReport) -> Result<String> {
    unimplemented!("stub: crate::data::capability::report_hash —— 原模块被 .gitignore 排除")
}

pub fn capability_audit(_config: &DataConfig) -> Result<CapabilityAudit> {
    unimplemented!("stub: crate::data::capability::capability_audit —— 原模块被 .gitignore 排除")
}

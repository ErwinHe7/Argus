//! STUB — 见 `src/data/mod.rs`。
//!
//! 推断依据：
//! - `src/api.rs:568` `fusion_snapshot(&config.input_path, config, as_of).map_err(...)?`
//!   随后 `serde_json::to_value(snapshot)` → `Result<T: Serialize>`；
//!   第二个参数是 `config`（`&ResearchConfig`，与 `config.input_path` 同源），
//!   第三个是 `as_of: DateTime<Utc>`；
//! - 返回值序列化后含 `model_eligible_domain_counts` 键（`src/api.rs:579`）；
//! - `src/api.rs:571` `verify_official_archive(&config.input_path, &state.config.data.manifest_root)`
//!   **不返回 Result**（没有 `?`），直接 `.verified` → 结构体含 `verified: bool`，且需 `Serialize`。

use std::path::Path;

use anyhow::Result;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::config::ContextFeedConfig;

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct FusionSnapshot {
    pub model_eligible_domain_counts: Value,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct OfficialArchiveVerification {
    pub verified: bool,
    pub reason_codes: Vec<String>,
}

pub fn fusion_snapshot(
    _input_path: &Path,
    _config: &ContextFeedConfig,
    _as_of: DateTime<Utc>,
) -> Result<FusionSnapshot> {
    unimplemented!("stub: crate::data::context::fusion_snapshot —— 原模块被 .gitignore 排除")
}

/// 依据：`src/bin/quantctl.rs:1717` `context::audit(&input, &config.data.context, cutoff)?`。
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ContextAuditReport {
    pub model_eligible_rows: usize,
    pub blockers: Vec<String>,
}

pub fn audit(
    _input: &Path,
    _config: &ContextFeedConfig,
    _cutoff: DateTime<Utc>,
) -> Result<ContextAuditReport> {
    unimplemented!("stub: crate::data::context::audit —— 原模块被 .gitignore 排除")
}

pub fn verify_official_archive(
    _input_path: &Path,
    _manifest_root: &Path,
) -> OfficialArchiveVerification {
    unimplemented!(
        "stub: crate::data::context::verify_official_archive —— 原模块被 .gitignore 排除"
    )
}

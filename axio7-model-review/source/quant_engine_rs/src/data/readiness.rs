//! STUB — 见 `src/data/mod.rs`。
//!
//! 推断依据：
//! - `src/api.rs:422` `doctor(&state.config.data).map_err(ApiError::internal)?` → `Result<_>`；
//! - `src/api.rs:424-426` 访问 `report.credentials`、`report.source_matrix`、
//!   `report.underlying_proxy`，全部被 `json!` 直接嵌入 → `Serialize`；
//! - `src/api.rs:432` `json!(report.readiness)`；
//! - `src/api.rs:4309` `report.readiness.status != "SPXW_BACKTEST_READY"` → `String`；
//! - `src/api.rs:4312` `report.readiness.missing_requirements.join(",")` → `Vec<String>`。

use anyhow::Result;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::config::DataConfig;

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ReadinessStatus {
    pub status: String,
    pub missing_requirements: Vec<String>,
}

/// 依据：`src/api.rs:4327-4335` `report.artifacts.into_iter()` 后访问
/// `artifact.path.contains(..)`（String）与 `artifact.manifest_hash.as_ref()`
/// （`Option<String>`）。
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ArtifactEntry {
    pub path: String,
    pub manifest_hash: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct DataDoctorReport {
    pub credentials: Value,
    pub source_matrix: Value,
    pub underlying_proxy: Value,
    pub readiness: ReadinessStatus,
    pub artifacts: Vec<ArtifactEntry>,
}

pub fn doctor(_config: &DataConfig) -> Result<DataDoctorReport> {
    unimplemented!("stub: crate::data::readiness::doctor —— 原模块被 .gitignore 排除")
}

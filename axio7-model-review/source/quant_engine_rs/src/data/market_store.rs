//! STUB — 见 `src/data/mod.rs`。
//!
//! 推断依据：`src/bin/quantctl.rs:1668-1702` 的完整使用块 ——
//! 两个 enum 的变体名来自 `match` 分支，`MaterializeRequest` 的字段集来自
//! 完整结构体字面量，`MarketDataStore` 的方法来自 `open` / `materialize` / `coverage`
//! 三处调用（`materialize` 需要 `&mut self`，因为调用点是 `let mut store`）。

use std::path::PathBuf;

use anyhow::Result;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use crate::domain::MarketBar;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AvailabilityPolicy {
    ObservedAtIngestion,
    CompletedMinuteEndPlusDelay,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LicenseScope {
    ResearchOnly,
    InternalDisplay,
    PublicRedistribution,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MaterializeRequest {
    pub database: PathBuf,
    pub source_path: PathBuf,
    pub provider: String,
    pub dataset: String,
    pub captured_at: DateTime<Utc>,
    pub availability_policy: AvailabilityPolicy,
    pub availability_delay_seconds: i64,
    pub license_scope: LicenseScope,
    pub license_reference: String,
    pub input_rows: usize,
    pub accepted_rows: usize,
    pub duplicate_rows: usize,
    pub rejected_rows: usize,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MaterializeReceipt {
    pub rows_written: usize,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StoreCoverage {
    pub datasets: Vec<String>,
}

#[derive(Debug)]
pub struct MarketDataStore;

impl MarketDataStore {
    pub fn open(_database: &std::path::Path) -> Result<Self> {
        unimplemented!("stub: MarketDataStore::open —— 原模块被 .gitignore 排除")
    }

    pub fn materialize(
        &mut self,
        _request: &MaterializeRequest,
        _records: &[MarketBar],
    ) -> Result<MaterializeReceipt> {
        unimplemented!("stub: MarketDataStore::materialize —— 原模块被 .gitignore 排除")
    }

    pub fn coverage(&self) -> Result<StoreCoverage> {
        unimplemented!("stub: MarketDataStore::coverage —— 原模块被 .gitignore 排除")
    }
}

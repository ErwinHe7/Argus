//! STUB — 见 `src/data/mod.rs`。
//!
//! 推断依据：
//! - `src/api.rs:364` `json!({"massive": crate::data::massive::status(&state.config.data.massive)})`
//!   —— 无 `?`，直接嵌入 json → 返回值本身可 `Serialize`，不是 `Result`；
//! - `src/api.rs:1353` `serde_json::to_value(crate::data::massive::status(&state.config.data.massive))`
//!   佐证同一签名。
//!
//! `massive::sync` 只被 `src/bin/quantctl.rs` 使用（`.await?`，返回 receipt），
//! 不在 lib 编译路径上，此处一并给出以便二进制也能构建。

use std::path::Path;

use anyhow::Result;
use chrono::NaiveDate;
use serde::{Deserialize, Serialize};

use crate::config::{DataConfig, MassiveConfig};

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MassiveStatus {
    pub configured: bool,
    pub entitlement: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MassiveSyncReceipt {
    pub rows: usize,
    pub output: String,
}

pub fn status(_config: &MassiveConfig) -> MassiveStatus {
    unimplemented!("stub: crate::data::massive::status —— 原模块被 .gitignore 排除")
}

pub async fn sync(
    _config: &DataConfig,
    _from: NaiveDate,
    _to: NaiveDate,
    _symbols: Option<Vec<String>>,
    _output: &Path,
) -> Result<MassiveSyncReceipt> {
    unimplemented!("stub: crate::data::massive::sync —— 原模块被 .gitignore 排除")
}

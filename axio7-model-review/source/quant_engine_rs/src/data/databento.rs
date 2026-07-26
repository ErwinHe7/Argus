//! STUB — 见 `src/data/mod.rs`。
//!
//! 推断依据：`src/api.rs:4249` 的 `api_opra_request` 返回
//! `crate::config::DataRequest`，其结果在 `src/api.rs:4295` 传给
//! `estimate_cost(&query).await.map_err(ApiError::internal)?`，
//! 返回值随后被 `json!` 直接嵌入 → async + `Result<T: Serialize>`。

use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::config::DataRequest;

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CostEstimate {
    pub estimated_records: Option<u64>,
    pub estimated_bytes: Option<u64>,
    pub estimated_vendor_charge_usd: Option<f64>,
    pub estimated_cost_usd: f64,
}

pub async fn estimate_cost(_query: &DataRequest) -> Result<CostEstimate> {
    unimplemented!("stub: crate::data::databento::estimate_cost —— 原模块被 .gitignore 排除")
}

/// 依据：`src/bin/quantctl.rs:1591` 与 `1628`
/// `databento::download(&config.data, request, confirm_cost, maximum_cost_usd).await?`。
/// 第二参数在 1628 处来自 `find_request()`，其返回类型是 `&DataRequest`
/// （`quantctl.rs:1263-1266`）。
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct DownloadReceipt {
    pub path: String,
    pub bytes: u64,
}

pub async fn download(
    _config: &crate::config::DataConfig,
    _request: &DataRequest,
    _confirm_cost: bool,
    _maximum_cost_usd: f64,
) -> Result<DownloadReceipt> {
    unimplemented!("stub: crate::data::databento::download —— 原模块被 .gitignore 排除")
}

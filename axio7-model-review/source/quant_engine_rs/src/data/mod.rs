pub mod capability;
pub mod context;
pub mod csv_import;
pub mod databento;
pub mod databento_live;
pub mod dbn_decode;
pub mod ibkr_relay;
pub mod manifest;
pub mod market_store;
pub mod massive;
pub mod massive_live;
pub mod options;
pub mod readiness;
pub mod sample_plan;

use std::path::{Path, PathBuf};

use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::config::DataRequest;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CostEstimate {
    pub request_name: String,
    pub dataset: String,
    pub schema: String,
    pub symbols: Vec<String>,
    pub start: String,
    pub end: String,
    pub estimated_records: u64,
    pub estimated_bytes: u64,
    pub estimated_cost_usd: f64,
    pub warning: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DownloadReceipt {
    pub path: PathBuf,
    pub bytes: u64,
    pub sha256: String,
    pub manifest_path: PathBuf,
}

pub trait LicensedFileImporter {
    type Output;
    fn import(&self, input: &Path) -> Result<Self::Output>;
}

pub fn request_output_path(root: &Path, request: &DataRequest) -> PathBuf {
    root.join(&request.dataset)
        .join(&request.schema)
        .join(format!(
            "{}__{}__{}.dbn.zst",
            request.name,
            request.start[..10].replace('-', ""),
            request.end[..10].replace('-', "")
        ))
}

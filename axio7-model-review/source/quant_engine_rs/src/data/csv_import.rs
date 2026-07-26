//! STUB — 见 `src/data/mod.rs`。
//!
//! 推断依据：`tests/core.rs:159` 写的是 `MarketBarCsvImporter.import(...)`，
//! 即在**值**上调用方法且没有构造表达式 → 单元结构体（unit struct）。

use std::path::Path;

use anyhow::Result;

use super::{FileImportReport, LicensedFileImporter};

#[derive(Debug, Clone, Copy, Default)]
pub struct MarketBarCsvImporter;

impl LicensedFileImporter for MarketBarCsvImporter {
    fn import(&self, _path: &Path) -> Result<FileImportReport> {
        unimplemented!(
            "stub: crate::data::csv_import::MarketBarCsvImporter::import —— 原模块被 .gitignore 排除"
        )
    }
}

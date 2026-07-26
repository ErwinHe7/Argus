//! STUB — 原 `src/data/` 整个目录被 `.gitignore` 的 `data/` 规则误伤，未进入交付快照。
//!
//! 这里重建的**只是被 crate 其余部分引用到的公开接口**，不是原实现。
//! 所有函数体一律 `unimplemented!()`，不提供任何近似实现 —— 假装实现会让
//! 测试结果失去意义。
//!
//! 存在的唯一目的：让 crate 重新编译，从而回答「除了这个被吞掉的模块之外，
//! 模型代码本身还有没有别的问题」。签名全部从调用点反推，
//! 每个类型上方注明了推断依据。
//!
//! 补回原始模块后请整体删除 `src/data/`（stub 版）。
//!
//! 已知原模块至少还包含以下子模块（被 `src/bin/quantctl.rs` 引用，
//! 不在 lib 编译路径上，故此处未重建）：
//! `dbn_decode`、`market_store`（含 `AvailabilityPolicy`、`LicenseScope`、
//! `MarketDataStore`、`MaterializeRequest`）、`sample_plan`。

use std::path::Path;

use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::domain::MarketBar;

pub mod capability;
pub mod context;
pub mod csv_import;
pub mod databento;
pub mod dbn_decode;
pub mod market_store;
pub mod massive;
pub mod massive_live;
pub mod readiness;
pub mod sample_plan;

/// 推断依据：`src/engine/mod.rs:29` 与 `tests/core.rs:6` 把它和
/// `csv_import::MarketBarCsvImporter` 一起导入，而 `tests/core.rs:159` 写的是
/// `MarketBarCsvImporter.import(Path::new(&path)).unwrap()` —— 值上调用方法、
/// 且需要单独导入名字，说明这是提供 `import` 的 trait。
pub trait LicensedFileImporter {
    fn import(&self, path: &Path) -> Result<FileImportReport>;
}

/// 推断依据：`tests/core.rs:160-163` 断言 `report.accepted_rows`、
/// `report.duplicate_rows`、`report.rejected_rows`、`report.records[0].timestamp`。
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct FileImportReport {
    pub input_rows: usize,
    pub accepted_rows: usize,
    pub duplicate_rows: usize,
    pub rejected_rows: usize,
    pub records: Vec<MarketBar>,
}

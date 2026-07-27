//! STUB — 见 `src/data/mod.rs`。
//!
//! 推断依据：`src/bin/quantctl.rs:1539` 调用点，参数类型来自同文件 clap 定义
//! （`quantctl.rs:255-264`）：`bars: PathBuf`、`event_date: Option<NaiveDate>`、
//! `strike_window_pct: f64`。返回值被 `write_json` 与 `to_string_pretty` 使用 → `Serialize`。

use std::path::Path;

use anyhow::Result;
use chrono::NaiveDate;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct FiveDaySamplePlan {
    pub dates: Vec<NaiveDate>,
    pub strike_window_pct: f64,
}

pub fn build_five_day_plan(
    _bars: &Path,
    _event_date: Option<NaiveDate>,
    _strike_window_pct: f64,
) -> Result<FiveDaySamplePlan> {
    unimplemented!(
        "stub: crate::data::sample_plan::build_five_day_plan —— 原模块被 .gitignore 排除"
    )
}

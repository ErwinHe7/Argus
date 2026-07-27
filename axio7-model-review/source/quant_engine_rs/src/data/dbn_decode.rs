//! STUB — 见 `src/data/mod.rs`。
//!
//! 推断依据：`src/bin/quantctl.rs:1727` 与 `1734`
//! `let rows = dbn_decode::write_ohlcv_csv(&input, &output, symbol_alias.as_deref())?;`
//! `let rows = dbn_decode::write_cbbo_csv(&input, &output)?;`

use std::path::Path;

use anyhow::Result;

pub fn write_ohlcv_csv(
    _input: &Path,
    _output: &Path,
    _symbol_alias: Option<&str>,
) -> Result<usize> {
    unimplemented!("stub: crate::data::dbn_decode::write_ohlcv_csv —— 原模块被 .gitignore 排除")
}

pub fn write_cbbo_csv(_input: &Path, _output: &Path) -> Result<usize> {
    unimplemented!("stub: crate::data::dbn_decode::write_cbbo_csv —— 原模块被 .gitignore 排除")
}

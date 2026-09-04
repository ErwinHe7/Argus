# Current source sync receipt

本分支把 AXIO7 当前模型、训练、实时数据接入和 native research 源码同步到 Argus，供外部审阅者直接查看、修改并提交 PR。

## 完整性

- 可编辑模型/runtime 源码：137 个文件。
- 可直接加载的冻结/候选 artifact：12 个 JSON。
- AXIO7 与 Argus 本分支同路径审阅文件合计：149 个。
- 缺失文件：0；多余文件：0；SHA-256 不一致：0。

审阅范围覆盖 `quant_engine_rs`、`intraday_quant` 和 `quant_core_cpp` 中的模型实现、测试、配置、数据 adapter、训练/报告源码与 runtime 说明。历史行情、实时行情行、数据库、provider session、密钥和生成缓存不属于源码，不进入仓库。

## 有意排除

- `quant_core_cpp/runtime/moomoo/APIChannel.dll`
- `quant_core_cpp/runtime/moomoo/moomoo_quote_bridge.exe`

以上两项是生成/供应商 runtime 二进制，不是模型源码。对应 runtime README 和源码合同已包含；二进制应从受信构建或供应商渠道获得，不应在代码审阅包中当作源码提交。

另排除未被源码引用的 synthetic JSONL fixture、`.orig`、cache、egg-info、数据库和市场数据文件。候选模型 artifact 未被删除：12 个 JSON 已恢复到可直接加载和浏览的 `source/quant_engine_rs/data/models/`，同时完整保留在 `model-artifacts/axio7-candidate-artifacts-2026-07-26.zip`。直接文件与 ZIP 每个成员的 SHA-256 全部一致。

## 当前实时数据状态

- Databento historical 与官方 Rust live adapter 均已包含；当前环境没有 live license，所以 production live 路径保持 fail-closed。
- IBKR Client Portal outbound relay 已包含，但合同严格限制为白名单 Level-1 bid/ask，不能传账户、持仓、订单或 cookies，也不能直接伪装为模型 OHLCV。
- Massive/Moomoo、readiness、normalized market store、manifest 和 sample-plan 源码均已包含。

## 验证

- `cargo fmt --check`：通过。
- `cargo clippy --all-targets -- -D warnings`：通过。
- `cargo test`：316 passed（296 library + 8 CLI + 12 integration），0 failed。
- Python pytest：26 passed，5 skipped，0 failed。
- C++：当前机器没有 CMake，未执行。

这些结果证明本审阅包可加载并满足现有自动化测试；它不等同于模型已校准、数据已获授权或 artifact 已晋升。
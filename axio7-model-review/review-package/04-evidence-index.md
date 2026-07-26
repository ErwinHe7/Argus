# 04 — 证据索引

## HMM / Baum–Welch

- `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs:97`：HMM fit、restarts、收敛和 BIC。
- `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs:225`：scaled forward/backward。
- `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs:270`：soft-EM / Baum–Welch 更新。
- `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs:348`：causal filtered probabilities。
- `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs:392`：full posterior 仅训练诊断。
- `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs:432`：log-space Viterbi。
- `axio7-model-review/source/quant_engine_rs/src/market_state.rs:318`：Baum–Welch transition counts 的诊断边界。
- `axio7-model-review/source/quant_engine_rs/src/bin/quantctl.rs:3429`：state candidates 与选择报告。
- `axio7-model-review/source/quant_engine_rs/src/bin/quantctl.rs:3437`：候选边界警告。

## Kernel / analog

- `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs:10`：12 维 feature schema。
- `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs:676`：train-only fit。
- `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs:726`：covariance shrinkage。
- `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs:767`：covariance inverse/fallback。
- `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs:864`：train-only OOD threshold。
- `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs:902`：距离函数。
- `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs:947`：causal query。
- `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs:1027`：candidate filters。
- `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs:1118`：每个历史日一个邻居。
- `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs:1159`：adaptive bandwidth。
- `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs:1170`：Gaussian posterior-overlap weights。
- `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs:1223`：distribution/local regression。
- `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs:1291`：ESS。
- `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs:1380`：NO_TRADE gates。

## SDE / OU

- `axio7-model-review/source/quant_engine_rs/src/engine/short_horizon.rs:424`：regime-conditioned diffusion fit。
- `axio7-model-review/source/quant_engine_rs/src/engine/short_horizon.rs:509`：VWAP residual OU fit。
- `axio7-model-review/source/quant_engine_rs/src/engine/short_horizon.rs:605`：transition estimate。
- `axio7-model-review/source/quant_engine_rs/src/engine/short_horizon.rs:1069`：多步 diffusion moments。
- `axio7-model-review/source/quant_engine_rs/src/engine/short_horizon.rs:2112`：fit tests。

## 传统模型、神经模型与校准

- `axio7-model-review/source/intraday_quant/src/intraday_quant/models/walk_forward.py:86`：Logistic。
- `axio7-model-review/source/intraday_quant/src/intraday_quant/models/walk_forward.py:90`：Ridge。
- `axio7-model-review/source/intraday_quant/src/intraday_quant/models/walk_forward.py:96`：HistGradientBoosting。
- `axio7-model-review/source/intraday_quant/src/intraday_quant/models/calibration.py:9`：isotonic/Platt wrapper。
- `axio7-model-review/source/intraday_quant/src/intraday_quant/models/causal_tcn.py:11`：causal convolution。
- `axio7-model-review/source/intraday_quant/src/intraday_quant/models/causal_tcn.py:120`：causal attention。
- `axio7-model-review/source/intraday_quant/src/intraday_quant/models/causal_tcn.py:148`：Mixture-of-Experts。
- `axio7-model-review/source/intraday_quant/src/intraday_quant/models/causal_tcn.py:311`：Student-t NLL。
- `axio7-model-review/source/intraday_quant/src/intraday_quant/training/cuda_challenger.py`：CUDA training、split 与报告。
- `axio7-model-review/source/quant_engine_rs/src/engine/models.rs:114`：Rust Platt calibrator。

## Artifact 与 runtime

- `axio7-model-review/model-artifacts/axio7-candidate-artifacts-2026-07-26.zip`：
  经 SHA-256 验证的 9 个 v2 candidate、registry 与 legacy standalone SPY v1
  artifact；解压后分别位于 `universe/` 与 `legacy/`。legacy 不应覆盖
  exact-symbol universe routing。
- `axio7-model-review/source/quant_engine_rs/src/frozen_universe.rs`：exact-symbol registry loading 与
  per-symbol failure isolation。
- `axio7-model-review/source/quant_engine_rs/src/bin/quantctl.rs`：Massive live model、options watch 与 CLI。
- `axio7-model-review/source/quant_engine_rs/container-entrypoint.sh`：runtime startup 与 readiness coupling。
- 实时 readiness receipt 未打包，因为它是环境/数据状态，不是模型源码。

## 数据与技术栈

- `axio7-model-review/source/quant_engine_rs/Cargo.toml`：Rust 生产依赖。
- `axio7-model-review/source/intraday_quant/pyproject.toml`：Python 研究依赖。
- Web/orchestration 不属于模型实现，本次没有复制完整 frontend。
- `axio7-model-review/source/quant_core_cpp/CMakeLists.txt`：C++20/native research。
- `axio7-model-review/source/intraday_quant/src/intraday_quant/features/pipeline.py:34`：offline features。
- `axio7-model-review/reference-docs/forecast-contract-and-evidence.md`：
  2026-07-25 的完整实时数据与生产技术债快照；其中单一 SPY live-routing
  问题已在 2026-07-26 修复，阅读时必须结合执行计划的 resolution receipt。
- `axio7-model-review/reference-docs/production-quant-inference.md`：执行与证据日志。

## 本包生成时的验证收据（2026-07-26）

- `npm run typecheck`：通过。
- `npm run build`：两次超过 60 秒执行窗口并被终止；
  `.next/export-detail.json` 为 `success:false`，本包不把它记作通过。执行计划中
  有更早的成功收据，但接收方应在自己的环境重新跑完整 build。
- `cargo fmt --check`：通过。
- `cargo clippy --all-targets -- -D warnings`：通过。
- `cargo test`：通过；286 library + 8 CLI + 12 integration tests。
- Python pytest：26 passed，5 skipped。
- C++：当前机器没有 CMake，未执行。

这些检查只能证明当前代码满足已有测试，不能证明模型已经校准、数据有权限或具备
production promotion 资格。

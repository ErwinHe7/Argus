# 04 — 证据索引

## HMM / Baum–Welch

- `quant_engine_rs/src/engine/regime.rs:97`：HMM fit、restarts、收敛和 BIC。
- `quant_engine_rs/src/engine/regime.rs:225`：scaled forward/backward。
- `quant_engine_rs/src/engine/regime.rs:270`：soft-EM / Baum–Welch 更新。
- `quant_engine_rs/src/engine/regime.rs:348`：causal filtered probabilities。
- `quant_engine_rs/src/engine/regime.rs:392`：full posterior 仅训练诊断。
- `quant_engine_rs/src/engine/regime.rs:432`：log-space Viterbi。
- `quant_engine_rs/src/market_state.rs:318`：Baum–Welch transition counts 的诊断边界。
- `quant_engine_rs/src/bin/quantctl.rs:3429`：state candidates 与选择报告。
- `quant_engine_rs/src/bin/quantctl.rs:3437`：候选边界警告。

## Kernel / analog

- `quant_engine_rs/src/analog_engine/mod.rs:10`：12 维 feature schema。
- `quant_engine_rs/src/analog_engine/mod.rs:676`：train-only fit。
- `quant_engine_rs/src/analog_engine/mod.rs:726`：covariance shrinkage。
- `quant_engine_rs/src/analog_engine/mod.rs:767`：covariance inverse/fallback。
- `quant_engine_rs/src/analog_engine/mod.rs:864`：train-only OOD threshold。
- `quant_engine_rs/src/analog_engine/mod.rs:902`：距离函数。
- `quant_engine_rs/src/analog_engine/mod.rs:947`：causal query。
- `quant_engine_rs/src/analog_engine/mod.rs:1027`：candidate filters。
- `quant_engine_rs/src/analog_engine/mod.rs:1118`：每个历史日一个邻居。
- `quant_engine_rs/src/analog_engine/mod.rs:1159`：adaptive bandwidth。
- `quant_engine_rs/src/analog_engine/mod.rs:1170`：Gaussian posterior-overlap weights。
- `quant_engine_rs/src/analog_engine/mod.rs:1223`：distribution/local regression。
- `quant_engine_rs/src/analog_engine/mod.rs:1291`：ESS。
- `quant_engine_rs/src/analog_engine/mod.rs:1380`：NO_TRADE gates。

## SDE / OU

- `quant_engine_rs/src/engine/short_horizon.rs:424`：regime-conditioned diffusion fit。
- `quant_engine_rs/src/engine/short_horizon.rs:509`：VWAP residual OU fit。
- `quant_engine_rs/src/engine/short_horizon.rs:605`：transition estimate。
- `quant_engine_rs/src/engine/short_horizon.rs:1069`：多步 diffusion moments。
- `quant_engine_rs/src/engine/short_horizon.rs:2112`：fit tests。

## 传统模型、神经模型与校准

- `intraday_quant/src/intraday_quant/models/walk_forward.py:86`：Logistic。
- `intraday_quant/src/intraday_quant/models/walk_forward.py:90`：Ridge。
- `intraday_quant/src/intraday_quant/models/walk_forward.py:96`：HistGradientBoosting。
- `intraday_quant/src/intraday_quant/models/calibration.py:9`：isotonic/Platt wrapper。
- `intraday_quant/src/intraday_quant/models/causal_tcn.py:11`：causal convolution。
- `intraday_quant/src/intraday_quant/models/causal_tcn.py:120`：causal attention。
- `intraday_quant/src/intraday_quant/models/causal_tcn.py:148`：Mixture-of-Experts。
- `intraday_quant/src/intraday_quant/models/causal_tcn.py:311`：Student-t NLL。
- `intraday_quant/src/intraday_quant/training/cuda_challenger.py`：CUDA training、split 与报告。
- `quant_engine_rs/src/engine/models.rs:114`：Rust Platt calibrator。

## Artifact 与 runtime

- `quant_engine_rs/data/models/universe/registry.json`：9 个 v2 candidate。
- `quant_engine_rs/data/models/universe/*.frozen.json`：每标的 frozen artifact。
- `quant_engine_rs/data/models/frozen_predictor_latest.json`：legacy standalone
  SPY v1 artifact；不应覆盖 exact-symbol universe routing。
- `quant_engine_rs/src/frozen_universe.rs`：exact-symbol registry loading 与
  per-symbol failure isolation。
- `quant_engine_rs/src/bin/quantctl.rs`：Massive live model、options watch 与 CLI。
- `quant_engine_rs/container-entrypoint.sh`：runtime startup 与 readiness coupling。
- `quant_engine_rs/data/live/massive_readiness.json`：最新 entitlement/readiness。

## 数据与技术栈

- `quant_engine_rs/Cargo.toml`：Rust 生产依赖。
- `intraday_quant/pyproject.toml`：Python 研究依赖。
- `package.json`：Web/orchestration 依赖。
- `quant_core_cpp/CMakeLists.txt`：C++20/native research。
- `intraday_quant/src/intraday_quant/features/pipeline.py:34`：offline features。
- `docs/handoffs/axio7-model-realtime-review-package-2026-07-25-zh.md`：
  2026-07-25 的完整实时数据与生产技术债快照；其中单一 SPY live-routing
  问题已在 2026-07-26 修复，阅读时必须结合执行计划的 resolution receipt。
- `docs/exec-plans/active/production-quant-inference.md`：执行与证据日志。

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

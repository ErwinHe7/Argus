# AXIO7 模型、算法与源码总表

下面的路径都相对于 Argus 仓库根目录。表中“已实现”表示存在可审查源码，不表示
已经通过生产晋升、校准或实时数据 readiness。

| 模型/算法 | 实际用途 | 当前状态 | 可直接修改的实现 |
|---|---|---|---|
| Diagonal Gaussian HMM | 市场状态识别 | 已实现；9 个 artifact 未晋升 | `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs` |
| Baum–Welch / soft EM | 训练 HMM 参数 | 已实现；有局部最优和初始化风险 | `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs` |
| Scaled Forward–Backward | 计算 α、β、γ、ξ | 已实现 | `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs` |
| Causal Forward Filter | 实时 regime posterior | 已实现；线上唯一允许的 HMM 推理 | `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs` |
| Log-space Viterbi | 最可能状态路径 | 仅离线诊断，不能用于实时特征 | `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs` |
| Same-regime Kernel Regression | 相似历史状态条件分布 | 核心候选，未校准 | `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs`、`axio7-model-review/source/intraday_quant/src/intraday_quant/models/analog_kernel.py` |
| Shrinkage Mahalanobis | 12 维相似度距离 | 已实现 | `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs` |
| Adaptive Gaussian RBF / Nadaraya–Watson | Kernel 权重与条件均值 | 已实现 | `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs` |
| Locally Weighted Linear Regression | Kernel 局部线性对照 | 已实现 | `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs` |
| Markov-switching SDE | 不同 regime 下的短周期收益矩传播 | Shadow-only | `axio7-model-review/source/quant_engine_rs/src/engine/short_horizon.rs` |
| VWAP residual OU | VWAP 偏离的均值回复 | Shadow-only | `axio7-model-review/source/quant_engine_rs/src/engine/short_horizon.rs` |
| Regime-conditioned Momentum | 简单动量对照 | Shadow-only | `axio7-model-review/source/quant_engine_rs/src/engine/short_horizon.rs` |
| Logistic Regression | 方向分类 | 离线/未晋升 | `axio7-model-review/source/intraday_quant/src/intraday_quant/models/walk_forward.py`、`axio7-model-review/source/quant_engine_rs/src/engine/models.rs` |
| Ridge Regression | return、MFE、MAE 回归 | 离线研究 | `axio7-model-review/source/intraday_quant/src/intraday_quant/models/walk_forward.py` |
| HistGradientBoosting | 分类和回归 challenger | 离线研究；不是 LightGBM | `axio7-model-review/source/intraday_quant/src/intraday_quant/models/walk_forward.py` |
| Causal TCN | 多周期神经网络 | PyTorch/CUDA 候选，未上线 | `axio7-model-review/source/intraday_quant/src/intraday_quant/models/causal_tcn.py` |
| Regime-gated TCN MoE | 4-expert 分布预测 | 候选；方向结果不稳定 | `axio7-model-review/source/intraday_quant/src/intraday_quant/models/causal_tcn.py` |
| Student-t Head | 重尾收益分布 | 候选，未晋升 | `axio7-model-review/source/intraday_quant/src/intraday_quant/models/causal_tcn.py` |
| Platt / Isotonic | 概率校准 | 算法已实现；没有线上晋升 artifact | `axio7-model-review/source/intraday_quant/src/intraday_quant/models/calibration.py`、`axio7-model-review/source/quant_engine_rs/src/engine/models.rs` |
| TVTP-HMM | 时变转移概率 HMM 对照 | 仅研究 | `axio7-model-review/source/quant_engine_rs/src/engine/tvtp_regime.rs` |
| Student-t HMM / HSMM | regime 模型比较 | 仅研究 | `axio7-model-review/source/quant_engine_rs/src/engine/regime_competition.rs` |
| Gamma Convexity | 期权 gamma 聚合 | 数据不完整；只能 unsigned/scenario | `axio7-model-review/source/quant_engine_rs/src/engine/gamma_convexity.rs` |
| Closing Short-cover Hazard | 尾盘行为研究 | 仅研究 | `axio7-model-review/source/quant_engine_rs/src/engine/closing_short_cover.rs` |
| Matrix Profile / Motif / FDR | 自动模式发现 | 仅研究 | `axio7-model-review/source/quant_engine_rs/src/motif_discovery/mod.rs`、`axio7-model-review/source/quant_engine_rs/src/pattern_factory.rs` |

## “Baum 什么算法”

这里指 **Baum–Welch**。它是 HMM 的 soft-EM 参数训练算法，不是 Bayesian
算法。当前仓库没有实现 Bayesian/PyMC/Stan、Naive Bayes、LSTM/GRU、
LightGBM、XGBoost 或 CatBoost，不能把这些名字写成现有能力。

## 可运行代码与 artifact

- Rust 生产推理与实时数据边界：
  `axio7-model-review/source/quant_engine_rs/`
- Python 离线研究、训练、验证与导出：
  `axio7-model-review/source/intraday_quant/`
- C++20 native research：
  `axio7-model-review/source/quant_core_cpp/`
- 9 个 exact-symbol 未晋升 artifact、registry、legacy SPY 对照与 candidate
  receipt：
  `axio7-model-review/model-artifacts/axio7-candidate-artifacts-2026-07-26.zip`
  （解压后分别位于 `universe/` 与 `legacy/`）。

artifact 是为了复现当前候选推理，不是生产批准证明。所有 9 个 universe
artifact 都选到了当前搜索边界 `K=8`，而且没有匹配的已晋升校准 artifact。

## 技术栈

| 边界 | 技术 |
|---|---|
| 生产推理 | Rust 1.88、Axum、Tokio、WebSocket、Databento SDK、SQLite、Serde |
| 离线训练 | Python 3.11、NumPy、pandas、scikit-learn、PyArrow、DuckDB、PyTorch/CUDA |
| Native research | C++20、CMake、SQLite、OpenSSL |
| Web/orchestration | Next.js 14、React 18、TypeScript、Zod、Supabase、Redis |
| 历史数据接口 | SQLite、PostgreSQL、Parquet；本仓库不包含历史观测 |
| 实时数据接口 | Massive、Moomoo；Databento live adapter 尚未完整接通 |

历史 replay 与实时流的目标是共同进入 normalized point-in-time record、Rust
causal feature engine 和同一 frozen inference path。不能把几百行历史数据
硬编码或粘贴进模型源码。


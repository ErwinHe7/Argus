# AXIO7 Model, Algorithm, and Source Map

All paths below are relative to the Argus repository root. “Implemented” means that reviewable source code exists; it does not mean the implementation has passed production promotion, calibration, or live-data readiness.

| Model/Algorithm | Actual Use | Current Status | Directly Editable Implementation |
|---|---|---|---|
| Diagonal Gaussian HMM | Market-regime identification | Implemented; 9 artifacts not promoted | `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs` |
| Baum–Welch / soft EM | HMM parameter training | Implemented; subject to local-optimum and initialization risks | `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs` |
| Scaled Forward–Backward | Computes α, β, γ, and ξ | Implemented | `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs` |
| Causal Forward Filter | Realtime regime posterior | Implemented; the only HMM inference permitted online | `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs` |
| Log-space Viterbi | Most likely state path | Offline diagnostics only; must not be used for realtime features | `axio7-model-review/source/quant_engine_rs/src/engine/regime.rs` |
| Same-regime Kernel Regression | Conditional distribution over similar historical states | Core candidate; not calibrated | `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs`, `axio7-model-review/source/intraday_quant/src/intraday_quant/models/analog_kernel.py` |
| Shrinkage Mahalanobis | Similarity distance in 12 dimensions | Implemented | `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs` |
| Adaptive Gaussian RBF / Nadaraya–Watson | Kernel weights and conditional mean | Implemented | `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs` |
| Locally Weighted Linear Regression | Local-linear kernel benchmark | Implemented | `axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs` |
| Markov-switching SDE | Propagation of short-horizon return moments across regimes | Shadow-only | `axio7-model-review/source/quant_engine_rs/src/engine/short_horizon.rs` |
| VWAP residual OU | Mean reversion of VWAP deviation | Shadow-only | `axio7-model-review/source/quant_engine_rs/src/engine/short_horizon.rs` |
| Regime-conditioned Momentum | Simple momentum benchmark | Shadow-only | `axio7-model-review/source/quant_engine_rs/src/engine/short_horizon.rs` |
| Logistic Regression | Direction classification | Offline/not promoted | `axio7-model-review/source/intraday_quant/src/intraday_quant/models/walk_forward.py`, `axio7-model-review/source/quant_engine_rs/src/engine/models.rs` |
| Ridge Regression | Return, MFE, and MAE regression | Offline research | `axio7-model-review/source/intraday_quant/src/intraday_quant/models/walk_forward.py` |
| HistGradientBoosting | Classification and regression challenger | Offline research; not LightGBM | `axio7-model-review/source/intraday_quant/src/intraday_quant/models/walk_forward.py` |
| Causal TCN | Multi-horizon neural network | PyTorch/CUDA candidate; not deployed | `axio7-model-review/source/intraday_quant/src/intraday_quant/models/causal_tcn.py` |
| Regime-gated TCN MoE | 4-expert distributional prediction | Candidate; unstable directional results | `axio7-model-review/source/intraday_quant/src/intraday_quant/models/causal_tcn.py` |
| Student-t Head | Heavy-tailed return distribution | Candidate; not promoted | `axio7-model-review/source/intraday_quant/src/intraday_quant/models/causal_tcn.py` |
| Platt / Isotonic | Probability calibration | Algorithms implemented; no promoted production artifact | `axio7-model-review/source/intraday_quant/src/intraday_quant/models/calibration.py`, `axio7-model-review/source/quant_engine_rs/src/engine/models.rs` |
| TVTP-HMM | Time-varying transition-probability HMM benchmark | Research only | `axio7-model-review/source/quant_engine_rs/src/engine/tvtp_regime.rs` |
| Student-t HMM / HSMM | Regime-model comparison | Research only | `axio7-model-review/source/quant_engine_rs/src/engine/regime_competition.rs` |
| Gamma Convexity | Options gamma aggregation | Incomplete data; unsigned/scenario only | `axio7-model-review/source/quant_engine_rs/src/engine/gamma_convexity.rs` |
| Closing Short-cover Hazard | End-of-day behavior research | Research only | `axio7-model-review/source/quant_engine_rs/src/engine/closing_short_cover.rs` |
| Matrix Profile / Motif / FDR | Automated pattern discovery | Research only | `axio7-model-review/source/quant_engine_rs/src/motif_discovery/mod.rs`, `axio7-model-review/source/quant_engine_rs/src/pattern_factory.rs` |

## “Which Baum Algorithm?”

This refers to **Baum–Welch**, the soft-EM parameter-training algorithm for HMMs, not a Bayesian algorithm. This repository does not implement Bayesian/PyMC/Stan, Naive Bayes, LSTM/GRU, LightGBM, XGBoost, or CatBoost; those names must not be presented as existing capabilities.

## Executable Code and Artifacts

- Rust production inference and realtime-data boundary:
  `axio7-model-review/source/quant_engine_rs/`
- Python offline research, training, validation, and export:
  `axio7-model-review/source/intraday_quant/`
- C++20 native research:
  `axio7-model-review/source/quant_core_cpp/`
- 9 exact-symbol unpromoted artifacts, registry, legacy SPY benchmark, and candidate receipt:
  `axio7-model-review/model-artifacts/axio7-candidate-artifacts-2026-07-26.zip`
  (After extraction, these are located under `universe/` and `legacy/`, respectively.)

The artifacts exist to reproduce the current candidate inference; they are not evidence of production approval. All 9 universe artifacts selected the current search boundary `K=8`, and none has a matching promoted calibration artifact.

## Technology Stack

| Boundary | Technology |
|---|---|
| Production inference | Rust 1.88, Axum, Tokio, WebSocket, Databento SDK, SQLite, Serde |
| Offline training | Python 3.11, NumPy, pandas, scikit-learn, PyArrow, DuckDB, PyTorch/CUDA |
| Native research | C++20, CMake, SQLite, OpenSSL |
| Web/orchestration | Next.js 14, React 18, TypeScript, Zod, Supabase, Redis |
| Historical-data interface | SQLite, PostgreSQL, Parquet; this repository contains no historical observations |
| Realtime-data interface | Massive, Moomoo; the Databento live adapter is not yet fully connected |

Historical replay and realtime streams are both intended to feed the same normalized point-in-time record, Rust causal feature engine, and frozen inference path. Do not hard-code or paste hundreds of lines of historical data into model source code.

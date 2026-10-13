# AXIO7 full model stack / 完整模型栈

> **This repository is not HMM-only.**
>
> AXIO7 currently contains HMM regime inference, 12-dimensional
> same-regime kernel regression, Markov-switching SDE moment propagation,
> VWAP-residual Ornstein–Uhlenbeck modelling, neural challengers, calibration,
> and additional research models.

## Core components

| Visible component name | Purpose | Status | Canonical implementation |
|---|---|---|---|
| **01 — HMM / Baum–Welch / Causal Filter** | Regime inference | Implemented; artifacts not promoted | [`regime.rs`](axio7-model-review/source/quant_engine_rs/src/engine/regime.rs) |
| **02 — 12D High-Dimensional Kernel Regression** | Same-regime analog conditional distribution | Core candidate; uncalibrated | [`analog_engine/mod.rs`](axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs) |
| **03 — Markov-Switching SDE** | Regime-conditioned return moment propagation | Shadow-only | [`short_horizon.rs`](axio7-model-review/source/quant_engine_rs/src/engine/short_horizon.rs) |
| **04 — VWAP Residual Ornstein–Uhlenbeck** | Regime-conditioned VWAP residual mean reversion | Shadow-only | [`short_horizon.rs`](axio7-model-review/source/quant_engine_rs/src/engine/short_horizon.rs) |
| **05 — Causal TCN / Regime-Gated MoE / Student-t** | Neural distribution challengers | Offline candidate | [`causal_tcn.py`](axio7-model-review/source/intraday_quant/src/intraday_quant/models/causal_tcn.py) |
| **06 — Calibration and Classical Challengers** | Platt, isotonic, Logistic, Ridge, HistGradientBoosting | Offline/unpromoted | [`models/`](axio7-model-review/source/intraday_quant/src/intraday_quant/models/) |
| **07 — Research Models and Pattern Discovery** | TVTP-HMM, Student-t HMM, HSMM, gamma, motifs, FDR | Research-only | [`quant_engine_rs/src/`](axio7-model-review/source/quant_engine_rs/src/) |

Open [`MODEL_COMPONENTS/`](MODEL_COMPONENTS/) to see one plainly named directory
per component, with direct links to the real source and review targets.

## Evaluate the models after execution costs

The four statistical components remain research candidates. Forecast quality
and simulated trading profitability are different measurements. Read the
[cost-aware research update](axio7-model-review/review-package/cost-aware-research.md)
for the explicit cost assumptions, causal execution rules, and limitations.

## Frozen artifacts contain the combined stack

The candidate JSON files under
[`data/models/`](axio7-model-review/source/quant_engine_rs/data/models/) are not
HMM-only. Their model version is:

```text
same-regime-kernel+cv-selected-hmm+regime-sde-shadow-frozen-v2
```

Each applicable artifact contains:

- `hmm`;
- `analog_engine` with training indices, center, scale, inverse covariance,
  learned metric weights, and OOD threshold;
- `short_horizon_model` with transition matrix, diffusion states, and
  VWAP-residual OU state slots.

## Why these names are pointers

The clearly named `MODEL_COMPONENTS/` directories are navigation entry points.
The canonical Rust and Python filenames remain unchanged so this handoff does
not break module imports, tests, artifact hashes, or the production inference
path. Reviewers should edit the linked canonical implementations.

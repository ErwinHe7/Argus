# 01 — HMM, Baum–Welch, and causal regime filtering

## What is implemented

- diagonal Gaussian HMM;
- Baum–Welch / soft EM fitting;
- scaled forward–backward;
- causal forward filtering for realtime regime posterior;
- log-space Viterbi for offline diagnostics only;
- state-count selection and regime-model comparisons.

## Canonical code — edit here

- [`engine/regime.rs`](../../axio7-model-review/source/quant_engine_rs/src/engine/regime.rs)
- [`engine/regime_competition.rs`](../../axio7-model-review/source/quant_engine_rs/src/engine/regime_competition.rs)
- [`engine/tvtp_regime.rs`](../../axio7-model-review/source/quant_engine_rs/src/engine/tvtp_regime.rs)

## Status

Implemented, but the nine exact-symbol candidate artifacts are not promoted.
Realtime inference may use only the causal filtered posterior; smoothed
posteriors and Viterbi paths are diagnostic-only.

# 02 — 12D high-dimensional same-regime kernel regression

## What is implemented

- 12-dimensional market-state feature vector;
- shrinkage Mahalanobis distance;
- same-dominant-regime and posterior-overlap filtering;
- adaptive Gaussian RBF / Nadaraya–Watson weights;
- locally weighted linear regression comparison;
- weighted return distribution, MFE, MAE, quantiles, ESS, OOD and no-trade
  gates;
- causal historical-neighbour eligibility and one-neighbour-per-session-day
  control.

## Canonical code — edit here

- **Production Rust:** [`analog_engine/mod.rs`](../../axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs)
- **Offline Python comparison:** [`analog_kernel.py`](../../axio7-model-review/source/intraday_quant/src/intraday_quant/models/analog_kernel.py)

## Frozen artifact field

Every applicable candidate artifact contains `analog_engine`, including
`train_indices`, `center`, `scale`, `inverse_covariance`,
`learned_metric_weights`, `ood_distance_threshold`, and `train_end`.

Artifacts:
[`quant_engine_rs/data/models/universe/`](../../axio7-model-review/source/quant_engine_rs/data/models/universe/)

## Status

Core candidate, currently uncalibrated and not promoted.

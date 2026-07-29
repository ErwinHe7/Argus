# 03 — Markov-switching stochastic differential equation

## What is implemented

- posterior-weighted state transition estimation;
- regime-conditioned drift and diffusion variance;
- effective-sample and variance validity gates;
- multi-step first/second-moment propagation over the Markov transition
  matrix;
- 5, 15, 30, and 60 minute research distributions;
- causal timestamp and filtered-posterior validation.

## Canonical code — edit here

- [`engine/short_horizon.rs`](../../axio7-model-review/source/quant_engine_rs/src/engine/short_horizon.rs)

Key implementation functions include `estimate_diffusion_states`,
`estimate_transition_matrix`, `additive_diffusion_moments`, and
`forecast_standard_horizons`.

## Frozen artifact field

The combined candidate artifact stores this under `short_horizon_model`,
including `transition_matrix`, `diffusion_states`, fit cutoff, and research
policy.

## Status

Shadow-only. It does not control published probabilities, allocation, or
execution.

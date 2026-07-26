# 04 — VWAP residual Ornstein–Uhlenbeck model

## What is implemented

- regime-conditioned weighted AR(1) fitting on VWAP residuals;
- conversion from discrete `phi` to continuous mean-reversion speed `kappa`;
- long-run residual level `theta`;
- innovation and diffusion variance;
- exact multi-step first/second-moment propagation;
- rejection gates for insufficient pairs, degenerate design, and
  non-mean-reverting estimates.

## Canonical code — edit here

- [`engine/short_horizon.rs`](../../axio7-model-review/source/quant_engine_rs/src/engine/short_horizon.rs)

Key implementation functions include `estimate_vwap_residual_ou` and
`vwap_residual_ou_moments`.

## Frozen artifact field

The combined candidate artifact stores OU parameters under
`short_horizon_model.vwap_residual_ou_states`. An artifact may contain the OU
state slots while setting `vwap_residual_ou_enabled=false` when validation
gates reject promotion.

## Status

Shadow-only and restricted to VWAP residuals; raw price is not accepted as the
OU process.

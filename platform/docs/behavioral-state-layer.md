# Behavioral State Layer (Legacy v1 Receipt)

> Superseded on 2026-07-26 by `axio.behavioral-state.v3`,
> `axio.market-emotion-proxy.v1`, and
> `docs/behavioral-sentiment-regime-literature-2026-07-25.md`. The v1 actor
> propensities, dominant actor, static influence weights, and inferred net-flow
> pressure described below were removed because OHLCV does not identify actor
> class, headcount, dealer sign, or capital share. The linked v3 specification
> is canonical; this page remains only as a historical receipt.

Status: research-only partial implementation
Canonical runtime: `quant_engine_rs`
Schema: `axio.behavioral-state.v1`

## Objective

The layer models observable behavior and funding pressure, not a single
collective human emotion:

```text
point-in-time market observations
  -> behavioral latent-state proxies
  -> actor-specific raw propensities
  -> normalized partial flow pressure
  -> future-distribution research
```

It does not claim to read investors' minds, count how many people will buy, or
observe dealer inventory. Actor influence refers to a capital-pressure
scenario, never headcount.

## Implemented contract

`quant_engine_rs/src/engine/behavioral_state.rs` defines:

- six research components: fear, FOMO, herding, attention, forced selling, and
  short covering;
- seven participant classes: retail, active institution, CTA/trend,
  vol-control, dealer, passive flow, and short seller;
- causal observation and availability cutoffs;
- component-level evidence and missing-input lists;
- actor raw propensities, signed pressure, and explicit scenario-weight
  semantics;
- a partial net-flow pressure index;
- coverage, confidence, warnings, and decision-neutral status;
- an explicit analog-integration gate.

The forecast bundle exposes the root `behavioral_state_layer`. Existing forecast
decisions are unchanged.

## Current partial calculation

The first implementation consumes only finalized one-minute features already
present in the Rust market-state engine:

- volatility-scaled 5/15-minute return;
- VWAP distance;
- realized volatility and range expansion;
- volume z-score, relative volume, and volume acceleration;
- cross-asset breadth, risk rotation, and market confirmation;
- close location, wick, streak, return acceleration, and the existing causal
  short-cover proxy;
- the forward-filtered HMM entropy.

Outputs from this subset are labeled
`PARTIAL_PRICE_FLOW_PROXY`, `RAW_PARTIAL_PROPENSITY_NOT_CALIBRATED`, and
`affects_decision=false`. No calibrated actor probability is emitted.

The current static actor weights are versioned research scenarios, not learned
capital shares. They must be replaced or validated using point-in-time flow
data before any production interpretation.

## Required external observations

A full point-in-time behavioral layer still requires:

1. VIX, VVIX, SKEW, and volatility term structure;
2. option NBBO, trades, contract definitions, point-in-time OI, and Greeks;
3. NYSE TICK/TRIN and advance/decline breadth;
4. credit-spread and funding observations;
5. CSAD and a cross-sectional correlation panel;
6. ETF creations/redemptions and closing-imbalance data;
7. point-in-time news/search/attention features;
8. short interest, borrow cost, and securities-lending data.

Every observation must retain `event_at`, `available_at`, `recorded_at`, source,
quality, coverage, and license scope. Missing or non-causal inputs do not receive
zero-filled substitutes.

Dealer direction remains unavailable even when unsigned gamma exposure is
present. Dealer sign may be shown only as named scenarios unless a defensible
positioning assumption is explicitly selected.

## HMM and sentiment separation

The HMM remains the structural regime model. The behavioral layer is a
conditional state within that regime. High fear in positive gamma, negative
gamma, high liquidity, and low liquidity must not be treated as the same
forecast condition.

The present root layer uses normalized filtered-regime entropy only as a
confidence reducer. It does not use smoothed or future state probabilities.

## Analog integration gate

Behavioral features are intentionally not inserted into the existing frozen
analog distance. Doing so would silently change the feature schema and invalidate
the current artifacts.

Integration requires:

1. historical point-in-time materialization of the behavioral features;
2. a new feature-schema and artifact version;
3. train-only normalization and distance-weight selection;
4. purged repeated walk-forward comparison against price/regime-only analogs;
5. negative controls, costs, drift tests, and an untouched test;
6. a 60–90 trading-day settled forward-shadow evaluation;
7. reviewed immutable promotion.

## Validation completed

- non-causal cutoffs are rejected;
- non-finite source features are rejected;
- selloff fixtures increase fear/forced-selling proxies without producing
  calibrated probabilities;
- dealer pressure remains unavailable without dealer-sign evidence;
- legacy payloads deserialize to an unavailable, decision-neutral layer;
- the full Rust test suite passes after integration.

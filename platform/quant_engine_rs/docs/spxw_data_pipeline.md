# SPX/SPXW point-in-time pipeline

AXIO7 is a resident Rust Quant OS. The Rust process owns ingestion, normalization,
features, inference, risk, OMS and the ledger. HTTP and the Next.js application are
control/display surfaces only; neither sits in the market-event decision path.

```text
licensed provider bytes
        |
        v
immutable raw file + SHA-256 manifest
        |
        +--> point-in-time SPXW definitions
        +--> OPRA quote/trade events
        +--> SPX index observations
        |
        v
strict validators and provenance gates
        |
        v
backward-only SPX as-of alignment
        |
        v
internal IV/Greeks with explicit convergence status
        |
        v
causal features -> candidate rules -> calibrated models
        |
        v
next-observable-quote execution (ask in, bid out)
        |
        v
append-only ledger and out-of-sample report
```

## Hard readiness gate

The SPXW backtest remains blocked until all of the following have validated
artifacts and manifests:

1. Point-in-time SPXW definitions.
2. SPXW option quotes with explicit dataset/schema provenance.
3. Consolidated OPRA BBO provenance for any result called NBBO.
4. Nonzero displayed bid and ask sizes.
5. Historical SPX index values.
6. Backward-only as-of alignment within the staleness limit.
7. Entry and exit quote events suitable for the requested execution precision.

IV or Greeks are diagnostics, not fills. A failed solver stores `null` plus a
rejection reason; it must never store zero to mean missing. Long-option fills use
`ask + slippage` on entry and `bid - slippage` on exit. Visible size can produce a
partial fill. No valid quote means no fill.

## Safe bootstrap commands

From `quant_engine_rs`:

```powershell
# No paid API call. Shows only credential presence and discovered artifacts.
cargo run --release --bin quantctl -- data doctor

# No download. With a Databento key this calls account-specific metadata cost,
# record-count and billable-size endpoints and writes an estimate artifact.
cargo run --release --bin quantctl -- data estimate opra `
  --parent SPXW --start 2024-07-01 --end 2026-07-18 `
  --schema definition --dte 0,1 `
  --output data/estimates/opra_definition_2y.json

cargo run --release --bin quantctl -- data estimate opra `
  --parent SPXW --start 2024-07-01 --end 2026-07-18 `
  --schema cbbo-1m --dte 0,1 `
  --output data/estimates/opra_cbbo_1m_2y.json

# Uses complete Massive SPY RTH days only to select diverse QA dates. SPY is
# recorded as UNDERLYING_PROXY_ONLY and never becomes SPX.
cargo run --release --bin quantctl -- data sample-plan

# This intentionally fails until every required artifact validates.
cargo run --release --bin quantctl -- data validate-spxw
```

The five-day downloader requires exactly five explicit dates, an explicit
confirmation flag, and a positive maximum cost. It estimates all requests before
downloading any bytes:

```powershell
cargo run --release --bin quantctl -- data opra-sample `
  --dates 2024-09-04,2025-04-07,2025-04-08,2025-04-09,2025-09-15 `
  --parent SPXW --schemas definition,cbbo-1m `
  --confirm-download --maximum-cost-usd 10
```

Do not run the final command until the estimate is reviewed. The initial
parent-wide estimate is deliberately labeled an upper bound: definitions must be
resolved first to build the actual historical 0/1DTE raw-symbol set.

## Forecasting boundary

The forecasting engine is already implemented as native models: calibrated
logistic regression, gradient-boosted heads, causal Gaussian HMM regimes, and a
past-only day-blocked analog kernel. It predicts direction, net return, MFE and
MAE, while candidate rules limit decisions to a few high-quality opportunities.
Those models can run on Massive SPY proxy bars for engineering validation, but an
SPXW P&L claim is impossible until the readiness gate above passes.

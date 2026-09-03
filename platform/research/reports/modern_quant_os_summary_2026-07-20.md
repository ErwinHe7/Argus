# Axio Quant OS implementation and evidence summary

Date: 2026-07-20

## Runtime decision

- Rust is the production system of record: resident event loop, causal feature engine, inference, risk, OMS, deterministic replay, and sole ledger writer.
- C++ is restricted to Nasdaq QBBO decoding, parity tests, and future profiling-proven hot paths. The laboratory `axiod` executable is not the production daemon.
- Perl is optional end-of-day reconciliation. It cannot submit orders or write trading state.
- Next.js and the CLI are query/control surfaces only.

## Implemented in this increment

- Corrected session VWAP to use cumulative point-in-time price-volume data instead of Massive's one-minute aggregate `vw`.
- Replaced the naive analog search with robust median/MAD scaling, adaptive kernel bandwidth, one observation per historical day, effective sample size, day concentration, and uncertainty penalties.
- Added a causal diagonal-Gaussian HMM with scaled forward-backward, Baum-Welch estimation, deterministic restarts, BIC, filtered state probabilities, and frozen-parameter forward likelihood.
- Added whole-session expanding walk-forward folds with explicit purged and embargoed days.
- Added a Rust append-only SQLite double-entry ledger with content hashes, idempotent source IDs, balanced transactions, correction references, and database triggers that reject updates/deletes.
- Added `quantctl research regime-fit` and `quantctl ledger` operations.

## Data evidence

- Source: Massive U.S. stock one-minute aggregates.
- Target: SPY as a tradable SPX direction proxy.
- Coverage: 2024-07-18 through 2026-07-17.
- Normalized file: 1,521,361 rows across SPY, QQQ, IWM, and frozen legacy SOXX context.
- No bid/ask exists in this file. It is not Nasdaq QBBO, consolidated NBBO, OPRA, SPX, or SPXW data.
- This interval was inspected by earlier experiments and is now classified as `contaminated_exploratory_vendor_underlying_point_in_time`.

## Current underlying replay

- Candidate states: 4,940.
- Selected trades: 2.
- Rejections: 4,147 below validation threshold; 697 insufficient past analogs; 94 insufficient effective analogs.
- Observed wins: 2 of 2.
- Net arithmetic return across those two underlying-proxy trades: 0.4196%.
- Mean net return per trade: 0.2096%.

Two trades are not enough to estimate a win rate, Sharpe ratio, or deployable edge. These values are pipeline diagnostics, not evidence of profitability. No SPXW option backtest was executed.

## HMM model-selection diagnostic

All models used 501 sessions and 38,898 finalized five-minute observations. The forward split froze parameters after training and isolated full sessions:

- Train: 2024-07-18 through 2025-07-17.
- Purged: 2025-07-18.
- Validation: 2025-07-21 through 2025-12-09.
- Embargoed: 2025-12-10.
- Test: 2025-12-11 through 2026-05-06.

| States | Full-history BIC | Validation avg log likelihood | Test avg log likelihood |
|---:|---:|---:|---:|
| 3 | 312582.5 | -3.002431 | -3.480101 |
| 4 | 293893.3 | -2.817382 | -3.266601 |
| 5 | 281705.2 | -2.596697 | -3.100142 |
| 6 | 268751.9 | -2.457903 | -2.909677 |
| 7 | 258773.9 | -2.338790 | -2.795445 |
| 8 | 250543.3 | -2.184833 | -2.693142 |

Validation likelihood still improves at the configured eight-state ceiling, so the search has not found a defensible complexity optimum. Eight states remains a research candidate, not a promoted regime model. The test column was reported after validation comparison and must not be used to tune another round on this same history.

## Verification

- Rust: 17 tests passed; strict Clippy with warnings denied passed.
- C++: strict build passed; CTest 1/1 passed (11 internal assertions).
- Perl: 7/7 ledger reconciliation tests passed.
- Next.js: optimized production build completed; existing unrelated lint warnings remain.
- SQLite ledger check: zero unbalanced transactions.

## Missing evidence before paper promotion

1. A new untouched future interval or separately licensed uninspected history.
2. Licensed Nasdaq capture if Nasdaq BBO behavior is part of the hypothesis. Nasdaq exchange BBO must never be described as consolidated NBBO.
3. Real SPX/SPXW OPRA NBBO with quote timestamps, sizes, contract definitions, and point-in-time underlying joins for 0DTE/1DTE execution research.
4. Validation-selected thresholds with block-bootstrap lower confidence bounds above costs, stability across regimes/months, and no dependence on a few episodes.
5. Paper-trading burn-in through the Rust risk/OMS/ledger path before any broker can be enabled.

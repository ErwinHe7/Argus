# AXIO7 market-data source matrix

This document is an admission-control contract. A provider name or a file name is
not evidence that a dataset is suitable for executable SPXW research. Every raw
artifact must retain its provider, dataset, schema, scope, timestamp semantics,
license note, byte count, and SHA-256 manifest.

| Source | Intended responsibility | Permitted use | Explicitly prohibited use |
|---|---|---|---|
| Databento `OPRA.PILLAR` definitions | Point-in-time SPXW instrument identity and definition revisions | Resolve raw symbols, strikes, expiry, multiplier and tick size known at each quote time | Guessing settlement style or treating a later definition revision as historically known |
| Databento `OPRA.PILLAR` `CMBP-1` | Historical consolidated BBO event stream with sizes | Execution-grade entry/exit simulation after validation; publisher 30 must be retained as consolidated OPRA provenance | Relabeling a venue BBO as NBBO or collapsing nanosecond events to an exact minute fill |
| Databento `OPRA.PILLAR` `CBBO-1m` | Minute-sampled consolidated BBO | Five-day coverage/quality prototype and coarse research | Claiming the sample is the exact quote observable at an arbitrary signal timestamp |
| Cboe licensed index/option files | SPX index values, licensed quote intervals, optional vendor calculations | Backward-only SPX as-of alignment and independent cross-checking | Mixing vendor Greeks with internal analytics without provenance |
| Massive stock aggregates | SPY/QQQ/IWM and other ETF context | Underlying proxy model development, RTH date selection and cross-asset features | Representing SPY as SPX, or using equity volume as SPX index volume |
| Nasdaq QBBO | One Nasdaq venue's quote stream | Decoder/parity experiments and single-venue diagnostics | Calling it consolidated OPRA NBBO |
| IBKR | Forward paper/live execution and reconciliation | Archive new quotes from the connection start, route paper orders, reconcile fills | Reconstructing expired SPXW historical NBBO |

## Timestamp contract

- Raw event and receive timestamps remain integer nanoseconds.
- `CMBP-1` is event precision; `CBBO-1m` is an interval sample.
- A signal produced after minute `t` may only use an entry quote strictly after
  the signal timestamp.
- SPX alignment is a backward as-of join. The selected index event must satisfy
  `index.ts_event <= option_quote.ts_event` and the configured staleness limit.
- DTE is counted using actual exchange sessions, not `expiration_date - date`.

## Current machine state

Run `quantctl data doctor` for the authoritative current state. On 2026-07-20,
Massive underlying files are present but no validated OPRA definitions, OPRA
quotes, Cboe SPX index series, or executable quote events are present. Therefore
the only correct options status is `SPXW_BACKTEST_BLOCKED`.

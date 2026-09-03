# AXIO7 Intraday Quant Architecture (superseded Python prototype)

> Production runtime moved to Rust/Axum and immutable DBN. See [intraday-quant-rust-architecture.md](intraday-quant-rust-architecture.md). The details below document the retained Python reference implementation and are not started by `npm run quant:dev`.

The system is shipped as six independently testable blocks. This is the practical Agile boundary: each block has a concrete artifact and acceptance check, while the full vertical slice remains runnable after every increment.

| Block | Responsibility | Runtime artifact | Acceptance check |
|---|---|---|---|
| 01 · Data | adapters, ET normalization, session calendar, quality rules | cleaned Parquet + DuckDB bars view | timezone, dedupe, invalid rows, no backward fill |
| 02 · Research | point-in-time features, setup candidates, labels | features/candidates/labels Parquet | t-only features, t+1 labels, same-minute RVOL |
| 03 · Models | logistic, analog kernel, gradient boosting, calibration | fold models + predictions | purged walk-forward, train-only scaling, validation calibration |
| 04 · Portfolio | cost-aware score, validation threshold, abstention constraints | selected + rejected ledgers | ≤ configured daily cap; every rejection has a reason |
| 05 · Execution | underlying bar-by-bar and real-NBBO option simulator | trade blotters | next-minute entry, adverse fills, stale/wide quote rejection |
| 06 · Product | FastAPI, DuckDB run registry, Next.js gateway/dashboard | API + `/quant/intraday` | API tests, TypeScript check, browser smoke test |

## Runtime topology

```text
Next.js dashboard
  /quant/intraday
        |
        v
Next.js server-only gateway
  /api/quant/intraday/*
        |
        v
FastAPI research service :8001
  run queue + model contract + artifacts
        |
        +--> deterministic Python pipeline
        |
        +--> state/research.duckdb
               research_runs
               candidate_decisions
               trades
               analog_cases
               model_diagnostics
               research_audits
```

The browser never receives a filesystem path to execute and cannot choose an arbitrary config file. It can start only allow-listed profiles. `INTRADAY_QUANT_TOKEN` is mandatory for every quant control-plane route except `/health`; it is held by the Next.js server and backend service and is never exposed to client JavaScript. The Next gateway also requires an authenticated administrator for reads and writes.

## Production data boundary

The included Yahoo profile is a short unofficial price-only hypothesis check. Production deployment requires licensed multi-year SPX/ES/SPY/cross-asset minute data and historical option NBBO with point-in-time Greeks, quote sizes, and open interest known at the open. The application deliberately keeps the option result empty until those fields exist.

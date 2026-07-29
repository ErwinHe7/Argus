# AXIO7 Rust Intraday Quant Engine

This is the non-Python backend for SPX intraday research. It separates licensed data acquisition, immutable raw storage, point-in-time research, event-ordered execution, and product APIs. It will not manufacture a historical source or label synthetic results as performance.

## Blocks and acceptance gates

| Block | Runtime responsibility | Current artifact | Gate |
|---|---|---|---|
| 00 Data contracts | provider, entitlement, cost and field contracts | `configs/production.yaml` | API key plus vendor cost estimate before any paid download |
| 01 Raw ingest | Databento Historical API, DBN.ZST and SHA-256 manifest | `src/data/databento.rs` | immutable file; no overwrite; manifest is non-synthetic |
| 02 Normalize | Rust DBN decoders and strict licensed CSV import | `src/data/dbn_decode.rs`, `csv_import.rs` | explicit UTC offset, dedupe, invalid quote/bar rejection |
| 03 Research | minute state, setups, labels, past-only kernel analog | `src/engine/*` | no observation or completed label from the future |
| 04 Validation | expanding folds, purge, embargo, abstention | `walk_forward.rs`, `backtest.rs` | no random split; at most 0–3 trades/day |
| 05 Execution | next-observable-minute underlying fills and option NBBO fills | `execution.rs` | long options buy ask+slippage and sell bid-slippage |
| 06 Product | Axum API, SQLite WAL run registry, Next server gateway | `api.rs`, existing `/quant/intraday` | no Python service and no HTTP call in the market-event hot path |

## Runtime boundary

Rust is the production system of record: resident event loop, deterministic replay, features, inference, risk, OMS, and the sole SQLite ledger writer. C++ is limited to the Nasdaq QBBO decoder, parity testing, and future profiling-proven hot paths. Perl is an optional end-of-day reconciliation client. Copying a famous fund's language choices does not reproduce its data or research discipline; the boundary is based on measured latency and operational risk. HTTP is only the control plane, so a signal never calls FastAPI, Axum, or Next.js to compute a risk decision.

## Data topology

```text
Databento Historical HTTP / Live Raw TCP
  GLBX.MDP3  -> ES minute/tick data
  EQUS.MINI  -> SPY/QQQ/IWM minute/L1 context
  OPRA.PILLAR -> SPX/SPXW option CBBO/NBBO
                 |
                 v
immutable DBN.ZST + SHA-256 JSON manifest
                 |
          Rust DBN normalization
                 |
      point-in-time research engine
                 |
SQLite WAL run metadata + JSON report -> Axum -> Next.js

Cboe DataShop / CGIF licensed files
  SPX index values, option quote intervals and optional calculations
                 |
          strict licensed CSV importer

IBKR paper/live
  execution and post-trade reconciliation only; never the historical source of truth
```

## Historical bootstrap and licensed real-time path (Massive)

The historical research phase uses SPY as the tradable SPX direction proxy and
Massive's adjusted one-minute stock aggregates. The production live adapter is
separate: it authenticates the real-time stock WebSocket, archives complete
`T/Q/A/AM` events, consumes only finalized `AM` bars, and downloads every page
of configured OPRA chain snapshots. Basic/delayed access is never relabeled as
real-time.

```powershell
$env:MASSIVE_API_KEY = "..."
cargo run --release --bin quantctl -- data massive-status
cargo run --release --bin quantctl -- data massive-sync `
  --from 2024-07-01 --to 2026-07-18 `
  --symbols SPY,QQQ,IWM,TLT,HYG,UUP,GLD
cargo run --release --bin quantctl -- research backtest --bars data/normalized/market_bars.csv

# Or run the complete real-data path in one command:
cargo run --release --bin quantctl -- research massive-run `
  --from 2024-07-01 --to 2026-07-18 `
  --symbols SPY,QQQ,IWM,TLT,HYG,UUP,GLD

# Schedule this command for incremental updates. Provider recency still depends on plan.
cargo run --release --bin quantctl -- data massive-poll --lookback-days 3

# Production entitlement/readiness contract (fails non-zero if not licensed):
cargo run --release --bin quantctl -- live massive-check

# Independently gate the equities and options workers:
cargo run --release --bin quantctl -- live massive-check --scope equity
cargo run --release --bin quantctl -- live massive-check --scope options

# Authenticated stock tape + incremental frozen inference:
cargo run --release --bin quantctl -- live massive-model

# Continuously refresh complete configured OPRA chains:
cargo run --release --bin quantctl -- live massive-options-watch
```

At five calls per minute, a complete two-year, seven-symbol bootstrap is expected
to take about an hour. Cached raw chunks are reused, so interrupted runs resume
without paying the request delay again.

The model receives active point-in-time 5m information separately from the last
fully completed 5m/15m bars. A 10:07 state cannot see the eventual 10:05-10:10
close. The report's `time_bucket_effects` section audits every completed five-minute
bucket using chronological 60/20/20 train/validation/test dates and applies
Benjamini-Hochberg false-discovery control before flagging an effect.

## Slow context feeds (Alva and similar aggregators)

Alva macro/index snapshots and daily technical metrics are not used as execution
prices. `src/data/context.rs` normalizes them behind an explicit
`event_time`/`available_time` contract and blocks model eligibility when a field
has no point-in-time history or its upstream vendor is undisclosed. The current
production configuration leaves this feed disabled. Databento is the selected
equities live provider; Massive SIP and OPRA capabilities remain separate,
explicitly invoked research adapters and are never started merely because a
Massive key is present.

```powershell
cargo run --release --bin quantctl -- data context-audit `
  --input data/context/alva_observations.jsonl `
  --cutoff 2026-07-21T13:30:00Z
```

See `../docs/alva-context-data.md` for the normalized schema and promotion rules.

Raw DBN is the local market-data database of record. SQLite stores only small control-plane metadata. For multi-user analytical queries, mirror normalized event partitions into ClickHouse or QuestDB and run Postgres for portfolio/configuration state; neither database belongs inside the single-event calculation loop.

## Deployment safety

`quantd` is intentionally loopback-only until an authenticated TLS/mTLS
gateway is implemented. The supported production target is
`infra/single-vm/compose.yaml`, where Next.js shares the Rust service network
namespace and Caddy exposes only Next.js. Direct Railway deployment is
fail-closed by the container entrypoint; setting the host to `0.0.0.0` is not
a workaround. The single-VM target fixes the quant service at one replica and
mounts persistent `quant-state` and `quant-live` volumes. The liveness endpoint
does not claim that live data or a model is promotion-ready. Massive SIP and
OPRA readiness are serialized separately and supervise separate children, so
an entitlement failure in one product cannot disable the other product.

## Required historical fields

Underlying/cross-asset bars require: `timestamp` with UTC offset, `symbol`, `open`, `high`, `low`, `close`, `volume`, optional `vwap`, `bid`, `ask`, `trade_count`, `source`, and `data_quality`. SPX itself does not have equity-style centralized volume, so SPY/ES volume is required for volume features.

Option execution requires: `timestamp`, `underlying`, OSI `option_symbol`, `expiry`, `dte`, `strike`, `call_put`, NBBO `bid`, `ask`, `bid_size`, `ask_size`, `last`, `volume`, opening-known `open_interest`, `iv`, `delta`, `gamma`, `theta`, `vega`, `underlying_price`, and `source`. OPRA CBBO supplies executable quotes; instrument definitions and a point-in-time underlying join supply contract metadata. IV/Greeks may be computed as diagnostics or purchased from Cboe, but theoretical marks are never reported as fills.

## Commands

From this directory:

```powershell
$env:DATABENTO_API_KEY = "db-..." # process env or .env.local; never commit it
cargo run --release --bin quantctl -- data doctor
cargo run --release --bin quantctl -- data capability
cargo run --release --bin quantctl -- data sample-plan
cargo run --release --bin quantctl -- data estimate opra --parent SPXW --start 2024-07-01 --end 2026-07-18 --schema definition --dte 0,1
cargo run --release --bin quantctl -- data estimate opra --parent SPXW --start 2024-07-01 --end 2026-07-18 --schema cbbo-1m --dte 0,1
cargo run --release --bin quantctl -- data validate-spxw

$env:DATABENTO_API_KEY = "db-..."
cargo run --release --bin quantctl -- data plan
cargo run --release --bin quantctl -- data cost --request es_ohlcv_1m
cargo run --release --bin quantctl -- data download --request es_ohlcv_1m --confirm-cost --maximum-cost-usd 25
cargo run --release --bin quantctl -- data decode-ohlcv --input data/raw/GLBX.MDP3/ohlcv-1m/<file>.dbn.zst --output data/normalized/es.csv --symbol-alias ES
cargo run --release --bin quantctl -- data validate-bars --input data/normalized/market_bars.csv
cargo run --release --bin quantctl -- research backtest --bars data/normalized/market_bars.csv
cargo run --release --bin quantctl -- research regime-fit --bars data/normalized/market_bars.csv --state-candidates 2,3,4,5,6,7,8,9,10
cargo run --release --bin quantctl -- predictor train
cargo run --release --bin quantctl -- predictor walk-forward
cargo run --release --bin quantctl -- predictor regime-competition
cargo run --release --bin quantctl -- predictor calibrate --input <oof.csv> --fit-start <RFC3339> --fit-end <RFC3339> --oos-start <RFC3339> --oos-end <RFC3339>
cargo run --release --bin quantctl -- research negative-controls --horizon 30
cargo run --release --bin quantctl -- predictor forecast --record-shadow
cargo run --release --bin quantctl -- predictor shadow-status
cargo run --release --bin quantctl -- ledger --database ../ledger/quant_ledger.sqlite3
cargo run --release --bin quantd -- --config configs/production.yaml
```

From the repository root, `npm run quant:dev` builds the release binary when needed and starts Rust plus the Next dashboard. `npm run quant:test` runs the Rust suite.

## Data that is not currently present

The repository contains adapters and tests, not a paid archive. A full production backtest remains blocked until a Databento account/API key and the appropriate market-data entitlements or purchased Cboe files are supplied. A broker connection cannot reconstruct expired option NBBO history; IBKR explicitly limits historical option availability and should be treated as an execution venue.

See [`docs/data_source_matrix.md`](docs/data_source_matrix.md) and
[`docs/spxw_data_pipeline.md`](docs/spxw_data_pipeline.md) for the source truth
matrix, hard readiness gate, timestamp semantics, and cost-capped sample workflow.

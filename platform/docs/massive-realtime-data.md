# Massive real-time SIP and OPRA data contract

## Production boundary

`quant_engine_rs` is the sole production market-state, feature, inference,
calibration, lineage, and forecast-contract implementation. The Next.js layer
only renders Rust API payloads. The production data profile does not start or
require Moomoo OpenD.

The configured provider is Massive:

- stocks: `wss://socket.massive.com/stocks`
- option-chain snapshots: `/v3/snapshot/options/{underlying}`
- credentials: server-only `MASSIVE_API_KEY`

The account must have both real-time consolidated SIP stock WebSocket access
and real-time OPRA option access. A successful TCP/TLS connection alone is not
readiness.

## Stock stream

For every configured symbol the Rust adapter subscribes to:

- `T`: individual SIP trades
- `Q`: SIP NBBO changes
- `A`: per-second qualifying-trade aggregates
- `AM`: per-minute qualifying-trade aggregates

Every authenticated market event is written to the rotating
`data/live/massive_stock_tape.jsonl` archive with provider timestamp, process
receive timestamp, event type, sequence where supplied, normalized fields,
complete raw provider payload, SHA-256, entitlement, stale/future flags, and
model eligibility. Authentication messages and API keys are never persisted.

Only a completed, grace-period-finalized, non-delayed, non-stale `AM` bar can
enter the current 5/15/30/60-minute model. Quotes, trades, and per-second bars
are preserved for replay and separately validated microstructure challengers;
they are not silently added to an already frozen feature schema.

## Full option chain

For each configured underlying the watcher follows `next_url` until pagination
is complete. It retains every parsed contract and reports:

- total received and parsed contracts
- identity parse failures
- pagination completion and truncation
- NBBO, fresh-NBBO, daily-open-interest, IV/Greeks, and underlying-price coverage
- strict model-eligible contract count
- earliest/latest quote times
- capture, OI-availability, and Greeks-availability times
- complete-contract-vector SHA-256
- explicit blockers

Daily open interest is labeled as daily OI available at capture time; it is not
misrepresented as intraday OI. The raw chain may be complete while only the
fresh, fully populated subset is model eligible. The configured coverage gates
must pass before any option input reaches Rust inference.

## Commands

```powershell
cd quant_engine_rs
cargo run --release --bin quantctl -- live massive-check
cargo run --release --bin quantctl -- live massive-check --scope equity
cargo run --release --bin quantctl -- live massive-check --scope options
cargo run --release --bin quantctl -- live massive-model
cargo run --release --bin quantctl -- live massive-options-watch
```

`massive-check` writes the versioned `data/live/massive_readiness.json` receipt.
Its default `all` scope exits non-zero if either SIP equities or configured
OPRA chains fail. The `equity` and `options` scopes are independent: missing
OPRA entitlement cannot suppress an entitled stock stream/model worker, and a
SIP failure cannot suppress an entitled options watcher. Each scope still
fails closed on missing credentials, delayed endpoints, HTTP 403, incomplete
configured coverage, or missing entitlement.

## Model gates

The intraday path never fits a model. It performs:

1. authenticated event ingest;
2. bounded current-session incremental feature update;
3. exact synchronized-context check;
4. immutable artifact/hash/schema validation;
5. frozen inference;
6. horizon-specific promoted-OOS calibration check;
7. five-second end-to-end SLA check;
8. append-only forward-shadow persistence.

Any failure produces `NO_FORECAST` and leaves market-data capture running.
Candidate calibration and regime-family competition artifacts cannot promote
the live model automatically.

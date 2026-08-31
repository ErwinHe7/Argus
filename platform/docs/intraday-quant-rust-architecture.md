# AXIO7 SPX Research: Rust Architecture Decision

## Decision

The production path is Rust, not Python: official vendor clients feed DBN into an in-process event engine. Axum is a control/read API, not the calculation path. The existing Python implementation remains a reference implementation during migration and is not started by `npm run quant:dev`.

## Latency budget

The per-event path is `decode -> state update -> candidate rule -> model heads -> score -> risk -> order intent`. It contains no HTTP, database round trip, DataFrame construction, JSON serialization, or global lock. Network API latency therefore does not determine signal latency. The dashboard reads completed snapshots independently.

## Storage boundaries

- DBN.ZST is immutable source-of-truth with one JSON manifest per acquisition.
- SQLite WAL stores run state and compact report JSON locally.
- ClickHouse/QuestDB is the scale-out analytical target for normalized events.
- Postgres is the target for accounts, configurations, orders, and reconciliation.
- Redis is optional for read-through snapshots; Kafka/Redpanda is optional for multi-process fan-out, not required in the single-process hot path.

## Data coverage truth

The engine exposes `/api/v1/data/plan` and `/api/v1/data/coverage`. With no API key/manifests it reports that licensed history is absent. It does not fall back to Yahoo or generated prices. Databento downloads require a server-side key, a vendor cost estimate, explicit confirmation, and a maximum dollar cap.

## Tail-cover analog

The closing short-cover setup is measured from information available at the current minute: positive 5/15-minute ramp, VWAP/session position, volume shock and acceleration, same-minute historical RVOL, and cross-asset breadth. Historical neighbors are standardized only on eligible history. A neighbor is excluded until its entire forward label horizon ended before the current signal. This prevents the 7/2-type pattern from being selected using any part of its future response.

The output is a distribution, not a prophecy: expected and median return, weighted win probability, MFE, MAE, uncertainty, similarity, and the timestamp of every neighbor. A high score can still lose. Position limits and abstention are hard constraints.

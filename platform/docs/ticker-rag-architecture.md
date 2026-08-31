# AXIO7 ticker RAG architecture

## Decision

AXIO7 uses structured retrieval-augmented generation for ticker questions. The
retrieval layer is exact and point-in-time: it resolves each requested ticker,
loads only that instrument's eligible database observations and model evidence,
and returns one independently auditable result per requested ticker. An LLM may
explain the retrieved evidence but may not calculate or alter market numbers.

Price, volume, features, forecasts, freshness, and coverage are retrieved with
SQL or the Rust market-data API. Vector retrieval is reserved for unstructured
filings, licensed news, transcripts, and research documents. A vector match is
never a substitute for the exact-symbol market-data lookup.

## Request path

```text
User question
  -> constrained ticker extraction (preserve order and every explicit ticker)
  -> point-in-time instrument/alias resolution
  -> Rust ticker-RAG endpoint (fan out by canonical instrument)
  -> exact-symbol database retrieval and evidence validation
  -> one result/status per requested ticker
  -> grounded explanation and comparable per-ticker UI cards
```

The cardinality contract is `N requested -> N returned`. Partial failure is a
normal response condition. One ticker's missing data cannot suppress another
ticker and one ticker's observation can never be copied to another result.

## Storage architecture

| Store | Purpose | Authority |
| --- | --- | --- |
| PostgreSQL `instrument_master` | Point-in-time security identity, listing, currency, asset class | Reference-data system of record |
| PostgreSQL `instrument_aliases` | Ticker, company name, former ticker, vendor symbol and proxy resolution | Point-in-time alias registry |
| PostgreSQL minute-bar archive | Durable historical and realtime finalized observations | Recovery, replay, audit and offline assembly |
| Rust append-only SQLite live store | Low-latency finalized-bar retrieval on the current single-VM runtime | Current online observation read path |
| Immutable object storage | Raw vendor files, manifests, feature snapshots and model artifacts | Long-term lineage and rebuild |
| Optional text/vector index | Filings, licensed news, transcripts and research documents | Supplemental narrative context only |

The current Rust endpoint reads the append-only live SQLite database whose
validated rows are continuously archived to PostgreSQL. The response names this
storage contract explicitly. A later online PostgreSQL reader may replace the
SQLite read path only after replay parity, latency, freshness, entitlement, and
rollback tests pass.

## Retrieval contract

`GET /api/v1/research/ticker-rag?symbols=GOOG,AMZN,MU,SNDK`

The response schema is `axio.ticker-rag.v1` and contains, in request order:

- `requested_symbol`, `canonical_symbol`, and `data_symbol`;
- `RETRIEVED`, `NO_STORED_OBSERVATIONS`, `INSUFFICIENT_DATA`, or
  `RETRIEVAL_FAILED`;
- a reason code and recovery explanation for every non-retrieved result;
- a symbol-matched observed-session evidence bundle when retrieval succeeds;
- provider, dataset, observation time, availability time, coverage, entitlement,
  and caveats;
- `probability_published=false` and `automatic_execution_enabled=false`.

`SPX -> SPY` is the only current explicit price/volume proxy in this contract.
Directly listed equities use their own ticker. Proxy identity must be present in
the structured result and cannot be introduced by prose templates.

## Reference-data ingestion

Supporting every listed ticker is a data-coverage program, not a prompt change.
The production ingestion job must load a licensed security-master/reference
catalog into immutable point-in-time `instrument_master` and
`instrument_aliases` records, record a content-hashed ingestion receipt, and
then subscribe or backfill the market datasets that the product is entitled to
use. Corporate actions, symbol changes, delistings, share classes, and listing
venue changes create new effective-dated records; they do not rewrite history.

Until the reference record and eligible observations exist, the customer sees a
truthful reason-coded result. AXIO7 does not silently fall back to Yahoo,
synthetic data, another ticker, or today's symbol mapping for an historical
cutoff.

## Grounded generation policy

The generator receives only validated per-ticker evidence bundles plus approved
unstructured citations. Every number in prose must copy a structured field.
Generation failure falls back to deterministic rendering of the same evidence;
it never changes result cardinality or numerical content.

## Release gates

1. Query tests prove that `goog amzn mu sndk` compiles to four ordered symbols.
2. Rust tests prove four requested symbols produce four independent statuses.
3. Contract validation rejects reordered, duplicated, cross-symbol, stale, or
   malformed evidence.
4. UI tests prove every result/status is visible and proxy copy is symbol-aware.
5. Database tests prove point-in-time alias resolution and append-only reference
   receipts.
6. Production activation requires a licensed reference catalog, archive/replay
   receipt, freshness monitoring, and a verified live-data readiness receipt.

Automatic order execution remains disabled.

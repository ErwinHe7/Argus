# AXIO7

Market strategy agents for public and licensed market-moving sources.

## Product

AXIO7 is a reproducible market-research copilot. A new user question is compiled
into `axio.market-query.v2`, executed by the native Rust engine, and returned as
an `axio.evidence-envelope.v1` containing candidates, counter-evidence,
historical statistics, data freshness, lineage, and audit hashes. The LLM/UI
does not calculate probabilities, Greeks, gamma exposure, or expected return.
Stored v1 explicit-rule monitors remain readable during migration; v1 cannot
request the v2 model-forecast intent.

## Stack

- **Next.js 14** App Router, TypeScript, Tailwind
- **Supabase** for Postgres, Auth, Realtime, and Storage
- **TokenRouter** for the multi-agent LLM layer
- **Market adapters** for Reuters/LSEG, X API, Truth provider webhooks, Finnhub, NewsAPI, SEC EDGAR, and options-flow vendors

## Key Routes

- `/market` - strategy console
- `/api/strategy/run` - strategy-agent API
- `/api/cron/market-strategy` - scheduled signal runner

## Setup

```bash
npm install
cp .env.example .env.local
npm run dev
```

Fill source credentials in `.env.local` before expecting production feeds.

## Native Quant OS

The intraday research/execution backend lives in `quant_engine_rs/`. Rust owns the resident state machine, causal features, models, risk, paper OMS, deterministic replay, and append-only double-entry ledger. `quant_core_cpp/` is a bounded Nasdaq QBBO/performance-parity module, not a replacement backend; `perl/` is optional EOD reconciliation. Next.js is only a query/control surface.

See `docs/quant_os_architecture.md`, `docs/forecast-contract-and-evidence.md`,
`docs/market-memory-research-factory.md`,
`docs/autonomous-pattern-mining.md`,
`docs/simons-public-quant-system.md`, `docs/alva-context-data.md`, and
`quant_engine_rs/README.md` for data entitlements, the sixteen-block Market
Memory contract, the public Simons-inspired model/risk blocks, commands,
promotion gates, and current evidence limitations.
The latest measured sixteen-block result is
`reports/market-memory-acceptance-2026-07-21.md`; unavailable artifacts remain
explicitly unavailable rather than being inferred from code.
The Simons-inspired data/model/risk acceptance is recorded in
`reports/simons-quant-system-acceptance-2026-07-21.md`.

Local native verification on Windows uses the installed Rust and MSYS2 UCRT64
toolchains:

```powershell
npm run quant:test
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-native-quant.ps1
```

The native script locates `C:\msys64` itself, builds with warnings as errors,
and runs CTest; the C++ tools do not need to be added to the global PowerShell
`PATH`.


### Run the local Quant OS

Run the Rust service and read-only Next.js console with the provider selected
by `quant_engine_rs/configs/production.yaml`:

```powershell
npm run quant:dev
```

The canonical production configuration owns its Databento equities supervisor
inside `quantd`; missing entitlement remains visible through `/ready` without
disabling historical research. Open
`http://127.0.0.1:3000/quant/intraday`. Stop all managed processes with
`npm run quant:stop`. Delayed, stale, unauthorized, truncated, or
field-incomplete data fails closed. This command never starts a broker or
routes orders.

Feed authentication and customer-facing usage rights are separate gates. An
authorized operator must install and pin the private receipt described in
`docs/market-data-rights-receipt.md`; legacy provider/reference environment
strings cannot make public forecast publication ready.

Massive SIP and OPRA are explicit optional adapters. To start them locally,
set an entitled `MASSIVE_API_KEY` and invoke:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start-intraday-quant.ps1 -StartMassiveWorkers
```

Their equity and options readiness gates are independent, so one missing
entitlement cannot suppress the other worker.
See `docs/massive-realtime-data.md` for the feed, entitlement, completeness,
and model-input contracts.

Refresh the staged Massive history, capability receipt, candidate model,
forecast contract, and regime artifact with validated staging, per-file atomic
replacement, rollback, and a last-written commit receipt:

```powershell
npm run quant:data:refresh
```

The public chat uses:

```text
POST /api/ask
POST /api/quant/research
```

The Next.js server attaches `INTRADAY_QUANT_TOKEN` and calls the private Rust
service configured by `INTRADAY_QUANT_API_URL`. A request that requires an
absent, stale, delayed, incomplete, or unentitled feed returns
`DATA_UNAVAILABLE`; OPRA is required only for option/gamma inputs. There is no
Yahoo or TypeScript forecast fallback.

For a container deployment, use the audited single-VM bundle:

```powershell
cd infra/single-vm
$env:GIT_COMMIT = (git -C ../.. rev-parse HEAD).Trim()
docker compose --env-file .env.server config --quiet
docker compose --env-file .env.server build --pull
docker compose --env-file .env.server up -d --no-build --pull never
```

Use the full [single-VM release, backup, acceptance, and rollback runbook](infra/single-vm/README.md).
It preserves the existing market-data volumes, mounts private rights/promotion/
calibration artifacts read-only, keeps the signed owner attestation host-only
while hash-binding it into acceptance, and refuses a build whose source commit
is not explicitly bound.

The Rust control plane remains loopback-only inside the shared network
namespace; Caddy exposes only Next.js. Direct Railway/public binding is
intentionally rejected until an authenticated TLS/mTLS gateway exists. The
container starts the API first, then starts each explicitly enabled live worker
only after that worker's own entitlement check passes. The optional owner
gateway is quote-only at the application boundary; all live/automatic
execution gates remain false and this deployment authorizes no live orders.

The refresh pipeline does not call a broker or create an order.

### Offline model validation

The Rust walk-forward command now evaluates the same causal feature contract
used by a candidate artifact. It fails closed unless `--bars` has an exact
normalized-data manifest and a pinned market-data rights receipt:

```powershell
Push-Location quant_engine_rs
cargo run --bin quantctl -- predictor walk-forward `
  --bars data/normalized/market_bars.csv `
  --output data/reports/walk_forward_contract_latest.json `
  --horizons 5,15,30,60
Pop-Location
```

To evaluate the no-UUP schema, add
`--feature-contract-config configs/candidates/live-feature-v2-no-uup.yaml`.
This creates a sealed `CANDIDATE_NOT_PROMOTED` report; it does not update the
production registry.

Python reports can consume separately sealed hypothesis tests, untouched
holdout trades, and point-in-time market baselines through
`validation_evidence` in the research configuration. Holdout and baseline
datasets must each be paired with their manifest or configuration validation
fails closed.

### Cross-sectional factor shadow

The 40/20/40 idea is isolated from the intraday predictor as a Rust-owned
cross-sectional research candidate:

- 40% momentum
- 20% explicitly labeled liquidity proxy
- 40% regime-conditioned price/volume

The fixed contract is
`quant_engine_rs/configs/candidates/cross-sectional-factor-rank-v1.yaml`.
It requires point-in-time universe membership, complete and fresh entitled
inputs, deterministic tie-breaking, and a content seal. It cannot emit a
calibrated probability, expected return, target weight, or broker order. The
old Yahoo-backed TypeScript scanner is quarantined; `/quant/scanner` shows the
candidate status, while its scan/reason APIs fail closed until a licensed
artifact is validated and promoted.

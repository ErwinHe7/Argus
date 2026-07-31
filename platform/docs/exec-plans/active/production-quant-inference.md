# Production quant inference and market-query integration

Status: active
Started: 2026-07-24
Owner: AXIO7
Default posture: research only, fail closed, execution disabled

Audit remediation ledger:
`docs/exec-plans/active/quant-remediation-41.md`

## Outcome

Turn a natural-language market question into a versioned, allow-listed query;
execute it in the Rust engine against point-in-time live and historical data;
return reproducible candidates, supporting and contrary evidence, historical
statistics, data freshness, lineage, uncertainty, and an audit identifier.

The first supported setup families are:

1. finalized-bar momentum continuation;
2. potential gamma-convexity feedback / gamma-squeeze structure;
3. VWAP rejection or reclaim;
4. opening-session five-minute exhaustion/turning window;
5. closing short-cover hazard;
6. statistical market dislocation.

These are research candidates, setups, or market dislocations. Only a
simultaneously hedgeable discrepancy that remains positive after fees,
slippage, financing, and borrow costs may be called arbitrage.

## Non-negotiable architecture

```text
Question
  -> constrained query compiler
  -> MarketQuery v2 (stored explicit-rule v1 migration only)
  -> Rust data/readiness gate
  -> Rust scan or historical evaluation
  -> EvidenceEnvelope v1
  -> optional LLM explanation
  -> web UI
```

- Python trains, validates, backtests research code, and exports immutable
  artifacts. It is not the online inference path.
- Rust owns features, model inference, Greeks/gamma aggregation, scenario
  economics, risk gates, historical query execution, and audit output.
- Next.js owns validation, authentication/rate limiting, proxying, and
  presentation. It performs no quantitative calculation.
- The LLM may compile or explain only within the JSON contract. Engine values
  cannot be overwritten by prose.
- No order-entry or brokerage mutation is in scope.

## Phase 0 audit — completed 2026-07-24

### Repository and deployment

- Next.js 14 frontend is deployed through the existing Vercel project and
  `axio7.com`.
- The Rust service already exposes health, readiness, live bars, frozen
  predictor, analog, options-intelligence, risk, and research endpoints behind
  `X-Research-Token`.
- No production `INTRADAY_QUANT_API_URL` or independently hosted `quantd`
  endpoint is configured.
- The current public `/api/ask` invokes a temporary TypeScript/Yahoo web
  forecast. That path violates the production ownership boundary and must be
  replaced by a Rust research-query proxy before production claims model
  connectivity.
- The working tree contains substantial user changes. Implementation must stay
  narrowly scoped and must not reset or overwrite unrelated work.

### Model and historical evidence

- A frozen Rust predictor artifact, prediction ledger, walk-forward reports,
  live forecast contracts, and approximately 427 sessions of normalized
  one-minute US equity data exist.
- The current predictor candidate is marked
  `CONTAMINATED_EXPLORATORY / RESEARCH_ONLY`; promotion was rejected because
  there is no untouched independent out-of-sample history.
- Forecast contracts already distinguish raw analog frequency from separately
  promoted calibrated probability and carry model, feature, data-manifest,
  causality, and decision-policy fields.
- The Rust gamma component computes only unsigned convexity magnitude and
  explicit sign scenarios. It correctly refuses incomplete or stale option
  chains and does not infer dealer position sign.

### Realtime data readiness

- `configs/production.yaml` requires Massive realtime stocks and complete OPRA
  chains, but the latest readiness receipt reports no stock WebSocket/realtime
  snapshot entitlement and no full OPRA chain entitlement for the configured
  universe. `production_ready=false`.
- The legacy Moomoo bridge verified quote protocol connectivity with Nasdaq
  Basic/TotalView/ArcaBook, but not consolidated SIP NBBO.
- No current IBKR, Tradier, Alpaca, Databento, or Cboe credential is configured
  in the website/runtime environment.
- Existing live verification did not produce a current passing finalized-bar
  and forecast receipt.

### Data-source policy

Professional free data can support delayed or end-of-day research, not a
production realtime gamma scanner:

- OCC daily open interest and aggregate volume are useful official historical
  inputs but are not realtime OPRA quotes.
- Cboe provides delayed quotes and paid historical quote products.
- Tradier can provide realtime consolidated equity/options data to eligible
  brokerage account holders; sandbox data is delayed.
- Alpaca's free plan is IEX equities plus an indicative options feed, so it
  cannot be labeled consolidated executable options/NBBO.
- IBKR market data requires account subscriptions and a running client
  integration; its historical API has pacing and options-history limitations.

Adapters may be added, but no provider is marked realtime or production-ready
until its entitlement, redistribution rights, coverage, and timestamps pass the
same Rust readiness contract.

### Baseline checks

- `cargo fmt --check`: passed.
- `cargo clippy --all-targets -- -D warnings`: passed.
- `cargo test`: passed.
- `python -m pytest` with an explicit writable base temp: 15 passed.
- `npm run typecheck`: passed.
- `npm run build`: passed (unrelated existing warnings only).
- C++ checks: blocked because CMake is not installed in the current
  environment.

## Phase 1 — query and evidence contracts

Implement in Rust:

- `MarketQuery v1`: intent, setup type, universe, horizon, data/freshness
  requirements, filters, exclusions, limit, and optional causal cutoff.
- `EvidenceEnvelope v1`: request/query hashes, cutoff, data snapshot,
  readiness, candidates, contrary evidence, historical analog statistics,
  model/feature versions, caveats, and research-only policy.
- Strict deserialization with unknown-field rejection, symbol normalization,
  finite numeric bounds, allow-listed horizons, maximum universe size, and no
  execution fields.
- Append-only JSONL audit record for each accepted query and response digest.

Acceptance:

- malformed, excessive, stale, incomplete, or unsupported requests fail closed;
- deterministic serialization and hashes have golden tests;
- no field can request, represent, or imply an order.

## Phase 2 — setup scanners and historical query

### Gamma-convexity feedback

Use only complete point-in-time option chains. Combine:

- near-dated unsigned gamma concentration near spot;
- call/put volume and open-interest concentration;
- volume/OI anomaly with explicit OI-as-of semantics;
- underlying relative volume, price momentum, and VWAP position;
- spreads, quote age, earnings/event risk, liquidity, and coverage as contrary
  evidence.

Do not infer dealer sign or opening/closing trade direction. If OPRA, Greeks,
OI, quote coverage, or the underlying snapshot is unavailable, return
`DATA_UNAVAILABLE` rather than a score.

### VWAP and five-minute turning windows

Use finalized five-minute bars and causally accumulated session VWAP. Report:

- current bar number and Eastern clock interval;
- reclaim/rejection/exhaustion condition state;
- historical sample count, median event bar, empirical quantiles, raw
  frequency, MFE/MAE, and explicit invalidation conditions;
- cross-asset confirmation and data-quality counter-evidence.

Any probability label requires a matching promoted calibration artifact;
otherwise expose only empirical/raw frequencies.

### Backtest query

Run the same normalized query against point-in-time historical snapshots with
purged walk-forward evaluation, transaction costs, data-availability cutoffs,
and no lookahead. Persist the query, data-manifest hash, feature/model versions,
result hash, and eventual realized outcome.

## Phase 3 — website integration

- Add a public research proxy with strict body limits, same-origin checks,
  server-only token injection, rate limiting, timeouts, and a narrow route
  allow-list.
- Change `/api/ask` to compile a question into `MarketQuery v1`, call Rust, and
  return the engine evidence. Disable the TypeScript/Yahoo forecast path.
- Present setup status, evidence and counter-evidence, historical analogs, data
  freshness, source/entitlement, model version, query DSL, and audit id.
- Preserve the formal Claude-inspired chat layout; do not expose control-plane
  endpoints or secrets.

## Phase 4 — artifact and runtime hardening

- Export immutable model artifacts with manifest, feature schema, label
  definition, training cutoff, validation metrics, checksums, and promotion
  status.
- Rust startup verifies artifact/schema/hash compatibility before binding the
  research routes.
- Add a multi-stage container, non-root runtime, read-only model mount,
  persistent append-only audit/ledger mount, health/readiness probes, and
  graceful shutdown.
- Keep `execution.enabled=false`; startup fails if a production research image
  attempts to enable execution.

## Deployment topology

```text
axio7.com (Vercel)
  -> POST /api/ask
  -> server-side POST /api/quant/research
  -> private HTTPS quantd service
  -> licensed live feeds + immutable artifacts + append-only audit store
```

Production cannot truthfully activate the model until the Rust service has a
stable HTTPS URL and at least one realtime equity plus consolidated options
entitlement passes readiness. The site may be deployed earlier only in a
fail-closed state that clearly reports the missing capability.

## Rollback

1. Revert the Vercel deployment to the last known-good version.
2. Remove/disable `INTRADAY_QUANT_API_URL`; the research route must return
   `DATA_UNAVAILABLE`, never fall back to Yahoo.
3. Stop the Rust service; no brokerage state changes exist because execution is
   disabled.
4. Retain audit and ledger files for diagnosis.

## Current blockers

1. No production host/credential for the Rust service.
2. Current Massive plan lacks realtime stocks and full OPRA-chain entitlement.
3. No untouched independent out-of-sample historical set for model promotion.
4. CMake is unavailable for native C++ verification.

These blockers constrain production claims; they do not block implementing and
testing the deterministic contracts, fail-closed scanners, proxy, UI, and
container locally.

## Monitor checkpoint — 2026-07-25

Implemented:

- natural-language monitor requests compile into the same allow-listed
  `MarketQuery v1` contract used by interactive scans;
- authenticated users can create, list, pause, and resume durable monitors;
- Supabase migration `022_market_monitors.sql` defines user-owned monitor
  rules, append-only run receipts, deduplicated events, and an atomic
  `SKIP LOCKED` claim function;
- the authenticated worker endpoint claims due rules during the US regular
  session and calls only the Rust research service;
- the Rust momentum condition uses finalized five-minute bars, cumulative
  directional return, directional-candle confirmation, session VWAP,
  last-bar continuation, and current-session recent-volume participation;
- only explicit engine trigger states create events. Missing/stale data,
  transport failures, unvalidated shadow output, and ordinary available
  results do not alert;
- the chat UI exposes monitor creation receipts and pause/resume state without
  order controls or profit guarantees.

Verification:

- `npm run typecheck`: passed;
- `npm run build`: passed with pre-existing warnings only;
- `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`, and
  `cargo test`: passed; 227 Rust tests;
- Python offline research suite: 26 passed, 5 skipped;
- Playwright monitor-chat smoke test: passed with no browser console errors.
- C++ verification remains unavailable because CMake is not installed.

Activation still requires:

1. configure `MARKET_MONITOR_CRON_SECRET` and a production
   `INTRADAY_QUANT_API_URL`/`INTRADAY_QUANT_TOKEN`;
2. host `quantd` at a stable private address reachable by the Next.js server;
3. obtain written public-product rights and passing readiness receipts for the
   selected live equity feed; gamma monitoring additionally requires complete
   OPRA quotes, definitions, Greeks inputs, and point-in-time OI;
4. either upgrade the confirmed Vercel Hobby project before registering a
   five-minute Vercel cron, or move the application to the prepared single-VM
   target with its authenticated five-minute scheduler.

Until those receipts exist, the deployed site must remain visibly fail closed.

Deployment receipt:

- production deployment `dpl_8GgiGocsckiggnHMsvCBfTeHJXHg` is ready and
  aliased to `https://axio7.com`;
- the hosted Playwright smoke test passed the chat, authentication-required
  monitor receipt, and explicit native-runtime-unavailable state;
- production environment inspection confirms that
  `INTRADAY_QUANT_API_URL`/`INTRADAY_QUANT_TOKEN` are not configured;
- production Supabase migration `022_market_monitors.sql` was applied through
  an isolated migration worktree because the linked project's remote migration
  history was otherwise empty. PostgREST service-role queries verified
  `market_monitors`, `market_monitor_runs`, and `market_monitor_events`;
- `infra/single-vm` now packages Caddy automatic TLS, the standalone Next.js
  server, private Rust `quantd`, and an authenticated five-minute monitor
  scheduler for a normal ARM64/AMD64 VPS;
- Compose validation, both production image builds, Caddy validation, and the
  local three-service health run passed. The web image was approximately
  94.5 MB and the Rust image approximately 52.2 MB on the local AMD64 build;
- the local scheduler reached the authenticated monitor endpoint and received
  the expected `outside_regular_market_window` receipt. With no live credential,
  Rust stayed online but reported `MASSIVE_REALTIME_NOT_READY`, started no live
  watchers, and exposed no substitute market result;
- Oracle Cloud Free Tier account creation failed after payment verification, so
  Oracle is no longer the active deployment target. The replacement target is
  an AWS Free account plan and a small EC2 instance covered by its promotional
  credits. The AWS registration page is open and awaits user-owned email,
  identity, and payment verification. No paid-plan upgrade is authorized;
- the single-VM target has not been launched while AWS registration is
  incomplete. It preserves the fail-closed data-license gate and keeps every
  execution flag disabled.

## Model-system audit and narrow-universe decision — 2026-07-25

The current model inventory, validation gaps, data-source options, and proposed
5–15 symbol research roadmap are documented in
`docs/model-system-audit-and-narrow-universe-roadmap.md`.

Material findings:

- the actual frozen online model is HMM regime filtering plus a same-regime
  analog kernel; Logistic, boosted, TVTP/HSMM, stochastic, and motif components
  are not one validated production ensemble;
- the latest negative controls report `NO_EDGE`, and the current candidate is
  `RESEARCH_ONLY / REJECTED_NO_INDEPENDENT_OOS_EVIDENCE`;
- a Python uncertainty calculation references a test-target mean and must be
  corrected before any affected research result is reused;
- daily OI observation time must be separated from quote capture and provider
  availability time;
- mutable overlapping data manifests and `latest` artifacts must be replaced by
  immutable partitions and a promotion registry;
- the first target scope is a private 5–15 symbol research scanner for momentum,
  VWAP-turn hazard, gamma-feedback structure, and volatility expansion;
- no calibrated probability may be activated until the corrected pipeline
  passes untouched walk-forward and forward-shadow promotion gates.

This audit changes no execution posture. Automatic execution remains disabled,
and live production activation remains blocked by hosting, entitlement, and
independent out-of-sample evidence.

## Implementation receipt — 2026-07-24

Completed:

- Rust `MarketQuery v1` and `EvidenceEnvelope v1` contracts with strict
  validation, deterministic hashes, append-only audit receipts, and no order
  fields.
- Causal five-minute session aggregation, session VWAP, opening-exhaustion and
  VWAP-reversal event detection, empirical historical analog statistics, and
  MFE/MAE reporting.
- Complete-chain gamma-structure scanner with explicit unsigned-gamma semantics,
  coverage/freshness checks, counter-evidence, and no dealer-position claim.
- Native research routes at `/api/v1/research/query`, `/v1/scan`, and
  `/v1/backtest/query`.
- Website natural-language compiler, server-only Rust proxy, evidence formatter,
  and research UI. The former Yahoo/TypeScript answer path is disconnected and
  has no production fallback.
- Non-root multi-stage container packaging, health check, and fail-closed
  startup policy.

Observed local end-to-end receipts:

- The SPX opening-turn question normalized to SPY and evaluated 504 historical
  sessions. It found 421 qualifying descriptive events, with median event bar 6
  (09:55–10:00 ET), interquartile range bars 3–11, and raw 15-minute
  continuation-down frequency 45.13%. This is descriptive evidence, not a
  calibrated predictive probability.
- A live gamma request for NVDA/AAPL/TSLA/AMD correctly returned
  `DATA_UNAVAILABLE` with zero candidates because a complete current OPRA chain
  and passing realtime SIP/OPRA readiness receipt were absent.

Verification:

- Rust: 218 library tests, 5 CLI tests, and 12 integration tests passed;
  formatting and warning-free Clippy passed.
- Python: 15 tests passed in the repository virtual environment.
- TypeScript/Next.js: typecheck and production build passed.
- Browser: the full ask → DSL → Rust → evidence-card flow passed Playwright
  smoke testing.
- Container definition: shell syntax and JSON configuration passed. Image build
  remains unverified because the local Docker daemon is not running.

Production activation remains blocked by the two external dependencies above:
a stable authenticated Rust service host and a licensed realtime consolidated
equity/options feed. Until both pass readiness, production must display an
explicit data-unavailable state and must not generate substitute candidates.

## Narrow-universe implementation receipt — 2026-07-25

Configured public universe:

`SPX, QQQ, NVDA, AAPL, MU, SOXX, NBIS, BE, IGV`

Completed:

- Added explicit public/model/price/options/VWAP mappings for all nine targets.
  SPX is no longer silently normalized to SPY; the engine chooses the explicit
  SPY VWAP proxy or SPX option root according to the requested calculation.
- Restricted the website query compiler and Rust query service to the
  configured public universe.
- Standardized model horizons to 5/15/30/60 minutes.
- Corrected Python walk-forward labels so every horizon trains against its own
  return/MFE/MAE, removed test-target leakage from uncertainty, and made
  rolling price-volume divergence session-causal.
- Embedded the Markov-switching log-return diffusion, VWAP-residual
  Ornstein-Uhlenbeck process, and regime-conditioned momentum head in the
  immutable Rust frozen artifact. It remains decision-neutral shadow research
  until separately validated and promoted.
- Added `predictor train-universe` to materialize one frozen candidate artifact
  per configured target plus a target registry.
- Added an append-only SQLite minute-bar store with deterministic batch IDs,
  file SHA-256, event/availability/capture timestamps, provider/dataset,
  license scope, and license reference. Research-only data cannot become
  public-product eligible.
- Added Massive index support and performed a real `I:SPX` entitlement probe.
  The current plan returned 403, so SPX cash-index price remains unavailable.
- Completed the Massive two-year historical backfill for the five previously
  absent target files: NVDA, AAPL, NBIS, BE, and IGV, then restored MU from 27
  cached vendor chunks.
- Added compliant 429 retry/backoff and safe 56-calendar-day stock chunks under
  the free-plan five-request-per-minute cap.
- Added `/api/v1/research/universe`, exposing target mappings, horizons, SDE
  status, gamma limitations, licensing gate, and execution-disabled policy.
- Added a public API license gate requiring server-side
  `AXIO7_PUBLIC_MARKET_DATA_PROVIDER` and an HTTPS
  `AXIO7_PUBLIC_MARKET_DATA_LICENSE_REFERENCE`; personal research batches
  cannot produce public candidates.
- Documented the public data decision in
  `docs/data-source-decision-2026-07-25.md`.

Verification at this checkpoint:

- Rust library: 221 passed.
- Rust CLI/integration: 5 + 12 passed; Clippy passed with warnings denied.
- Python: 16 passed.
- TypeScript: typecheck passed.
- Next.js production build: passed with existing unrelated lint warnings.

Public activation remains blocked. The lowest-cost credible first purchase is
Databento EQUS.MINI for public equities, subject to written confirmation of
AXIO7's use. Public realtime gamma additionally requires an OPRA Vendor
Agreement/Exhibit A and an external-distribution plan. Personal Massive data is
retained as `RESEARCH_ONLY`.

Historical materialization receipt:

- append-only SQLite batches: 2;
- rows: 3,577,530;
- source coverage: 2024-07-18 through 2026-07-24 overall;
- target row counts: SPY 428,995; QQQ 447,840; NVDA 476,157; AAPL 376,553;
  MU 381,074; SOXX 272,350; NBIS 306,726; BE 266,550; IGV 229,093;
- all current batches are `RESEARCH_ONLY` and
  `public_product_eligible=false`;
- the current personal Massive index plan rejected `I:SPX` with HTTP 403.

The first debug `train-universe` invocation was intentionally stopped without
publishing a partial artifact. After adding target subsets and stage progress
logging, the optimized release job completed all nine immutable candidate
artifacts in 100 seconds. Every registry entry reports
`same-regime-kernel+cv-selected-hmm+regime-sde-shadow-frozen-v2` and
`short_horizon_sde_present=true`. The registry remains
`CANDIDATE_ARTIFACTS_NOT_PROMOTED`; model availability must fail closed until
independent OOS validation, calibration, and promotion are complete.

## CUDA and PostgreSQL transition — 2026-07-25

- Hardware inspection identified an NVIDIA GeForce RTX 5070 Laptop GPU with
  8,151 MiB VRAM and compute capability 12.0. The prior Python 3.14
  environments either had no PyTorch or a CPU-only PyTorch build.
- Added a reproducible Python 3.12 / PyTorch CUDA 13.0 setup and a real
  matrix-multiply/backpropagation smoke test. CUDA remains an offline-training
  accelerator; it does not move production inference out of Rust.
- Retained the existing append-only SQLite archive as immutable source
  evidence, but established PostgreSQL as the website/continuous-ingestion
  market database.
- Added an append-only PostgreSQL schema for equity minute bars, equity NBBO,
  option contracts, option quotes, option trades, daily open interest, batches,
  and readiness receipts. Event time, availability time, recording time,
  provider, data quality, and license scope remain explicit.
- Added a point-in-time `equity_minute_bars_asof` SQL function and a chunked,
  count-verified SQLite-to-PostgreSQL migration utility.
- IBKR is not presently connected locally: no TWS/Client Portal Gateway process
  or API port is available, and no repository environment contains the
  required IBKR account/client configuration. The connected AXIO7 options MCP
  endpoints also return HTTP 410 `feature_retired`; they cannot be used as a
  production data source.
- PostgreSQL migration does not upgrade the license of the source data. The
  current Massive batches remain `RESEARCH_ONLY`, and option tables remain
  empty until a genuine entitled OPRA/IBKR/vendor feed is archived.

Verified receipt:

- Python 3.12.13, PyTorch `2.12.0+cu130`, CUDA build 13.0;
- `torch.cuda.is_available() == true`, device capability 12.0, BF16 supported;
- a 2048×2048 CUDA matrix multiplication plus backward pass completed with
  finite gradients;
- local PostgreSQL 17 is healthy on loopback port 55432;
- SQLite and PostgreSQL both contain exactly 3,577,530 minute bars;
- PostgreSQL coverage receipts preserve all 14 stored symbols and both source
  batch identifiers;
- the nine target/proxy symbols have zero historical bid/ask rows;
- PostgreSQL option contracts, quotes, trades, and open interest remain zero,
  accurately reflecting the absence of an entitled historical option archive;
- point-in-time SQL correctly excluded the later MU batch at a cutoff when the
  earlier SPY batch was already available;
- Python verification now reports 18 passing tests.

## Options Basic archive and CUDA challenger receipt — 2026-07-25

- Verified the current Massive credential against an expired NVDA contract
  from 2024-07-26 and current expired contracts from 2026-07-24. The free
  entitlement returns true per-contract minute aggregates across its
  documented two-year window.
- Added a separate partitioned `option_minute_bars` table and point-in-time
  query. Aggregates are never written into NBBO, individual-trade, or
  open-interest tables.
- Added a rate-limited, resumable-by-immutable-manifest options slice ingestor
  with raw-response hashes, contract definitions, coverage receipts, source
  license, and a conservative Basic end-of-day availability policy.
- Materialized one verified NVDA expiration slice: the 2026-07-24 210 Call and
  Put, 390 one-minute bars each, 780 rows total. A same-day cutoff returned
  zero rows and the next-day eligibility cutoff returned all 780.
- Corrected the OCC source classification after inspecting the official CSV:
  its free Daily Open Interest download is a market-wide total by product
  class, not per-contract OI.
- Added a 54,896-parameter shared causal TCN challenger for the configured
  nine-symbol/proxy universe. It uses 24 causal five-minute observations,
  symbol embeddings, multi-task direction/return heads, BF16 CUDA training,
  training-only normalization, chronological train/validation/test sessions,
  two-session embargoes, and validation-only probability calibration.
- The first immutable checkpoint was trained from 3,185,338 eligible minute
  rows / 345,285 complete five-minute rows. It used 97,538 training sequences,
  24,303 validation sequences, and 23,976 final test sequences.
- Initial aggregate untouched-test AUC was 0.560 for 5 minutes, 0.530 for
  15 minutes, and approximately 0.508 for both 30 and 60 minutes. The 5-minute
  Brier score improved only modestly over its validation-prevalence baseline;
  longer horizons did not establish a useful edge.
- Added per-symbol untouched-test diagnostics. At five minutes, SPY and QQQ
  recorded AUC 0.579 and 0.560 respectively, but their accuracy improvements
  over the validation-prevalence baseline were only about 0.1 and 0.2
  percentage points. No target/horizon result is treated as promotion evidence
  without repeated walk-forward and forward-shadow confirmation.
- Archived 25 official OCC monthly reports covering 507 observed trading days
  from 2024-07-18 through 2026-07-24. They remain in the dedicated market-total
  table and `option_open_interest` remains empty.
- Final checks passed: Python 26 tests with one CUDA-only test skipped in the
  CPU test environment; Rust formatting, warning-free Clippy, 221 library
  tests, 5 CLI tests, and 12 integration tests; TypeScript typecheck and the
  Next.js production build.

The TCN artifact remains `CANDIDATE_NOT_PROMOTED`. The historical archive was
captured after the events, the option archive lacks NBBO and OI, and no forward
shadow trial or executable-cost validation exists. It cannot serve website
probabilities or enable execution.

## Regime-gated neural challenger receipt — 2026-07-25

Implemented a second offline CUDA challenger without changing the production
execution posture:

- Replaced the two-head research TCN with a 160,224-parameter causal
  regime-gated mixture of four experts.
- Added causal last-query temporal attention and an interface that can replace
  the latent gate with filtered probabilities from a separately validated Rust
  regime artifact.
- Added a heavy-tailed Student-t return distribution, direction logits,
  within-horizon VWAP-cross logits, and favorable/adverse excursion heads for
  5/15/30/60-minute horizons.
- Added a causal EWMA drift prior with bounded expert/horizon-specific learned
  shrinkage. The prior is not forced into the forecast and does not replace the
  canonical Markov-switching SDE in Rust.
- Added expert-balance and specialization regularization, validation-only
  Platt calibration for direction and VWAP-cross outputs, distribution
  coverage/NLL metrics, and per-symbol untouched-test diagnostics.
- Converted normalization state to tensors and recorded the complete
  architecture constructor in the checkpoint. The final artifact passed
  `torch.load(..., weights_only=True)` and strict state-dictionary reload.

Training used the same immutable research-only historical extraction and the
same 97,538 / 24,303 / 23,976 chronological train/validation/test sequences.
The selected four-epoch artifact is:

`intraday_quant/data/models/regime_gated_v2_candidate/`

Aggregate untouched-test results:

| Horizon | Direction AUC | Direction Brier gain | Return IC | VWAP-cross AUC |
| --- | ---: | ---: | ---: | ---: |
| 5m | 0.5542 | +0.00237 | +0.0285 | 0.8480 |
| 15m | 0.5242 | -0.00003 | +0.0185 | 0.8491 |
| 30m | 0.5005 | -0.00136 | +0.0078 | 0.8365 |
| 60m | 0.4940 | -0.00154 | +0.0255 | 0.8021 |

The result is a useful VWAP-event research challenger, not a promoted
directional price predictor. It does not beat the original TCN's 5-minute
direction AUC, and 15/30/60-minute calibrated direction probabilities do not
beat the baseline. The artifact therefore remains
`CANDIDATE_NOT_PROMOTED`, automatic execution remains disabled, and the Rust
service must not publish these values as production probabilities.

Next model work is constrained to:

1. repeated purged walk-forward folds and multiple seeds;
2. immutable cached five-minute training panels;
3. forward-shadow outcomes from an entitled realtime equity feed;
4. separate task selection or gradient-conflict controls before another
   architecture expansion;
5. a verified immutable neural runtime in Rust before any promotion;
6. a gamma expert only after point-in-time contract NBBO/OI data exists.

External requirements:

- Public momentum/VWAP launch needs a licensed, redistributable realtime
  equities feed and a stable authenticated HTTPS host for `quantd`.
- Public gamma launch additionally needs a complete OPRA chain, daily
  contract-level OI with availability timestamps, and written external-use
  rights.
- A 60–90 trading-day forward-shadow window is required after the feed starts.
- No additional GPU is required for this narrow-universe stage; the local RTX
  5070 Laptop GPU is sufficient.

Verification:

- focused CUDA/model contract tests: 8 passed;
- full Python suite: 26 passed, 5 optional-dependency skips;
- Rust: formatting and warning-free Clippy passed; 221 library, 5 CLI, and
  12 integration tests passed;
- TypeScript typecheck and Next.js production build passed;
- C++ checks remain unavailable because CMake is not installed.

## Website authentication and local Rust connection receipt -- 2026-07-25

Completed:

- preserved the existing Supabase Google OAuth, Apple OAuth, email magic-link,
  `/auth/callback`, and session-refresh implementation;
- added a visible Google sign-in entry to the research home page and an
  authenticated account/sign-out state without creating a second identity
  store;
- added a server-side runtime probe that authenticates to
  `/api/v1/research/universe`, verifies `quant_engine_rs` ownership, and
  requires execution to remain `DISABLED` before showing the connected state;
- changed the local launcher to create a cryptographically random,
  process-memory-only research token when no server token is configured, so
  Next.js and `quantd` share authentication without writing a secret to disk;
- changed the launcher and runtime receipt to use the active `/` research home
  instead of a retired legacy page; and
- added a repeatable Playwright smoke test for the home-page Google entry,
  preserved OAuth page, authenticated Rust status, and browser console.

Observed local end-to-end receipt:

- Rust `/health` returned `runtime=rust`, `backend=axum`, and `status=ok`;
- the website runtime probe returned `CONNECTED`,
  `CONFIGURED_RESEARCH_UNIVERSE`, and `execution=DISABLED`;
- a home-page `/api/ask` request reached Rust and returned
  `axio.evidence-envelope.v1` with an immutable model contract and audit ID;
- that research request correctly returned `DATA_UNAVAILABLE` because the
  public redistribution license is not configured and the frozen artifacts
  remain unpromoted. No TypeScript, Yahoo, synthetic, or LLM quantitative
  fallback was used; and
- the browser smoke test passed with zero console errors and retained the
  original Google, Apple, and email sign-in choices.

Verification:

- TypeScript typecheck and Next.js production build passed;
- Rust formatting and warning-free Clippy passed; 222 library, 5 CLI, and
  12 integration tests passed;
- Python offline research suite: 26 passed, 5 optional-dependency skips;
- Playwright Google/model home smoke test passed; and
- C++ checks remain unavailable because CMake is not installed.

## AWS production deployment receipt -- 2026-07-25

Infrastructure:

- AWS Free Plan was verified in the authenticated console with USD 100 total
  credit, USD 0 used, and a displayed expiration of 2027-07-26. The account was
  not upgraded to the paid plan.
- Created EC2 instance `axio7-production`
  (`i-0533d077591d7f63b`) in `us-east-2` on the free-tier-eligible `t3.micro`
  shape, Ubuntu 26.04 LTS x86-64, a 20 GB `gp3` volume, required IMDSv2, and
  detailed monitoring disabled.
- Installed Docker Engine and Compose v2, added a 2 GB swap file, loaded
  prebuilt AMD64 application images, and deployed the single-VM stack under
  `/opt/axio7`.
- The Rust control service remains private to the Docker network. Only Caddy
  publishes HTTP and HTTPS; automatic execution and every brokerage mutation
  gate remain disabled.

Runtime evidence:

- `quantd` reported healthy with `runtime=rust`, `backend=axum`, and
  `status=ok`; the web container returned HTTP 200 internally.
- Caddy, Next.js, Rust, and the scheduler used under 100 MB of steady-state
  memory in aggregate during the deployment check.
- The scheduler is running, but its market scans fail closed while public
  market-data licensing and model promotion are absent.
- Server secrets are stored only in the ignored, mode-0600
  `/opt/axio7/.env.server` file and were not copied into client bundles or
  committed files.

Public routing:

- Vercel DNS now has explicit `A` records for `axio7.com` and
  `www.axio7.com` pointing to the EC2 public address. Existing mail records
  were preserved, and the former Vercel default records remain available as a
  rollback path.
- Authoritative DNS and independent public resolvers returned the EC2 address.
  Caddy obtained a valid public certificate after propagation and served the
  Next.js application over HTTPS with HSTS.
- The existing Supabase project, Google provider, site URL
  `https://axio7.com`, and callback
  `https://axio7.com/auth/callback` were retained, so no user identity store
  was replaced during migration.
- Added a canonical configured-origin check for TLS-terminating reverse
  proxies. This corrected browser POST requests that Next.js had rejected
  after seeing Caddy's internal HTTP scheme, while a deliberately foreign
  origin continued to return HTTP 403.
- The production Playwright receipt passed the formal research home, Google
  entry, Supabase authorization initiation, exact callback, Rust runtime
  status, and browser console checks. A same-origin NVDA momentum/VWAP request
  reached Rust and returned HTTP 200, `axio.evidence-envelope.v1`,
  `DATA_UNAVAILABLE`, and zero candidates, as required by the activation gate.
- Both apex and `www` passed public certificate verification; `www` returns a
  permanent redirect to the apex. Common secret-probing paths returned HTTP
  404 and did not expose the server environment.

Activation boundary:

- Production has no configured redistributable realtime equities/options
  entitlement and no promoted immutable forecasting artifact.
- Therefore public momentum, VWAP, gamma, and probability answers remain
  explicitly `DATA_UNAVAILABLE`; no Yahoo, synthetic, delayed-as-realtime, or
  LLM-generated quantitative fallback is permitted.
- The deployment completes hosting and model-service connectivity. It does not
  claim that the research system has live production evidence until a licensed
  feed, readiness receipt, forward-shadow trial, and model promotion all pass.

Final deployment checks:

- TypeScript typecheck and the Next.js production build passed.
- Rust formatting and warning-free Clippy passed; 222 library, 5 CLI, and
  12 integration tests passed.
- Python offline research tests passed: 26 passed and 5 optional-dependency
  tests skipped.
- C++ checks remain unavailable because CMake is not installed.

## External model and realtime-data review handoff -- 2026-07-25

The reviewer-facing engineering package is
`docs/handoffs/axio7-model-realtime-review-package-2026-07-25-zh.md`.

The audit confirmed that compilation and contract tests pass, but public
realtime prediction remains blocked by production integration gaps in addition
to the already recorded external entitlements:

- the Massive realtime runner still loads the single-target legacy
  `frozen_predictor_latest.json` instead of orchestrating the nine v2 artifacts
  in the universe registry;
- equity shadow inference is coupled to the all-options OPRA readiness gate;
- the Massive loop persists predictions but does not automatically settle
  matured forward outcomes;
- the selected Databento EQUS.MINI public-equity path has historical
  download/decode support but no live adapter;
- normalized live events are archived to JSONL rather than continuously
  materialized into the append-only PostgreSQL market store;
- production TypeScript routes still expose legacy quantitative calculation
  modules outside the Rust-only inference boundary; and
- container health checks do not supervise freshness or liveness of the model
  and options watcher child processes.

These findings do not relax the existing fail-closed posture. They define the
minimum engineering scope for an external implementation bid; they do not
authorize model promotion, public probability publication, or execution.
## 2026-07-25 — Behavioral State Layer v1

- Added the Rust-native `axio.behavioral-state.v1` contract and exposed it on
  each forecast bundle as a root descriptive research layer.
- Implemented causal price/volume-only indices for fear, FOMO, herding,
  attention, forced selling, and short covering plus partial actor-pressure
  scenarios for retail, active institutions, CTA/trend, vol-control, and short
  covering.
- Dealer and passive-flow pressure fail closed because dealer sign, ETF
  creations/redemptions, closing imbalances, and complete point-in-time option
  lineage are not observed.
- All indices and actor propensities are explicitly raw and uncalibrated.
  Calibrated probabilities remain absent, static influence weights are labeled
  as scenario assumptions, and `affects_decision=false`.
- Behavioral features are not added to the frozen analog distance. Promotion
  requires historical point-in-time behavioral materialization, a new artifact
  schema, repeated purged walk-forward tests, and a settled forward-shadow
  window.
- Rust validation: 225 library tests, 5 `quantctl` tests, and 12 integration
  tests passed.

## 2026-07-25 -- Behavioral/Sentiment Regime v2 hardening

- Superseded the v1 behavioral contract with `axio.behavioral-state.v2` and a
  hashed `axio.behavioral-price-flow-features.v2` schema.
- Removed OHLCV-derived retail, institution, CTA, vol-control, short-seller,
  and dealer attribution, dominant actor, static capital weights, and pseudo
  net-flow pressure. The replacement fields are observable market proxies with
  explicit psychology interpretation hypotheses and no actor/headcount claim.
- Added raw stress-like, chase-like, crowding-like, attention-shock-like,
  rebound/squeeze-like, and mixed response-regime compatibility scores. They
  are not probabilities and remain `affects_decision=false`.
- Added explicit cross-asset completeness and coverage. Missing VXX or another
  required basket member no longer becomes observed neutral breadth in the
  behavioral layer or market memory.
- Removed the invented historical `latest_input_available_at=bar_end` value.
  The live forward-shadow adapter now attaches provider availability only when
  it is aligned with the root behavioral observation cutoff.
- Added `axio.l1-order-flow-proxy.v1` with entitlement, lineage, future/stale,
  sequence-gap, spread, displayed-depth, microprice, event-rate, and stationary
  L1 OFI validation. It is explicitly not L2/L10 Deep OFI, is excluded from the
  frozen feature schema, and is decision-neutral.
- Recorded paper-by-paper integration decisions and psychology/sentiment data
  gates in `docs/behavioral-sentiment-regime-literature-2026-07-25.md`.
- No model was promoted. The production decision path remains frozen causal HMM
  plus same-regime analogues, research-only, and `NO_TRADE`.
- Validation: `cargo fmt --check`, Clippy with warnings denied, 232 Rust library
  tests, 5 `quantctl` tests, 12 Rust integration tests, TypeScript typecheck,
  Next.js production build, and Python 26 passed / 5 skipped.

## Paddle live billing deployment receipt -- 2026-07-25

Completed:

- verified the live Paddle account, approved `axio7.com` website, active
  production webhook, live client token, and the Starter, Pro, and Advanced
  monthly and annual catalog prices;
- confirmed that Paddle automatic currency conversion is active for CAD, CNY,
  EUR, HKD, JPY, KRW, and USD;
- deployed the Paddle pricing, transaction, webhook, customer-portal, welcome,
  refund, privacy, terms, and support routes to the AWS production web
  container;
- stored the least-privilege live API key and webhook signing secret only in
  mode-0600 `/opt/axio7/.env.server`; the browser bundle contains only the
  Paddle live client token intended for client-side use;
- explicitly enabled trusted `X-Forwarded-For` handling for the private
  Next.js service behind the production Caddy proxy, so Paddle re-resolves the
  visitor country from the server-observed IP before creating a transaction;
- retained the pre-deployment image as
  `axio7-web:rollback-pre-paddle-20260726`; and
- removed the temporary GitHub release and local image-transfer artifact after
  the EC2 image was loaded.

Live evidence:

- the deployed AMD64 image ID is `1bbf71c5fdeb`, and the recreated web
  container reported healthy;
- the Paddle API credential returned HTTP 200 from production;
- the signed-in public pricing page rendered Paddle `formattedTotals` of
  `$50.00`, `$150.00`, and `$300.00` monthly and `$500.00`, `$1,500.00`, and
  `$3,000.00` annually for the observed US location; and
- no live payment was attempted.

Live zero-cost E2E status (2026-07-26 UTC):

- the account owner confirmed verification is complete, the Live default
  payment link is saved, and the approved production domain is deployed;
- a unique 100% Live discount is active, restricted to Starter monthly,
  non-recurring, single-use, unused, and expiring after 24 hours; its code is
  intentionally not stored in the repository;
- the first owner checkout attempt failed because the server generated the
  Paddle transaction `checkout.url` from the reverse proxy's internal origin;
- the first repair still inlined the local `http://localhost:3000` public site
  value and caused authenticated production checkout requests to return 403;
- checkout origin reconstruction now requires the runtime-only
  `AXIO7_SITE_URL` in Production and accepts that public origin only when the
  browser Origin or proxy-forwarded origin independently confirms it;
  contract tests, TypeScript validation, and the production build passed;
- production image
  `sha256:ac9986661666ff068ebe8f8907013dde2e9c580bc590c977967eb0d83c4b3d7e`
  is deployed and healthy, with the prior image retained as
  `axio7-web:rollback-pre-origin-fix-20260726`;
- the running server reports the exact `https://axio7.com` canonical origin,
  no `localhost:3000` in the checkout origin code, and a same-origin
  unauthenticated probe reaches the route with `401 authentication_required`;
- the stale failed checkout attempt has no matching Paddle transaction;
- the account owner personally completed the Live Starter-monthly checkout
  using the single-use 100% discount; no agent entered payment details or
  submitted Checkout;
- Paddle reports the resulting transaction as `completed`, in Live mode, with
  USD total `0`, and the checkout attempt, customer, subscription, transaction,
  billing-account, and webhook mirrors reconciled to the same account;
- Paddle notification delivery logs for `transaction.completed`,
  `subscription.created`, `subscription.activated`, and
  `subscription.updated` report `delivered` with HTTP 200, while the
  application event ledger records one successful processing attempt and no
  error for each event;
- the subscription was upgraded from Starter monthly to Pro monthly with
  `proration_billing_mode=do_not_bill`; Paddle created no new transaction, the
  database price mirror changed to Pro, and access remained granted;
- end-of-period cancellation was exercised and verified: the subscription
  remained `active`, the scheduled cancellation timestamp matched the current
  period end, the webhook returned HTTP 200, and access remained granted;
- immediate cancellation was then exercised and verified: Paddle and the
  database both report `canceled`, no scheduled change remains, the
  cancellation notification returned HTTP 200, and the access helper denies
  access; and
- the dedicated discount was used exactly once and archived. The real
  transaction/customer/subscription/webhook history was preserved, and no
  refund or paid adjustment was created.

Remaining non-billing production blockers found during the same live audit:

- Google OAuth initialization and the authenticated user session are working,
  but the site navigation and sign-in presentation require visual unification;
- the configured TokenRouter credential returns HTTP 401, so the explanatory
  LLM correctly falls back to deterministic copy until the credential is
  rotated; and
- public market inference remains fail-closed because Production has no
  configured public-redistribution license reference, live entitled feed, or
  pinned promoted model artifact. Placeholder values or unlicensed data must
  not be used to bypass these gates.

## 2026-07-26 -- Market-state transition source audit and v2 contract

- Reviewed the user-supplied market-state transcript and screenshots and
  recorded the source audit in
  `docs/market-state-transition-video-review-2026-07-26.md`.
- The claim that today's state is the "biggest indicator" of tomorrow is not
  established evidence. The price-only example does not model psychology,
  participant identity, or sentiment.
- The Rust state artifact now computes same-session endpoint occupancy as
  filtered posterior \(q_t A^h\) for 5/15/30/60-minute horizons, never as a
  scalar probability raised to a power.
- \(A_{ii}^h\) is exposed only as uninterrupted-state survival. Geometric
  expected duration, future self-transitions, and terminal occupancy are
  separate fields; absorbing-state duration is unbounded rather than replaced
  with an arbitrary large finite number.
- Transition support is estimated from causal training sequences with soft
  posterior pair mass \(\xi_t(i,j)\). State naming comes only from the immutable
  artifact's train-statistic profiles. Labels that implied unobserved clock or
  liquidity information were replaced with neutral price-flow descriptions.
- Purged forward evaluation now selects state count independently inside each
  fold using train-only fits and the fold validation suffix. The test suffix is
  first accessed only after state-count selection and parameter freezing.
- Cross-session forecasts fail closed pending a separately trained and
  validated overnight/session-boundary artifact. At the session boundary,
  same-session next-state probability is nullable instead of silently becoming
  a tomorrow forecast.
- Raw posterior certainty and Bull-minus-Bear-style contrasts remain
  descriptive and uncalibrated. Normalized posterior regime entropy may only
  impose a pre-registered fail-closed veto; it no longer scales allocation.
- `/state/current` now exposes the v2 artifact with freshness, coverage,
  availability, model/feature lineage, horizon, duration, transition-support,
  and decision-boundary fields. Missing availability lineage blocks the
  response; stale or otherwise degraded inputs mask all live probabilities.
- The API requires the exact registered feature schema, binds the declared
  model hash to the embedded model content, validates allocation and duration
  claims against the artifact, and allow-lists cross-session output fields.
  The content hash is self-consistency evidence, not a trusted-registry
  promotion receipt.
- No model was promoted and automatic execution remains disabled.
- Validation passed: Rust formatting; Clippy for all targets with warnings
  denied; 257 Rust library tests, 8 `quantctl` tests, and 12 Rust integration
  tests; TypeScript typecheck; Next.js production build; Python 26 passed /
  5 skipped; and 11 native C++ checks.

## 2026-07-26 -- Forecast contract v4.4 SDE/kernel interval receipt

- Confirmed the canonical Rust predictor already contained a genuine
  regime-conditioned log-return diffusion and VWAP-residual OU model, plus a
  12-dimensional same-regime adaptive Gaussian-kernel regression. The former
  was hidden in a shadow payload and the latter did not expose its full public
  evidence contract.
- Added SDE Gaussian moment-matched Up/Flat/Down model-implied mass and central
  80/90/95% log-return ranges. They are explicitly uncalibrated,
  decision-neutral, not confidence/conformal guarantees, and exclude the jump
  diagnostic from modeled tail moments.
- Added a first-class 12D kernel evidence object with selected dimensions,
  metric, kernel, bandwidth, neighbors, ESS, Nadaraya-Watson mean,
  distance-local-linear intercept, and the exact cost-band direction threshold.
- Added separate 95% Wilson estimate intervals for raw Up/Flat/Down
  kernel-weighted historical frequencies using Kish ESS. These remain
  exploratory and exclude serial-dependence, model-selection, and drift
  uncertainty.
- Added 80%/90% kernel-weighted empirical return ranges. The labels are
  next-minute open to horizon close, so ambiguous `expected_price` and legacy
  price quantiles now fail closed. Rust separately emits a clearly named
  current-close arithmetic reference scenario; the browser neither reconstructs
  it nor presents it as a label-aligned/executable price forecast.
- Replaced the SDE's approximate symmetric log-return event threshold with
  exact lower/upper thresholds `ln(1-c)` and `ln(1+c)`, matching the kernel's
  symmetric simple-return cost band. Invalid/negative/non-finite spread or
  slippage inputs now fail closed.
- Generic direction probabilities now fail closed. Without a matching
  `PromotedOos` artifact all three are null. A promoted binary-up artifact may
  publish `p_up` and its OOS reliability-bin sampling interval, while
  `p_down`/`p_flat` stay null until a joint multiclass calibrator is separately
  validated.
- Reliability-bin lookup now uses the calibrated probability coordinate
  (matching OOS bin construction), not the raw analogue frequency. Public and
  opportunity projections require the eligible flag, exact promoted runtime
  status, empty rejection reasons, and matching finite runtime/top-level
  values; legacy payloads cannot publish an injected probability.
- Updated `/quant/intraday` and the analogue workspace to show the SDE and
  kernel evidence side by side, label every interval by its actual semantics,
  and withhold directional headlines when calibration is not promoted.
  A promoted binary `P(up)` is never expanded into a promoted bearish or
  whole-direction conclusion, and partial state posterior vectors fail closed
  instead of rendering missing values as zero.
- No model was promoted, no automatic execution was enabled, and the SDE
  remains `affects_decision=false`.
- Validation passed: Rust formatting; Clippy for all targets with warnings
  denied; 274 Rust library tests, 8 `quantctl` tests, and 12 Rust integration
  tests; TypeScript typecheck; isolated Next.js production build; Python
  26 passed / 5 skipped; CMake configure/build plus 11 native C++ checks; and a
  headless Chromium mock-API UI-contract smoke of the unpromoted overview,
  promoted binary-P(up)/negative-mean branch, and analogue tab with zero
  blocking console or network errors. The browser smoke is intentionally not
  represented as a live auth/gateway/quantd end-to-end receipt.

## 2026-07-26 -- Unified membership/auth UI production receipt

- Unified the research workspace, pricing, billing, welcome, and sign-in
  surfaces around the same light, restrained AXIO7 research palette.
- Connected the production navigation contract end to end: Research `/`,
  Plans `/pricing`, Membership `/billing`, and Intraday `/quant/intraday`.
  The model workspace now exposes both membership destinations directly.
- Preserved the Paddle.js contract: country-aware `PricePreview` totals,
  monthly/yearly switching, the one-page overlay checkout variant, exact
  configured Live price IDs, signed-in email prefill, and `/welcome` success
  redirect.
- Hardened auth callback and sign-out return paths against protocol-relative
  and external redirects. The root sign-in CTA now enters the chooser
  honestly; only the exact `Continue with Google` action initiates OAuth.
- Added allow-listed LLM provider-failure telemetry. Production logs expose
  only operation, category, HTTP status, and provider host; they do not record
  prompts, credentials, headers, or response bodies.
- Built and deployed the web-only AMD64 image
  `sha256:58cc5c512c3929ad056d111c0d524271e3eb0476e79f241648db66409516ab1b`.
  The web container is healthy. The Rust container ID and start timestamp did
  not change during deployment. The prior web image remains available as
  `axio7-web:rollback-pre-ui-auth-20260726`.
- Runtime preflight confirms `PADDLE_ENVIRONMENT=live`, a Live API key, a
  `live_` browser token, and all six `pri_` plus all three `pro_` catalog IDs.
  No Paddle sandbox environment setter exists in application or client
  bundles. The SDK's packaged sandbox endpoint string is an unreachable
  alternate branch while the required environment is Live.
- Live browser verification passed for `/`, `/pricing`, `/billing`, and
  `/welcome`. The authenticated account was recognized, the Rust gateway
  reported connected, all membership links resolved, and Paddle returned the
  observed US totals of `$50.00`/`$150.00`/`$300.00` monthly and
  `$500.00`/`$1,500.00`/`$3,000.00` annually. No additional checkout or
  transaction was created during this visual verification.
- The live Google smoke passed home, sign-in entry, existing OAuth
  preservation, exact callback `https://axio7.com/auth/callback?next=%2F`,
  Rust runtime status, and zero browser-console errors.
- A live `NVDA` request reached Rust and failed closed with
  `PUBLIC_MARKET_DATA_REDISTRIBUTION_LICENSE_NOT_CONFIGURED`, as required.
  The explanatory TokenRouter request still returns HTTP 401. Producing a
  trustworthy public ranking therefore remains blocked on a licensed,
  externally redistributable market-data feed, its entitlement reference, a
  promoted immutable model artifact, and a valid LLM credential; no
  placeholder or unlicensed fallback was introduced.
- Validation passed: UI/navigation 4/4, Paddle contracts 6/6,
  auth/LLM/quant contracts 10/10, TypeScript typecheck, Next.js production
  build, Rust formatting and Clippy with warnings denied, 294 Rust tests, and
  Python 26 passed / 5 skipped. CMake was unavailable for this run, so the
  native C++ suite was not rerun.
- The temporary EC2 transfer file, local transfer archive, GitHub release, and
  temporary release tag were permanently removed after verification. The
  rollback image was intentionally retained.

## 2026-07-26 -- Market Emotion proxy and obsidian intraday UI

- Upgraded the existing decision-neutral behavioral layer to
  `axio.behavioral-state.v3` and added the Rust-owned
  `axio.market-emotion-proxy.v1` publication contract.
- The displayed 0–100 value is a raw compatibility index for aggregate
  market-response patterns (`STRESS_LIKE`, `CHASE_LIKE`, `CROWDING_LIKE`,
  `ATTENTION_SHOCK_LIKE`, `REBOUND_SQUEEZE_LIKE`, or
  `MIXED_OR_CONFLICTED`). It is not a calibrated probability, direct human
  psychology observation, participant share, or actor attribution.
- Publication fails closed unless the finalized one-minute bar's provider
  availability is verified and causally aligned, price/volume/cross-asset
  coverage is complete, all six component indices are finite, the top pattern
  has at least five raw-index points of separation, no behavioral probability
  is present, and `affects_decision=false`.
- The live-artifact validator binds the displayed label, raw index, score
  margin, coverage, source scope, and publication timestamp to the canonical
  behavioral layer. Missing or malformed evidence produces `WITHHELD` with a
  null display value.
- `/quant/intraday` now has a route-owned full-width obsidian shell instead of
  inheriting the warm background, `max-w-5xl` constraint, and duplicate global
  footer. The global navigation receives a route-scoped dark glass treatment.
- The forecast is the dominant visual object. A Market Emotion panel sits
  beside it with a low-frequency animated halo, raw compatibility ring, top
  Rust pattern scores, availability status, as-of time, coverage, and explicit
  non-probability caveat. All motion stops under `prefers-reduced-motion`.
- Existing lower workspaces are recolored through a scoped quant palette;
  their data semantics and tab contracts are unchanged. No competitor source,
  copy, logo, or brand asset was copied.
- The behavioral proxy remains outside the frozen 12D analog feature schema,
  expected-return model, probability calibration, and decision policy. No
  model was promoted and automatic execution remains disabled.
- Rollback condition: if the v3 proxy fails timestamp/source/coverage binding,
  the API rejects the live artifact and the UI shows `WITHHELD`; the visual
  shell can be reverted independently without changing Rust forecast math.
- Validation passed: Rust formatting and Clippy with warnings denied; 277 Rust
  library tests, 8 `quantctl` tests, and 12 integration tests (297 total);
  Python 26 passed / 5 skipped; TypeScript typecheck; Next.js production build;
  and the routed-mock Chromium UI contract across desktop, 390px mobile,
  promoted binary-P(up), and analogue states. The browser receipt has zero
  blocking console/network errors, verifies reduced-motion behavior, and
  rejects both document-level overflow and internally clipped mobile headline
  tracks. CMake was unavailable for this run, so native C++ checks were not
  rerun. The browser smoke is not a live gateway, entitlement, freshness, or
  licensed-market-data end-to-end receipt.

## 2026-07-26 -- Exact multi-symbol live artifact orchestration

- Resolved the code-side single-SPY worker gap recorded in the external model
  review. Both live workers now load `data/models/universe/registry.json` and
  select frozen predictors only by the exact canonical `model_symbol`.
- The Massive worker owns one bounded incremental feature engine and one
  frozen predictor per configured forecast symbol. One missing, invalid, or
  target-mismatched artifact, or one feature-engine initialization failure,
  disables only that symbol while licensed market-data capture and the other
  symbols continue.
- The legacy Moomoo forward-shadow worker uses the same exact symbol-keyed
  artifact map. It cannot reuse the SPY predictor when another configured
  symbol is missing.
- Registry metadata is checked against each artifact's target, artifact
  version, and model hash after the artifact's existing static content-hash
  validation. The existing inference-time dataset-manifest, causality,
  freshness, calibration, and promotion gates remain unchanged.
- Windows-written registry paths are normalized for the Linux production
  container, and future universe registries write portable `/` separators.
- This change does not promote any candidate artifact, alter the public market
  data license gate, enable execution, or create substitute artifacts.
- Validation passed: Rust formatting, warning-free Clippy, 281 library tests,
  8 `quantctl` tests, and 12 integration tests.

## 2026-07-26 -- Mobile fail-closed UX and sanitized readiness receipt

- Replaced the raw mobile `DATA_UNAVAILABLE` response with a compact
  `Result withheld` card. The user-facing sentence explains that AXIO7 did not
  publish a ranking because required licensed, current, and validated evidence
  is unavailable.
- Moved machine blocker codes into collapsed technical details, made the codes
  copyable, and added defensive wrapping so long identifiers cannot widen or
  clip the document on narrow screens.
- Removed the empty `0 items` evidence section from withheld responses while
  preserving the audit ID, cutoff, availability, freshness, coverage, model
  version, and material-caveat contract whenever those fields are available.
- Added the research-token-protected
  `GET /api/v1/system/readiness` endpoint and embedded the same sanitized
  receipt in the system-status response. It aggregates license, entitlement,
  feed/stream freshness, promotion, calibration, ledger, and exact-symbol
  forecast readiness without exposing secrets, URLs, hashes, or credentials.
- LLM authentication is reported as `EXTERNAL_UNKNOWN` because it is owned by
  the web runtime rather than the Rust service. The receipt does not infer a
  successful provider login from configuration alone.
- Updated visible home, account, billing, legal, and support copy to describe
  AXIO7 as an impersonal quantitative market-research system. Starter, Pro,
  and Advanced now share the same core research capability; the tiers no
  longer imply different mathematical models or fabricated model access.
- `/learn` and `/about` now return to the research workspace, while `/quant`
  enters `/quant/intraday`. Robots and sitemap entries match that navigation.
- Updated the Paddle provisioning source to research-oriented product names
  and descriptions. A Live API update was deliberately not forced after the
  existing credential returned HTTP 403 for all three metadata-only PATCH
  requests; zero Paddle products or prices were partially changed. The
  remaining external action is `Products: Write` permission or an equivalent
  dashboard metadata update.
- Local validation passed: TypeScript typecheck; Next.js production build;
  23 JavaScript contract tests; Rust formatting, warning-free Clippy, 286
  library tests, 8 CLI tests, and 12 integration tests; and Python 26 passed /
  5 skipped. CMake was unavailable.
- A 390x844 Chromium contract test confirmed no horizontal overflow,
  technical details collapsed by default, and safe wrapping after expansion.
  This was a routed local smoke, not a claim of licensed live-model readiness.

## 2026-07-26 -- Pricing action availability repair

- Corrected the Paddle configuration-error branch so it no longer removes the
  Starter, Pro, and Advanced membership cards or their subscription actions.
- A local or preview runtime without Live Paddle credentials now shows the
  documented USD list prices and sends each subscription action to the
  configured Live AXIO7 pricing surface. A fully configured production runtime
  still uses Paddle `PricePreview`, the exact allow-listed Price ID, and the
  existing verified transaction/webhook fulfillment path.
- Added a UI contract regression test requiring membership actions in the
  configuration-error branch. This does not relax checkout, entitlement, or
  payment-event validation.
- Validation passed: TypeScript typecheck, 8 UI/navigation contracts, the
  Next.js production build, a headless Chromium check of all three visible
  actions plus a real navigation to the Live pricing surface, Rust formatting,
  warning-free Clippy, 296 library tests, 8 CLI tests, 12 integration tests,
  and Python 26 passed / 5 skipped. CMake was unavailable for this run.

## 2026-07-26 -- ICPC-level model and numerical-method review package

- Added `docs/handoffs/icpc-gold-model-review-2026-07-26/` as an owner-mediated
  review package. It is not assigned or sent to an external reviewer by the
  system; the repository owner chooses the recipient.
- The package inventories the implemented diagonal-Gaussian HMM, scaled
  forward/backward, Baum-Welch soft EM, causal filtering, diagnostic Viterbi,
  12-dimensional same-regime adaptive Gaussian-kernel regression,
  Markov-switching log-return diffusion, VWAP-residual OU process, traditional
  supervised challengers, neural candidates, calibration, and research-only
  model families.
- The package explicitly distinguishes implemented, shadow-only,
  research-only, unpromoted, and not-implemented methods. In particular,
  Baum-Welch is the implemented HMM EM optimizer; no Bayesian/PyMC/Stan,
  LSTM/GRU, LightGBM, XGBoost, or CatBoost implementation is claimed.
- The earlier single-SPY live-routing finding is marked resolved in code and
  moved to independent verification: both live workers now use the
  exact-symbol universe loader and per-symbol failure isolation.
- Remaining review blockers include HMM state selection reaching the tested
  boundary, unavailable immutable promotion/calibration artifacts, Massive
  SIP/OPRA entitlement failure, missing Massive in-loop outcome settlement,
  no continuous Rust PostgreSQL live archive, readiness coupling, child-process
  supervision, incomplete point-in-time options data, and TypeScript quant
  boundary cleanup.
- A prior Linear assignment to Yuan Mei was removed, and Yuan Mei was removed
  from the issue subscriber list. The issue remains an unassigned internal
  record; this review package is intended for manual owner delivery.
- Package-generation validation passed Rust formatting, warning-free Clippy,
  286 library tests, 8 CLI tests, 12 integration tests, Python 26 passed /
  5 skipped, and TypeScript typecheck. Two Next.js build attempts exceeded the
  60-second command window and were terminated; the resulting
  `.next/export-detail.json` reported `success:false`, so this run does not
  claim a successful production build. CMake remained unavailable.
- Published a data-free source snapshot and the review package to the private
  `ErwinHe7/Argus` repository as draft PR `#1` from
  `agent/axio7-model-review` into the empty `main` baseline. The handoff
  excludes historical/live observations, databases, generated outputs,
  secrets, and environment files.
- After owner confirmation, added all nine unpromoted exact-symbol frozen
  candidate artifacts and the legacy comparison artifact. Structural review
  confirmed that these files contain parameters, hashes, training lineage,
  and analog training-row indexes rather than raw market observations. Added
  a 24-entry model-to-source map and clone/test instructions so the reviewer
  can modify implementation code rather than receiving documentation alone.
  The authoritative handoff commit is
  `d9128416a0eef8aa0eca21bbab7107e06115e1d6`.

## 2026-07-26 -- Verified web-to-Rust model-runtime connection

- Replaced the website's configuration-only Rust connectivity probe with
  `axio.model-runtime-receipt.v1`. The Rust research-universe endpoint now
  loads and statically validates every exact-symbol frozen artifact before the
  Next.js status route can report `CONNECTED`.
- The connection receipt exposes only status, requested/loaded/failed counts,
  symbol-level sanitized reason codes, the separate quality/promotion boundary,
  and the disabled execution state. It does not expose credentials or raw
  loader errors.
- The first real runtime probe correctly rejected all nine files and exposed a
  latent compatibility defect: the artifact self-hash was being recomputed
  from the current deserialized Rust structure. Additive defaults in nested
  serializable types changed that in-memory representation after the immutable
  files were generated, so valid source files were falsely rejected.
- Frozen-universe loading now validates the hash against the original immutable
  JSON value while retaining artifact-version, model-version, target,
  feature-schema, HMM, regime-selection, analog-index, stochastic-lineage,
  registry model-hash, and exact-symbol checks. It does not regenerate,
  substitute, or silently repair a model artifact.
- The Next.js probe reports connected only when all configured models load,
  loaded count equals requested count, failed count is zero, the Rust ownership
  boundary matches, and automatic execution is disabled. Partial or malformed
  receipts return HTTP 503 and fail closed.
- The research UI now displays model runtime connectivity separately from
  market-data and publication eligibility. A request may truthfully show
  `Rust model connected` and `Result withheld` together, with the model version,
  feature contract, registry state, and exact artifact count visible in the
  model runtime contract.
- The local release stack was rebuilt and restarted. The live local status
  receipt reported `LOADED`, 9/9 exact frozen artifacts, zero failures, Rust
  ownership, and execution disabled. A real Chromium request for `NVDA`
  traversed the Next.js `/api/ask` proxy and Rust query endpoint, rendered the
  9-artifact runtime contract, and still withheld the ranking because the
  public redistribution license gate is not configured.
- No model was promoted, no probability gate was weakened, no unlicensed or
  synthetic market data was introduced, and automatic execution remains
  disabled. Rollback/fail-closed condition: any missing, rejected, partial, or
  incompatible runtime receipt makes the website display `Model offline`.
- Validation passed: TypeScript typecheck; Next.js production build; 25
  JavaScript contracts; Rust formatting; warning-free Clippy; 288 Rust library
  tests, 8 CLI tests, and 12 integration tests; Python 26 passed / 5 skipped
  using the repository virtual environment; the direct Rust runtime smoke; and
  the live local Chromium web-to-Rust smoke with zero console errors. CMake was
  unavailable, so native C++ checks were not rerun.
- Production deployment completed on `axio7.com`. The running web image is
  `sha256:e02564d3314e82e7bf740654600e079f767fadc18917c616db50517288e04818`
  and the running Rust image is
  `sha256:1b17544604575ffc680c363773e0d4d9eeda0eddec7ccce644f5a569d6c3a5b2`;
  both services reported healthy after recreation.
- The public status route returned `CONNECTED`, `LOADED`, 9 requested, 9
  loaded, zero failed, Rust ownership, and execution disabled. A production
  Chromium request for `NVDA` completed without console errors and displayed
  the 9-artifact runtime contract while independently withholding the
  unlicensed live result.
- Server-side rollback tags
  `axio7-web:rollback-pre-model-backend-20260726` and
  `axio7-quantd:rollback-pre-model-backend-20260726` retain the exact images
  that were running immediately before this deployment.

## 2026-07-26 -- Databento historical credential and owner-only IBKR gateway

- Verified the owner-supplied Databento API credential through the canonical
  Rust `quantctl data cost` path without printing or committing the secret.
  The configured 14-symbol `EQUS.MINI` one-minute request from 2023-03-28
  through 2026-07-19 estimated 4,608,089 records, 258,052,984 bytes, and
  USD 2.883966833353. No download or charge was started because an explicit
  maximum-cost confirmation is still required.
- Added `DATABENTO_API_KEY` to the Rust container's server-side environment
  contract. The credential remains absent from tracked configuration,
  fixtures, browser bundles, application logs, and generated receipts.
- Added a checksum-pinned build of the official IBKR Client Portal Gateway.
  Port 5000 is published only on VM loopback for an operator SSH tunnel; Caddy
  does not expose it. The Compose network permits the web server to reach the
  gateway, while the gateway container remains read-only with bounded JVM
  memory and a non-root user.
- Added an administrator-only IBKR health/session indicator and owner snapshot
  panel to the research workspace. The corresponding health, Level 1, and
  options routes now require an authenticated AXIO7 administrator. Failed IBKR
  requests cannot silently substitute Yahoo or another retail feed.
- IBKR observations expose provider, observation cutoff when supplied by the
  gateway, server availability time, freshness/session state, Level 1 coverage,
  license scope, and caveats. Outside the US regular-session window the UI says
  `outside regular session`; it does not relabel a prior close as realtime.
- This phase connects authenticated owner market data to the website, not to
  public redistribution. The public Rust research result remains fail-closed
  until an appropriate customer-facing market-data license and fresh native
  forecast artifacts are available. Automatic execution, live broker routing,
  and anomaly order execution remain disabled.
- Local verification passed: TypeScript typecheck; 28 JavaScript contract
  tests; checksum-pinned gateway image build; gateway startup on loopback;
  unauthenticated gateway HTTP 401 readiness behavior; 74.58 MiB observed
  gateway memory; and the Compose configuration contract.
- Production deployment completed on `axio7.com`. The running web image is
  `sha256:9da9fb6fb40ab06c3fa794d0e60a4a2d0c6d74ce93810ef1c12bd8da73ce2b04`;
  the IBKR Gateway image is
  `sha256:e371c22d7079630eed14681a7ffeb59b9fd9d2f60950474c113049a4c0da9b36`;
  and the unchanged Rust image is
  `sha256:1b17544604575ffc680c363773e0d4d9eeda0eddec7ccce644f5a569d6c3a5b2`.
  All three services reported healthy and the public homepage returned HTTP
  200.
- A production Chrome check in the authenticated administrator session showed
  `Rust models connected`, 9/9 validated frozen artifacts, `IBKR login
  required`, and the owner-only market-data panel with execution disabled.
  No browser console errors were recorded. The loopback SSH tunnel is active
  and the official Gateway login tab was handed to the owner.
- Remaining operator action: accept the local Gateway certificate page and
  complete IBKR browser login plus 2FA. A Sunday verification can prove
  authentication and last-snapshot access, but only an open market can prove a
  fresh regular-session observation. Rollback image
  `axio7-web:rollback-pre-ibkr-owner-data-20260726` retains the prior web
  release.

## 2026-07-26 -- Server-side Databento live adapter and production receipt

- Added an official Databento Rust `LiveClient` adapter owned by
  `quant_engine_rs`. It subscribes only to the configured
  `EQUS.MINI/ohlcv-1m/raw_symbol` universe, requests no replay, persists a
  bounded normalized JSONL bar artifact, and maintains an atomic stream-status
  receipt.
- Configuration validation now accepts Databento only when the audited
  EQUS.MINI request exists and every live symbol is present in that request.
  The existing quote-only, trade-API-disabled, staleness, log-rotation, and
  automatic-execution-disabled controls remain mandatory.
- Every accepted bar carries provider, dataset/schema, bar cutoff, AXIO7
  availability time, entitlement acknowledgment, delayed/stale/replay flags,
  point-in-time symbol-mapping verification, coverage, and caveats. Stale,
  future-timestamped, delayed, replayed, unmapped, unentitled, or disconnected
  input fails closed and cannot reach inference.
- Added administrator-only `GET /api/market/databento/health`, backed by the
  Rust `/api/v1/live/status` and `/api/v1/live/bars` endpoints. The research
  workspace now displays Databento entitlement separately from the 9/9 frozen
  model receipt and the IBKR verification session. It never substitutes a
  historical or delayed price.
- A real local and production authentication probe reached Databento and was
  rejected with `A live data license is required to access EQUS.MINI`. The
  Databento portal showed no active subscriptions, a USD 199/month starting
  price for Databento US Equities live access, and USD 125 in remaining
  credits. No subscription was purchased because the credit does not cover the
  listed monthly price and the recurring paid commitment was not confirmed.
- The owner-completed IBKR browser login continued to leave
  `/iserver/auth/status`, `/tickle`, and `/portfolio/accounts` at HTTP 401.
  Therefore the ordinary portal/browser success page was not treated as an
  exportable Client Portal API session, and no broker credential was copied
  into the website.
- Production deployment completed on `axio7.com`. The running web image is
  `sha256:05f39019964ef651aa4fd585c77af9089a60a5bbef37e88ecca047880e4f7449`
  and the running Rust image is
  `sha256:e439add181d94f7f1b20886cfac479113a5bf3223027ebd0ad1cfe0a0be26609`.
  Both services reported healthy. The production administrator page showed
  `Rust models connected`, the exact Databento live-license blocker, the IBKR
  API-session blocker, and disabled execution. A production `NVDA` request
  traversed the Next.js-to-Rust path and displayed the 9-artifact runtime
  contract while correctly withholding an unlicensed market result.
- Validation passed: TypeScript typecheck; Next.js production build; the
  administrator/private-market-data contract suite; Rust formatting;
  warning-free Clippy; 291 Rust library tests, 8 CLI tests, and 12 integration
  tests; and Python 26 passed / 5 skipped. CMake was unavailable, so native C++
  checks were not rerun. Rollback images
  `axio7-web:rollback-pre-databento-live-20260726`,
  `axio7-web:rollback-databento-live-v1-20260726`, and
  `axio7-quantd:rollback-pre-databento-live-20260726` retain the immediately
  preceding production states.

## 2026-07-26 -- Credit-funded Databento history and IBKR outbound quote relay

- Used the existing Databento account credit, with an explicit USD 5 safety
  maximum, for the audited `context_etf_ohlcv_1m` historical request. The
  request covers 14 symbols from 2023-03-28 through 2026-07-19 and was
  estimated at USD 2.883966833353. No monthly or recurring Databento
  subscription was purchased.
- The compressed raw artifact is 75,263,685 bytes. Its manifest is
  `context_etf_ohlcv_1m__20260726T193121Z.manifest.json`; the downloaded
  artifact checksum matches that receipt and the receipt records
  `synthetic=false`. The credential and full artifact checksum are not
  recorded here.
- Canonical Rust bar validation accepted all 4,608,089 decoded one-minute rows
  with zero rejected rows and zero duplicates. Coverage contains exactly the
  14 requested symbols with no unresolved instrument identifiers. The
  normalized CSV is 472,076,044 bytes.
- The AWS instance did not have enough memory for a second in-memory validation
  pass and the audit container exited 137. Instead, the production decode was
  compared byte-for-byte to the locally canonical-validated CSV with SHA-256;
  both checksum and byte count matched. The file was then atomically installed
  as the production `market_bars.csv`. The running Rust container sees
  4,608,090 CSV lines including the header, and its protected coverage endpoint
  reports `real_vendor_bars_ready=true`.
- Historical account credit does not unlock Databento realtime access or
  customer-facing redistribution. The Databento live adapter remains
  fail-closed without a live license; the historical file is available only
  to historical/backtest research paths and is never labeled realtime.
- Reproduced the IBKR Client Portal Gateway login locally. The browser reported
  login success, but the official Gateway then received HTTP 401 `Access
  Denied` from `/sso/validate`; brokerage auth, account, and market-data
  endpoints consequently remained unavailable. AXIO7 did not treat the outer
  login page as an authenticated brokerage API session and did not attempt
  session takeover, account funding, or trading.
- Added a quote-only local-to-cloud relay contract so a future valid owner
  session can send allow-listed Level-1 bid/ask snapshots over outbound HTTPS.
  The relay excludes cookies, account state, positions, orders, and trading
  methods; Rust rejects stale, delayed, frozen, unentitled, malformed, or
  incomplete batches before persistence. Quote data is not promoted to
  one-minute OHLCV and does not drive the model without a separately validated
  causal bar finalizer. Automatic execution remains disabled.
- Production deployment completed on `axio7.com`. The running web image is
  `sha256:37b36d99b2089bf8ec91cfc2e8d6cd9d441823be50cf1059f743ebe4d8be4efa`
  and the running Rust image is
  `sha256:224617a0d83902b47e531f0a9f2c895f05c27c4905c8ab04b100e2557a4e5aea`.
  Web, Rust, and the unchanged IBKR Gateway reported healthy. Production
  receipts reported 9/9 models loaded, eight manifests,
  `real_vendor_bars_ready=true`, an empty quote-only relay receipt, and
  execution disabled.
- Public contract probes returned HTTP 200 for the site and model status, HTTP
  401 for unauthenticated relay reads and wrong-token writes, and HTTP 422 when
  a valid relay token submitted a payload outside the Rust
  `deny_unknown_fields` schema. A real one-shot local bridge probe stopped
  fail-closed at the IBKR Gateway HTTP 401 and posted no quote batch.
- Validation passed: TypeScript typecheck; Linux/AMD64 Next.js production
  build; six targeted IBKR Node contracts; six Python relay tests; Rust
  formatting; warning-free Clippy; 296 Rust library tests, 8 CLI tests, and 12
  integration tests.
  Rollback images `axio7-web:rollback-pre-ibkr-relay-20260726`,
  `axio7-quantd:rollback-pre-ibkr-relay-20260726`, and
  `axio7-web:rollback-pre-ibkr-relay-allowlist-20260726`, plus the corresponding
  Compose backup, retain the immediately preceding production states.
- Corrected the external-review delivery after the empty `main` baseline caused
  the repository landing page to appear blank. Generated candidate artifact
  JSON files were consolidated into a SHA-256-verified 4,668,881-byte ZIP,
  reducing the GitHub comparison from roughly 2.0 million generated lines to
  69,358 actual source/documentation additions without removing model code or
  artifacts.
- Squash-merged Argus PR `#1` into the default `main` branch at
  `a30b221fde84f5ba45da8510e42207d1e4190b79`, then updated the reviewer
  instructions through `baab9fb7c29d5de82e218faf67777e181ff347fc`.
  GitHub collaborator `Shiccovo` was independently confirmed with `write`
  permission; no replacement invitation was necessary.

- Follow-up Argus PR `#2` restores the 12 frozen/candidate JSON artifacts at
  their directly loadable `quant_engine_rs/data/models/` runtime paths while
  preserving the verified ZIP. The generated analog-index lines are retained
  intentionally and marked as generated in GitHub; they are model artifacts,
  not raw vendor observations.
- The PR matches 137 editable model/runtime source files plus 12 artifacts
  against the current AXIO7 workspace by same-path SHA-256: 149/149 files, zero
  missing, zero extra, and zero mismatches. It adds the current Databento,
  Massive, IBKR quote-only relay, readiness/store/manifest source, Python report
  modules, and native runtime configuration.
- Argus draft PR `#2` is open at `https://github.com/ErwinHe7/Argus/pull/2`;
  collaborator `Shiccovo` was explicitly requested as reviewer and retains
  write access. Validation passed Rust fmt, warning-free Clippy, all 316 Rust
  tests, and Python pytest with 26 passed and 5 skipped. C++ was not run because
  CMake is unavailable on this machine.
- Added an explicit reviewer navigation layer without renaming canonical model
  modules: root entry
  `00_START_HERE_MODEL_STACK__HMM_KERNEL_SDE_OU.md` and seven plainly named
  `MODEL_COMPONENTS/` directories now identify HMM, 12D kernel regression,
  Markov-switching SDE, VWAP-residual OU, neural challengers, calibration, and
  research models. This changes documentation only; production imports,
  implementation files, and artifact hashes remain unchanged.

## 2026-07-26 -- Authentication and Paddle membership production switch

- Production pricing now exposes exactly three Paddle-backed tiers: Starter at
  USD 49/month, Pro at USD 149/month, and Lifetime at USD 1,999 as a one-time
  purchase. The live Starter checkout opened successfully and displayed the
  Paddle-hosted payment form; no payment was submitted during verification.
- Applied `024_paddle_lifetime_access.sql` to the production Supabase project.
  Readiness, the lifetime entitlement RPC, and nullable one-time transaction
  storage all returned `true`.
- Replaced the website runtime Paddle key with a least-privilege key containing
  four read and four write permissions for prices, customers, subscriptions,
  transactions, and customer-portal sessions. It has no adjustment read or
  write permission. The temporary product/price deployment key and the prior
  EC2 runtime key were revoked after the new catalog and runtime key passed
  live API checks.
- Recurring cancellation is fixed to the next billing period. The AXIO7
  customer UI contains no refund or refund-request action and does not call the
  Paddle adjustment API. The active webhook destination now subscribes to 13
  events, including `adjustment.created` and `adjustment.updated`, so
  Paddle-reviewed outcomes still revoke or preserve access correctly.
- Production deployment completed on `axio7.com`. The running web image is
  `sha256:99b19eaa59932d208c8f568bfbc75861b9c0be0feb17338a9351293d71a5da0b`
  and reported healthy. Public smoke checks confirmed all three prices and
  purchase buttons, the hosted Starter checkout, the final-sale policy, and
  `heguantao565@gmail.com` on the support and refund-policy pages.
- Google OAuth reached Google's account chooser with the callback return fixed
  to `https://axio7.com/auth/callback?next=%2Fpricing`. Apple is intentionally
  unavailable in the public sign-in UI instead of exposing Supabase's
  unsupported-provider error. The current Apple Account can access the free
  Developer account but is not enrolled in the Apple Developer Program, so
  Apple web OAuth credentials cannot be created until the owner explicitly
  approves and completes Apple's paid enrollment.
- Validation passed: 16 targeted Paddle/auth contract tests, TypeScript
  typecheck, Linux/AMD64 Next.js production build, production Paddle price
  read, Supabase lifetime readiness query, container image identity/health,
  and public pricing/auth/policy smoke checks. The rollback image
  `axio7-web:rollback-pre-auth-billing-refund-20260726` retains the preceding
  production state.

### 2026-07-26 -- Paddle automatic-checkout repair and permanence guard

- Repaired the live Paddle checkout path without changing the catalog or
  fulfillment boundary. The client now passes only the server-created
  transaction ID to `Paddle.Checkout.open`; it no longer supplies a second
  customer email that can conflict with the transaction's authenticated Paddle
  customer.
- Removed the invalid attempt to update a reusable Paddle transaction from
  `draft` to `ready`. Paddle Checkout collects the required billing fields and
  performs that transition itself. Existing `draft`, `ready`, and `past_due`
  transactions remain reusable so repeated clicks do not create duplicate
  subscriptions.
- Added a repository-level billing permanence contract: Paddle remains the
  canonical production provider; `/pricing` must retain working Starter, Pro,
  and Lifetime purchase actions; recurring plans keep automatic renewal; and
  access changes only after verified Paddle webhook events. Products, prices,
  credentials, webhook handlers, billing routes, migrations, and catalog
  mappings must not be deleted or archived without an explicit owner-approved
  migration and rollback plan.
- Confirmed that the public production origin is the AWS/Caddy deployment at
  `18.225.108.70`. The repaired web image
  `sha256:99b9a796fbbac7b5ffa8b4943902d0c242bbae6bd7f7509f6a920eca46033efb`
  is healthy. Rollback tags
  `axio7-web:rollback-pre-paddle-auto-payment-20260726` and
  `axio7-web:rollback-pre-paddle-draft-fix-20260726` retain the two immediately
  preceding states.
- Live verification opened the visible Paddle hosted-checkout overlay for the
  Starter subscription using the existing production transaction
  `txn_01kyg8321d13mx0dwa1rkvajys`. The prior checkout error did not recur, and
  no payment details were entered or submitted.
- Validation passed: 16 targeted Paddle/navigation contract tests, TypeScript
  typecheck, a Linux/AMD64 Next.js production build, deployed-container image
  identity and health, and the authenticated public checkout smoke test.

## 2026-07-26 -- External-review model, ledger, and deployment hardening

- Resolved the Python/Rust analog ambiguity by choosing the audit's safe
  downgrade path rather than claiming estimator parity. The canonical serving
  analog remains Rust. The distinct Python mean/std Euclidean estimator is
  renamed `legacy_exploratory_euclidean_analog`, removed from shipped model
  lists, marked `promotion_eligible=false` and `production_parity=false`, and
  excluded before ensemble/selection. The ambiguous `analog_kernel` config
  name is rejected. It may be explicitly opted into only as non-promotion
  offline research until a real Rust CLI/FFI parity fixture and golden test
  exist.

- Upgraded the prediction ledger to transactional schema version 2. Startup
  now audits legacy rows for more than one settlement per prediction before it
  creates the one-settlement unique index. A duplicate legacy database fails
  with `PREDICTION_LEDGER_MIGRATION_BLOCKED_DUPLICATE_SETTLEMENTS`; the
  transaction rolls back and preserves every original row and `user_version`.
- Prediction retries now treat only `created_at`, `decision_as_of`,
  `latest_input_available_at`, and `earliest_executable_time` as retry-varying.
  Settlement retries treat only `settlement_id` and `settled_at` as
  retry-varying. Every caller consumes and returns the first canonical ledger
  payload; any other difference remains an immutable collision and fails
  closed.
- `/ready` now fails on a nonempty or malformed supervisor blocker and declares
  `readiness_scope=supervisor_connection` with
  `bar_freshness_evaluated=false`. Finalized-bar freshness, model artifacts,
  coverage, and publication eligibility remain owned by the authenticated
  production-readiness receipt.
- Massive v2 receipts are consumed by separate equity and options scopes.
  General equity research requires `equity_realtime_ready`; gamma-specific
  research continues to require combined `production_ready`. The combined
  value is accepted as an equity/options fallback only for an explicitly
  versioned v1 receipt. Responses expose both scoped values so an OPRA denial
  cannot silently disable or masquerade as SIP readiness.
- The single-VM entrypoint now acquires a nonblocking `flock` lease on the
  persistent quant-state volume before starting `quantd`. The images install
  Bash and util-linux, `tini -g` forwards signals to the process group, Bash
  `wait -n -p` reaps the first failed child instead of polling zombies, and
  shutdown terminates then waits for every known child. Massive equity and
  options workers run independent readiness gates; historical bars and the
  universe registry constrain only the equity model worker.

Verification completed locally: Rust formatting; warning-free Clippy across
all targets; binary compilation; 316 library tests, 8 CLI tests, and 12
integration tests; Python 32 passed with 5 optional-dependency skips; Bash and
POSIX shell syntax; Bash child-reaping primitive; and full Docker Compose
configuration expansion. No production rollout was performed by this change.

Deployment/rollback condition: quiesce `quantd`, back up the SQLite database
together with its WAL and the rest of the quant-state volume, and confirm the
legacy duplicate audit passes before replacing the running image. Keep one
replica; the runtime lock is the second fail-closed defense. If migration is
blocked, retain the untouched volume for diagnosis. Rolling back across schema
versions requires restoring the matching quiesced database/WAL backup; never
delete ledger rows, the v2 unique index, or append-only triggers as cleanup.

## 2026-07-26 -- External audit B1-B6 and M1-M3 remediation

Scope: this work addresses every verified item present in the attached review
summary. The referenced `axio7-model-review/review-package/REMEDIATION-PLAN.zh-CN.md`,
`fix/handoff-buildable` branch, and the M4-M12/D1-D5 details were not present in
this checkout or its configured remotes, so those unseen findings are not
claimed as remediated.

- B1/B2: root runtime ignores are anchored, nested source directories are no
  longer ignored, and a source-integrity guard now runs in pre-commit and CI.
  The owner working tree contains the real 15-file Rust data layer, contains no
  `todo!`/`unimplemented!` stubs there, and defines
  `massive_full_option_chain.v2`. However, `git ls-files` still reports zero
  tracked files in `quant_engine_rs/`, `intraday_quant/`, and
  `quant_core_cpp/`. Local verification is therefore not yet an externally
  reproducible branch snapshot; a scoped review commit followed by a clean
  checkout run remains a release gate.
- B3: `cutoff - latest.event_at <= max_age` was retained unchanged because it
  is the correct expression once the real data types are available.
- B4/B5/B6: native CMake accepts either official SQLite imported-target name;
  the Python base package remains torch-free while the `neural` extra declares
  CPU-compatible PyTorch; clean-checkout CI now covers source integrity, web,
  Rust, base and neural Python, and native C++ checks. `uv.lock` was not
  regenerated because the required package metadata was unavailable offline;
  regenerate it with approved registry access before treating uv as a locked
  install path.
- M1: the production Gaussian HMM now performs emission, forward/backward,
  gamma, xi, filtering, and Viterbi calculations in log space. It no longer
  clamps underflow to `1e-300` or resets an underflowed row to a plausible
  uniform posterior. Failed EM restarts are discarded, and final restart
  ranking recomputes likelihood/BIC from the final parameters. Extreme-density
  likelihood parity is covered at `1e-9` tolerance.
- M2: all four selection paths call one occupancy-gated candidate selector.
  Selection uses a global validation-likelihood or training-BIC mode, a 1%
  minimum occupancy rule, deterministic smaller-K tie breaking, an expanded
  2-12 grid, and final-refit occupancy revalidation. Frozen predictor v3 is the
  only accepted inference contract. Existing v1/v2 artifacts remain readable
  for diagnosis but are rejected for inference and must be retrained and
  independently promoted.
- M3: the Python implementation is now named
  `LegacyExploratoryEuclideanAnalogModel`, is absent from defaults, is marked
  non-parity/non-promotion, and cannot enter the selected ensemble or trade
  blotter. Rust remains the canonical serving implementation. One inventory
  CSV remains stale because another process holds an exclusive file lock; it
  was not force-unlocked.
- Deployment: the control plane remains loopback-only. The supported container
  topology is the documented single-VM shared network namespace, not direct
  Railway public exposure. SQLite/state volumes are persistent, prediction and
  settlement retries are semantically idempotent, legacy duplicate settlement
  migration fails closed, one replica is enforced twice (Compose and `flock`),
  child failure terminates the container, and equity/options entitlement gates
  are independent. No production deployment was performed.

Verification: `npm run typecheck` and the 65-page Next.js production build
passed; Rust formatting, warning-free all-target Clippy, binary checks, 316
library tests, 8 CLI tests, and 12 integration tests passed; Python reported 32
passed and 5 skipped, with 10 neural CPU tests passed; the native GCC 16 build
passed warnings-as-errors and all 11 C++ tests; source-integrity, shell syntax,
PowerShell parsing, and Docker Compose expansion passed. Docker image build was
not run because the local Docker named pipe was inaccessible. No model was
promoted, no automatic execution was enabled, and no live-data readiness claim
was made.

## 2026-07-27 -- Auditable release snapshot and v3 candidate retraining

- Created source snapshot `81a91f5490c78254c1b3e5b241c5df9aa6b86cb8` from an explicit 430-file allow-list. The snapshot now tracks 104 Rust, 61 Python, 8 native C++, and 11 infrastructure files; raw/normalized/live runtime data, SQLite/WAL files, build products, local environments, and unrelated scratch trees remain excluded. The source-integrity hook and CI guard pass.
- Regenerated and committed `intraday_quant/uv.lock`. The base environment remains torch-free while the separately locked `neural` extra owns PyTorch.
- Reverified the complete implementation before artifact generation: the 65-page Next.js production build and TypeScript check passed; 57 web/auth/Paddle/market contracts passed; Rust formatting, all-target warning-free Clippy, 319 library tests, 8 CLI tests, and 12 integration tests passed; Python reported 32 passed / 5 optional skips plus 10/10 neural CPU contracts; the warnings-as-errors native build and all 11 C++ assertions passed.
- Retrained all nine configured public targets with the v3 log-space, occupancy-gated selector and embedded source commit `81a91f5490c78254c1b3e5b241c5df9aa6b86cb8`. All selected candidates satisfy the 1% causal filtered-posterior occupancy floor. IGV selected an internal K=11 optimum. SPX, QQQ, NVDA, AAPL, MU, SOXX, NBIS, and BE still select K=12 at the tested boundary and retain `STATE_COUNT_OPTIMUM_IS_NOT_ESTABLISHED`.
- The registry remains `CANDIDATE_ARTIFACTS_NOT_PROMOTED`, execution remains disabled, and no calibration or model was promoted. The eight unresolved boundary results must continue to fail closed; they are evidence that the original M2 symptom is now detected rather than hidden, not evidence for publication.
- Production diagnosis confirmed `axio7.com -> Caddy -> Next.js -> loopback Rust quantd` is connected. The running Databento account has no active live subscription and the server reports `A live data license is required to access EQUS.MINI`; the public redistribution/model-use license reference and pinned promotion registry hash are also absent. No Yahoo, delayed-as-realtime, synthetic, or retail-broker substitute may be enabled.
- Paddle remains the production billing provider. Current Starter, Pro, and Lifetime catalog completeness is validated from the three current prices; legacy prices are webhook compatibility only. The single-VM environment generator now preserves an existing production environment atomically and fails before write when any required Paddle variable is absent.

Deployment condition: preserve the production `.env.server`, quiesce quantd, capture the SQLite/WAL plus complete `quant-state` and `quant-live` volumes, retain rollback image/config tags, and deploy one replica only. The public result must remain `DATA_UNAVAILABLE` until both a real customer-facing market-data right and independently promoted model/calibration evidence exist.

## 2026-07-27 -- Production rollout of the auditable release

- Deployed release source `247f84a78a2edfb46d6e7e777baedc40a6ed552d`
  to the existing single-VM AWS/Caddy production origin at `axio7.com`. The
  running Linux/AMD64 images are:
  - web:
    `sha256:832ac83848deed958dc34f4011ee9671235ed584a45a3110e55370b9d9c0461a`
  - quantd:
    `sha256:1308ed2de1122f3b5a202446809cbf9dff1ce65e81893f4b76892edfb27769c5`
- Preserved the production `.env.server`. Before replacement, quiesced the
  scheduler, web service, and quantd; captured the pre-deploy Compose file,
  Caddyfile, mode-600 environment file, container inventory, and image
  inventory under `/opt/axio7/releases/20260727-247f84a/rollback`; tagged both
  preceding application images for rollback; and backed up both persistent
  volumes. Backup receipts:
  - `quant-state.tgz`:
    `c6e9796aa30356a01374b29ee57ead4d3841f03edb12db5f17f8f593ed232dfc`
  - `quant-live.tgz`:
    `bee9e4ac40e766804af223b801b584a6acc948bb9b24c61bed71901cd122371d`
- Ran the v2 prediction-ledger audit against the mounted production state
  before starting the service. It reported append-only state, zero duplicate
  settlement evidence, and `PREDICTION_LEDGER_V2_AUDIT_OK`. The resulting
  SQLite files are owned by the non-root `axio` runtime user. Quantd, web, IBKR
  gateway, monitor scheduler, and Caddy are running; quantd, web, and the
  gateway report healthy.
- Public smoke verification returned HTTP 200 for `/`, `/pricing`, and
  `/api/quant/research/status`. Status reports native Rust, execution disabled,
  and 9/9 configured artifacts loaded. An authenticated browser rendered all
  three Paddle actions with live localized prices: Starter USD 49/month, Pro
  USD 149/month, and Lifetime USD 1,999 one time. An unauthenticated checkout
  attempt failed before transaction creation with HTTP 401, and a forged
  Paddle signature was rejected with HTTP 400. After rollout, Paddle retried
  its previously failed, vendor-signed production deliveries; six observed
  deliveries were verified, durably processed, and acknowledged with HTTP 200
  rather than the pre-deploy HTTP 500 catalog-completeness failure.
- A production UI request for lowercase `nvda` completed end to end through
  Next.js and Rust, normalized the symbol to `NVDA`, and returned an auditable
  `axio.evidence-envelope.v1` with `DATA_UNAVAILABLE`, no candidates, and eight
  explicit blockers. No estimate, Yahoo data, stale-as-realtime data, synthetic
  value, transaction, order, or personalized recommendation was produced.
- The deployment intentionally does not claim publishable live research.
  Quantd continues to report that the configured Databento account lacks the
  live `EQUS.MINI` entitlement. The public provider/redistribution license
  reference, active pinned promotion registry hash, and independently promoted
  calibration remain absent. Eight of nine v3 HMM candidates also still select
  the tested K=12 boundary. These conditions remain fail-closed release gates.

- The optional grounded-explanation provider currently returns HTTP 401 from
  `api.tokenrouter.com`. Quantitative evidence and fail-closed responses remain
  available through the deterministic formatter, but a valid server-side
  OpenAI-compatible key is required to restore generated prose explanations.

Rollback condition: if any deployed health or contract check regresses, stop
the scheduler and application services, restore the matching quiesced volume
archives and `.env.server.pre`, retag the captured pre-deploy image IDs, restore
`compose.pre.yaml` and `Caddyfile.pre`, and restart one replica only. Do not
roll back the database independently from its matching SQLite/WAL archive.

## 2026-07-27 -- Owner-only Moomoo OpenD inference relay

Implemented:

- Added a separate owner-only HTTPS forecast relay from the loopback Moomoo
  OpenD/Rust runtime into the single-VM Rust service. The publisher token is
  distinct from the research token, server-only, at least 32 characters, and
  protected by exact route, JSON/body-size, constant-time token, timeout, and
  120 requests/minute/IP gates.
- Rust accepts only exact-symbol frozen artifacts in the configured nine-symbol
  registry, 5/15/30/60-minute horizons, causal clocks, pinned OpenD source
  versions, immutable lineage hashes, NO_TRADE output, and fully withheld
  calibrated-probability fields. Live and replay payloads require different
  evidence, availability, and capability metadata.
- Deterministic replay now consumes the actual OpenD SDK JSONL schema, ignores
  non-K_1M callbacks, treats provider bucket end as synthetic replay
  availability where the original receipt clock is unavailable, and writes to
  replay-only bars, forecast, and SQLite paths. It cannot overwrite or satisfy
  the public live artifact gate.
- Added a quote-only historical K_1M exporter using only
  `OpenQuoteContext.request_history_kline`, loopback OpenD, unadjusted bars,
  bounded pagination, pinned SDK version, and explicit unknown original
  point-in-time availability. No account, position, order, or trade API is
  imported or called.
- The administrator-only website preview and chat now prefer owner Moomoo
  output while customer-facing research remains fail closed. Public
  redistribution rights, calibrated probability, advice, and execution remain
  false/withheld. Unsupported GOOG/SNDK model requests were replaced with
  registered NVDA/AAPL targets; the landing-page readiness probe uses SPY so a
  post-cutoff historical replay can be shown before the next live NVDA bar.
- Exact source-JSON hashes are validated before typed artifact loading and then
  protected by an in-memory mutation seal. Release-built inference remains the
  required execution mode for the current immutable artifacts.

Verification:

- Rust formatting and warning-free all-target Clippy passed; 349 Rust tests
  passed with zero failures.
- TypeScript typecheck and the 65-page Next.js production build passed; six
  Moomoo relay/security/symbol/environment contracts passed.
- Python offline research reported 32 passed and 5 optional skips. The Moomoo
  quote/history bridge tests reported 15 passed.
- Native CMake configured and built four targets; CTest passed 1/1. The full
  Windows C++ toolchain is installed; the GCC runtime directory only needed to
  be added to the build process PATH.

Deployment state: production rollout is complete through commit `713d27f`.
OpenD exported 780 actual SPY K_1M rows for 2026-07-23 through 2026-07-24.
Release Rust deterministic replay generated four 5/15/30/60-minute forecasts
and the owner relay accepted them as `OWNER_HISTORICAL_REPLAY_READY`.

Deployment evidence and corrections:

- The first `073ad522cc0e` cutover exposed CRLF line endings in the Linux
  entrypoint. The deployment stopped before promotion and restored the prior
  healthy images and volumes. Commit `d23df4395c95` normalizes the copied
  entrypoint in the image and was then deployed successfully.
- Commit `bebe2f3ec7e0` corrected replay availability clocks so each forecast
  remains causal and explicitly labelled `DETERMINISTIC_REPLAY`.
- A broad serde JSON float-roundtrip change in `a803fbf086e0` fixed the owner
  receipt but changed legacy frozen-artifact content hashing. Production
  verification caught all 9 artifacts as rejected before handoff. Commit
  `713d27f` removed that global behavior and scoped persisted-decode hash
  normalization to the owner relay only.
- The final Linux/AMD64 quantd image is
  `sha256:357d2399ccb6c6a2404c567afb5d80ee9b42548278d191ad794eddf24b1edeb8`.
  The unchanged web image remains
  `sha256:3c81e6af54d9e01ce541edb0e90dad6c2d1d09eb6ffaac150354a91b876ccc55`.
  Quantd, web, IBKR gateway, scheduler, and Caddy are up; quantd, web, and the
  gateway report healthy.
- The final model-runtime receipt is `LOADED`, with 9/9 requested immutable
  artifacts loaded and zero failures. Public smoke returned HTTP 200 for `/`,
  `/pricing`, and `/api/quant/research/status`; unauthenticated owner-preview
  access returned HTTP 403 and a forged Moomoo relay token returned HTTP 401.
  The pricing page still exposes Paddle Starter, Pro, and Lifetime purchase
  actions.
- The explicit owner administrator allowlists were updated server-side and the
  authenticated website renders `Rust models connected`, `Moomoo replay
  ready`, and the SPY owner model card. The owner endpoint returns four rows.
  The 15-minute row uses reference price 738.28 and raw conditional mean
  `0.00046409564493725246` at a historical replay cutoff; calibrated
  probability, customer redistribution, advice, and execution remain
  withheld.
- Final rollback archives under `/opt/axio7/releases/20260727-713d27f` are:
  - `quant-state.tgz`:
    `4e252e14c1b20a820174d9ca8317e9d89378f89edcf3383d93b7f452a337c93c`
  - `quant-live.tgz`:
    `ab9d558f1dda2b6a13b2f5ccf6770fce24bda82574992623580491da1e70ff9b`

The customer-facing market answer remains intentionally fail closed. The
configured Databento account currently reports that an `EQUS.MINI` live data
license is required, and neither the Moomoo owner session nor the IBKR owner
gateway establishes customer redistribution rights. Enabling public live
answers requires a verified customer-facing redistribution license/reference
and fresh causal observations; no unlicensed, delayed-as-realtime, or
synthetic substitution is permitted.

### Local owner forward-shadow activation

- Rebuilt the Windows `quantctl` release from the same current source used for
  the final server correction, then started the quote-only Moomoo stream
  against loopback OpenD. The official SDK callback verified OpenD
  `10.9.6908`, US quote rights, and Basic/Ticker/K_1M subscriptions for the 14
  configured symbols. The persisted status is
  `CONNECTED_QUOTE_PROTOCOL_VERIFIED`, capability
  `D1_REALTIME_UNDERLYING_VERIFIED`, with no blocker.
- Installed the current-user scheduled task `AXIO7 Moomoo Owner Relay`. It
  starts at Windows logon, runs at limited privilege, waits on the Rust
  supervisor, and is configured for bounded restart on failure. The relay
  token is stored with current-user Windows DPAPI under the local AXIO7 runtime
  directory; it is absent from the repository, task arguments, process command
  lines, and logs. The task-launched Rust and official Python bridge processes
  were both observed running after a deliberate stop/start test.
- The runtime loaded all nine frozen predictors and kept quote-only,
  `LIVE_FORWARD_SHADOW`, and execution-disabled policy in force. Before the
  regular session, the K_1M status is
  `SUBSCRIBED_AWAITING_FIRST_BAR`; this is a readiness state rather than a
  live-forecast claim.
- An authenticated production chat query for SPY rendered the four owner-only
  5/15/30/60-minute replay rows while retaining the separate customer
  publication warning. The 15-minute row reports reference 738.28 and raw
  conditional mean `+0.046%`.
- NVDA correctly has no pre-open owner forecast. Its immutable artifact cutoff
  is 2026-07-24 20:00 UTC, so the Rust runtime rejected a 2026-07-24 replay
  with `frozen predictor cutoff is not before the inference query`. The first
  causal regular-session NVDA observation can exist only after the next
  completed market minute. No older-symbol fallback, future observation, or
  synthetic value was substituted.

## 2026-07-27 -- Customer chat simplification and live-publication audit

- Removed the administrator Databento, Moomoo, and IBKR diagnostics, status
  badges, default owner preview, and their 30-second polling loops from the
  customer landing page. The customer surface remains one conversational
  research workspace. Exact-symbol owner preview remains available only inside
  an authenticated administrator conversation and the full owner dashboard
  remains under `/quant/intraday`.
- The server-side Databento entitlement endpoint, owner relays, Rust model
  status, publication gates, evidence envelope, Paddle purchase actions, and
  execution-disabled controls are unchanged. UI simplification does not turn a
  withheld result into a publishable one.
- Databento's logged-in plan portal currently reports no active subscription.
  The US Equities Standard checkout shows USD 199/month, USD 122.12 in account
  credits, USD 76.88 due today before tax, and the saved payment method ending
  0514. The final recurring purchase has not been submitted without explicit
  owner confirmation. Official EQUS.MINI terms describe the derived feed as
  eligible for commercial external display/redistribution without a separate
  exchange license identifier; production still requires a successful
  subscription receipt and a same-team server-side API-key entitlement check.
- Independent promotion audit found zero of nine v3 candidates eligible for
  publication. Eight candidates still select the declared K=12 search
  boundary. IGV selects K=11 but still lacks matching untouched OOS,
  calibration, same-hash forward-shadow evidence, manual review, and promotion
  approval. All nine candidate artifacts declare fail-closed calibration, and
  no current-hash prediction has the required settled forward evidence.
- The audit also found that the current single calibration artifact and
  single-tuple promotion registry schemas cannot independently represent all
  nine production model hashes while readiness requires all nine to match.
  Multi-model calibration/promotion registry work is therefore a prerequisite;
  no environment-only change may bypass it.

Verification before deployment: the 18 focused conversation, Databento,
Moomoo, IBKR, Rust-ownership, authorization, and billing contracts passed;
`npm run typecheck` passed; and the 65-page Next.js production build passed.
Production deployment and browser receipts are pending.

## 2026-07-28Z emergency uncalibrated direction release

A release candidate was prepared after the licensed Databento connection was
shown to be healthy but a plain NVDA request was withheld before the Rust model
could return a safe research condition.

- The public observation gate is now independent from the probability
  publication gate. Licensed, entitled, fresh Databento observations may reach
  the model while absent promotion or calibration continues to block every
  calibrated probability.
- Uncalibrated output is projected through an explicit whitelist under status
  `UNCALIBRATED_RESEARCH_OUTPUT`. It exposes only symbol, directional
  orientation, horizon, observation/availability times, age, licensed source,
  coverage, model lineage, publication status, and caveats. Probability,
  expected move/price, raw frequency, rank, and trade fields are withheld.
- Direct-symbol requests retain the configured universe until after native
  ranking and then filter to the requested model symbol, so NVDA cannot vanish
  merely because another configured symbol has a higher internal rank.
- The emergency release keeps the explicit K=2..12 production regime grid
  because all nine current frozen artifacts match its config hash exactly.
  The partial K=2..16 config was excluded; that upgrade requires a single
  clean-commit retrain of the full nine-model universe.
- Gamma and options publication are outside this release.
- Every customer-visible candidate row must match the immutable prediction
  ledger. Databento rows additionally must match the exact source-envelope
  receipt; a reports JSON file alone can no longer cross the public boundary.
- Databento live-bar validation is shared by inference and customer research.
  Schema, dataset, entitlement, replay/delay/staleness flags, symbol mapping,
  bar source/quality, causal clocks, and the configured availability-lag limit
  are now checked by the same fail-closed validator.
- databento_inference_receipt.v3 is the customer-publication commit marker:
  forecast first and receipt last. It binds the source-envelope hash, forecast
  file hash, per-row model hash and prediction IDs, causal clocks, publication
  time, and the end-to-end SLA budget; partial writes roll back fail closed.
- The Rust envelope seal and server-side TypeScript verifier independently
  enforce the response SHA-256 and publication semantics. A live-data blocker
  clears every live candidate. Independently validated point-in-time
  historical rows may remain under `PARTIAL`; freshness is bounded by the
  stricter of request and server policy, and no probability, expected-price,
  rank, raw-frequency, or trading field is permitted in a live candidate.

Pre-deployment evidence: 374 Rust library tests, 25 Rust binary/integration
tests, Clippy with warnings denied, nine conversation-contract tests, five
response-envelope verifier tests, TypeScript typecheck, and the 65-route
Next.js production build passed. The
Python suite passed 32 tests with five skips; native CMake built 10 targets and
CTest passed 1/1.

Production deployment and next-session live-bar acceptance are pending. No
replay, delayed-as-realtime, stale, synthetic, or alternate-symbol value may be
used to manufacture an immediate result. Rollback is the previous quantd/web
image pair; rollback must preserve Paddle, Databento secrets, and persistent
data volumes.

Deployment data gate: all nine frozen artifacts bind to the exact immutable
training CSV SHA-256 `ef9a80712ac2b57489c563efade124c76f06e563320b69aafe23a5d8f2bd92eb`.
The production normalized volume must be atomically verified against that hash
before quantd cutover; the different AWS Databento-history CSV must not be
silently substituted. Databento remains the licensed live observation source.

## 2026-07-28Z independent historical-backtest release

The customer chat now separates realtime publication readiness from historical
evaluation. A closed-session or stale-feed blocker still removes every live
candidate, but it no longer deletes a successfully computed historical row.
The envelope reports `PARTIAL` when a live result is withheld while the
historical result remains available. An explicit backtest request does not
require a realtime feed and reports `AVAILABLE` when its historical evaluation
completes.

The Rust-owned historical evaluator now covers opening turn, VWAP reversal,
momentum, and statistical dislocation. It detects the first causal
completed-bar event per session, enters hypothetically at the next five-minute
bar open, exits at the requested horizon close, and subtracts the configured
round-trip spread and slippage assumption. The response exposes the sample
period, sessions, event and completed-label counts, net win rate, mean and
median net return, event-by-event compounded net return, maximum drawdown,
method version, source, manifest hash, and material caveats.

These metrics are labeled
`HISTORICAL_CONDITION_REPLAY_NOT_FROZEN_MODEL_OUT_OF_SAMPLE`. The current
immutable dataset overlaps model research/training and has no post-training
window large enough to claim untouched frozen-model OOS performance. The UI
therefore says this is a historical condition replay, not a calibrated
probability or frozen-model OOS result.

Pre-deployment evidence: 375 Rust library tests, 25 Rust binary/integration
tests, Clippy with warnings denied, ten conversation-contract tests,
TypeScript typecheck, the 65-route Next.js production build, 32 Python tests
with five skips, native CMake build, CTest 1/1, and all 14 Paddle permanence
contracts passed. Automatic execution remains disabled.

## 2026-07-28Z Paddle 0/69/699 production pricing release

AXIO7 production now exposes four public membership cards: Free at USD
0/month with read-only access, Pro at USD 69/month with a displayed USD 149
original price and 54% discount, Annual at USD 699/year with a displayed USD
1,499 original price and 53% discount, and Enterprise with written custom
volume pricing. Lifetime is no longer a public purchase option. Historical
Paddle products, prices, transactions, and subscriptions remain preserved.

The live recurring catalog is Free
`pri_01kymjn5cde81z68cfjrcnptpp`, Pro
`pri_01kymjjgjdhp86hatg9yx41fp1`, and Annual
`pri_01kymjrawnh203mkhzz9d3sn08`. Paid access continues to be granted only
from verified Paddle webhook or server-side reconciliation state. A verified
server guard blocks Free users from research runs, scans, backtests, and
monitors.

Production source commit
`1e43b726d0a35b1e17a32d76989b623eaf874ff5` was deployed as web image
`sha256:984a222539822b279d53395fb5c4da11b541763f43e4d0b80ddfcb0eed21bb5f`.
The container reported healthy and `/pricing` returned HTTP 200. Authenticated
browser acceptance opened the Paddle Pro checkout with USD 69 subtotal,
closed it, opened Annual with USD 699 subtotal, closed it, and switched back
to Pro without a stale-selection lock. Every acceptance checkout was closed
without submitting payment.

Release verification passed TypeScript typecheck, the 65-route Next.js
production build, 17 Paddle catalog/permanence contracts, and six Paddle
refund/cancellation contracts. Rollback tags are
`axio7-web:rollback-pre-paddle-7ecf8b2`,
`axio7-web:rollback-pre-paddle-legacy-attempt-fix`, and
`axio7-web:rollback-pre-paddle-close-cleanup-fix`; rollback must preserve the
production Paddle environment, historical catalog, and persistent data.

## 2026-07-28Z production model-bridge deployment receipt

Production source commit
`bfdd6212e36202afda1953d1e2bca709678198e7` was deployed from branch
`codex/production-model-bridge-20260728`. The running services were verified
against the exact local image IDs:

- quantd:
  `sha256:297d5f7e424ac5dc8af98b5e66f6f6235c214fdc6c8207a4f5f6caf9ef0e888e`
- web:
  `sha256:1a624ca1fe786d3830ec756081a1c9b785f4d7c76053b086fd258b94f961628c`

Both containers reported healthy. Public acceptance returned HTTP 200 for the
home and pricing pages. Authenticated browser acceptance confirmed that the
website reports all nine Rust models connected, a supported SPX
opening-buy-exhaustion backtest completes through the Rust quant engine, and
the predictive scheduled-event request `predict tomorrow FOMC market
reaction` fails closed with `scheduled_event_model_not_ready`. The supported
SPX result remains explicitly labeled as a contaminated exploratory historical
condition replay, not a calibrated probability or frozen-model out-of-sample
result.

The Databento readiness endpoint reported authenticated and entitled realtime
`EQUS.MINI` streaming with zero reconnects. The finalized-bar watermark
advanced after cutover, demonstrating that the asynchronous service remained
responsive while historical warmup and inference work ran on the blocking
pool. The inference-universe receipt reported `UNIVERSE_READY` for all nine
configured symbols with no symbol failures and
`market_data_capture_continues=true`.

Public predictive publication remains intentionally blocked. The production
readiness receipt reports an absent promotion registry, unavailable
calibration, zero ready forecasts, and no customer-publication inference
receipts at acceptance time. No probability was manufactured or substituted.
FOMC, macro-event, and earnings predictions require separately validated,
promoted immutable artifacts before the website may publish them.

Automatic execution remains disabled in the running web container:
`LIVE_EXECUTION_ENABLED=false`, `BROKER_LIVE_ENABLED=false`, and
`ANOMALY_LIVE_ORDER_ENABLED=false`. Paddle Free, Pro, and Annual purchase
actions and automatic recurring billing remained present; no checkout payment
was submitted during this deployment.

The first deployment build exposed an operational path error: copying
`infra/single-vm/compose.yaml` to `/opt/axio7` changes the meaning of its
relative `../..` build context and can build stale source. Those images were
not accepted. The release was rebuilt directly from the checked-out source
root with the two Dockerfiles, the exact image IDs above were verified, and
cutover used `--pull never`. Only 2.074 GB of rebuildable Docker builder cache
was pruned after the first web build exhausted disk; images, persistent market
data, model artifacts, Paddle state, and rollback material were preserved.
Future deployments must run Compose from `infra/single-vm` as documented or
build from the checked-out source root rather than relocating the Compose
file.

Rollback tags are
`axio7-quantd:rollback-pre-model-bridge-bfdd621` and
`axio7-web:rollback-pre-model-bridge-bfdd621`. The protected environment and
Compose backup live under
`/opt/axio7/backups/model-bridge-bfdd621`, with quant-state and live-data
archives in the same directory. Rollback must preserve the production
environment, Paddle infrastructure, Databento credentials, and persistent
data.

Pre-deployment verification passed 376 Rust library tests, 25 Rust
binary/integration tests, Rust formatting and Clippy with warnings denied,
11 conversation-contract tests, TypeScript typecheck, the 65-route Next.js
production build, 32 Python tests with five skips, and native CMake/CTest
1/1.

## 2026-07-28Z Part 0 live-forecast recovery checkpoint (in progress)

This checkpoint replaces the ticker-only and mutable-publication behavior in
the current release candidate. It is not a production deployment receipt.

- New interactive questions compile to `axio.market-query.v2`. A bare ticker
  requests a neutral `model_forecast` for every configured horizon; the query
  compiler no longer invents bearish/bullish direction, a setup, or a
  five-minute horizon. Stored v1 explicit-rule monitors remain readable during
  migration, but v1 cannot request `model_forecast`.
- A model-forecast response is atomic across its requested symbols and
  horizons. Missing, duplicate, or unexpected symbol/horizon rows block the
  entire live candidate set rather than returning a selectively complete
  forecast.
- The evidence envelope carries explicit model-runtime, market-data, context,
  inference, and publication readiness stages. Registry presence or one fresh
  bar is insufficient to display a green ready state.
- Databento validation now quarantines an invalid or zero-volume row at the
  affected symbol. It records the diagnostic and continues consuming the
  stream; the invalid row is neither persisted nor sent to inference. Feed
  freshness independently requires every target and required context symbol.
- Context readiness distinguishes observed-trade intervals, causally inferred
  no-trade intervals under an uninterrupted Databento subscription/health
  contract, and unknown missing intervals, with exact public counts and reason
  codes. Databento does not emit a per-symbol no-trade record, so this state
  must never be described as vendor-confirmed. Unknown gaps remain fail closed.
  A low-activity symbol is not deleted merely to force a forecast.
- Live forecast publication uses immutable per-symbol generation files plus an
  append-only ledger publication commit. Customer reads select only a
  generation whose prediction identifiers and content hash have matching
  commits. An orphaned generation after a process crash is skipped, and the
  previous committed generation remains readable.
- Failed or unpublished prediction attempts no longer enter settlement or
  count as verified live evidence. The ledger separately reports attempts and
  committed publications.
- The customer UI renders each horizon separately and in deterministic order.
  It distinguishes uncalibrated directional research output from an exactly
  matched promoted/calibrated artifact; probability is hidden unless the full
  promotion receipt passes. Unrelated historical-rule cards are omitted from a
  live model question.
- Full live diagnostic status is paid-access protected. The public website
  continues to preserve Paddle Free, Pro, and Annual purchase actions.

Local web verification at this checkpoint passed TypeScript typecheck, the
65-route Next.js production build, and 41 query, envelope, paid-access, and
Paddle contract tests. Rust and Python phase gates are still running and must
be recorded before this checkpoint can advance.

Remaining hard blockers:

1. The existing local production process has a working Databento credential:
   the 2026-07-28 post-close diagnostic showed authenticated and entitled
   realtime `EQUS.MINI`, 14 subscribed symbols, fresh heartbeats, and 3,273
   finalized bars. All nine frozen model artifacts were loaded. This receipt
   belongs to the older running binary, however; the recovery candidate still
   needs a new-code real-session inference/publication receipt and production
   deployment access. No market-database URL or deploy credential is available
   in this clean worktree.
2. The current UUP context requirement still has unknown sparse intervals. It
   may be removed only after a causal ablation, full-universe retrain, new
   feature/config/data hashes, and validation show that the replacement
   artifact is safe; otherwise the artifact needs an explicit missingness-aware
   schema.
3. The current nine candidate artifacts are not promoted/calibrated. Until
   untouched holdout, walk-forward, calibration, forward-shadow, and manual
   promotion evidence match the exact immutable hashes, the website may expose
   only the constrained uncalibrated research orientation.

Automatic execution remains disabled. This recovery work does not add broker
order routing, personalized recommendations, or a bypass for freshness,
coverage, entitlement, causality, or promotion checks.

The same diagnostic exposed the immediate old-runtime failure: every target
status reports `frozen predictor research model config mismatch`. The running
dirty configuration expanded the HMM grid to K=2..16 after the immutable
artifacts had been trained and hashed against K=2..12. The recovery branch
restores the exact K=2..12 contract used by all nine artifacts. K=13..16 cannot
be introduced by an environment edit; it requires a full-universe retrain,
new hashes, and validation. This source/artifact drift must be removed by
deploying one canonical build before interpreting any later context blocker.

The 2026-07-28 captured session makes the UUP failure concrete. From 11:10
through the close, UUP produced 20 positive-volume one-minute rows and only one
six-row contiguous run, while liquid targets produced roughly 268 rows. The
Databento OHLCV contract explicitly states that no record is emitted when no
trade occurs and documents forward-filled close/zero-volume interpolation as
one transparent client-side policy:
`https://databento.com/docs/schemas-and-data-formats/ohlcv` and
`https://databento.com/docs/examples/basics-historical/ohlcv-resampling`.

Therefore the preferred Part 1 candidate is not blind deletion. A v2 causal
observation policy may classify an absent OHLCV interval as
`CAUSAL_ABSENCE_UNDER_CONTINUOUS_HEALTH` only after the interval and grace
period have elapsed, the subscription and symbol mapping were acknowledged
before the interval, and the connection remained continuously healthy across
it. Disconnect, slow-reader, replay, or unverified intervals remain
`UNKNOWN_MISSING`. A zero-volume flat context row may then be materialized
only inside a separately versioned feature schema and must pass historical
ablation, full-universe retraining, untouched validation, and forward-shadow
checks before production use.

## 2026-07-28Z 41-item remediation local release-candidate checkpoint

This checkpoint supersedes the unfinished local verification statement above.
It is a source and test receipt, not a production deployment, model-promotion,
market-data-rights, or real-session acceptance receipt.

The local release candidate now contains the Part 0, Part 1, and Part 2
remediation described in
`docs/exec-plans/active/quant-remediation-41.md`. In particular:

- Ticker-only questions compile to a neutral model-owned forecast across every
  configured horizon. The website neither invents direction/setup/horizon nor
  substitutes an unrelated historical rule.
- Licensed finalized bars, causal context, frozen inference, immutable
  publication, settlement, and customer visibility have separate fail-closed
  contracts. Atomic multi-symbol/multi-horizon publication cannot be shortened
  by a ranking limit.
- The customer-facing feed indicator is derived from the sanitized production
  readiness receipt. It requires pinned public-use rights, provider
  entitlement, a fresh stream, and all-symbol feed freshness; it no longer
  infers readiness from one raw bar.
- Historical evaluation fails closed on malformed or conflicting input,
  incomplete sessions, non-clock-time labels, unaccounted exclusions, and
  unauthorized VWAP. The offline evaluator records purged folds, measured and
  sensitivity costs, baselines, block-bootstrap intervals, effective sample
  size, stability, negative controls, multiple-testing correction, overlap,
  and untouched-holdout status.
- The subscriber surface renders a concise result, interpreted query, the five
  readiness stages, horizon-specific evidence, provenance, diagnostics, and
  recovery actions on desktop and mobile. A withheld result says plainly that
  no live forecast was generated.
- The former TypeScript/Yahoo factor scanner and explainer are disconnected.
  A separate Rust-owned 40/20/40 factor candidate now has a paid,
  metadata-only status path. It returns
  `CANDIDATE_NOT_PROMOTED`, explicit blockers, and `execution: DISABLED`; it
  publishes no rank, probability, expected return, position, or order.

Final local verification:

- Rust: `cargo fmt --all -- --check` passed; Clippy passed for all targets with
  warnings denied; `cargo test` passed 440 library tests, 15 `quantctl` tests,
  12 native-core integration tests, one shared completed-bar response fixture,
  and one finalized-bars-to-visible-evidence fixture.
- Python: 59 tests passed and five optional tests were skipped. The only
  warning is an external Starlette `TestClient` deprecation.
- Web: 95 Node contract tests and six public-context contract tests passed;
  TypeScript typecheck passed; the optimized Next.js build generated 66 pages.
  Existing repository-wide Sentry, font, image, and one unrelated hook lint
  warning remain non-blocking.
- Native C++: CMake/Ninja built successfully and CTest passed 1/1.
- Browser: desktop English, mobile Chinese, localized recovery actions, and
  the factor-shadow page passed against the production build with zero browser
  console errors.

The following are still hard external promotion/deployment inputs and were not
fabricated:

1. A genuine, pinned market-data rights receipt for the exact provider,
   product, research use, and public display use. The expected local file is
   `quant_engine_rs/data/rights/market_data_rights_receipt.json`.
2. The exact normalized training bars, raw inputs, and immutable manifests.
   This clean worktree does not contain
   `quant_engine_rs/data/normalized/market_bars.csv`,
   `quant_engine_rs/data/raw/`, or `quant_engine_rs/data/manifests/`.
3. A sealed full-universe retrain and validation report for the no-UUP
   candidate, followed by exact-hash untouched holdout, calibration,
   forward-shadow, and manual promotion receipts.
4. A regular-session nine-symbol latency, coverage, and publication receipt
   from this candidate build.
5. Production database/deployment access for a canonical image build, cutover,
   authenticated subscriber acceptance, and rollback receipt.

Until all five inputs exist, the correct customer behavior is fail closed.
Local tests establish contract correctness; they do not establish predictive
accuracy or authorize production publication. Automatic execution remains
disabled and no broker order route was added.

## 2026-07-28Z Databento technical-entitlement capture utility

An offline-tested operator utility now captures a narrowly scoped Databento
technical-entitlement receipt from the official historical metadata API. It
checks that the process credential can see `EQUS.MINI`, `ohlcv-1m`, and a
valid per-schema entitled range, then persists only endpoint status and
response hashes plus the validated range. The API key, Basic header, account
data, query string, and response bodies are never written. Publication remains
fail closed: this receipt is not the account-bound market-data rights receipt,
a live subscription/freshness receipt, or evidence of customer display,
derived-output publication, or redistribution rights.

The operator contract and safe invocation are documented in
`docs/databento-technical-entitlement-receipt.md`. Synthetic fixture and static
contract tests run without an API key or network request. A live capture is
still an external operator action and was not performed by this checkpoint.

## 2026-07-28Z immutable training-lineage sealing utility

`quantctl data seal-training-lineage` now creates the strict
`axio.normalized-market-bars-training-lineage.v1` manifest required by the
Rust training gate. Run it from `quant_engine_rs/` only after the exact
normalized bars, every immutable raw source artifact, and the account-bound v2
rights receipt are present. The receipt location is fixed at
`data/rights/market_data_rights_receipt.json`; its exact SHA-256 must be pinned
in `AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256`.

```powershell
$bars = "data/normalized/market_bars.csv"
$barsSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $bars).Hash.ToLowerInvariant()
$env:AXIO7_MARKET_DATA_RIGHTS_RECEIPT_SHA256 = "<64-hex receipt SHA-256>"
cargo run --release --bin quantctl -- `
  --config configs/production.yaml `
  data seal-training-lineage `
  --bars $bars `
  --source data/raw/<provider>/<immutable-source-file-or-directory> `
  --provider <provider-id-from-receipt> `
  --product <product-id-from-receipt> `
  --adjustment-status vendor-adjusted `
  --output "data/manifests/normalized_market_bars_$barsSha256.json"
```

Repeat `--source` for additional files or directories. Use
`--adjustment-status raw-unadjusted` only when that is the true normalized-data
contract. Provider IDs must use canonical lowercase and product IDs canonical
uppercase, matching the verifier and receipt contract. The fail-closed source
binding currently recognizes Databento dataset labels
(`DATABENTO_<DATASET>`, `Databento/<DATASET>`, or
`Databento/<DATASET>/ohlcv-1m`) and the exact
`massive`/`US_EQUITIES_REALTIME` → `MASSIVE_STOCKS_AGG_1M` mapping. A new
provider/product needs an explicit reviewed mapping before sealing. The command
streams the normalized CSV to validate every market bar, reject duplicate
symbol/timestamp rows, derive its exact row count and sorted
symbol/source/data-quality sets, hash each raw artifact, validate the pinned v2
receipt for model-input use, and publish the manifest atomically without
overwriting an existing name. It rejects path escape, symlinks, empty inputs,
duplicate files or content, mixed or mismatched normalized source identity,
and incoherent configured data roots. It never copies market data or
contracts, prints no credential or receipt body, does not grant publication
rights, does not promote a model, and does not enable automatic execution.

The content-addressed basename is mandatory. A repeated or concurrent seal of
the same bars resolves to the same no-clobber destination; it cannot create a
second manifest that would make the training verifier ambiguous. If an older
eligible manifest already binds the same exact bars under another name, the
command fails with `TRAINING_LINEAGE_ALREADY_SEALED` for operator audit rather
than creating a duplicate.

## 2026-07-28Z single-VM deployment and sealed-acceptance hardening

The local release candidate now has a fail-closed deployment contract for the
nine-symbol production artifact set. This is source and offline-test evidence,
not a production deployment or a regular-session acceptance receipt.

- Both application images require an explicit 40-character `GIT_COMMIT`, use
  commit-specific image tags, and carry the same OCI revision label. The exact
  frozen model directory is initialized into a commit-specific named volume
  and mounted read-only.
- Normalized bars, manifests, the account-bound v2 rights receipt, v2
  promotion registry/evidence, v2 calibration registry, and optional sanitized
  technical-entitlement evidence for the owner-attestation path are injected
  only through ignored read-only runtime mounts. Their independent hashes and
  per-entry promotion pins reach only `quantd`; private artifacts are excluded
  from both Docker build contexts. Technical entitlement never replaces the
  separate rights receipt or live-stream readiness gates.
- Owner-attestation technical freshness is a point-in-time signature check:
  `captured_at` must be within the prior 24 hours of `signed_at` and no more
  than five minutes later. It is not a daily repinning requirement. Current
  rights validity/review clocks and live provider, stream, and completed-bar
  freshness remain independent rolling gates.
- The signed account-owner attestation remains in the ignored, mode-`0700`
  `private-rights-evidence` host directory. It is never mounted or serialized
  into acceptance output. Backup/rollback includes it, while sealed acceptance
  independently compares only its SHA-256 with the rights receipt's
  `evidence_artifact_sha256`. The directory/file modes are fixed at
  `0700`/`0600`, hard links and extra members fail closed, and backup storage
  must remain encrypted and access-controlled because recovery archives
  necessarily contain the private bytes.
- Container health remains the loopback `/health` liveness contract so a
  provider outage does not take down the website, Paddle checkout, or recovery
  guidance. `verify-runtime.sh` separately requires `/ready`, exact 9/9 frozen
  artifact loading, matching image revisions, and disabled automatic
  execution. It is intentionally weaker than publication acceptance.
- `production-release-backup.sh` requires a clean deployed checkout, matching
  image revision labels, an exact normalized-data hash, a quiesced
  state/live/WAL pair, and checksum-seals runtime artifacts, Caddy state,
  protected configuration, and every Compose service image ID.
- `production-release-rollback.sh` checksum-validates and fully extracts every
  old archive before quiescing. Before any overwrite it checksum-seals the
  current configuration, images/revisions, runtime artifacts, and four fixed
  volumes. Replacement is restricted to those fixed volume names; a failure
  after replacement begins attempts to restore the emergency set. A
  successful rollback requires quantd/web liveness, Caddy/scheduler/IBKR
  running, every exact old service image ID, and a read-only model universe
  identical to the old quantd image.
- `seal-nine-symbol-acceptance.py` requires a genuine US regular session, two
  stable authenticated `/api/v1/system/readiness` snapshots, complete
  immutable ledger-backed publications for all nine symbols and all four
  horizons, fresh entitled Databento data, verified v2 rights, independently
  pinned promotion, promoted calibration, disabled execution gates, exact
  source/image/config/data/artifact hashes, and a fresh trusted-TLS public
  `/api/health` response for the same commit. It also binds the local Caddy
  domain/config and sanitized states of quantd, web, Caddy, and the scheduler.
  The host JSON artifacts are parsed only from bytes that still match their
  container-verified pins, quantd mounts must equal the exact approved set,
  and no running Compose container may bind the host-only attestation tree.
  Output is atomically installed with a SHA-256 component manifest; it is not a
  digital signature or evidence of predictive accuracy.

Offline deployment checks passed: both Dockerfiles passed `docker build
--check`; the single-VM Compose file expanded successfully with isolated
placeholder values; four Bash helpers passed `bash -n`; thirteen acceptance unit
tests and eight deployment static-contract tests passed. The existing private
market-data and owner-rights generator contract tests also remain part of the
release check. PR #9
(`origin/codex/databento-shadow-release`) was compared read-only for useful
9/9 runtime checks; no merge, cherry-pick, rebase, or push was performed.

Deployment remains blocked on the genuine external artifacts already listed in
this plan, production access, and a real regular-session capture. No acceptance
bundle was fabricated. The canonical backup helper also rejects a legacy
running image without the matching OCI revision label; the first migration
from such an image requires a separately documented manual full-state and
image-ID backup rather than weakening that provenance check. Automatic
execution remains disabled and this work adds no broker-order authorization.

## 2026-07-28Z account-owner rights evidence path

- Added the distinct `ACCOUNT_OWNER_ATTESTATION` v2 evidence basis. It is
  publishable only as
  `OWNER_ATTESTED_WITH_TECHNICAL_ENTITLEMENT`, never as vendor-issued
  `VERIFIED` evidence.
- The shared Rust validator now binds exact provider/product, legal entity,
  active plan, account/license, account, and subscription identity hashes;
  exact model-input, customer-display, and derived-output scopes; signed,
  validity, and review clocks; official product/terms URLs; and the SHA-256 of
  a fresh sanitized Databento technical-entitlement receipt. Raw redistribution
  is forced false. Missing, malformed, stale/future, identity-mismatched, or
  hash-mismatched evidence fails closed.
- When the provider exposes no subscription ID, the owner path permits only an
  explicitly labeled `OWNER_DEFINED_NOT_VENDOR_ID` binding. That label is
  included in the domain-separated subscription hash and never presented as a
  vendor-issued identifier.
- Added `quantctl data validate-market-data-rights` and
  `scripts/create-owner-market-data-rights-receipt.ps1`. The operator utility
  accepts factual identity/account inputs, creates salted domain-separated
  hashes, stages the exact artifacts, calls the production Rust parser, copies
  the sanitized technical receipt, and atomically commits the rights receipt
  last. It prints only private paths and hashes and never reads a market-data
  credential.
- The repository owner supplied the factual private identity, active-plan,
  account, owner-defined subscription binding, reviewer, and short
  validity/review inputs. The generator created the ignored private
  attestation, technical-evidence copy, and rights receipt and accepted their
  exact staged bytes through the shared Rust parser. A read-only follow-up
  confirmed the attestation and technical hashes, exact scopes, local-reference
  label, active plan, and no raw-redistribution or vendor-evidence claim. No
  private identity or account value is recorded in this plan or committed.
  Deployment must use the generator's full 64-character receipt pin; this
  rights dimension does not bypass any remaining live-data, model, calibration,
  publication, or acceptance gate.

## 2026-07-28Z one-time flat-deployment migration bridge

The production VM inspection found a legacy flat deployment at `/opt/axio7`,
not a Git checkout: its Compose, Caddy, environment, and runtime files are
direct children of that directory, and the running web/quantd image revision
labels resolve to null. The canonical commit-bound backup helper correctly
refuses this state and remains unchanged.

Two narrowly scoped source-side helpers now bridge only that first migration:
`production-legacy-flat-migration-backup.sh` and
`production-legacy-flat-migration-restore.sh`. The backup requires explicit
`--confirm-legacy-quiesce`, fingerprints the exact four-service/four-volume
legacy topology and expected bind mounts, verifies disabled execution, records
every full container/image ID, recovery-tags every image, stops all four
services, and archives the complete detached volumes. This preserves SQLite
main databases together with every existing WAL/SHM/journal file rather than
copying selected database paths. It also seals the exact flat Compose, Caddy,
environment, and approved runtime trees without printing environment
contents. Full file and directory manifests, member path/type rejection,
extraction preflight, and a fixed checksum allow-list fail closed before
success. A successful backup leaves the stack stopped for cutover.

The checksum-sealed bundle contains its own restore helper and recovery
command. Restore preflights the entire bundle, exact local recovery image
bindings, saved Compose/Caddy configuration, and disabled execution gates
before replacement. It first makes a separate complete emergency snapshot,
restores only the four fixed volumes and flat runtime/configuration, and starts
the exact old images with `--no-build --pull never`. If startup or verification
fails after replacement begins, it stops resolved AXIO7 containers and retains
both emergency and preflight paths. Neither path prunes or deletes Docker
images, named volumes, or backups.

This is an offline implementation receipt only. Neither helper was run against
the VM, and no production container, image, volume, file, or service state was
changed. The operator must run the one-time backup successfully before the
first canonical cutover and retain its mode-`0700`, access-controlled,
encrypted-at-rest bundle and recovery image tags until rollback is verified.
All automatic-execution gates remain false; this bridge adds no broker route or
order authorization.

## 2026-07-29Z Argus canonical repository transfer and worker partition fix

- `ErwinHe7/Argus` is now the canonical collaboration repository. The complete
  current product was added under `platform/` on
  `codex/live-model-integration` at transfer commit `9dc7d24`; the prior
  data-free review snapshot remains preserved separately under
  `axio7-model-review/`.
- Transfer integrity matched all 739 source files byte-for-byte before Git
  normalization. The committed bundle contains exactly nine frozen
  exact-symbol candidates plus the registry. Real environment files,
  credentials, private rights/technical receipts, raw and normalized market
  data, databases, build trees, and runtime state were excluded.
- The live exact-nine scheduler previously selected a worker bound of four but
  split nine jobs into three equal chunks. It now partitions the jobs as
  `3/2/2/2`, creating every selected worker while preserving the four-worker
  ceiling and disjoint mutable ownership.
- The partition regression tests pass, `cargo fmt --check` passes, and
  `cargo clippy --lib -- -D warnings` passes. The transferred web application
  passes typecheck, 50 contract tests, and a production Next.js build.

This records source transfer and offline validation only. No production
container, DNS record, secret, live data feed, model promotion, customer
traffic, or broker execution state was changed. The real server must still
pass the documented exact-nine readiness and release-acceptance gates before
cutover; automatic execution remains disabled.

## 2026-07-30Z transparent SPX raw-likelihood result contract

- Bare SPX/SPY trend, direction, outlook, forecast, and prediction questions
  now route to the Rust-owned next-session daily-regime report. Questions
  explicitly asking for the current, live, intraday, or today's trend continue
  to use the observed-session report.
- The daily-regime interface is now `axio.daily-regime.v3`, model version
  `2026-07-30.v4`. Rust publishes the 15-nearest-same-regime up and
  down-or-flat outcome shares together with a two-sided 95% Wilson score
  interval for the raw up share. The web proxy independently verifies the
  counts, shares, interval parameters, and recomputed bounds before rendering.
- The customer result begins with a concise list containing the raw outcome
  shares, their uncertainty interval, the conformal next-session return point
  and 90% prediction interval, empirical interval coverage, and purged
  walk-forward directional accuracy. It labels the raw likelihood as
  uncalibrated and does not represent it as a promoted probability.
- No probability gate was weakened. `probability_published` remains false,
  automatic execution remains disabled, and a calibrated probability still
  requires a separately validated, immutable, promoted artifact.

Offline validation passed: TypeScript typecheck, all 21 quant-conversation
contract tests, the production Next.js build, `cargo fmt --check`,
`cargo clippy --all-targets -- -D warnings`, all Rust tests (492 library tests
plus binary/integration suites), 59 Python tests with five licensed-data tests
skipped, and the C++ CMake/CTest suite. The Next.js build retained the existing
non-fatal warning about duplicate inherited ESLint plugin configuration.
Production deployment and exact `spx trend` browser acceptance are still
pending.

## 2026-07-31Z sector-rotation challenger and PostgreSQL live-archive contract

Local source on `codex/sector-rotation-model-v1` now contains a separately
gated daily sector/theme challenger. It treats MAGS as an explicit ETF proxy
for the Magnificent Seven, SKYY as cloud computing, IGV as software, SOXX as
semiconductors, and the eleven SPDR sector ETFs as the broad rotation basket.
The six new causal completed-session features are Mag-7, cloud, and software
returns relative to SPY; sector leadership breadth; sector-return dispersion;
and growth-versus-defensive rotation. Every sector row requires real Databento
observations near both regular-session edges. Missing history or a missing
current group fails the challenger closed.

The customer-published 15-feature daily result is unchanged. The challenger is
compared with that baseline only on matched queries through a paired purged
expanding walk-forward evaluation. It must have at least 80 matched queries,
adequate directional-call coverage, at least a two-percentage-point raw
hit-frequency gain, and no increase in mean absolute next-session return error
before it can become eligible for forward shadow. Even then it remains
unpromoted until an untouched holdout, forward-shadow receipt, immutable
artifact, and manual promotion exist. The report serializes this state and
never turns the comparison frequency into a calibrated probability.

Six immutable Databento request partitions are declared for 2023 through the
last completed 2026-07-30 session. They are not considered present merely
because the request exists; hash-matched DBN files and manifests must be
downloaded through the existing account-entitled path before evaluation can
begin.

The PostgreSQL market schema now has a separately keyed, monthly partitioned
`live_equity_minute_bars` table, append-only live archive receipts, and a
unified point-in-time reader. Both the historical reader and the unified
reader require `recorded_at <= decision_cutoff` in addition to availability,
closing a causal gap where a theoretically available but not-yet-observed row
could otherwise enter a historical decision. A new idempotent archiver copies
only Rust-finalized SQLite rows that pass source, schema, symbology, OHLC,
completion-clock, availability-clock, entitlement, and rights-pin validation.
It replays a bounded overlap into a logical provider/dataset/schema/symbol/time
primary key and emits content-hashed append-only receipts. Database credentials
and rights evidence remain server-side and are never printed.

The canonical single-VM Compose inventory now includes a private PostgreSQL 17
service and a revision-bound `market-archive` service. PostgreSQL binds only to
the private Compose network and stores its data on the dedicated market-data
volume. The archiver receives the rights pin and database password only through
server-side environment variables and mounts the source SQLite store read-only.
Backup, rollback, runtime verification, and sealed acceptance now inventory the
two services explicitly. Release rollback intentionally preserves the
append-only database forward rather than claiming to restore it from the
application release tarball; an independent EBS snapshot or logical database
backup is required before a cutover.

Full local validation passed Rust formatting, warning-free Clippy for all
targets, 495 Rust library tests, 16 `quantctl` tests, 12 native-core integration
tests, the explicit completed-bar fixture, and the live-publication end-to-end
fixture. Python passed 63 tests with five licensed/optional tests skipped.
TypeScript typecheck and the 67-page optimized Next.js build passed with only
the repository's existing Sentry and duplicate inherited ESLint-plugin
warnings. CMake/Ninja built the native code and CTest passed 1/1. The five
focused PostgreSQL/live-archive tests, eight production deployment contract
tests, and `git diff --check` also passed. Dockerfile `--check` remains
unverified because the local Docker Desktop Linux daemon is not running. An
account-authenticated AWS inspection found one healthy legacy four-service
deployment, no RDS database, one dedicated 100GB ext4 market-data volume, and
2,316,177 finalized Databento `EQUS.MINI` / `ohlcv-1m` SQLite rows through
2026-07-31T20:44:00Z. The Rust and web containers are healthy and all nine
configured model artifacts are loaded. The public UI's “Model offline” state
was caused by its status route requiring paid access, not by a service outage.
No AWS resource or production service was changed during that inspection.
Automatic execution remains disabled.

## 2026-07-31Z public activation and acquisition instrumentation

The research status probe is now a public, no-store, read-only market path;
all research execution routes remain paid and authenticated. Guest starter
prompts are actionable and route through sign-in and pricing instead of
appearing disabled. The browser records a bounded first-touch attribution
receipt and allow-listed landing, starter, sign-in, pricing, checkout, and
research lifecycle events. Signup attribution is forwarded server-side
without capturing auth codes, email addresses, full query strings, or research
questions.

A public `/research/sector-rotation` page explains the exact sector/theme
proxies, causal feature classes, point-in-time requirements, promotion gates,
and caveats without publishing a current signal or performing a quantitative
calculation in TypeScript. It is included in the sitemap and robots contract.
The measurable 30-day channel and experiment sequence is recorded in
`docs/growth/30-day-user-acquisition.md`. External posts, Product Hunt launch,
and paid acquisition remain unexecuted until the production release gate is
green and the repository owner selects or provides the publishing accounts.

## 2026-07-31Z production migration staging

The account-authenticated AWS staging pass created commit-tagged EBS snapshots
of both the root filesystem and the dedicated market-data filesystem. It also
created and attached a separate encrypted, temporary 10GB migration-backup
volume, formatted only the newly attached empty device, and mounted it at
`/mnt/axio7-migration-backup` with owner-only permissions. No production
container or service was stopped. The release Git bundle was encrypted at rest
in the existing private S3 handoff path, independently SHA-256 verified in the
development workspace, CloudShell, and the migration volume, and cloned to the
exact release commit with complete Git history.

Both EBS snapshots completed before any filesystem change. The root volume was
then expanded from 20GB to 40GB and the ext4 filesystem was grown in place,
leaving approximately 24GB free for the commit-bound build. The encrypted
migration-backup volume remains independently attached and is retained for the
rollback window. No market-data mount or production state volume was resized.

Successive read-only preflights exposed only representation differences in the
observed flat release: explicit singleton `replicas: 1`, CRLF line endings,
default Compose build-image names, a normalized-away web `env_file`, matching
web/quantd OCI revisions without a source checkout, a Caddy image whose command
requires an explicit validation entrypoint, and intentional hard links between
identical immutable public artifacts in old release directories. The bridge
now accepts only the exact safe form of each condition. It still rejects scale
overrides, revision disagreement, environment disagreement, mutating Compose
dry-runs, links or special archive members, and any private owner attestation
with more than one hard link. Public runtime hard links are recorded path by
path and content-hashed, then dereferenced into independent regular archive
members.

The corrected helper bundle was SHA-256 verified in the development workspace,
CloudShell, and the encrypted migration volume. Its full production read-only
preflight passed and explicitly reported that no service or image was changed.
Bash syntax, the 14 deployment/legacy migration contract tests, and
`git diff --check` pass. The legacy four-service deployment remains healthy and
online. Cutover remains blocked until the exact committed candidate is built in
the canonical checkout layout, its new PostgreSQL environment is prepared
without exposing secrets, and both the forward startup and sealed legacy
restore commands are staged. Automatic execution remains disabled.

## 2026-07-31Z production cutover and archive receipt

The production cutover completed from the legacy flat four-service deployment
to the canonical single-VM stack at commit
`b65821894490e9717b4b0e42f4c447e1ebe56b73`. The active release now runs
quantd, web, Caddy, monitor-scheduler, PostgreSQL 17, the continuous market
archiver, and the IBKR market-data-only gateway. All seven services reached
their required healthy or stable-running state. Runtime verification confirmed
the Rust inference owner, a connected web-to-quantd path, all nine requested
frozen model artifacts loaded with zero failures, a ready provider supervisor,
HTTP 200 from Next.js, and every automatic-execution switch disabled.

Before writer quiescence, both production EBS filesystems had completed
snapshots. The exact legacy release, configuration, image IDs, runtime trees,
named volumes, checksums, and recovery command were then sealed on the separate
encrypted migration volume. That volume and the snapshots remain retained for
the rollback window. The dedicated market-data filesystem is now bind-mounted
into the canonical runtime through an explicit, validated `fstab` entry; no
market data was moved onto the root filesystem.

The first append-only SQLite-to-PostgreSQL archive inserted exactly 2,317,963
rows with zero duplicate or rejected rows and emitted a content-hashed archive
receipt. PostgreSQL remains private to the Compose network, its credentials
remain server-side, and the source rights are recorded as `INTERNAL_USE` rather
than silently upgraded to public display. The initial query exposed that its
`recorded_at`-first ordering required a large SQLite temporary sort. The
selection now follows the source `WITHOUT ROWID` primary-key order, and an
`EXPLAIN QUERY PLAN` regression test rejects any temporary B-tree sort for this
path.

Production Docker Compose 2.40 also exposed that `images -q` may return a bare
64-hex image ID instead of the older `sha256:`-prefixed representation. Runtime
verification, backup, emergency recovery, and final rollback verification now
canonicalize either representation through Docker before comparing or sealing
IDs. The production checkout itself remained clean; the temporary compatibility
verifier used during cutover was removed after the strict receipt passed.

Public verification returns HTTP 200 from the homepage and the read-only
`/api/quant/research/status` endpoint. Its after-hours feed-freshness gate is
correctly blocked while the model runtime remains 9/9 loaded and connected.
The earlier HTTP 410 from `/api/health` and redirect from
`/research/sector-rotation` were middleware allow-list omissions, not service
failures. Both exact paths are now explicitly active, with contract coverage,
so the trusted-TLS release seal and the public acquisition page reach their
intended handlers.

Post-cutover validation passes TypeScript typecheck and the 67-page production
build, nine deployment contracts, four acquisition contracts, shell syntax,
64 Python tests with five licensed/optional skips, Rust formatting, warning-free
Clippy, 495 Rust library tests, 16 CLI tests, 12 native integration tests, and
both production contract fixtures. The sector challenger remains shadow-only:
the six declared historical Databento partitions are not present yet, no
accuracy improvement is claimed, and no promotion can occur until the paired
purged walk-forward, untouched holdout, calibration, and forward-shadow gates
all pass.

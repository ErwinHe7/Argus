# Leo model and service source catalog

This repository contains the newer production sources under `platform/`. The
archived `axio7-model-review/` tree remains for reproducibility; it is not the
source of the current Astra's Pick static overlay.

## Models and research

| Capability | Canonical source | Current boundary |
| --- | --- | --- |
| Production quant inference and frozen model registry | `quant_engine_rs/`, `intraday_quant/`, existing model artifacts | Use each artifact's validation and freshness requirements; inclusion in Git does not promote a model. |
| Native research components | `quant_core_cpp/` | Native research, not duplicated in the browser. |
| Mean reversion MR-v1 and momentum MOM-v1 | `quant_engine_rs/src/strategy_lab/` | Deterministic replay and paper-only execution contracts. |
| Fixed-range GRID-R1 | `quant_engine_rs/src/strategy_lab/grid/`, `quant_engine_rs/grid_wasm/` | Browser-local historical replay; broker execution unavailable. |
| Price structure and market map | `quant_engine_rs/src/market_map.rs`, `quant_engine_rs/market_map_wasm/` | Conditional research scenarios, not calibrated forecasts. |
| Earnings move comparison | `quant_engine_rs/src/earnings_radar.rs` | Requires validated historical events and entitled contract quotes; withholds missing comparisons. |
| Options IV research | `intraday_quant/src/intraday_quant/iv_lab.py`, `lib/iv-lab/` | Dated conditional valuations; options execution unavailable. |
| Stock shortlist | `intraday_quant/src/intraday_quant/shortlist.py` | Three transparent technical rules; dated source-bound ranking, not a profitability claim. |
| Event evidence and outcome journal | `intraday_quant/src/intraday_quant/radar.py` | Source chronology and immutable local evidence; no invented probabilities. |
| Repeated local research | `intraday_quant/src/intraday_quant/strategy_lab/` | Deterministic program runs; no LLM required per evaluation. |

Paths above are relative to `platform/`. See the feature delivery records in this
directory for precise rules, validation results, missing evidence, and prerequisites.

## Website, APIs, and runners

- `features/research-desk/`: Astra's Pick, TradingView embeds, shortlist, radar,
  research evidence, and browser-local plans/journals.
- `features/strategy-lab/`: separate authenticated strategy workspace.
- `workers/event-radar/`: Cloudflare scheduled official-calendar collection.
- `workers/shortlist-feed/`: authenticated publication and public dated reads.
- `workers/public-market-map/`: public market-map service.
- `connectors/strategy/`: Rust runner and narrow local moomoo Python adapter.
- `connectors/research-runner/`: Windows/Linux operation and VPS preparation.
- `../ritual-investing-api/src/domains/strategy-lab/` and
  `../supabase/functions/strategy-api/`: owner-scoped strategy control plane.
- `../supabase/migrations/20260908003020_strategy_lab_control_plane.sql`:
  strategy storage and isolation. Apply only to the intended linked project.

Real-money execution remains disabled. Installing source code does not supply
broker authentication, historical-data entitlements, a signing certificate, or
evidence of an actual broker entry/hold/exit cycle.

## Reproduce the frontend

From `platform/`, install the locked Node dependencies, use the repository's Rust
toolchain, and add the `wasm32-unknown-unknown` target. Then run:

```sh
npm ci
rustup target add wasm32-unknown-unknown
node scripts/grid-research-build.mjs
node --import tsx scripts/research-desk-build.mjs
node node_modules/typescript/bin/tsc --noEmit -p features/research-desk/tsconfig.json
```

The Grid build creates a local source-hash receipt and WASM binary. Private
`.quant-runtime/` files are not uploaded. The approved dated display artifacts
are included because the static build validates their contracts and provenance;
they are not a replacement for a live market-data feed.

Production uses the verified static-overlay process described in
`event-radar-delivery.md` and `domain-publication.md`. The frozen backend release
is an external deployment prerequisite. Do not replace it by deploying a wholesale
build of the dirty Next.js application. Keep the original application, pricing,
authentication callbacks, service bindings, and existing Worker hostname.

## Hosting

The website and lightweight scheduled radar run on Cloudflare. They do not require
a VPS. A persistent local computer or user-owned VPS is needed for long-running
native research and a locally authenticated OpenD connector. No VPS purchase is
included in this source publication.

Credentials, broker account records, local databases, raw private market feeds,
generated caches, and installation dependency directories are excluded from Git.

# Daily Market Map artifact export

The canonical numerical implementation is `src/market_map.rs`. The browser renders
its `market-map-snapshot-v1` output; it never calculates indicators, scenarios or
simulation probabilities. This is a daily research view, not a streaming quote
feed. It does not estimate fair value, identify risk-free arbitrage or place orders.

## Production input and command

Run from `platform/quant_engine_rs`:

```sh
cargo run --locked --bin market-map -- --input /private/market-map-input.json --output /private/snapshot.json
```

The input JSON is the `MarketMapInput` Rust struct. Required fields:

| Field | Content |
|---|---|
| `asset` | `asset_id` UUID, symbol, name, asset_type, exchange, currency, market_timezone |
| `horizon` | `5d`, `10d`, `20d`, or `60d` |
| `bars` | 60–756 ordered, completed, adjusted regular-session OHLCV bars with RFC3339 `observed_at` |
| `sources` | Identified provider/dataset records with observation, availability and retrieval timestamps plus stated delay |
| `ohlcv_source_id`, `corporate_actions_source_id` | Source IDs resolving within `sources` |
| `options_iv` | `source_id`, fixed `tenor_days`, and 6–252 ordered `{observed_at, percent}` observations with consistent ATM definition |
| `sector` | `source_id`, `sector_id`, `sector_name`, `benchmark_symbol`, and 6–252 ordered `{observed_at, value}` benchmark closes |
| `corporate_actions_adjusted` | Must be `true`; the upstream importer verifies adjustments and corporate-action coverage |
| `display_authorized` | Must be `true`, set only after the importing process validates actual provider rights receipts |
| `generated_at` | RFC3339 generation/decision time; inputs must have been available by this time |
| `max_age_seconds` | Explicit daily research freshness tolerance, at most seven days; the published bundle also expires at the next expected completed session |
| `expected_sessions` | Expected historical exchange sessions; must equal observed bar count |
| `projected_sessions` | Exactly the horizon's future session close timestamps, from the exchange calendar |

Optional fields: `seed`, and `trades` with `{observed_at, price, volume}` plus
`trades_source_id`. Trades produce an **observed trade volume** profile. Without
trades, the optional profile is absent and its limitation is disclosed. Historical
daily volume and simulated endpoint density remain separate quantities.

The last six IV and benchmark points must align with the latest six returned bar
sessions. IV aligns by New York session date and preserves its actual observation
time (for example, 15:45 IV alongside a 16:00 close). Post-close observations are
rejected; IV source and evidence timestamps remain the actual IV sampling time.
Missing IV is not replaced with realized volatility. No missing vendor
data is replaced with a synthetic input. Entitlement, adjustments, missing coverage,
source causality, stale observations and invalid prices fail before output writing.

`platform/scripts/market-map-refresh.mjs` owns provider access, rights receipts,
exchange calendar coverage and publication of the final validated artifact bundle.
Provider credentials and unlicensed raw responses must remain outside the frontend.

## Numerical definitions

- SMA20 and Bollinger20 use completed closes; bands use population standard
  deviation and a multiplier of 2.
- RSI14 and ATR14 use Wilder smoothing with an arithmetic initialization over the
  first 14 changes/true ranges. Flat RSI is 50; no losses with gains is 100.
- Momentum is five-session price rate of change, with a five-observation SMA signal.
  Velocity is the daily log return in percent; acceleration is its first difference.
  Custom KNIFE/SPIKE conditions and remaining states are disclosed in provenance.
- ZigZag is a 3% closing-price reversal. Pivots record both the extreme observation
  time and later confirmation time. Confirmed historical pivots never use future
  data; the unfinished leg remains provisional.
- Support and resistance use the nearest confirmed close pivot on each side,
  falling back to the trailing 20-session low/high. Stretch/down use bands and ATR.
- Monte Carlo uses 5,000 seeded trials of overlapping historical five-session
  log-return blocks, sampled with replacement. SplitMix64 and complete input hashing
  make the artifact reproducible. Twenty-four paths and 512 terminal particles are
  stratified by terminal rank, retaining actual trial IDs. Thirty-two endpoint bins
  account for every trial. Scenario curves are pointwise 25th/50th/75th percentiles,
  not forecasts or necessarily single realizable trial paths.
- The simulation is explicitly **uncalibrated**. It does not infer empirical future
  probabilities, scale with IV, include execution costs or establish option value.
- THE READ is deterministic prose tied to resolving evidence IDs inside the same
  snapshot. It cannot invent news, causes, observed prices or a pricing discrepancy.

## Explicit visual-review artifact

```sh
cargo run --locked --bin market-map -- --example --horizon 20d --output ../lib/market-map/artifacts/review.json
```

`--example` produces an envelope with `mode: illustrative_review_only`, an explicit
synthetic notice, and a full `snapshot`. Symbol `DEMO` and all source labels identify
synthetic observations. The review has a fixed historical date and is served only by
the separately marked review path. It is never loaded as a fallback production map.
Other horizons can be generated with `--horizon 5d`, `10d`, or `60d`.

## Focused verification

```sh
cargo test --locked --lib market_map::tests
rustfmt --edition 2024 --check src/market_map.rs src/bin/market-map.rs
```

Tests cover known Wilder/SMA results, causal indicator/pivot prefixes, input
freshness/rights/coverage rejection, seeded reproducibility, genuine sampled return
paths, histogram trial conservation, and evidence/serialization integrity. The
orchestration layer additionally validates exported JSON against the strict schema.

## Public observed-data contract

`PublicMarketMapInput` is a separate input and output contract; the original member
equity map still requires its full entitled input set, including ATM IV history.
The CLI selects the public contract only for explicit `mode: public_market`.

Public inputs contain the existing asset, OHLCV bars, identified sources, horizon,
generation time, expected session count, freshness limit and supplied projection
dates. Additional fields are:

- `calendar`: `exchange` or `continuous`.
- `price_adjustment`: explicitly `unadjusted`, `split_adjusted`,
  `split_dividend_adjusted`, or `source_adjusted_unverified`.
- `ohlcv_source_id` and `benchmark: {source_id, benchmark_symbol, name, series}`;
  benchmark series contains observed `{observed_at, value}` closes.
- `rights: {access, terms_url, usage_note}` describing the actual public source
  terms, independently of member entitlements. Allowed access labels are
  `government_open_data`, `unauthenticated_public_api`, and `public_market_data`.

Equities and ETFs can use their real exchange timezone, including `Asia/Taipei`.
TWSE STOCK_DAY is labeled `bars.session: exchange_daily`: its official daily
statistics include more than the regular trading session. Its import convention
uses 17:00 Taiwan time as the statistics-date cutoff; source availability and
retrieval retain the actual fetch time. `regular_session_only` is false for these
statistics. The importer supplies official exchange session dates rather than
inventing weekdays. Continuous markets instead use `session: continuous`, UTC
midnight daily boundaries, consecutive observed days and projections including
weekends. Missing days, future observations and stale sources fail closed.

Public output uses `market-map-public-snapshot-v1`, retaining the same numerical
chart structure and explicitly returning `panels.implied_volatility: null`.
Coverage completeness refers to its three required inputs (OHLCV, benchmark,
simulation). `missing_inputs` lists `options_iv` and `trade_volume_profile`.
Unadjusted inputs remain labeled unadjusted: corporate-action price discontinuities
remain in the historical returns and are disclosed. No realized volatility is
substituted for option IV. The legacy `panels.sector` structural key carries the
actual named benchmark, not an inferred sector or institutional-flow label.

Both contracts call the same Rust indicators, ZigZag, reference-level, volume and
historical-bootstrap functions. The public path neither accesses nor bypasses the
existing member research routes.

The U.S. HF Data Library integration uses `source_adjusted_unverified`.
The provider describes adjusted prices, but its complete adjustment method and
dividend treatment have not been independently verified. This state deliberately
sets `corporate_actions_adjusted: false`; it means neither raw unadjusted data nor
verified complete split/dividend adjustment. The Read carries this distinction,
and indicators and simulations use the supplied values with that limitation.
`split_dividend_adjusted` remains available for a source with adequate adjustment
evidence; a provider declaration alone must not select it.
The [provider's daily update implementation](https://github.com/elkassabgi/hfdatalibrary/blob/main/pipeline/daily_update.py)
implements a split-detection heuristic with automatic rescaling for sufficiently
large consistent ratios and manual review below its threshold. Reviewing that file
did not establish a complete dividend-adjustment path; documentation claims are
therefore insufficient to mark this integration fully adjusted.

HF's documentation identifies post-2022 observations as IEX-only trading activity
rather than the consolidated tape. The public Read therefore calls volume
source-observed and, when IEX appears in the OHLCV source description or usage note,
explicitly distinguishes that volume from consolidated SIP totals. The displayed
close is likewise called the source-reported daily close. Provider descriptions
are documented in its [methodology](https://hfdatalibrary.com/pages/docs) and
[data-version definitions](https://hfdatalibrary.com/pages/versions); these statements
are not treated as independent proof of complete adjustment.

## WebAssembly runtime

`market_map_wasm` is a small standalone `cdylib` crate that imports this exact source
file. It has no network, filesystem, clock or vendor-secret access. It exposes only
the public-input calculation and never supports the synthetic review command.

```sh
rustup target add wasm32-unknown-unknown
cargo build --locked --manifest-path market_map_wasm/Cargo.toml --target wasm32-unknown-unknown --release
```

Copy `target/wasm32-unknown-unknown/release/market_map_wasm.wasm` into
`platform/workers/public-market-map/market-map.wasm` (respect an alternate
`CARGO_TARGET_DIR` when configured). The Worker statically imports the module and
creates `new WebAssembly.Instance(module, {})`; the module requires no imports.

The byte-buffer ABI exports `memory`, `mm_alloc(length)`, `mm_compute(pointer,
length)`, and `mm_dealloc(pointer, length)`. Encode an input JSON to UTF-8, allocate
and write its bytes, then compute. The returned `u64` is a JavaScript `BigInt` with
output pointer in the upper 32 bits and output length in the lower 32 bits. Decode
that output as `{ok:true,snapshot}` or `{ok:false,error}`. Reacquire memory views
after compute because memory can grow, and free both input and output buffers once
using their exact pointer and length. Inputs over 4 MiB are rejected. The Worker
owns source fetching, actual source terms, validation, caching and request access.

### Validation receipt — 2026-09-04

- The full locked production crate passed `cargo test --locked --lib
  market_map::tests`: nine tests passed, with unrelated tests filtered. Its native
  `market-map` binary built successfully.
- The standalone WASM crate passed ten tests, including the public-only JSON ABI
  boundary, and `cargo clippy --locked --all-targets -- -D warnings`.
- The released WebAssembly module is 1,305,303 bytes, has no imports, and exports
  exactly `memory`, `mm_alloc`, `mm_compute`, and `mm_dealloc`. SHA-256:
  `b073a930d412748b4cf506ffa1521495e93152245eaff20ea5aeb9ca607f96df`.
- Eight real TWSE inputs were exercised through the WebAssembly ABI: 2330 and 0050
  across all four horizons. Each used 126 observed exchange daily statistics ending
  on 2026-09-04, with completed-date closes of TWD 2,410 and TWD 107.9 respectively.
  All eight calculations succeeded and accounted for all 5,000 simulation trials.
  Every output retained missing IV as null and `regular_session_only: false`.
- For the same real 2330 input, WASM and native output had identical input hashes,
  seeds, RSI values and every terminal quantile (absolute difference zero in this
  check). Input and output byte buffers were explicitly released in the ABI test.
- Local Node measurements across those real inputs were approximately 9–32 ms
  after module loading, with an earlier cold computation near 50 ms. These are
  local observations, not a Cloudflare service-level guarantee. The Worker caches
  completed snapshots and must provide sufficient CPU for a cache miss.

The real input receipt is under the ignored runtime path
`platform/.quant-runtime/public-market-map/inputs.json`; source fetching and
website publication are owned by the public-data Worker/orchestration. No review
fixture was used to produce these public outputs.

### U.S. source-metadata revision — 2026-09-04

The `split_dividend_adjusted` extension passed all eleven WASM-crate tests,
including a targeted check of all three adjustment labels, unchanged indicator
values, rejected unsupported adjustment assumptions, and explicit IEX/SIP volume
scope. The updated release retains the same four ABI exports and zero imports.
Its size is 1,306,778 bytes and SHA-256 is
`cd11b5ab72d137f697c6ad4d5f150a35d3bd7fac8e12192740b5a6667ab6e105`.
This metadata validation does not itself certify availability of current AAPL/SPY
source data; the importer and publication checks handle that separately.

### Final adjustment-evidence correction — 2026-09-04

HF now uses `source_adjusted_unverified`, with
`corporate_actions_adjusted: false`. The focused adjustment/scope regression test
passed for all four adjustment states, verifies the explicit unknown-adjustment
wording, and confirms indicator values are unchanged when only the label changes.
This correction supersedes treating the HF provider declaration as sufficient
evidence for `split_dividend_adjusted`.

The rebuilt release is 1,307,367 bytes, retains the same four ABI exports and zero
imports, and has SHA-256
`12074f29aca70d383f287118d1b5d954c717168f148ece223895ba2763b5ed6b`.

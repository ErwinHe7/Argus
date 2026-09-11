# US Market Map data worker

`leo-market-map` prepares AAPL and SPY daily research from HF Data Library's
clean daily Parquet files, delegates every indicator and simulation calculation
to the shared Rust WASM module, and stores a validated bundle in KV.

The US adapter is implemented and tested. The authenticated HF download and
production US bundle are **not yet verified**: `HF_DATA_API_KEY` is still
required. Public metadata requests for AAPL and SPY both returned 200 on
2026-09-04. Missing credentials and expired data fail closed; an old Taiwan
snapshot, local EODHD review, or synthetic fixture cannot enter this service.

## Service and storage contract

- Secret: `HF_DATA_API_KEY`. Never put it in a Wrangler `vars` entry or browser
  configuration. HF requires a verified email and completed account profile;
  its [API reference](https://hfdatalibrary.com/pages/api) says keys expire after
  30 days, so operational key renewal remains necessary.
- KV binding: `PUBLIC_MAP_STORE`; US bundle key: `snapshots:us:v1`.
- `GET /status` returns `{available, mode: "public_market", market: "US",
  symbols: ["AAPL", "SPY"], expires_at?}`. Availability requires credentials and
  all eight current HF/IEX snapshots with correct US asset metadata.
- `GET /snapshots` returns `{mode, generated_at, expires_at, snapshots, receipts}`.
  Optional `symbol=AAPL|SPY` and `horizon=5d|10d|20d|60d` filter the response.
- Invalid queries return 400. Missing, invalid, or expired data returns 503.
  Read requests never contact the source or run simulations. The website calls
  this worker through its `PUBLIC_MARKET_MAP` service binding.
- There is no public recompute endpoint. Cron runs at **13:00 and 14:00 UTC**;
  the second attempt accommodates upstream publication delays. A complete
  successful bundle replaces the US key last. Failed runs leave existing data
  untouched, with its original expiry. The old `snapshots:v1` key is not read
  or overwritten by the US adapter.

## HF source, format, and security

The documented authenticated two-step request is:

1. `GET https://api.hfdatalibrary.com/v1/download-token/AAPL?timeframe=daily&format=parquet&version=clean`
   with `X-API-Key` (SPY uses the corresponding ticker).
2. Fetch the returned short-lived signed URL on the **same exact allowlisted
   origin** without the API-key header. Every redirect is rejected.

The live API's [maintainer source](https://github.com/elkassabgi/hfdatalibrary/blob/main/api/src/index.js)
warns that non-minute CSV objects may not exist, despite the daily CSV example
in the documentation. This adapter therefore requests daily **Parquet** directly.
The provider's [upload code](https://github.com/elkassabgi/hfdatalibrary/blob/main/pipeline/r2_client.py)
uses PyArrow `write_table` with its default Snappy compression. `hyparquet`
1.29.2 decodes Snappy, timestamps, and INT64 volume in the Worker; it performs
deserialization only. No TypeScript OHLC aggregation or quantitative model is
introduced. Original downloads are bounded at 8 MiB and 15,000 rows.

Signed URLs and headers exist only within that request. Cache entries and
receipts contain the stable, token-free endpoint. Original Parquet bytes are
stored as base64, and their SHA-256 is computed from the actual binary body.
Fetch errors log only the origin/path and stable error codes, never error bodies,
headers, query tokens, or credential-bearing exception text.

## Observation and adjustment semantics

The provider's [daily aggregation code](https://github.com/elkassabgi/hfdatalibrary/blob/main/pipeline/aggregate.py)
retains `datetime`, OHLC, summed Volume, and the last `source` tag. Recent rows
must explicitly carry `source="iex"`. This is **IEX-only observed trading**,
not the consolidated SIP tape, NBBO, or total market volume. Daily OHLC may
differ from consolidated prices. No missing session or sparse minute is filled.
All 126 expected daily sessions must be present for both assets.

HF's website describes adjusted prices, but its
[incremental pipeline](https://github.com/elkassabgi/hfdatalibrary/blob/main/pipeline/daily_update.py)
shows limited heuristic split handling and does not establish complete dividend
adjustment. The adapter uses `price_adjustment="source_adjusted_unverified"`
and `coverage.corporate_actions_adjusted=false`. Neither raw-unadjusted prices
nor independently verified corporate-action adjustment is claimed. The current
data vintage is unsuitable as point-in-time backtest history without separate
vintage controls. Upstream trade-break corrections are also incomplete.

Apple uses SPY as its S&P 500 ETF comparison; SPY uses an explicitly named Apple
comparison. These are comparison assets, not inferred sector fund flows.
Options IV and observed trade-volume-by-price remain absent. Their fields and
missing-input names stay explicit; ATR/realized volatility never replaces IV.
The Rust model still computes 5,000 historical-bootstrap paths for each horizon.

## Calendar and freshness

`us-calendar.ts` records the official
[NYSE 2026–2028 calendar](https://www.nyse.com/trade/hours-calendars), verified on
2026-09-04. It includes holidays, half days, and America/New_York DST offsets.
The schedule has a bounded validity range; unknown years fail closed. Emergency
exchange closures require a calendar update and otherwise cause missing-data
rejection. The calendar receipt hashes the derived session schedule, **not** an
HTTP response body; its timestamp records the review of the official table.

HF's scheduled ingestion starts at 06:00 UTC, with no guaranteed completion
time. The adapter uses 08:00 UTC on the next calendar day as an earliest T+1
target; it is never labeled the actual availability time. AAPL/SPY metadata was
still updating at 10:24/12:31 UTC during the initial check. Actual `available_at`
and `retrieved_at` always use the download receipt time. Each bar's observation
timestamp is its actual XNYS regular-session close, including early closes.

Unfinished and not-yet-due rows are excluded. Expiry is the next trading
session's next-day **14:30 UTC** refresh deadline, capped at seven days after
the last observation. Redownloading an old file cannot extend that deadline.
Weekends and market holidays extend the correct publication window; stale
source files eventually return unavailable rather than a new freshness label.

## Attribution

Elkassabgi, A. (2026). *HF Data Library*.
[DOI: 10.5281/zenodo.19501605](https://doi.org/10.5281/zenodo.19501605).
The compilation is CC BY 4.0; post-2022 observations also carry IEX's terms:
Data provided for free by IEX. By accessing or using IEX Historical Data, you
agree to the [IEX Historical Data Terms of Use](https://www.iex.io/legal/hist-data-terms).
Both attributions are retained in the snapshot's rights/source information.

## Initial generation and release

With `HF_DATA_API_KEY` already set in the process environment, run from platform:

```powershell
node --import tsx scripts/public-market-map-refresh.mjs --force
```

This uses the same source adapter and WASM module, caches raw documents under
`.quant-runtime/public-market-map-us/`, and writes
`lib/market-map/artifacts/public-us-bundle.json` only after all gates pass.
`--fetch-only` writes local inputs without computing. The command never changes
KV. If it reports `hf_api_key_missing`, no live HF download was attempted.

After a successful actual-source run, install the Worker secret through
`wrangler secret put HF_DATA_API_KEY --config workers/public-market-map/wrangler.jsonc`,
seed **only** the validated US file to `snapshots:us:v1`, and deploy the feature
configuration. The caller must then verify `/status`, the returned observation
cutoff, and one actual scheduled-event refresh. Until that validation succeeds,
this remains a prepared integration, not a verified production feed.

Raw scheduled responses use `source:hf:us:v1:<stable-url hash>` for a 15-minute
cache and `raw:hf:us:v1:<original-binary hash>` for 120-day retention. Provider
keys are not part of either cache key.

Narrow checks:

```powershell
node node_modules/typescript/bin/tsc --project workers/public-market-map/tsconfig.json
node node_modules/tsx/dist/cli.mjs --test scripts/public-market-map.test.ts
```

`scripts/fixtures/hf-daily-snappy-test.json` contains explicitly synthetic Parquet test
data for Snappy/timestamp/INT64 parsing and the WASM boundary. It is never a
production snapshot or fallback. Authenticated HF download remains a separate
required verification. `PublicMarketMapEnv` keeps generated Worker runtime
types separate from the website's Cloudflare globals.

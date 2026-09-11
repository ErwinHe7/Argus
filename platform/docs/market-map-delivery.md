# Market Map delivery — 2026-09-04

## U.S. code deployed — feed activation awaits the HF credential

The owner clarified that the feature must use U.S. equities. The Taiwan release
below does not meet that requirement and is being superseded, not relabeled.
The default U.S. instrument is AAPL, with SPY as the public comparison instrument.
Source ingestion targets HF Data Library's clean daily Parquet exports, with IEX
venue coverage, USD prices and the U.S. exchange calendar explicitly identified.

HF's metadata endpoint was reachable and showed current files, but downloads
require a free account with a verified email and an API key. No key has been
provided yet. The owner has been asked for it while implementation proceeds.
The credential is a Worker secret, never a browser setting. Keys expire after
30 days according to the provider. [API](https://hfdatalibrary.com/pages/api),
[source license](https://hfdatalibrary.com/pages/license).

EODHD demo returned genuine current AAPL/VTI daily observations and may be used
for a local personal evaluation only. Its public-display restriction prevents
using it as the production feed. No EODHD response is seeded to production KV.
The public route and navigation fail closed until a valid U.S. bundle exists.

The provider's actual download implementation guarantees daily Parquet, not
daily CSV. The adapter retains exact Parquet bytes and their SHA-256 receipt,
uses a bounded Snappy-capable decoder, and never persists the signed URL or key.
Its public site describes adjusted prices, but the inspected incremental
pipeline shows heuristic split handling without a verified dividend-adjustment
step. HF inputs therefore use `source_adjusted_unverified` and do not claim
verified corporate-action adjustment. All numerical analysis still runs in Rust.

The genuine local AAPL review showed the 328.21 close for September 3, 2026,
with 130 observed sessions and VTI as the explicitly named comparison. Browser
verification confirmed that changing 20D to 5D updated the chart and The Read.
Public production uses AAPL/SPY only after HF ingestion succeeds; these local
EODHD observations are not proof of public HF activation.

U.S. data Worker deployed as `2f4ff515-22a7-4170-a08e-8f7091cb4c0b`.
Its live `/status` returns `available:false, market:US`; AAPL snapshots return
503 because credentials are absent, and the former `2330` query returns 400.
No U.S. production snapshot or EODHD local snapshot has been written to KV.

Website Worker `leo` deployed as `928e86d6-d58d-4e54-9acd-ee4d8956ccd5`.
`npm run build:cloudflare` passed, including Next compilation and TypeScript
validation. The deployed homepage returned 200 and browser inspection confirmed
that the missing-data Market Map link is absent. The Map route returned an
actual HTTP 404, AAPL's public API returned 503, the old Taiwan public query
returned 400, and the unauthenticated member API continued to return 401.
The loading boundary was removed so missing data does not prematurely stream
a 200 response. No current-market or synthetic placeholder is displayed.

The 11 focused U.S./legacy contract tests and standalone Worker typecheck
passed. Tests include actual Snappy Parquet decoding of a disclosed synthetic
fixture, U.S. session boundaries, eight WASM outputs, old-market rejection,
source/token checks and expiration. Nine existing navigation tests also passed.
The older Taiwan checks below do not establish U.S. production ingestion success.

The interactive personal review remains available at
`http://127.0.0.1:3000/discover/market-map` while the local processes run. Its feed
listens only on `127.0.0.1:8790`; Next also binds to loopback. The final browser
check showed only the available AAPL selector, its genuine 328.21 close, the
simulation cloud and matching explanation. Its source remains explicitly
EODHD demo / personal local evaluation; VTI is the named benchmark. This local
snapshot expires at 2026-09-04T22:00:00Z.

Remaining activation step: supply the verified-account `HF_DATA_API_KEY`, run
and validate an actual HF download, seed the valid U.S. bundle, and verify a
real cloud scheduled refresh. The prepared parser/fixture checks do not replace
that real-source validation. No free account was registered on the owner's
behalf, and no provider subscription was purchased.

## Previous Taiwan release (superseded by U.S. requirement)

- Website: https://leo.axio7.workers.dev/discover/market-map
- Website Worker `leo`: `10b4bed3-514e-46d5-8970-51ba5e155aec`.
- Data Worker `leo-market-map`: `25676800-4bbc-4ba3-9c84-733b54bcebee`.
- Source: official Taiwan Stock Exchange daily tables, 2330 and 0050, with
  126 actual trading days per asset and four simulation horizons each.
- Latest observed date at release: 2026-09-04; closes 2410 and 107.90 TWD.
- Refresh: daily at 10:00 UTC / 18:00 Taipei. Official responses feed the
  canonical Rust engine compiled to WASM; complete validated bundles replace KV
  `snapshots:v1`. The website uses an internal Cloudflare service binding.

This release supersedes the initial synthetic preview below. The former
`/discover/market-map/preview` route redirects to the real-data page, and the
homepage links directly to that page. No synthetic fallback is present in the
public feed. The original member-vendor route retains its authentication and
entitlement checks.

### Source semantics and missing inputs

TWSE daily volume includes regular, odd-lot, after-hours fixed-price and block
transactions, so these records are labeled `exchange_daily` with a conservative
17:00 Taipei statistics cutoff and actual retrieval times. Prices are unadjusted;
corporate actions may affect price-return indicators. Historical dates are
checked against official all-market trading records, including the 2026-07-10
closure; future reference dates use the official holiday schedule.

Option IV and observed trade-level volume profiles are not supplied and remain
missing. The UI explicitly labels its fourth panel as ATR14 in TWD, states the IV
gap, and names the comparison asset. The chart, levels, simulations and The Read
all come from the same Rust snapshot.

Source and usage basis: [registered daily dataset](https://data.gov.tw/dataset/11549),
[TWSE terms, open-data exception](https://www.twse.com.tw/zh/terms/use.html), and
[Open Government Data License 1.0](https://data.gov.tw/license). The page includes
source/license attribution. Applying the dataset's published usage basis to its
official monthly historical representation is an inference, not a claim that
TWSE supplied a separate written authorization to this project. Raw-source JSON
receipts and notes are retained by the ingestion pipeline.

### Current release verification

- `npm run typecheck` and `npm run build:cloudflare` passed. Worker standalone
  TypeScript checking passed. The website excludes generated OpenNext output and
  the Worker's separate runtime type project from its own compilation; binding
  types are still generated from the actual Wrangler configuration.
- Native engine build and 9 focused engine tests passed. The WASM wrapper's
  10 tests and strict Clippy passed; real input calculations matched native
  numerical outputs. All 8 real artifacts passed the website schema.
- 10 focused public/legacy contract tests passed. Independent source/contract
  review found no blocking issue.
- Remote scheduled execution really fetched TWSE sources, recomputed all eight
  snapshots and updated KV at `2026-09-04T12:20:44.633Z`; its provider retrieval
  times were later than the initial local seed. This was verified beyond a
  scheduler acknowledgment, using both the success log and the new stored data.
- Deployed default and 0050 pages returned HTTP 200 with the correct real
  closing values. `/api/market-map/public?symbol=2330` returned four real
  horizons with 126 bars, `IV=null` and no DEMO data. The original unauthenticated
  member endpoint continued to return HTTP 401.
- Browser verification confirmed rendered real prices, horizon changes and
  matching changes to the simulation explanation; local verification also
  covered asset selection, evidence linking and the mobile layout.
- The old preview redirect uses Next streaming: its initial HTTP status may be
  200 with a redirect marker, rather than a standalone HTTP 307 response.

## Initial illustrative release (superseded)

Published to the existing Leo Cloudflare Worker:

- Preview: https://leo.axio7.workers.dev/discover/market-map/preview
- Worker: `leo`
- Version: `244202bb-e0a6-4100-b365-51224329d99b`
- Build: `npm run build:cloudflare` completed successfully.
- Deploy: `opennextjs-cloudflare deploy` completed successfully.

The release includes four illustrative horizons (5, 10, 20 and 60 sessions),
historical candles, SMA/Bollinger bands, pivots and reference levels, actual Rust
bootstrap simulations, volume/RSI/momentum/IV and sector panels, a separate
traded-volume profile, and explanations linked to snapshot evidence. Every
example input is disclosed as synthetic. This is a feature preview, not a live
market feed or a promoted valuation/prediction model.

## Verification

- TypeScript check and production Next/OpenNext build passed.
- Six focused Rust tests; twelve data/contract/normalization tests; nine existing
  navigation tests passed. Rust formatting and isolated strict Clippy passed.
- Desktop and mobile layout/interaction review passed for the illustrative
  preview. The Impeccable detector returned no findings.
- On the deployed page, switching from 20D to 5D changed the selected horizon,
  simulation summary and terminal values. Returning to 20D restored those
  values. Selecting explanation evidence highlighted the corresponding ledger
  references and exposed source labels and dates.
- Public preview and homepage returned HTTP 200; the homepage includes its link.
- Unauthenticated `/api/market-map?symbol=DEMO&horizon=20d` returned HTTP 401 with
  `authentication_required` and no snapshot.
- `/discover/market-map/DEMO` renders Next's not-found content with noindex and
  no map or synthetic snapshot. Because this route streams, its HTTP status is
  200 (a soft 404); it is not a hard HTTP 404.

## Remaining activation inputs

Production snapshots remain empty and hidden until the configured market-data
credential, same-tenor historical ATM IV, instrument/calendar configuration,
runnable research executables, source display-rights evidence and existing
member-authentication configuration are supplied. A real trade archive is also
needed for the observed-trade volume-by-price panel. See
`lib/market-map/README.md` for exact input formats and the refresh command.

No actual provider data connection or scheduled refresh has been activated.
The daily refresh implementation is ready to be configured with those inputs.

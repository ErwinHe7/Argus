# Astra's Pick

Astra's Pick opens with a short, explained stock ranking. Read why a candidate
stands out, inspect its chart and counterpoint, then keep a plan. Broader markets
and the fifteen retained tools support that first decision. The existing purple
model palette and Leo Lion remain.
Source paths, asset paths, route IDs, and storage keys retain research-desk
naming for compatibility; that is not the public product name.

## Public routes

| Route | Destination |
| --- | --- |
| / | Picks: dated technical shortlist; served at the root without a redirect |
| /#/board | Markets: provider stock, crypto, and forex screeners |
| /#/structure?symbol=AVGO | Charts for the selected instrument |
| /#/iv?symbol=AVGO | Options lab for a supported stock |
| /#/positions?symbol=AVGO | Trade plan with the symbol prefilled |
| /original/ | Preserved original Leo marketing homepage |
| /app/ | Existing Leo app |
| /app/research-desk/ | Compatible direct entry and static asset base |

The feature-owned worker-routing.ts serves the static analyzer for GET/HEAD /,
canonicalizes /original to /original/, and delegates the preserved homepage to
the original Worker. It guards the original page's cached layout alias. Other
requests keep the original Worker, Request, bindings, methods, and bodies.
Source wrangler.jsonc persists main as features/research-desk/worker-entry.mjs.
That entry wraps the frozen Worker and re-exports its named handlers. The
original-page alias patch and cache revision are documented in the release stage.

## Tools and boundaries

The header exposes Picks, Markets, My plans, and a Tools disclosure. All tool IDs
remain hash routes under the root or compatible direct entry. The original site
remains accessible in the footer. Picks and local journals/plans load independently
of option/event/chart archives.

| Hash route | Public tool | Implemented capability |
| --- | --- | --- |
| #/strategies | Strategies | MR/MOM rules and local paper connector controls; separate GRID-R1 browser-local historical replay with per-slot accounting and clearly labeled fictional demonstrations. Grid broker execution unavailable. |
| #/foundry | Return enhancement | Validated data/foundry.json: four research-agent roles, the PROBE → BACKTEST → PAPER ladder with both live stages locked, a historical covered-call/collar/protective-put backtest against buy-and-hold, and the agent ledger. Currently both sections are pending; no result is published. No orders or options execution. |
| #/crypto | Crypto | TradingView's Coinbase BTC/USD and ETH/USD daily charts in UTC, attribution, and a link to create a local plan. No local crypto dataset or option-model integration. |
| #/playbook | Market overview | TradingView SPY chart plus separately dated averages, RSI, realized volatility, ATR, and trailing range. SPY remains an ETF proxy. |
| #/tech-playbook | Technology | TradingView QQQ chart and dated research context; QQQ is an ETF proxy, not NDX. |
| #/radar | Event radar | Official-source calendar collection, source freshness, deterministic explanations, chart/plan links, and evidence export. |
| #/earnings | Earnings radar | Sourced earnings-call dates and validated local earnings-comparison reports; the user-entered calendar remains available. |
| #/structure | Charts | TradingView candles and volume for ten tracked markets; verified AAPL/MSFT/WMT chart links also resolve. Dated SMA20/SMA50/RSI, replay, reference levels, and readings remain in an expandable archive. |
| #/forecast | Forecast record | Publication requirements and recorded evidence; no published probability model or verified performance record. |
| #/board | Markets | TradingView stock, crypto, and forex screeners with provider sorting, filters where supported, and verified full-screener links; archived observations and export remain separately accessible. |
| #/algo | Trade journal | User-entered strategy notes and reviews. No algorithm execution or verified performance. |
| #/positions | Trade plans | Symbol-prefilled local thesis, reference price, review, open/closed state, and export. No brokerage synchronization. |
| #/events | Event radar | Alias of the source-backed radar, with unknown outcomes preserved; not a general news feed. |
| #/research | Methods | Data coverage, technical and options assumptions, and downloadable source artifacts. |
| #/iv | Options lab | Six underlying symbols, TradingView underlying chart in Charts, dated Call/Put assumptions, 12,960 precomputed conditional valuations, and a local notebook. |
| #/handbook | Guide | Workflow, units, storage guidance, and existing Leo Plans & payment access. |

## Sources and analysis

AstraHome.tsx owns the ranked shortlist, candidate evidence, selected chart,
recovery states, and plan entry. ExploreMarkets.tsx owns broader provider browsing.
Desk.tsx owns the shell and tool routes. The shared
`tradingview/` module owns provider listings, isolated hosted charts, ticker tape,
market board, loading/retry, and attribution. CryptoMarkets.tsx uses the shared
chart. catalog.ts, desk.css, types.ts, and storage.ts
retain feature ownership. The Options lab reuses components/iv-lab/IvLab.tsx.

The local IBKR artifact contains DXYZ, ZM, AVGO, AMZN, GOOGL, NVDA, SPY, and QQQ.
DXYZ is a closed-end fund; SPY and QQQ are ETF proxies. Daily history ends on
September 4, 2026. The first six symbols were collected September 6; SPY/QQQ
were collected September 7 at 10:01:18 UTC. Spot observations and completed
closes remain separate. Rebuilding does not refresh a quote.

Python exports data/market-analysis.json with the astra-market-analysis.v1
schema and astra-daily-market-read.v1 feature version. Close above both SMA20
and SMA50 is Uptrend; below both is Downtrend; equality/disagreement is Mixed.
Missing inputs remain Unavailable. RSI14 at or above 70 is Overbought, at or
below 30 is Oversold, and between is Neutral. These describe recorded data,
not forecast strength or reversal probability. Summaries, watch conditions,
and basis are exported alongside their cutoff. Watch conditions compare with
frozen reference levels; they are not monitored alerts or validated trade rules.

The retained option data includes annualized composite IV, the provider's own
52-week IV percentile, and annualized realized volatility over 20 sessions.
Independent IV/percentile timestamps and the composite tenor are unavailable.
Composite IV is not a listed contract quote. The options model uses stated
European Black–Scholes assumptions and excludes costs, American early exercise,
and actual dividends. Calendar completeness and corporate-action adjustment
remain unverified. See [data/README.md](data/README.md) for the retained evidence
and data-generation contract.

The primary charts, ticker tape, and market board use TradingView's hosted data.
Stock/fund availability and delays vary by listing; crypto uses Coinbase spot.
The widgets do not republish data into this project or supply research, option
model, or broker execution inputs. Existing IBKR metrics remain dated snapshots.

The Return enhancement page (`foundry/`) renders data/foundry.json, a
leo-foundry-publication.v1 document written by the offline Python foundry. The
browser and build validate it with foundry/contract.ts and reject overlays
labelled as synthetic fixtures (the Python `publish` refuses every synthetic
input); TypeScript formats values and derives none. Regenerate it from
Argus/platform/intraday_quant with the command below. With no `--state-dir` or
`--overlay-artifact` it writes the pending sections; published sections need
`--rights-confirmed`. The [root README](../../../README.md) section "Return
enhancement & exploration agents" covers the roles, ladder, commands, and data
rights.

~~~powershell
python -m intraday_quant.foundry publish --output ../features/research-desk/data/foundry.json
~~~

The [shortlist contract](shortlist/README.md) explains the separate three-rule
Python screen, exact source binding, five-company/three-fund scope, expiry labels,
and regeneration commands. Screen matches are descriptive research candidates;
they do not establish fundamental value, profitability, or trading authority.
Bootstrap scripts run inside opaque-origin data iframes, so they cannot read
Leo authentication storage. Strategies and the exact OAuth callback omit the
global tape; chart pages remain usable during local research-data outages.
See [tradingview/README.md](tradingview/README.md) and the
[TradingView delivery record](../../docs/tradingview-delivery.md).

## Local records

Calendar, journal, and plan records retain leo.research-desk.records.v1 in
localStorage, up to 200 entries. Option notes retain leo.iv-lab.notebook.v1,
up to 100. Data stays in that browser and origin. Exports preserve a copy;
clearing storage or changing devices does not transfer records. Storage errors
remain visible. The existing Leo membership workflow is unchanged.

## Build and review

From Argus/platform:

~~~powershell
node scripts/grid-research-build.mjs
node --import tsx scripts/research-desk-build.mjs
node node_modules/typescript/bin/tsc --noEmit -p features/research-desk/tsconfig.json
node --import tsx --test features/research-desk/worker-routing.test.cjs
node --import tsx --test features/research-desk/foundry/contract.test.ts
~~~

For a clean checkout, install dependencies and the Rust WASM target first; see
[the model and service source catalog](../../docs/model-catalog.md). Production
still requires the frozen backend release and the static-overlay process.

The static build emits HTML, JS/CSS, JSON artifacts, Lion, and Inter under
public/app/research-desk/. It does not rebuild the server backend. Include
feature data files explicitly in a source release because the repository's
data ignore rule also matches this directory.

The previous published visual evidence is under .impeccable/review/astra-pick/.
The follow-up verdict marks both scored mobile fixes resolved with no visible
regressions: the home chart uses a compact 600 × 290 SVG and 20-unit axis text
below 700px, while the three-column options watchlist stacks symbol, IV, and
percentile within each cell below 650px. The chart text measures 10.73 CSS pixels
at a 390px viewport. Its ship disposition covers those two fixes, not a blanket
review of the whole surface. The analyzer is now live at the root. Browser
checks confirmed the Astra's Pick root/title, loaded market readout, real BTC
widget, one original-page scene, and no page errors. The receipt is
.impeccable/review/astra-pick/live-browser-checks.json in the platform.
The later TradingView integration is prepared locally, with evidence under
`.impeccable/review/tradingview/`; it does not claim a new public deployment.
Earlier Research Desk checks apply to the predecessor. [DESIGN.md](DESIGN.md)
and its scoped sidecar describe the current implementation.

## Release boundary

The current stage is workspace release-work/leo-research-home-20260907/.
It preserves the prior compiled backend and non-feature assets, with the
feature routing wrapper and updated static assets. Use that stage's RELEASE.md,
stage-receipt.json, and audit-stage.py for exact manifests and validation.

Astra's Pick is live at https://leo.axio7.workers.dev/ on version
31f5c855-3aec-4e01-9ad9-e0869ee5cee5. Deployment
854644a6-f0d1-4d68-8bed-9621d4d92790 serves 100% of traffic. The predecessor version
e7017d50-5991-4cc1-89f7-6c7048bc406e remains the rollback reference. No
custom-domain change is claimed. All 23 live asset hashes match the stage;
root, original, app, pricing, and both health endpoints pass. Bindings and the
frozen backend remain unchanged, with only the documented original-page alias
client chunk amended. The stage's live-verification.json,
deployment-status.json, deployed-version.json, and RELEASE.md retain the
publication receipts. Do not rebuild unrelated dirty Next source through the
general deploy:cloudflare command for this staged release.

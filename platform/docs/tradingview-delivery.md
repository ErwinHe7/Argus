# TradingView integration

The user's chart reference now defines the primary market display: dark
TradingView candlesticks, volume, timeframes, and technical tools inside Astra's
existing aubergine interface. The integration is a static frontend change.

## Coverage

The overview, Charts, SPY/QQQ market views, Crypto, and the Options lab Charts tab
use the shared hosted chart. The tape and Market board show provider quotes.
All ten existing markets have verified exchange-qualified listings: DXYZ, ZM,
AVGO, AMZN, GOOGL, NVDA, SPY, QQQ, Coinbase BTC/USD, and Coinbase ETH/USD.
AAPL, MSFT, and WMT also resolve for strategy/reference links. Unknown listings
show an external symbol-search link instead of an exchange guess. WMT's current
listing is NASDAQ:WMT.

TradingView's [U.S. widget coverage](https://www.tradingview.com/widget-docs/markets/north-america/)
lists delayed stock/fund data; its
[worldwide coverage](https://www.tradingview.com/widget-docs/markets/worldwide/)
lists Coinbase as real-time. The displayed provider status governs each chart.
Loading a widget does not verify quote timeliness or completeness.

These are official hosted widgets, not a raw market-data API. Their quotes do
not enter Leo's research calculations, option inputs, or local trading runner.
The [provider data FAQ](https://www.tradingview.com/widget-docs/faq/data/)
explains this distinction and why a personal TradingView subscription does not
upgrade website widget data.

## Retained behavior

Recorded research, IV assumptions, and contract quotes retain their original
source and cutoff. Charts exposes the old indicators, reference levels, and
history replay in a dated disclosure. Market board retains archived export.
Options lab labels its recorded model-input chart and metrics separately.
Google identity, paper controls, journals, trade plans, and local records retain
their existing ownership and storage. Strategy symbols have a separate chart
link; TradingView cannot submit or influence broker orders.

## Integration boundary

`features/research-desk/tradingview/` contains the explicit listing registry,
official embed configuration, React components, isolated iframe document,
provider smoke check, and focused tests. Bootstrap scripts execute only in
sandboxed opaque `data:` origins. They cannot read parent cookies/storage or
navigate the top-level page. Attribution and external provider links remain
visible. Only bounded presentation-state messages from the current iframe and
attempt are accepted; no prices cross into Leo state.

Symbol changes and retries dispose of their previous frames and listeners.
External `tvwidgetsymbol` query strings cannot override the selected listing.
Strategies and the OAuth callback do not mount TradingView frames. Stock,
crypto, ETF, and board routes can render without the archived JSON files.

## Verification and release

The scoped TypeScript check and static build pass. Twenty-five tests cover
mapping, embed isolation, message validation, existing routes, session/control
contracts, and browser-local records. Actual provider and browser evidence is
recorded under `platform/.impeccable/review/tradingview/`.

Its browser receipt records 19 passing checks, no page errors, and seven settled
desktop/mobile captures covering home, stock charts, board, Options Charts, and
Crypto. Injected bootstrap failures and archived-JSON outages are labeled as test
events. The independent finish review's documentation finding is resolved; its
ship disposition is limited to that scored fix. Generic agents supplied the
Impeccable reviewer and documenter roles. The existing aubergine/gold/Inter design,
Lion assets, and provider presentation boundary are synchronized in DESIGN.md,
its sidecar, and the surface brief. This creates no new brand palette or raster.

The final reduced-motion source replaces the moving tape with ten static symbol
links and a Market board link, displaying no prices and mounting no hosted tape.
That later state is verified in `mobile-reduced-motion.png` and the final grid
browser receipt: ten static symbol links, no hosted tape, and an actual provider
chart. The separate reduced-motion review gives a scoped ship disposition. Grid
strategy work and its visual review remain separate.

The shared-provider smoke observed all three official widget frames and seven
chart canvases. All three outer frames were blocked from reading parent test
storage. An optional widget-sheriff request failed while chart rendering worked;
this is documented as external-provider behavior, not a quote-quality test.

Web release preparation uses a fresh static overlay of the previously prepared
Strategy Lab stage. The frozen backend and unrelated assets must remain
byte-for-byte identical. No Next.js server rebuild, broker operation, hosted
deployment, or native connector package change is included.

The final combined stage is
`C:/Users/Hj/Desktop/Leo Roar/release-work/leo-grid-tradingview-20260907`.
Its receipt verifies 2,583 unchanged frozen backend files, unchanged unrelated
assets and Worker configuration, and eight changed desk-owned assets. All current
public desk files match the staged hashes. Wrangler 4.127.1 completed the final
deploy dry run with 358 assets; the stage remains prepared and not deployed.
The retained backend's existing `=== -0` warning is recorded in `dry-run.log`.

## Picks follow-up

The later Picks-first refinement adds provider stock, crypto, and forex
screeners to Markets and a separate dated Python-generated shortlist to the
homepage. Its scope, browser evidence, source-data boundary, and newer prepared
static overlay are recorded in [picks-delivery.md](picks-delivery.md). The receipts
above remain historical evidence for the earlier TradingView extension.

# Hosted TradingView presentation

`TradingViewChart`, `TradingViewTape`, and `TradingViewBoard` embed the official
TradingView widgets. Charts request dark daily candles and volume. Their controls
can change the displayed timeframe; the site does not read the resulting prices.

The default market registry preserves the eight existing stock/fund instruments
and Coinbase BTC/USD and ETH/USD. AAPL, MSFT, and WMT also have explicitly verified
chart mappings for strategy examples. Unknown symbols link to TradingView's symbol
search instead of guessing their exchange. An empty board remains empty.

TradingView's published coverage lists U.S. equities as delayed and Coinbase as
real-time. Availability, entitlement, session, timestamp, and delay indications
inside each widget remain the authority for that display. Loading an iframe does
not verify quote freshness. Widgets cannot supply the historical research inputs,
IV fields, strategy observations, or broker execution prices used elsewhere.

## Isolation and lifecycle

Each official bootstrap runs inside a sandboxed `data:text/html` iframe. The data
origin is opaque, even with `allow-same-origin`; Leo's authentication storage is
inaccessible. Neither third-party bootstrap scripts nor market-data code execute
in Leo's parent document. `srcdoc` with `allow-same-origin` would lose this boundary
and must not replace it. Popups may open TradingView with no referrer, but the
embedded frame cannot navigate the top-level page.

Each symbol change or retry gets a fresh iframe and attempt ID. Cleanup removes
the frame, timeout, and listener. Parent messages accept only the current window,
the opaque `null` origin, and the current attempt ID; they contain presentation
state only. A provider frame load dismisses the loading message without asserting
that prices are real-time or even available. The external open link remains usable
when scripts fail or TradingView displays an internal data error.

Charts always expose Retry, including after the embed reports that it loaded.
This lets a user recover when the provider has no prices without pretending Leo
can inspect the cross-origin quote state. A bootstrap failure displays an
explicit message inside the reserved chart region as well as its recovery
controls. Retrying disposes of the old frame before creating the new attempt.

The isolated document has no Leo URL query, so a `tvwidgetsymbol` query on Leo
cannot override the selected listing. Chart symbol changes are disabled.
TradingView branding and links remain visible inside each frame.

## Verification

Run from `platform`:

```powershell
node --import tsx --test features/research-desk/tradingview/widgets.test.ts
node node_modules/typescript/bin/tsc --noEmit --target ES2022 --module esnext --moduleResolution bundler --jsx react-jsx --esModuleInterop --skipLibCheck --strict features/research-desk/tradingview/index.ts features/research-desk/tradingview/widgets.test.ts features/research-desk/tradingview/provider-smoke.ts
```

The optional `provider-smoke.ts` network check requires Playwright; set
`LEO_PLAYWRIGHT_MODULE` to its installed module directory when it is not available
through normal Node resolution. It runs a task-owned local server and browser,
then closes both. It does not inspect the user's authenticated browser.

The September 8, 2026 01:43 UTC smoke check observed all three official nested
frames and seven advanced-chart canvases. All three opaque hosts were blocked
from reading a test value in parent localStorage. A widget-sheriff rules request
failed; the hosted frames still rendered. This receipt establishes presentation
and isolation, not quote correctness, latency, coverage, or trading suitability.

## Official references

- [Advanced chart](https://www.tradingview.com/widget-docs/widgets/charts/advanced-chart/)
- [Ticker tape](https://www.tradingview.com/widget-docs/widgets/tickers/ticker-tape/)
- [Market data widget](https://www.tradingview.com/widget-docs/widgets/watchlists/market-quotes/)
- [U.S. widget coverage](https://www.tradingview.com/widget-docs/markets/north-america/)
- [Worldwide widget coverage](https://www.tradingview.com/widget-docs/markets/worldwide/)
- [Multiple widgets and symbol overrides](https://www.tradingview.com/widget-docs/faq/many-widgets/)
- [Walmart's current listing](https://www.tradingview.com/symbols/NASDAQ-WMT/)
# Broad market browsing

`TradingViewScreener` reuses the same isolated provider wrapper for the Markets page. Exactly one selected market widget is mounted. Stocks start with U.S. listings by market capitalization; Forex starts with the provider's top gainers; both retain TradingView's toolbar and filters. Crypto uses the Cryptocurrency Market coin table, initially ordered by market capitalization in USD. Provider coverage is broader than the small Leo research dataset, but is not a promise to cover every asset. No fixed asset count is displayed.

Current official generators use `embed-widget-screener.js` for all three presets, including crypto's `screener_type: "crypto_mkt"`. The cryptocurrency widget is not the richer full TradingView Crypto Coins Screener and does not promise its saved screens or export features. The selected market's “Open full screener” link opens TradingView's corresponding stock, crypto-coins, or forex tool. Browser verification rejected the former symbol-query form because TradingView redirected it to the markets directory and dropped the query.

Verified official references:

- [Stock screener preset](https://www.tradingview.com/widget-docs/widgets/screeners/screener/demos/stock/)
- [Forex screener preset](https://www.tradingview.com/widget-docs/widgets/screeners/screener/demos/forex/)
- [Cryptocurrency Market generator](https://www.tradingview.com/widget-docs/widgets/screeners/crypto-mkt-screener/)
- [Widget data boundaries](https://www.tradingview.com/widget-docs/faq/data/)
- [Available markets](https://www.tradingview.com/widget-docs/markets/)

These are provider-owned tables, orderings, and ratings. They do not supply raw observations to Astra's ranking, local research, option inputs, or execution. Stock widget data may be delayed; a personal TradingView subscription does not upgrade website widget entitlements.

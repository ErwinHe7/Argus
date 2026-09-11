# Picks: an explained technical shortlist

The homepage answers which recorded stocks deserve closer inspection. It opens
with three ranked rows, a plain-language reason, and a selected chart. The main
navigation is Picks, Markets, My plans; supporting tools retain their routes.

## Rules and ownership

`intraday_quant/src/intraday_quant/shortlist.py` is the offline screen. It uses
completed daily closes and existing indicator observations, never the separate
last-trade field, IV, account state, or TradingView widget values.

1. Close strictly above SMA50.
2. RSI14 between 50 and 65, inclusive.
3. Close between SMA20 and 1.05 × SMA20, inclusive.

Rows are ordered by the number of matching conditions, then lower ATR14/close,
then symbol. Company stocks and funds are separate. These chosen thresholds
describe a technical setup; they are not fitted returns, valuation research,
probabilities, a personal recommendation, or trading authorization.

The retained source contains five company stocks (NVDA, ZM, AMZN, GOOGL, AVGO)
and three funds (SPY, QQQ, DXYZ). The initial cutoff is September 4, 2026.
Calendar completeness, corporate-action adjustment, and independent daily-close
availability remain unverified. Broader symbol identities without observations
cannot receive ranks. Unknown or incomplete input rows receive explicit exclusions.

## Rebuild

From `platform`, using a Python environment with the existing research dependencies
and IANA time-zone data:

```powershell
$env:PYTHONPATH = 'intraday_quant/src'
.quant-runtime/strategy-research-venv/Scripts/python.exe -m intraday_quant.shortlist
node --import tsx scripts/research-desk-build.mjs
```

The generator writes `features/research-desk/data/shortlist.json`; its CLI binds
`inputSha256` to the exact source file bytes. The static build validates the
versioned contract and source hash before copying it into public assets. A changed
source requires a new export. No Next.js or frozen backend rebuild is involved.

`reviewAfter` is the next scheduled core-session close from the retained bounded
NYSE calendar. For the initial release it is September 8, 2026 at 20:00 UTC.
This is a review deadline, not proof of new observations. Missing schedule or
time-zone support leaves it null; the UI still calls the evidence a dated snapshot.

## Interface and recovery

The homepage independently fetches `/app/research-desk/data/shortlist.json`.
Initial failure, malformed evidence, and future timestamps show no candidates.
A failed refresh retains the previous dated list. Expiry labels rows Historical.
Selecting a row switches the supporting chart; mobile selection focuses and
reveals the detail pane, with a return control. Plan and chart links preserve the
selected symbol. No order is placed. A source download includes rules, provenance,
all ranks, and exclusions.

Markets uses official TradingView stock, crypto, and forex screeners. Their
universe and ordering remain the provider's. Hosted charts and screeners cannot
be imported into the ranking engine through a TradingView data API; see the
[official FAQ](https://www.tradingview.com/widget-docs/faq/data/). A broader Astra
ranking requires an entitled observation feed and its validation, rather than
scraping embedded tables.

## Checks

```powershell
$env:PYTHONPATH = 'intraday_quant/src'
.quant-runtime/strategy-research-venv/Scripts/python.exe -m unittest discover -s intraday_quant/tests -p test_shortlist.py
node --import tsx --test features/research-desk/shortlist/contract.test.ts features/research-desk/tradingview/widgets.test.ts scripts/research-desk-contract.test.ts features/research-desk/worker-routing.test.cjs
npx tsc --noEmit --project features/research-desk/tsconfig.json
```

Browser receipts and desktop/mobile captures are under
`.impeccable/review/picks/`. Injected stale states, source failures and bootstrap
failures are software tests, not broker or market-performance evidence.

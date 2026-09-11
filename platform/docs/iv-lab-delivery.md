# Leo IV Lab — delivery notes

Local route: `/research/iv`. The development preview runs at
<http://127.0.0.1:3107/research/iv>.

This extends Leo's existing Market Map with an English options research workbench.
It is a usable historical-data first version, not a live signal or execution service.

## Delivered workflow

- Six Anthropic-related watchlist symbols: DXYZ, ZM, AVGO, AMZN, GOOGL and NVDA.
- Price, underlying composite IV, 52-week IV percentile, completed-session technical
  indicators and linked official relationship/event evidence.
- Call/Put scenarios with 14/30/60/90 initial calendar days, three relative strikes,
  three elapsed-time choices and a 6-by-5 price/IV matrix. Across all symbols this
  is 12,960 Python-generated conditional valuations.
- Full option repricing, Greeks and separate price-only, IV-only, time-only and
  nonlinear interaction effects. IV changes use percentage points.
- Four retained AVGO option bid/ask snapshots in their own evidence view. Other
  symbols show an explicit missing-contract-data state.
- Browser-local research notes with hypothesis, invalidation condition, saved
  scenario parameters, restoration, deletion and JSON export. No account sync.
- Desktop and mobile layouts, keyboard tab navigation, labelled controls and a
  locally scrollable mobile technical chart positioned at the latest observation.

## Data and quantitative boundaries

Retained IBKR evidence is in `../../deliverables/leo-iv-research/market-data.json`
and the corresponding raw files. It was retrieved on 2026-09-06; last-trade
references and completed daily bars are dated 2026-09-04. Last trades may be after
hours and differ from the regular-session closes used for technical indicators.
Composite IV, IV percentile and option quote fields lack independent field
timestamps. They are never presented as verified current observations.

There is no historical IV time series, so this version cannot establish an IV
uptrend or estimate the probability that spot and IV rise together. Existing
technical indicator definitions informed the implementation, but the old trained
prediction runtime has not been connected or promoted. No win rate is claimed.

SMA20, Bollinger20, RSI14, ATR14, KDJ9/3/3, MACD12/26/9 and 20-session realized
volatility are generated in Python. Eight inconsistent OHLC rows were detected;
the artifact retains only the contiguous valid suffix after the last bad row for
DXYZ and NVDA, with coverage recorded. Prices are not repaired or filled.

Pricing uses European Black-Scholes under explicit research assumptions: 4%
continuous annual interest, 0% dividend yield, ACT/365 and a hypothetical 100-share
multiplier. Strikes are hypothetical relative strikes. Starting IV is the
underlying composite indicator used as an assumption, not an actual contract IV.
The model omits American exercise, discrete dividends, spreads, fees, slippage,
taxes and an event/volatility-surface model. Actual contract snapshots are kept
separate and are not executable inputs. No trade or broker account action occurs.

Event evidence is retained in `lib/iv-lab/artifacts/events.json` with official
source URLs. Publication dates, investment carrying values, portfolio weights
and unconfirmed future dates remain distinct. In particular, an IPO date and a
further pre-IPO model release schedule remain unknown.

## Implementation map

- `components/iv-lab/`: interactive workbench, scoped styles and design record.
- `app/research/iv/page.tsx`: page with validated server-provided overview.
- `app/api/quant/research/iv-lab/route.ts`: read-only symbol endpoint. Invalid,
  duplicate or unsupported query inputs return 400; invalid artifacts fail closed.
- `lib/iv-lab/`: schema validation, source annotations, server artifact loading,
  browser notebook and checked-in research artifacts.
- `intraday_quant/src/intraday_quant/iv_lab.py`: deterministic pricing and technical
  calculation layer. TypeScript selects and formats the outputs.
- `scripts/iv-lab-import.mjs`: validates and imports offline artifacts.
- `components/market-map/MarketMap.tsx` and `components/AppShell.tsx`: scoped route
  and navigation integration. Existing billing has not been changed.

## Rebuild and run

From the workspace root (`Leo Roar`), regenerate the retained research export:

```powershell
python Argus/platform/intraday_quant/src/intraday_quant/iv_lab.py --input deliverables/leo-iv-research/market-data.json --output deliverables/leo-iv-research/derived/iv-lab.json
```

From `Argus/platform`, validate and import it, then run the preview:

```powershell
node --import tsx scripts/iv-lab-import.mjs
$env:AXIO7_NEXT_DIST_DIR='.next-iv-lab'
npm run dev -- --hostname 127.0.0.1 --port 3107
```

The generator uses the Python standard library and makes no network requests.
Rebuilding the same input preserves its retrieval receipt; it does not make the
market evidence newer. To refresh, first collect new evidence with its original
source dates and units, then regenerate and import.

## Verification

- 19 Python tests passed: known prices, put-call parity, finite-difference Greeks,
  monotonicity, expiry/invalid inputs, percentage-point units, decomposition,
  indicator warm-up/causality and input integrity.
- 6 TypeScript contract tests passed: artifact and query validation, malformed
  inputs and evidence boundaries.
- Repository typecheck and optimized Next production build passed. Build output
  includes existing unrelated Sentry/Prisma and lint warnings.
- Browser-verified scenario controls, stock switching, technical and contract
  views, missing-contract state, note save/reload/restore/delete and source dates.
  Runtime browser warning/error log was empty during the review.
- Desktop and 390px/646px views inspected. The mobile chart keeps readable 11px
  ticks in a local 860px-wide scroll area without page overflow. Independent final
  design review: ship, with no unresolved material findings.

Validation commands from `Argus/platform`:

```powershell
python -m unittest discover -s intraday_quant/tests -p test_iv_lab.py -v
node --import tsx --test scripts/iv-lab-contract.test.ts
npm run typecheck
$env:AXIO7_NEXT_DIST_DIR='.next-iv-build'
npm run build
```

Screenshots are retained in `.impeccable/review/iv-lab/`. No public deployment,
new paywall, live data subscription, trading integration or prediction-performance
validation has been completed for this feature.

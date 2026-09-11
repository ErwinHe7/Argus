# Picks: a shortlist first

Prepared locally September 7, 2026 ET. This extension is not published.

Subsequent release: Picks and automatic publication are live as of September 8.
The [automatic Picks delivery record](automated-picks-delivery.md) supersedes that
deployment status; earlier evidence below retains its original scope.

## Product

The first page now opens with **What’s worth buying?** and three ranked company
stocks. Each row gives a plain-language reason, the number of matching rules,
and a screen-match or wait status. The selected stock exposes its chart, exact
checks, counterpoint, and next review condition. These are impersonal technical
research candidates, not current purchase instructions or business valuations.

The main navigation is Picks, Markets, My plans, and Tools. All fourteen retained
analysis routes remain accessible. Plans, journals, and other browser-local
records keep their existing storage; they render independently of archived
chart-data loading. The original Leo website remains linked in the footer.

Markets presents actual TradingView stock, crypto, and forex screeners. Users
can sort and filter the provider's tables or open its full screener. Provider
ordering is visibly distinct from Astra's own shortlist. Only the selected
screener mounts, inside the existing isolated iframe boundary.

## Ranking and coverage

Python generates the validated `astra-shortlist.v1` artifact from the retained
IBKR observations. Company stocks and funds are ranked separately. The three
fixed checks are close above SMA50, RSI14 from 50 through 65, and close from
SMA20 through 1.05 times SMA20. Ties favor lower ATR14 relative to close, then
symbol. These are declared engineering choices, not fitted or validated claims
of predictive advantage. The browser performs no financial scoring.

The retained universe has **five company stocks and three funds**, with daily
history through **September 4, 2026**. Its company order begins NVDA (3/3), ZM
(2/3), and AMZN (1/3). Price, source, cutoff, rule details, exclusions, and data
limitations are inspectable. Adjustment and calendar completeness are not
independently verified. Source retrieval time does not establish when a daily
close became available. The underlying symbol directory is an identity index,
not historical price coverage.

The artifact is bound to the exact source file SHA-256. Its NYSE-calendar review
deadline is September 8, 2026 at 20:00 UTC. After expiry, the interface labels the
retained ranking Historical. Failed refreshes preserve dated prior values;
invalid initial or future-dated evidence produces no suggestions.

TradingView's hosted widgets do not expose a raw-data/export API for our model,
and a personal paid TradingView plan does not upgrade website-widget data.
Provider displays therefore do not update Astra's scores or enter its execution
path. Expanding Astra's own ranking requires entitled observations with verified
coverage and provenance. See the official [TradingView data FAQ](https://www.tradingview.com/widget-docs/faq/data/).

## Verification

- Eleven Python tests cover indicator boundaries, rank stability, asset
  classification, malformed inputs, coverage, provenance, and future invariance.
- Four shortlist contract tests validate the artifact, source binding, internal
  consistency, disabled execution/prediction flags, and temporal states.
- Twenty retained widget, route, storage, and contract tests pass. Scoped
  TypeScript and the static desk build also pass.
- Fourteen browser checks pass across desktop and mobile: candidate selection,
  keyboard focus and return, all provider screeners, external screener links,
  retry, local-plan preservation, archived-data outages, stale evidence, and
  initial/refresh failures. Injected failures are identified in the receipt.
- The confirmation records no page errors or first-party mutating requests.
  The earlier first-pass receipt retains its failures and 32 unattributed React
  errors; those have not been retroactively classified as provider errors.

Actual desktop NVDA/ZM and mobile ZM candle-and-volume rendering was observed.
The default mobile NVDA observation initially contained unavailable OHLC values;
this remains recorded separately from successful UI controls. The targeted
follow-up observed that the same default NVDA frame populated OHLC and Volume
when scrolled into the real 390 × 844 viewport, before Retry or a ticker change.
One Retry recreated the provider frame and loaded the same symbol successfully.
This supports viewport-dependent initialization or painting; the provider's
internal cause is not observable.

The original full-page screenshot compositor left the offscreen chart blank
despite populated provider content. The final full-page capture uses a documented
390 × 2,828 capture viewport so every region paints, with unchanged mobile width
and chart dimensions. The separate 390 × 844 viewport capture and targeted
receipt preserve actual phone-layout and Retry evidence. No data, ticker, DOM,
CSS, or image pixels were substituted. Software and browser tests do not establish
market-data accuracy, profitability, or broker readiness.

The scoped style detector recorded twelve type-ramp advisories and no errors or
warnings. Its exit code was 2 because advisories remain; it is not recorded as
a clean detector run. Evidence and captures are in
`platform/.impeccable/review/picks/`.

The independent finish review gives a scoped **ship** disposition with no
material findings after the targeted mobile recapture. Its initial recapture
finding is retained in `recapture-review.md`; the final `finish-review.md` covers
the required desktop/mobile Picks and Markets captures and corroborating phone
viewport evidence. This is an interface review, not authorization or evidence
of a hosted deployment. A fresh documenter merged the implemented composition
into the scoped design contract and sidecar without replacing the brand.

## Release and operation

The static overlay is staged at
`C:/Users/Hj/Desktop/Leo Roar/release-work/leo-picks-20260907`.
Its frozen backend, unrelated assets, Worker configuration, and existing
`leo.axio7.workers.dev` hostname remain unchanged. Four desk-owned assets change:
the HTML entry, JavaScript, CSS, and new shortlist JSON. No Next.js application
rebuild or cloud deployment is included.

The prepared overlay preserves 2,583 frozen backend files. Wrangler 4.127.1
completed a deploy dry run with 359 assets. The retained backend's pre-existing
`=== -0` warning remains documented in the stage log.

To refresh the shortlist, follow the generator and static-build commands in
`features/research-desk/shortlist/README.md`; do not edit scores manually. A source
change without a matching generated artifact fails the build. Keep the dated
state if a new authorized dataset is unavailable. Hosted chart Retry remains
available even when the embed loaded but prices did not appear; it makes no
claim that the browser can inspect the provider's data.

Existing Strategy Lab, GRID-R1, paper connector, identity, and deployment gates
are unchanged. This feature submits no broker orders, enables no real-money
operation, and introduces no new paid provider fallback.

# Event radar and evidence assistant · September 10, 2026

The release adds a functional source calendar, an evidence assistant and a native
earnings-comparison research engine to Astra's Pick. It extends the existing site
through its static-overlay deployment process. Picks remains the opening route;
charts, browser-local plans, paper strategy setup, original application, membership
and Paddle checkout routes are preserved.

## Delivered capabilities

| Capability | Implementation and evidence |
| --- | --- |
| Event radar | `#/radar`; upcoming, earnings, macro and past filters; search; verified source links; exact ET timing; source review status; retained values on refresh failure. |
| Earnings calendar | Verified Adobe and Micron call observations in the initial selected watchlist. Conference-call time is not presented as results-release time. Existing local calendar entries remain accessible under `#/earnings`. |
| Background calendar checks | Separate `leo-event-radar` Worker, twenty-minute Cron, SQLite Durable Object, fixed official sources, bounded responses and deadlines, last-good retention. No browser needs to remain open. |
| Event-to-plan workflow | Selected event populates a local plan with symbol, event date, source and watch conditions. Broad macro links use SPY as a labeled chart reference. No order is sent. |
| Evidence assistant | Deterministic supported questions about source, timing, watch conditions, missing predictive evidence, shortlist and paper setup. Zero AI calls. Unsupported questions are declined. |
| Earnings comparison | Rust `earnings-radar` CLI validates synchronized pre-event ATM quotes and correctly aligned historical reactions. It produces last-nine absolute-move statistics and midpoint/ask straddle cost measures, or explicit unavailability. |
| Report viewer | Bounded JSON import into the current browser tab, original cutoff, source links, historical counts and limitations. Imported reports are labeled user supplied, never promoted into the public feed. |
| Research journal | Local Python compiler and append-only SQLite hypothesis/outcome journal, frozen event revisions and hash-linked records. Public ledger initially empty; no invented calls or wins. |
| Existing tools | TradingView charts/screeners, dated causal structure research, options scenarios, grid research and paper-strategy workspace remain available. |

## External prerequisites and limits

This is not a reproduction of Balder's proprietary models or its reported trading
performance. The public reference shows reports and methodology descriptions, not
an importable agent implementation. Leo has no promoted predictive model or
validated probability cone. There is no new SEC/insider/13F filing collector or
venue-adjusted 24-hour index feed in this release.

The event feed contains calendar metadata, not actual release results, analyst
consensus or executable quotes. Its first eight records were verified from four
official sources. Automatic Fed/BLS checks and manually verified issuer dates
have separate provenance. A successful server heartbeat does not turn a blocked
source into a working integration.

Current stock ranking still depends on the separately supplied market history.
At the September 10 audit, that history ended September 4 and the local shortlist
publisher had stopped September 8. The research runner recorded a MemoryError.
The UI keeps the dated ranking visibly stale. The new calendar does not refresh
stock prices or certify the old screen as a present buying opportunity.

An entitled price/options provider, aligned earnings history and a validated
evaluation sample are required before populated earnings comparisons or market
probabilities can be published. TradingView hosted widgets do not expose a raw
data API, and a paid TradingView subscription does not upgrade widget data rights.
See [TradingView's official data FAQ](https://www.tradingview.com/widget-docs/faq/data/).

Calendar polling and the evidence assistant run on Cloudflare without a VPS.
Cloudflare resource usage follows the account's plan. A VPS or another always-on
computer is useful for the native backtest/research runner and locally authenticated
OpenD connector. No VPS was purchased or installed, and no broker session was
configured in this release. The previously prepared VPS source package remains
a separate prerequisite-driven deployment.

## Verification

- Python compiler/journal: 16 tests passed on Windows and Ubuntu 24.04 via WSL.
- Rust earnings engine: 12 unit tests, 3 report-contract groups, 3 native CLI
  integration checks passed. Windows x64 executable is an unsigned development
  build; no new macOS/Linux native earnings build is claimed.
- UI data/explanation contracts: 6 test groups passed (including the same 3
  report-contract groups above, not an additional independent count).
- Desktop/mobile browser workflow: 8 checks passed. Includes archive outage,
  selected-event plan saving, exact FOMC date, local report import, unsupported
  assistant questions, failed refresh retention, export and keyboard navigation.
- Scoped frontend TypeScript check and static asset build passed.
- Hosted worker/proxy: native SQLite persistence, concurrent refresh, source
  failure retention, bounded input and routing checks recorded by the deployment
  package. Actual Cron observation is recorded separately from injected tests.
- Finish review: initial date, answer-snapshot and mobile-return findings fixed;
  final disposition `ship` in `.impeccable/review/event-radar/finish-review.md`.

No test result establishes profitability, real broker execution or current
market-data coverage. Fictional test inputs remain outside published market data.

## Operation and artifacts

- Calendar worker: `workers/event-radar/README.md`.
- Calendar/compiler/journal: `intraday_quant/docs/event-radar.md`.
- Earnings inputs and native CLI: `docs/earnings-radar-comparison.md`.
- API/artifact: `features/research-desk/data/event-radar-contract.md` and strict
  `features/research-desk/radar/contract.ts`.
- Source snapshot: `features/research-desk/data/event-radar.json`.
- Static overlay and deployment receipts: workspace
  `release-work/leo-event-radar-20260910/`.

## Reference research

- [Balder earnings radar](https://balder-ai.com/radar): inspected the public
  earnings/event/research functions, without importing proprietary performance.
- [Federal Reserve calendar](https://www.federalreserve.gov/newsevents/2026-september.htm).
- [BLS September release calendar](https://www.bls.gov/schedule/2026/09_sched.htm).
- [Adobe investor relations](https://www.adobe.com/investor-relations.html).
- [Micron earnings-call announcement](https://investors.micron.com/news/press-release/2026/Micron-Technology-to-Report-Fiscal-Fourth-Quarter-Results-on-September-30-2026/default.aspx).
- [Options Industry Council: long straddle](https://www.optionseducation.org/strategies/all-strategies/long-straddle).

## Production release verification

The main Worker deployment is `b057b8d6-3e95-4c2a-847c-4d8040a951f6`.
The final web JavaScript hash is
`b4945d4ba62f1deb98bc8f5230b3b692017090964d21c00f36744bd7b980a3b2`;
CSS is `02fbf3890525f33488dee4a2e22dba374febbe69abaad46878b35002044521fb`.
The overlay preserves all 2,583 frozen backend hashes and unrelated assets.

Five production verification groups passed on September 10: six existing URLs
returned 200; JS/CSS matched the reviewed build; the same-origin feed returned
validated calendar metadata; the evidence assistant resolved Micron correctly;
MU/ADBE official chart embeds loaded; and Picks retained its visibly dated ranking.
These checks did not exercise a payment transaction or inspect executable prices.
The receipt is `.impeccable/review/event-radar/live-verification.json`.

The separate calendar Worker accepts newer, operator-verified manual source
bundles on a subsequent scheduled refresh. Older verification dates cannot
replace newer records. This administrative source-publication path is part of
the deployed code and exposes no public write endpoint; issuer dates remain
manually verified, not labeled as automatic collection. See its operator runbook.

TradingView destinations for new event symbols were explicitly verified against
[Micron](https://www.tradingview.com/symbols/NASDAQ-MU/) and
[Adobe](https://www.tradingview.com/symbols/NASDAQ-ADBE/). Five widget contract groups
and the two existing journal/return-link contract groups passed after integration.

The actual production Cron ran at 2026-09-10T19:40:21Z. Its published artifact
contains 10 events and six sources. The Fed automatic source succeeded; the BLS
automatic request received HTTP 403 from Cloudflare. Previously manually verified
BLS dates retained their original verification time and manual mode. The earlier
22-event successful Fed/BLS result was an independent local upstream fetch, not
this production result. The final strict browser artifact validator also accepted
the production publication. `actualCronObserved` is true in the release receipt.
The temporary deployment log tail has been stopped.

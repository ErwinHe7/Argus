# AXIO7 41-item remediation ledger

Status: local release candidate implemented; external promotion gates remain  
Started: 2026-07-28  
Order: Part 0, then Part 1, then Part 2  
Safety posture: research only, fail closed, execution disabled

This ledger maps every item in the 2026-07-28 independent audit to a concrete
acceptance condition. `Implemented locally` means the recovery branch contains
the code and local contract coverage. It does not mean production has passed a
licensed real-session receipt, immutable model promotion, or deployment
acceptance.

| # | Part | Problem | Required acceptance | Status |
|---:|---|---|---|---|
| 1 | P0 | Ticker-only query invents setup, direction, and horizon | Bare ticker compiles to neutral model-owned forecast; no compiler direction; all configured horizons unless explicitly narrowed | Implemented locally |
| 2 | P0 | No live forecast artifact | Finalized licensed bars must reach Rust inference, immutable publication, API, and paid UI | Pipeline implemented locally; real-session and deployment receipts pending |
| 3 | P0 | Sparse UUP blocks cross-asset context | Publish exact counts; classify causal no-trade only across healthy intervals; validate removal/replacement and retrain | Candidate v2 removes UUP from the required breadth schema; exact Databento lineage and rights are sealed; isolated full-universe retrain remains pending |
| 4 | P0 | Inference skip hides blocker | Persist target stage, failed inputs, counts, cutoff, skew, and a public-safe reason | Implemented locally |
| 5 | P0 | “Rust models connected” overstates readiness | Separate model runtime, feed, context, inference, and publication stages | Implemented locally |
| 6 | P0 | Historical rule is not the live model | Never show rule replay for a model forecast; require explicit rule assumptions | Implemented locally |
| 7 | P0 | Displayed historical rule has no edge | Classify after-cost non-edge explicitly and remove it from headline/fallback use | Implemented locally |
| 8 | P0 | Evidence wording is overstated | Use “exploratory historical condition replay,” never independent frozen-model OOS | Implemented locally |
| 9 | P0 | None of nine artifacts is promoted | Withhold calibrated probability/rank unless exact immutable promotion and calibration receipts match | Publication guard implemented; model promotion remains pending |
| 10 | P1 | Training and displayed replay overlap | Report overlap and prohibit OOS labels for overlapping periods | Implemented locally in sealed offline validation |
| 11 | P1 | Walk-forward evidence unfinished | Complete purged walk-forward folds and persist metrics, exclusions, lineage, and hashes | Evaluator and CLI implemented; exact Databento training inputs are now sealed; isolated no-UUP run remains pending |
| 12 | P1 | Historical parser is permissive | Fail closed on malformed/conflicting duplicates/noncausal rows and account for incomplete sessions | Implemented locally |
| 13 | P1 | “15-minute” may not be 15 clock minutes | Require exact timestamp continuity for entry and exit | Implemented locally |
| 14 | P1 | Late events disappear from denominator | Persist detected, eligible, excluded, and reason-specific counts | Implemented locally |
| 15 | P1 | Historical/live VWAP parity is unproven | Preserve authorized vendor VWAP separately; verify reconstruction parity and lineage | Implemented locally; deterministic vendor/proxy parity test passes and exact Databento source lineage is sealed |
| 16 | P1 | Cost model is insufficient | Add gross/net return, breakeven cost, measured-cost inputs, and sensitivity grid | Implemented locally |
| 17 | P1 | Statistical validation is missing | Add block-bootstrap intervals, baselines, stability, effective N, controls, FDR, and untouched holdout | Implemented locally; untouched evidence files must be supplied to produce a promotable report |
| 18 | P1 | Dislocation threshold mixes units | Use dimensionally consistent standardized quantities and minimum history; revalidate selectivity | Implemented locally |
| 19 | P1 | HMM state count hits search boundary | Use nested train-only state selection/refit and require a stable OOS interior optimum | Selection/refit implemented; promotion awaits a verified full-data report |
| 20 | P1 | Analog distance is not trained for return skill | Compare the active metric with a supervised future-return-loss metric under causal folds | Implemented locally; promotion awaits the comparison report |
| 21 | P1 | Added complexity has weak evidence | Keep weak challenger out of production; compare on preregistered holdout metrics | Candidate-only guard and comparison path implemented; no challenger promoted |
| 22 | P1 | SPX is modeled through SPY | Make proxy, basis risk, source clocks, and limitations prominent and test them | Implemented locally |
| 23 | P1 runtime | Feed freshness is symbol-blind | Require freshness for every target and required context symbol | Implemented locally |
| 24 | P1 runtime | Nine-model latency is unproven | Produce a real-session nine-symbol latency/coverage/SLA receipt | Pending external real-session acceptance |
| 25 | P1 runtime | Source and deployment contracts drift | Build from canonical source; keep artifact-matched K=2..12; reconcile schema, hashes, and publication order | Implemented locally; canonical production deployment pending |
| 26 | P1 runtime | Data rights receipt is not durable | Store a pinned provider/product/use/display/validity receipt without exposing secrets | Owner-attested receipt is generated, technically entitlement-bound, hash-pinned, ignored by Git, and accepted by the production Rust parser; raw redistribution remains false |
| 27 | P2 | `PARTIAL` dominates the headline | Lead with “No live forecast generated” when publication is unavailable | Implemented and browser-tested locally |
| 28 | P2 | Interpreted query is hidden | Show symbol/proxy/setup/direction/horizon/mode and assumptions | Implemented and browser-tested locally |
| 29 | P2 | Internal blocker codes reach users | Map codes to plain explanations while retaining raw code in diagnostics | Implemented and browser-tested locally |
| 30 | P2 | Caveats are unrelated to setup | Emit and render only setup-relevant caveats | Implemented and contract-tested locally |
| 31 | P2 | Long text wall duplicates cards | Use a concise conclusion plus structured evidence/readiness/provenance cards | Implemented and browser-tested locally |
| 32 | P2 | Losing rule lacks direct conclusion | State that it lost money after stated costs when metrics establish that fact | Implemented and browser-tested locally |
| 33 | P2 | Win-rate bar resembles confidence | Remove it or add baseline and return context without probability styling | Implemented and browser-tested locally |
| 34 | P2 | Typography/metadata are too small | Meet readable desktop/mobile sizes and contrast in browser acceptance | Implemented and browser-tested locally |
| 35 | P2 | English/Chinese locale is mixed | Persist request locale and render one locale consistently | Implemented and browser-tested locally |
| 36 | P2 | Recovery and explainer provenance are absent | Add retry/status/historical/assumption actions and grounded-vs-fallback provenance | Implemented and browser-tested locally |
| 37 | Tests | Bare ticker regression | Assert no invented setup, direction, or horizon | Implemented locally |
| 38 | Tests | Missing bars-to-visible-UI end-to-end path | Test bars → causal context → immutable publication → API → UI contract | Deterministic cross-language contract implemented; real-session E2E remains pending |
| 39 | Tests | Data-integrity cases are incomplete | Cover continuity, malformed data, coverage, freshness, proxy parity, and exclusions | Implemented locally |
| 40 | Tests | Production-ready lacks real-session proof | Require a sealed nine-symbol acceptance receipt before ready state | Gate implemented; pending external real-session acceptance |
| 41 | Separate model | 40/20 multi-factor idea is conflated with intraday repair | Build only as a Rust-owned, PIT, cross-sectional shadow research model with separate validation; never auto-route orders | Shadow candidate and paid Rust status bridge implemented; rank remains withheld |

## Removed or quarantined paths

- The Yahoo-backed TypeScript factor scanner and LLM reasoner are no longer
  callable production calculation paths. The paid APIs now fail closed until
  the Rust factor candidate and a licensed point-in-time universe are promoted.
- Historical replay is no longer substituted for a missing model forecast.
- Failed or orphaned forecast attempts cannot be settled or presented as
  published evidence.
- Automatic broker execution remains disabled; no remediation item authorizes
  order routing or personalized portfolio actions.

## Remaining release evidence

- Owner-attested customer-display/model-use rights and the authenticated
  Databento technical entitlement are now bound to a 64-character receipt pin;
  the private evidence stays outside Git.
- The normalized Databento bars and original DBN source are sealed in an
  immutable training manifest covering 4,608,089 rows and 14 symbols.
- Production Docker and database access are verified; deployment waits for the
  all-nine atomic publication and rollback checks to finish.
- A regular-session capture long enough to produce the nine-symbol latency,
  coverage, inference, and publication receipt.
- Exact untouched holdout, calibration, and forward-shadow evidence followed by
  explicit owner promotion approval.

No missing credential or failed model gate may be replaced by Yahoo, synthetic
bars, delayed-as-realtime data, another symbol, or an unvalidated artifact.

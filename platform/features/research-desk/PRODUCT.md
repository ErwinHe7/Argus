# Astra's Pick

## Purpose

Help a visitor decide which stocks deserve further research, beginning with a
short, ranked list and a clear reason for each candidate. The public first page
is useful before signing in and uses the same impersonal screen for every user.
Supporting analysis follows the shortlist rather than competing with it.

An independent deterministic publisher now updates the website through a bounded,
authenticated result feed. It uses no LLM calls for routine screening. Fresh
publisher status never replaces the original market observation date; failed
updates retain dated values. Raw history, credentials, and broker state remain
outside this public feed. Runtime and deployment evidence are recorded in
`docs/automated-picks-delivery.md` at platform scope.

## Main workflow

Picks → read the reason and counterpoint → inspect the chart → save a plan.
Markets offers wider provider browsing. My plans retains browser-local records.
Charts, options, strategy research and paper setup, catalysts, and methods stay
available under Tools. Existing routes, membership, billing, identity, and the
original Leo application keep their own contracts.

## Event radar extension · September 10, 2026

Radar is the second main navigation destination; Picks remains the first page.
The radar lists selected, primary-source macro releases and issuer earnings calls,
with search, upcoming/past filters, exact Eastern times when verified, source
review status, chart links, and a prefilled browser-local trade plan. Existing
earnings notes remain available on the earnings route. Radar and forecast-record
views load independently of the archived options/chart dataset.

A separate Cloudflare Worker checks fixed official calendar sources every twenty
minutes and retains successful evidence through later failures. Manual issuer
observations retain their original verification date. Neither artifact creation
nor a running service proves that every source is current. This is a selected
watchlist, not a complete all-asset calendar.

The evidence assistant performs bounded deterministic queries of the displayed
records. It uses no LLM or paid fallback, does not access accounts, and cannot
submit orders. It declines questions outside its supported evidence. Answers
are tied to their evidence snapshot and cleared when that snapshot changes.

The canonical Rust earnings calculator accepts entitled, timestamped option
quotes and event-aligned historical prices. The browser can inspect a locally
imported output report; format validation does not certify its provenance. No
public numerical earnings comparison is supplied without those inputs. A
straddle premium is not a directional forecast or a probability interval.

The local append-only hypothesis/outcome journal is a research tool, not a
trusted public timestamp service. The hosted forecast record begins empty.
No calibrated direction model, verified win rate, real-money execution, or
options execution is enabled by this extension. Existing paper-only contracts,
membership and Paddle billing remain unchanged.

Implementation and outstanding prerequisites: `docs/event-radar-delivery.md`.

## Shortlist evidence

The first shortlist screens five retained company stocks and three funds using
recorded IBKR daily observations. Python produces the fixed descriptive screen;
the browser validates and displays it. The chosen rules are price above SMA50,
RSI14 between 50 and 65, and a close between SMA20 and 105% of SMA20. Condition
count determines order, followed by lower ATR/close and symbol for ties.

This is technical screening, not a fundamental valuation, forecast probability,
personal portfolio recommendation, or demonstrated trading edge. The cutoff,
limited universe, unverified calendar/adjustments, and review deadline remain
visible. Missing or inconsistent artifacts do not receive invented substitutes.

TradingView hosts stock, crypto, and forex screeners and charts. Its listings,
filters, ratings, data availability and delays belong to that provider. Astra
does not extract hosted quotes or pass them to a model. A broad universe ranked
by Astra requires a separate entitled data feed with verified coverage.

## Design and accessibility

Retain the approved Lion, aubergine/gold palette, Inter, and TradingView charts.
Use plain English, a short first-page list, and progressive disclosure. Support
keyboard selection, visible focus, mobile reading and return navigation, honest
loading/error/stale states, and reduced motion.

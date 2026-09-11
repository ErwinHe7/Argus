# Continuous research monitor

This is a local operational extension of Leo's existing Strategy Lab. The owner
requested a continuously running program that checks datasets, backtests explicit
strategy rules, and retains research without repeated AI calls. It may run on
the user's computer or a prepared Ubuntu VPS. It does not execute broker orders
or automatically promote research into trading.

The monitor shows real worker heartbeat, queue state, recorded trials, data
readiness, and research-only pause/resume. Missing historical evidence is shown
as missing; no financial performance or live-account activation is implied.
Unchanged inputs reuse durable results. In-progress pure research may finish
after pause. The broker connector retains its separate authorization boundary.

The display binds to loopback only, with no public CORS, strict Host/Origin checks,
and a per-process control token. On a VPS, use an SSH tunnel. Raw market histories,
broker credentials, and arbitrary local files have no monitor endpoint.

The interface inherits the existing Lion, Inter, aubergine, and candle-gold
identity. Desktop and mobile require readable job reasons, freshness, controls,
and available-history disclosures. This precise operations panel does not replace
the Picks homepage or add a new market-research navigation hierarchy.

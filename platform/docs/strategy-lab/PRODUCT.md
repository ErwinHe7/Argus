# Strategy Lab product contract

Strategy Lab extends Astra's Pick with user-selected deterministic U.S. equity
strategies, local historical evaluation, dry runs, and moomoo SIMULATE accounts.
It does not activate real-money or options execution. The existing research
services, journal, trade plans, subscriptions, and Flutter application retain
their existing behavior and data ownership.

The website owns authenticated configuration, device authorization, mandates,
control requests, and evidence display. The local connector owns broker access,
data entitlement, deterministic decisions, durable orders, reconciliation, and
local software stops. Brokerage credentials and historical datasets stay local.
Rust owns strategy and monetary calculations. Python prepares data and bridges
the vendor SDK. TypeScript validates and presents contracts, without a second
quantitative implementation.

Each configuration is immutable. A new revision does not silently change the
management of an existing position. This release permits one active policy per
paper account, which also prevents competing policies for an account/symbol;
one leased connector owns each account. Broker paper facts, modeled costs,
daily-bar approximations, injected tests, and real broker tests remain distinct.
There is no validated profitability claim or performance target.

Continuous research is a separate local service. It watches configured local
input files, records source-readiness checks, and runs eligible, predeclared
research jobs through the canonical Rust engine without LLM calls. It does not
download data, rewrite strategies, promote results, or submit broker orders.
Its private loopback monitor presents research evidence and research pause/resume;
these controls do not change paper-connector mandates or broker exposure.
Research pause prevents new job batches after acknowledgement; an active
read-only batch may finish. The service retains rejected and successful attempts
and reuses unchanged inputs across restarts. VPS deployment is a separate
operational step. See [continuous research delivery](CONTINUOUS-RESEARCH.md).

GRID-R1 adds a separate, browser-local research replay of fixed-range whole-share
grids. It uses the same canonical Rust implementation through native JSON and
WebAssembly. Each replay freezes its inputs; imported provenance is explicitly
user-declared and unverified. Synthetic demonstrations are visibly labeled.
Results include unsold inventory and costs, not just completed-cycle profit.
Grid requests never create configurations, mandates, or broker orders in the
strategy API. Grid paper execution requires additional per-slot accounting and
broker evidence and remains unavailable. See [GRID-R1](GRID-R1.md).

Pausing stops new entry submissions after acknowledgement. It does not cancel
pending orders, close positions, or stop local management of existing exposure.
An offline connector cannot acknowledge remote requests. Lease expiry inhibits
new entries locally. Software stops require the computer, SDK adapter, and OpenD
to remain healthy with fresh quotes. Stopping the process is not an order cancel.

The supervisor explains bounded recorded evidence and may request a pause.
It cannot order, cancel, liquidate, edit rules, or resume. Deterministic controls
and anomaly detection do not depend on an LLM being available.

Release preparation is a fresh overlay of the verified Astra build. Frozen
backend bytes and unrelated assets must match. Deployment, signing, native
platform support, market entitlement, and broker lifecycle checks have separate
receipts; a source implementation is not a claim that these have passed.

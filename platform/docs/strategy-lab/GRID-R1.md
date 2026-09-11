# GRID-R1: fixed-range grid research

This is a working research implementation of a cash-start, long-only grid for
whole shares. It runs in Rust on the user's computer, either through the offline
CLI or inside a browser worker using WebAssembly. It does not send orders.
The existing MR-v1/MOM-v1 paper connector and its allowlist remain unchanged.

## What the research established

Grid trading repeats purchases and sales at predefined price levels. Arithmetic
grids use equal price differences; geometric grids use equal price ratios.
Exchange implementations may buy opening inventory, which changes the risk and
capital needed. GRID-R1 deliberately starts with cash and no inventory.
[OKX's explanation](https://www.okx.com/en-us/help/i-spot-grid)
describes both spacing methods and the effect of leaving the range.

A positive sum of completed grid trades can coexist with a loss in total account
value. Inventory accumulated during a decline can lose more than closed cycles
earn. Leo therefore leads with marked equity and total P&L and shows closed-cycle
P&L separately. See [Bybit's P&L definitions](https://www.bybit.com/en/help-center/article/Profit-Loss-Calculations-Spot-Grid-Bot).

The assertion in the supplied social-media post that most quantitative models
are based on grids was not established by these sources. The
[2025 Dynamic Grid Trading preprint](https://arxiv.org/html/2506.11921v1)
studies a particular model and retrospective cryptocurrency dataset. Its
assumptions and results are not evidence that Leo's implementation is profitable.
GRID-R1 is an independently specified fixed-range variant, not a replication of
that paper or an exchange's execution engine.

## Exact rules

1. Freeze a request containing symbol, bounds L/U, interval count N, tick size,
   spacing, starting cash, per-order commission, adverse slippage, and a loss
   threshold relative to starting capital. The historical `configured_at` is a
   supplied cutoff; it does not prove the rules were actually selected then.
2. Compute N+1 ascending levels. Arithmetic: L + i(U-L)/N. Geometric:
   L(U/L)^(i/N). Round down to the tick, preserving aligned endpoints, and reject
   a grid whose rounding collapses distinct levels.
3. Each interval owns one inventory slot with a fixed budget of starting cash/N.
   Determine whole-share quantity using its buy level and a round-trip commission
   reserve. Reject capital insufficient for one share in every slot. Profits do
   not enlarge future quantities. No leverage, short selling, martingale, or
   automatic range widening is permitted.
4. An empty slot proposes a buy when the previous completed close was strictly
   above its lower level and the current completed close is at or below it,
   provided the current close remains within the global range. The first bar
   cannot trigger a purchase. There is no silent initial inventory allocation.
5. A proposal can fill only at the next supplied session's open. A buy requires
   the open to remain within the global range and the opening price plus adverse
   slippage to be at or below its buy limit. Cash and exit-fee reserves must cover
   the purchase. An ineligible proposal expires; another downward crossing is
   needed for a later buy attempt.
6. A held slot proposes a sell when its completed close is at or above the next
   higher level. The following open minus adverse slippage must meet that limit.
   Otherwise the proposal expires. A later eligible close can propose it again.
   Completed cycles can repeat. A slot never buys and sells at the same observed
   open. Existing inventory can still exit above the global upper boundary.
7. At each completed close, mark cash plus inventory. Reaching the configured
   starting-capital loss threshold latches liquidation, clears proposals, and
   prevents further entries. Liquidate existing slots at the next observed open
   with adverse slippage and commissions. Gaps can exceed the threshold. If the
   dataset ends first, show the remaining exposure and pending liquidation.
8. Preserve each lot's basis, entry fee, pending direction, and cycle count.
   Cash is posted with checked six-decimal arithmetic. At each close require:
   total P&L = closed-cycle P&L + loss-exit P&L + unrealized inventory P&L.

## Fill model and limits

`DAILY_CLOSE_SIGNAL_NEXT_OPEN_LIMIT_APPROXIMATION` is a sampled daily grid.
It does not model standing intraday grid orders. High/low fields are validated
for OHLC consistency but never used to invent crossing order or intraday cycles.
Opening-price eligibility does not establish full fills, queue priority,
historical bid/ask availability, market impact, partial fills, or broker behavior.
Drawdown and the loss trigger are sampled at closes, not measured intraday.

The grid and buy-and-hold benchmark start with equal cash. Buy-and-hold purchases
whole shares at the second observed open using the same entry cost assumptions.
Both mark final inventory rather than assuming a free final liquidation. Cash
earns no interest. This version excludes external cash flows, dividends, taxes,
corporate-action cash flows, and borrowing. Split-adjusted history is an
approximation, not an assertion that those prices could have been traded.

Requests allow 2–5,000 completed sessions and 2–100 intervals, subject to a
100,000 session × interval work limit, 100,000 journal-event limit, and 4 MiB
browser input limit. Unsupported fields, malformed amounts, collapsed levels,
duplicates, reversed dates, future bars, overlapping sessions, and prior-close
availability after the next open are rejected. Session calendars and missing
sessions remain declared by the dataset supplier and are not independently
verified by this module.

## Use in Leo

Open **Strategies → Grid research**. Choose an explicitly fictional demonstration
or import a full request JSON. Imported files remain in browser memory and go
only to the local WebAssembly worker. No broker, cloud database, or language model
receives the dataset. Changing an input requires another replay; a result retains
its frozen configuration and identifiers. Export the request and report to keep
an audit copy. The three examples illustrate range cycles, a decline, and an
upward escape. Their returns are teaching fixtures, never market-performance
evidence or a suggested parameter set.

Download one example request as the import template. Replace every bar and the
source manifest with information from a dataset you are entitled to use. Prices
must be decimal strings, with at most six fractional digits; timestamps must
include a UTC offset. `available_at` records when a completed bar became usable.
Use `classification: "observed"` only for actual observations. Required manifest
fields include source, original dataset SHA-256, calendar source, adjustment,
coverage, availability, and license scope. The engine also hashes its canonical
bar representation. These hashes identify inputs; neither authenticates a
vendor nor verifies your source declarations.

The output reports cash, open quantity/value, total P&L/return, realized cycles,
loss exits, unrealized inventory P&L, fees, close-sampled drawdown, occupied slots,
range breaches, pending liquidation, cash/buy-and-hold comparisons, and the full
journal. All reports have `promotion_eligible: false`. An observed import is
labeled user-supplied and not independently verified.

## Build and offline operation

Install Rust with `wasm32-unknown-unknown`, then run from `platform`:

```text
node scripts/grid-research-build.mjs
node scripts/research-desk-build.mjs
cargo test --manifest-path quant_engine_rs/grid_wasm/Cargo.toml
```

The static build verifies the WASM hash and its canonical source receipt before
copying assets. A source change requires a new WASM build. The worker is recreated
for each replay and terminated afterward or after a 30-second timeout.

For the native `strategy-lab` JSON CLI, add `"operation": "grid_replay"` to a full
request and pass it on standard input. The browser/import request omits this CLI
dispatch field. The Python entry point can invoke the same operation without
changing the imported request:

```text
python -m intraday_quant.strategy_lab grid-replay --input request.json --output report.json --engine path/to/strategy-lab
```

Set `PYTHONPATH` to `intraday_quant/src` when running directly from the repository.
The Python adapter validates the result's research-only flags and writes a new
report file; it does not overwrite an existing one. Python must not implement a
second version of the strategy.

Broker paper enablement needs durable per-slot fill allocation, reservations,
reconciliation, competing-exit handling, and actual broker lifecycle evidence.
This research release supplies none of that authorization. Live-money and options
execution remain disabled.

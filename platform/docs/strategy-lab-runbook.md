# Deterministic equity strategy research

This feature implements the fixed `MR-v1` and `MOM-v1` specifications. It does not
promote a strategy or authorize execution. Production inference and monetary
arithmetic run in Rust. Python prepares data and evaluates immutable outputs;
TypeScript may validate and render these reports.

## Build and verify

From `platform/quant_engine_rs`, use the repository's Rust toolchain, or the
isolated installed toolchain explicitly:

```powershell
$env:CARGO_HOME='C:\Users\Hj\.cache\leo-strategy-tools\cargo'
$env:RUSTUP_HOME='C:\Users\Hj\.cache\leo-strategy-tools\rustup'
$env:PATH="$env:CARGO_HOME\bin;$env:PATH"
cargo +1.94.0 test --locked --lib strategy_lab
cargo +1.94.0 build --locked --bin strategy-lab
```

The executable is `target/debug/strategy-lab.exe` on Windows. It reads **one JSON
request from stdin** and writes one JSON response to stdout. It loads no `.env`
file, opens no broker connection, and makes no network requests. Errors return
`{"error":"...","execution_authorized":false}` and exit code 1. Requests are
bounded to 32 MiB. Financial strings have at most six decimal places; numeric JSON
money values and silent rounding are rejected.

```powershell
Get-Content -Raw -LiteralPath request.json | .\target\debug\strategy-lab.exe
```

Use Python's subprocess input or a UTF-8 pipe for non-ASCII provenance fields.
The connector uses this same executable rather than rewriting risk calculations.

## Runtime wire contract

Exact Rust types live in `quant_engine_rs/src/strategy_lab/mod.rs`.

- `operation: "evaluate"`: `strategy`, `as_of`, `bars`, `evidence`, nullable
  `position`, `pending_entry` and optional `history_mode`.
- `operation: "size"`: `strategy`, `equity`, `cash`, `gross_exposure`,
  `pending_commitment`, `entry_price`, `signal_atr`, `daily_start_equity`,
  `peak_equity`, `paused`, `commission_per_order` and `slippage_bps`.
- `operation: "stop"`: `strategy`, `first_fill_price`, `signal_atr`.
- `operation: "replay"`: the complete `ReplayRequest` documented below.

`strategy` is exactly `MR-v1` or `MOM-v1`. Runtime parameters are fixed presets;
there is no parameter override in the evaluate/size/stop interfaces. All money,
price and ATR fields use decimal strings; quantities are whole-share integers.
`as_of` and observation timestamps are timezone-aware RFC3339.

Each daily bar contains `session_date`, `open_at`, `close_at`, `available_at`,
`open`, `high`, `low`, `close`, and integer `volume`. Evidence contains `source`,
`dataset_sha256`, `calendar_source`, `adjustment_verified`, `coverage_verified`,
`availability_verified`, `classification` (`observed` or `synthetic_fixture`),
and `license_scope`. A hash identifies supplied data; it is not itself proof of
provider entitlement or historical availability.

Default `history_mode: "point_in_time"` requires historical availability before
subsequent sessions. `current_observed_snapshot` instead permits historical bars
received together now and `availability_verified:false`, solely for a decision
made after receipt. It preserves the actual receipt times. It cannot be used for
historical replay. Both modes require verified adjustment/calendar coverage and
completed valid bars. The latest close must be no more than seven days old;
the connector additionally checks the latest expected exchange session.

An owned position supplies quantity, first fill price, initial/current stop,
entry session, highest completed close since entry and held-session count.
The entry session counts as held session one at its close. Partial-fill custody
and cumulative updates belong to the connector. Rejected or missing data never
creates a zero quote or a replacement observation.

Decision output contains action (`enter_long`, `exit_long`, `hold`), exact reason,
signal ATR, proposed stop, indicators, decision ID, eligible-after timestamp,
classification and history mode. `execution_authorized` is always false: the
decision still needs broker, mandate, freshness, ownership and risk gates.
Wall-clock polling time is excluded from decision identity. The connector must
also key each entry attempt by configuration hash, symbol and signal session,
so refreshed receipts, cancelled attempts or a same-session exit cannot retry it.

## Baseline definitions and monetary path

Both strategies wait for 220 completed sessions. SMA/Bollinger dispersion uses
twenty closes including the signal day and population variance. RSI14/ATR14 use
Wilder smoothing seeded by the arithmetic mean of the first fourteen changes
or true ranges. An equivalence test checks the existing Market Map definitions.
ATR converts upward to six decimal places for conservative stop-distance sizing.

MR enters when z20 <= -2 and RSI14 <= 30. Its stop is first entry fill minus
2 ATR from the signal day. A close at/above current SMA20 or ten held sessions
generates an ordinary exit for the next eligible session.

MOM enters when close exceeds the previous 55-session high, excluding the current
bar, and exceeds SMA200. Its initial stop is fill minus 3 signal-day ATR. After
each completed bar, the stop can rise to the highest completed close since entry
minus 3 current ATR; it never falls. A close below the previous 20-session low
generates the ordinary next-session exit.

Initial simulation limits are risk 25 bps of equity, position notional 500 bps,
gross notional 2,000 bps, no borrowing, whole shares, and reserves for both order
commissions plus adverse exit slippage. Daily loss at 100 bps or drawdown at
500 bps pauses entries. Pauses latch; stops and scheduled exits continue.
The size input's entry price is the maximum intended entry fill price, not an
unbounded market-order assumption. Supplied equity/high-water inputs must already
respect cash-flow boundaries and broker reconciliation.

## Offline data and replay

Python commands run from `platform/intraday_quant`. The isolated test environment
is `../.quant-runtime/strategy-research-venv/Scripts/python.exe`; a project Python
environment with Pydantic and exchange-calendars works equally well.

```powershell
$env:PYTHONPATH='src'
python -m intraday_quant.strategy_lab prepare --input source.json --output input.json
python -m intraday_quant.strategy_lab replay --input input.json --engine ../quant_engine_rs/target/debug/strategy-lab.exe --output replay.json
python -m intraday_quant.strategy_lab evaluate --input replay.json --output report.json --registration registration.json
python -m intraday_quant.strategy_lab sensitivity --input input.json --engine ../quant_engine_rs/target/debug/strategy-lab.exe --output sensitivity.json
```

`prepare` accepts `leo-strategy-source.v1`: symbol, strategy, bars with session
dates and actual historical available-at times, source evidence, code revision,
starting capital and costs. It verifies dates against XNYS, including holidays
and early closes. It cannot infer when historical data first became available
from a present-day download. Missing sessions, inconsistent prices, unverified
adjustments and absent availability attestations fail closed.

`ReplayRequest` adds source evidence, code revision, dependency versions,
starting capital, commissions, slippage, optional external cash flows at session
opens and optional **research-only** parameter neighbors. Its immutable run hash
binds the full input/configuration. Files are created exclusively; reruns cannot
overwrite earlier evidence accidentally.

Replay uses `DAILY_OPEN_PROXY_WITH_BAR_STOP_AND_ADVERSE_GAPS`, not the production
09:35–09:40 quote-window experiment. It processes risk-reducing exits before
entries, fills opening gaps through stops at the adverse opening price, applies
trailing stops only on later prices and records intrabar stop times as session
reporting boundaries rather than fabricated tick times. A journal records every
cash/quantity change, and account equity includes idle cash and open holdings.
External deposits and withdrawals are removed using valuations at their exact
session-open boundaries. Cash dividends, settlement delays and partial fills
are not modeled by this daily proxy; external flows must never stand in for
dividends. No dividend-reinvested total-return claim is made.

## Evidence, experiments and report upload

`leo-strategy-research.v1` reports bind the replay artifact hash, run ID, strategy,
symbol, source evidence, observation/availability cutoffs, code revision and cost
assumptions. Metrics include net account time-weighted return, drawdown, realized
and unrealized P&L, fees, exposure duration and winner concentration. Reports add
moving-session-block uncertainty, zero-yield cash and disclosed price-only
buy-and-hold benchmarks. Every report remains exploratory and nonpromoted.

Preregistration specifies an experiment ID, strategy/symbol, freeze time before
the future holdout, separate development/holdout dates, minimum sessions, return
and drawdown objectives, trial count and prior-inspection disclosure. Cross-boundary
positions are flagged. Passing descriptive objectives does not prove that a file
was unseen, and does not grant execution or promotion authority.

Sensitivity runs all predeclared neighbors using the same Rust engine, without
selecting the winner: 1x/2x/3x costs; MR z 1.8/2.2, RSI 28/32 and ATR multiples
1.5/2.5; MOM breakout lookbacks 50/60 and ATR multiples 2.5/3.5. Overrides exist
only in replay, have distinct run hashes, and are labeled research variants.
The deployment interface continues to reject parameters that change MR-v1 or MOM-v1.

Synthetic fixtures exercise engineering only and are rejected by performance
reporting. The existing retained IBKR evidence can instead produce a metadata-only
capability receipt:

```powershell
python -m intraday_quant.strategy_lab capability --input ../../../deliverables/leo-iv-research/market-data.json --output capability.json
```

The generated local receipt is
`.quant-runtime/strategy-research/source-capability-20260907.json`. Actual retained
observations exist, but independent historical availability, adjustments,
calendar completeness and a full executable options archive are missing. These
gaps are preserved as blockers; no market performance was manufactured.

## Focused checks

```powershell
$env:PYTHONPATH='src'
python -m unittest discover -s tests -p test_strategy_lab.py -v
```

Rust tests cover decimal/fee conservation, exact indicators and Market Map parity,
warm-up, threshold/excluding-current-bar logic, causal rejection, gap stops,
next-session execution, trailing stops, ten-session counting, external cash flows,
repeat-poll identity, current-observed versus historical mode, replay determinism
and nondeployable research overrides. Python tests cover official sessions,
input integrity, immutable output, holdout boundaries, deterministic uncertainty
and synthetic/performance separation.

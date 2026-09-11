# Earnings comparison research contract

The `earnings-radar` native CLI compares an observed at-the-money straddle cost
with completed, event-aligned historical stock moves. It does not predict a
direction, publish calibrated probabilities, or execute an option trade. No
qualified live option/history dataset was added with this feature.

The canonical implementation is `quant_engine_rs/src/earnings_radar.rs`;
`quant_engine_rs/src/bin/earnings-radar.rs` is a bounded, offline JSON interface.
The browser schema is `features/research-desk/radar/earnings-contract.ts`.
It validates a user-imported report's shape; import does not authenticate its
data, demonstrate that Rust generated it, or establish a profitable strategy.

## Calculation and limits

For each report, select the last regular close strictly before the earnings
announcement and the first regular close strictly after it. The supplied
calendar must place the announcement between two adjacent sessions, after the
earlier close and before the next open. Intraday/unknown announcement times
are unavailable. A conference-call time must not be substituted for an unknown
earnings-release time.

The signed stock price move is `(after / before - 1) * 100`. The comparison
retains the last nine supplied events in chronological order, or all supplied
events when there are three through eight. It reports their absolute moves,
median, and raw up/down/unchanged counts. The up frequency describes the sample
only. The calculation is a stock-price reaction study, not total return or an
options backtest.

For a same-underlying, same-strike, same-expiry call and put, divide the sum of
their midpoints by underlying spot and express it as a percentage. The sum of
their asks is reported separately. Divide midpoint cost percentage by median
absolute historical move for a descriptive ratio; withhold it if the median is
zero. A larger ratio does not automatically mean options should be sold.

This premium proxy includes time and volatility outside the earnings event;
it is not event-only implied volatility, a confidence interval, or a guaranteed
move. Midpoint does not establish an achievable fill. Commission, future
spreads, slippage, exercise, dividends, and changes in implied volatility are
not included.

Method references checked September 10, 2026:

- [OIC strategy definitions](https://www.optionseducation.org/strategies/all-strategies-en)
  describe the paired call/put structure and identical strike/expiration.
- [Cboe DataShop FAQ](https://datashop.cboe.com/faqs) distinguishes its
  earnings-implied-move method, which uses volatility differences between
  expirations, from a simple straddle cost. Leo does not claim to reproduce that
  proprietary calculation.

## Input

The complete typed schema is the public `Request` struct. JSON uses snake_case
and rejects unknown fields. Required top-level fields:

| Field | Meaning |
| --- | --- |
| `schema_version` | `leo-earnings-comparison-request.v1` |
| `symbol` | One U.S. underlying, uppercase symbol; at most 12 characters |
| `as_of` | Explicit-offset timestamp at which all evidence was available |
| `event_at` | Actual upcoming earnings announcement time, strictly later than `as_of` |
| `event_known_at` | When its timing became known, no later than `as_of` |
| `event_source` | `{title, url}` for the timing evidence; HTTPS |
| `history_source` | `{title, url}` for the historical price dataset; HTTPS |
| `history_price_basis` | `split_adjusted_regular_close` |
| `history_entitled` | Explicit declaration that the input is permitted for this use |
| `calendar` | Complete session manifest described below; null produces unavailable |
| `history` | Three to forty historical events; latest nine enter the summary |
| `options` | Synchronized quote snapshot below; null produces unavailable |

`calendar` contains `source: {title, url}`, `version`, `coverage_start`,
`coverage_end` (ISO dates), and strictly increasing `sessions`:

```json
{"date":"YYYY-MM-DD","open_at":"TIMESTAMP","close_at":"TIMESTAMP"}
```

The declared coverage must cover the historical reactions, current event, and
option expiry. Opens must be 09:30 New York time and closes 16:00 or 13:00 New
York time for an early close. Weekends are rejected; timezone/DST conversion is
performed in Rust. The program checks internal consistency, not the authority
or completeness of a user-provided exchange calendar. The report says so.

Each `history` entry contains `event_id`, `event_at`, `event_known_at`, `source`,
`before` and `after`. Each close has this shape:

```json
{"session_date":"YYYY-MM-DD","observed_at":"TIMESTAMP","available_at":"TIMESTAMP","price":null}
```

Replace `null` with an entitled, positive split-adjusted regular-close price.
`observed_at` must exactly equal its calendar session close. The event must
have been known by the pre-event close, and both observations must have become
available by `as_of`. Duplicate IDs, timestamps or reaction sessions are rejected.

`options` contains `source`, `entitled`, `quote_unit: "usd_per_share"`, `spot`,
`spot_observed_at`, `spot_available_at`, `strike`, `listed_strikes`, `expiry_at`,
`call` and `put`. Each leg contains:

```json
{"symbol":"SYMBOL","right":"call","strike":null,"expiry_at":"TIMESTAMP","bid":null,"ask":null,"observed_at":"TIMESTAMP","available_at":"TIMESTAMP"}
```

Use `right: "put"` for the put. Both legs' symbol/strike/expiry must match the
snapshot and requested underlying. `listed_strikes` is the strictly increasing
observed strike grid for that expiry; the selected strike must be nearest to
spot (lower strike wins an exact tie). Expiry must match a supplied session
close and cover the first post-event session. Quotes must be observed during
regular hours, no more than 60 seconds old at `as_of`, mutually synchronized
within five seconds, uncrossed, and available by the cutoff.

Source permission and adjustments are declarations that must be checked by the
data provider/import workflow. They are not independently certified by this
offline calculation. TradingView widgets are not an input export mechanism.

## Run and import

Build the native development executable with the repository's pinned Rust
toolchain:

```text
cargo build --manifest-path quant_engine_rs/Cargo.toml --bin earnings-radar
```

On PowerShell:

```powershell
Get-Content -Raw -LiteralPath .\private-input.json |
  & .\quant_engine_rs\target\debug\earnings-radar.exe |
  Set-Content -Encoding utf8 -LiteralPath .\earnings-report.json
```

On macOS/Linux after a native build:

```sh
./quant_engine_rs/target/debug/earnings-radar < private-input.json > earnings-report.json
```

Input is capped at 512 KiB. The process never contacts a network service or
reads credentials. A well-formed but unavailable request returns a report with
`status: "unavailable"`, reason codes and `comparison: null`; the exit status
alone does not imply evidence availability. Malformed/oversized requests return
a minimal error envelope, which is not a completed importable research report.

An available report includes the original source links, input SHA-256,
`as_of`, event time, feature version, complete sample counts, and limitations.
`prediction_enabled` and `execution_enabled` are always false. Import the
report into the Earnings radar to inspect it beside the event calendar; do not
treat a historical `as_of` as today's live market.

The website's empty request download intentionally contains no stock prices,
option quotes or invented calendar/history. Complete its fields using the
structures above. Fictional inputs used by unit tests remain in test code only.

## Verification

Focused Rust tests cover known values, timing alignment, missing inputs,
lookahead, exact quote-age/synchronization boundaries, crossed quotes, expired
contracts, mismatched leg identities, currency units, nearest strikes,
duplicate reactions, chronological latest-nine selection, zero denominators,
nonfinite outputs, timezone/session checks, and strict deserialization.
The browser tests cover permissions, unknown fields, time/count consistency,
and unavailable-state suppression. See the release receipt for executed results.

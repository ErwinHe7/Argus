# Cost-aware research accounting

The model families remain HMM / Baum-Welch / causal regime filtering,
same-regime kernel regression, Markov-switching SDE, and VWAP-residual OU.
This change improves selection and execution evaluation rather than replacing
their forecasting equations. Nothing here reproduces a firm's private alpha
or promotes a model.

## Running the explicit research scenario

From this Rust package, using a local licensed CSV that is already available:

```powershell
cargo run --locked --bin quantctl -- --config configs/research-cost-aware.yaml research backtest --bars C:\path\licensed-market-bars.csv --output data/reports/cost-aware.json
```

The complete profile is a snapshot derived from `configs/production.yaml`;
live ingestion and broker execution are disabled in this research profile.
It does not download market data, place orders, or promote artifacts. The
illustrative costs are assumptions for sensitivity analysis: full underlying
spread 2 bps, minimum latency 250 ms, option commission $0.65 per contract per
side, 25% of displayed size, and premium impact of $0.02 per share at 100%
displayed-size participation. Replace them with entitlement-correct,
point-in-time measurements and actual applicable fees before drawing
economic conclusions.

## Underlying units and selection

The existing underlying backtest is a one-unit price-return study. Its legacy
`commission_per_trade` remains a fixed round-trip amount per unit, charged
once; it is not relabeled as a per-side order fee. Python's historical
commission configuration has different units: consult its cost documentation.
The new `full_spread_bps` is the full quoted spread, half per side.
`underlying_slippage_bps` is charged on each side.

Pre-trade cost estimates use the signal's close and include commission,
spread, and slippage. A candidate whose expected net return is nonpositive
is rejected even when a permissive score threshold would otherwise admit it.
Actual cash P&L uses the same one-unit quantity on entry and exit; gross return,
spread/slippage/commission return, and net return all use raw entry price as
their denominator. This corrects the former slipped-entry denominator.
Each trade exposes `cost_breakdown`; no breakdown is invented when reading
an older serialized trade.

The report includes `cost_sensitivity` at 1x, 2x, and 3x execution costs with
unchanged selected trades. It reports net return, net expectancy, win rate,
summed gross/cost returns, and a break-even cost multiplier (null with zero
costs). This is an accounting stress test, not a refit, holdout test,
capacity estimate, or simulation of a different execution path.

Signal timestamp must match its indexed state; consecutive bars must be the same
symbol/session exactly one minute apart. Their timestamps label interval starts;
close-based signal features become available one minute later. Entry uses the
first subsequent open at or after that cutoff plus latency. With positive
latency, the boundary open is already past and a later minute open is required.
The zero-latency legacy baseline permits an idealized fill on the cutoff boundary.
Invalid prices,
missing or reordered bars, and negative or nonfinite costs fail closed.
Retrospective bar defects invalidate the entire evaluation; the report CLI
returns an error rather than omitting positions with unpriceable exits.
Likewise, a time exit requires the full holding window or a verified configured
session close. Arbitrary truncated files cannot create profitable early exits.
Legacy callers of `backtest::run` must inspect `evaluation_status`; invalid
results contain no trades, equity, or cost-sensitivity economics. Report callers
use `backtest::try_run`, which returns an error for an invalid evaluation.
Holding horizons contain exactly H bars including the entry bar, matching the
existing forward labels when latency is zero.
Forward labels reject zero horizons and skip truncated, cross-session,
mixed-symbol, invalid-price, or discontinuous windows rather than assigning
an H-minute label to less than H bars. Standing barriers include the
entry bar; stop wins when stop and target both occur in the same bar. Exit time
is the completed exit-bar cutoff, so an H=1 trade still closes after its open.
The available OHLC schema does not independently prove receipt time or the
intrabar path. The underlying study has no volume-capacity model:
SPX is a cash index, and SPY proxy volume does not make SPX executable.
Short borrow, financing, taxes, and nonlinear underlying market impact remain
outside this one-unit study. The Python execution layer supplies explicit
notional and causal completed-volume research constraints separately.

## Option fills and incomplete liquidation

Option fills require finite positive prices, a valid noncrossed quote,
displayed liquidity, the same underlying/expiry/strike/right/symbol, an
unexpired contract, and quotes after signal/planned exit plus minimum latency
within the allowed staleness window. Exchange timestamps alone cannot prove
network receipt time, queue position, or that visible liquidity survived.

Entry quantity uses only entry ask size and configured participation.
Exit quantity independently uses the later bid size. Future exit liquidity
never changes an earlier entry fill. If entry was filled but the exit quote
is invalid or insufficient, the result is `UNLIQUIDATED` with separate
`filled_contracts`, `exit_filled_contracts`, and
`unliquidated_contracts`. Completed-round-trip gross/net/cost fields stay
null; callers must not count this as a closed profitable trade or a zero-P&L
trade. A zero entry fill likewise has no net P&L.

The legacy `gross_pnl_per_contract` field remains executed-price P&L after
spread/slippage/impact, before commission. New `mid_gross_pnl_per_contract`
is mid-to-mid gross, `cost_breakdown` is dollars per contract,
`net_pnl_per_contract` subtracts all modeled costs, and `net_pnl_total`
multiplies that by fully liquidated entry quantity. Options use the standard
100-share multiplier. Impact is a linear sensitivity assumption:
premium impact per side = configured full-participation premium impact
times filled contracts / visible side size. It is not a calibrated
Almgren-Chriss solver or an empirical law.

## Public references consulted

- [HRT: Applying Artificial Intelligence to Trading](https://www.hudsonrivertrading.com/hrtbeat/ai-trading/)
  explains prediction, optimization, and execution as separate problems and
  maximization of net revenue subject to risk constraints. This motivates a
  cost gate; it does not disclose their signals or implementation.
- [Optiver: Electronic Trading](https://www.optiver.com/insights/explainers/electronic-trading/)
  describes bid/ask quotes, price/time priority, latency, and depth constraints.
  No specific Optiver model is claimed.
- [Gueant and Pu: Option pricing and hedging with execution costs and market impact](https://arxiv.org/abs/1311.4342)
  is original research on the interaction of hedging, execution costs, and
  market impact. It motivates reporting friction explicitly, without implying
  that this small simulator implements their optimal-control solution.

All three are public framework sources. They provide no evidence that this
project has positive untouched out-of-sample net alpha.


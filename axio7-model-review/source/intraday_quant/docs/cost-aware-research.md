# Cost-aware offline research

This extension measures whether a research signal survives explicit transaction
cost assumptions and causal execution gates. It does not reproduce HRT,
Optiver, or a hedge fund's internal strategy. The HMM / Baum-Welch causal regime
filter, 12D same-regime kernel, Markov-switching SDE, and VWAP-residual OU
implementations remain unchanged; this work adds execution and validation
discipline around research. No frozen runtime artifacts were empirically
retrained or promoted; the demonstration produces disposable synthetic
challenger fits.

## Run a bounded software demonstration

From this Python package, after installing its existing dependencies:

```powershell
python -m pip install -e ".[dev]"
python -m intraday_quant.cli run-all --config configs/cost_aware_research.yaml
```

The checked-in example uses synthetic SPY bars and the existing logistic and
gradient-boosting challengers. It does not require an account, buy data, execute
orders, or establish a tradable edge. Every output remains labeled synthetic
software validation. This small example does not retrain or replace the four
statistical runtime model families. Original ingestion modules have been
restored from the existing local Python source, without copying market data.

To evaluate supplied market data, copy the config, set `data.adapter` to `csv`
or `parquet`, and set `data.input_path` to entitled point-in-time bars for the
target equity. Keep the walk-forward test untouched. Existing `analog_kernel`
training additionally requires the real `quantctl` executable, compatible
normalized bars and an explicit configuration; it fails when unavailable,
without substituting the retired Python estimator.

## Cost contract

| Parameter | Meaning |
| --- | --- |
| `execution_costs.trade_notional` | Entry reference dollars; `quantity = notional / raw_entry` and the same quantity exits. Default 100,000 preserves the former research size. |
| `execution_costs.full_spread_bps` | Full assumed bid-ask spread; each fill pays half. Optional; unset preserves legacy `costs.estimated_spread_bps` as half spread on each side. |
| `costs.underlying_slippage_bps` | Additional adverse slippage per fill. It excludes spread and impact. |
| `execution_costs.commission_per_side` | Fixed dollars charged at entry and exit. Optional; unset preserves the Python `costs.commission_per_trade` amount on each fill. |
| `execution_costs.latency_ms` | Bar timestamps are interval starts. Closing features become available at label + 1 minute; entry is the first bar open at or after that actual cutoff + latency. Zero latency allows an explicitly idealized boundary fill. A 250 ms assumption moves entry to label + 2 minutes. |
| `execution_costs.require_volume_capacity` | Opt-in equity share-volume validation; default false is explicitly `not_checked`. |
| `execution_costs.max_participation_rate` | Maximum fixed order quantity divided by prior completed, consecutive same-symbol minute share volume. |
| `execution_costs.impact_bps_at_full_participation` | Assumed temporary execution penalty, multiplied by that participation ratio on each side. It requires capacity validation. |

Spread, slippage and impact dollars use each fill's raw price times the fixed
quantity. Entry and exit price adjustments always move against the trading
side, for both long and short positions:

```text
gross_pnl = direction * quantity * (raw_exit - raw_entry)
total_cost = entry_and_exit(commission + half_spread + slippage + size_impact)
net_pnl = gross_pnl - total_cost
gross_return = gross_pnl / entry_reference_notional
net_return = net_pnl / entry_reference_notional
break_even_return_bps = total_cost / entry_reference_notional * 10000
```

The legacy Python `estimated_spread_bps` was already charged twice by label and
selector estimates; it now also enters actual simulated fills. Setting the new
full-spread override prevents ambiguous conversions. Python legacy commissions
were per side, whereas the archived Rust legacy `commission_per_trade` has a
different per-unit round-trip convention. These names must not be copied across
languages as though they represented identical economic units.

Pre-trade scoring, validation win labels and barrier labels now share the
baseline of spread, both-side slippage and both-side commission. It is a
baseline at equal entry/exit reference prices and explicitly excludes unknown
future size impact; the final backtest uses each fill's actual raw reference
and prior-bar volume. Probability calibration remains a separately governed
artifact process. The label cost field does not assert that a position can
actually be liquidated.

The real Rust analog bridge's expected/median returns and MFE/MAE are now
oriented to candidate direction, including short signals. The original upward
frequency remains `raw_up_probability`; `win_probability` is unavailable
because that frequency cannot establish profitability after the configured costs.
These raw analog rows remain browseable in prediction and report artifacts but
are excluded from the strategy probability ensemble. Analog-only candidates
are rejected as `unsupported_probability_semantics`; classical calibrated
families can still be evaluated independently.

## Causal and fail-closed gates

Candidates consume the existing ten daily research slots in time order. Only
same-timestamp candidates compete by strength. Portfolio selection likewise
consumes daily limits and cooldown in time order, using model score only for
same-timestamp ties. A stronger afternoon candidate cannot change an already
selected morning prefix. A candidate may trade only once across forecast
horizons. The simulator enforces the open-position limit.

ATR is frozen at the signal bar's actual closing cutoff, not at its opening
label or a future entry bar. `signal_bar_time` retains the input label and
`signal_time` records label + one minute. Fills use the first bar open at or
after actual cutoff plus configured latency. Labels use the same delayed
entry and store each horizon's `forward_available_at`; fold purges use real
decision times and reject labels not yet mature at the next fitting boundary.
OHLC exits become known only at that minute's end. Same-minute stop/target
collisions resolve to the stop; adverse opening gaps use the worse opening
price. Windows end at official XNYS closes, including early closes; they do
not cross to tomorrow. Missing minutes, truncated non-closing horizons,
nonfinite prices and costs fail closed. If official calendars are unavailable,
weekday schedules are no longer substituted.

Capacity uses `volume` of the identified target equity, never `volume_1m`
cross-asset features. SPX, VIX and other cash-index/proxy volume cannot establish
tradable capacity. Prior minute volume is an explicit conservative proxy;
it is not available depth, guaranteed future liquidity, or a queue simulation.
An entry rejected for size remains in `execution_rejections.csv` and
`rejected_candidates.parquet`. An entered position with an unpriceable exit
aborts underlying P&L publication, so losing or illiquid trades cannot vanish
from the performance sample.

Option fills require finite, positive uncrossed NBBO, observed displayed size
and a strictly later quote. Exits also require size and cannot precede entry.
An unavailable exit is `unliquidated`, with no net P&L. The existing options
`gross_pnl` and `cost` continue their executable ask-to-bid convention;
new `mid_gross_pnl`, `all_in_cost`, spread, slippage and commission columns
make the full midpoint-to-net decomposition visible. Equity execution overrides
do not silently change the one-contract options legacy commission.

## Review the results

The example writes beneath `data/cost-aware-software-validation/reports/`:

- `trade_blotter.csv` / `.parquet`: fixed quantity, raw and adjusted prices,
  all four cost components, participation, timing and per-trade break-even.
- `execution_rejections.csv`: entry gate reasons.
- `cost_audit.json`: assumptions, component totals, gross/net reconciliation,
  mean break-even bps and 1x/2x/3x cost stress.
- `research_report.md` / `.html`: the same stress table beside untouched test
  metrics and data-source limitations.

Stress keeps trades and fill references fixed and only multiplies modeled
costs. It does not reselect test trades, fit impact or choose a new profitable
parameter. The break-even cost multiplier is aggregate gross P&L divided by
aggregate cost and is null when cost is zero. A negative value indicates
negative aggregate gross P&L even before any nonnegative transaction cost.
These reports remain research artifacts, not production promotion evidence.

The existing `analog_kernel` bridge trains against sessions before the test
cutoff, which may include validation sessions, unlike the Python challengers'
training partition. It does not inspect test labels, but direct model-family
comparability requires separately aligning those training cutoffs. This change
does not modify the existing bridge's fit-window policy or claim comparable
training samples.

## Public basis and limits

[Almgren and Chriss, *Optimal Execution of Portfolio Transactions*](https://www.risk.net/journal-risk/2161150/optimal-execution-portfolio-transactions)
separates temporary and permanent market impact and studies execution-cost
versus price-risk tradeoffs. The [December 2000 original paper, mirrored PDF](https://www.smallake.kr/wp-content/uploads/2016/03/optliq.pdf)
was inspected for the linear temporary-impact framework. Our linear
participation penalty is a transparent research assumption, not their full
optimal liquidation solver, a fitted law, or an institutional implementation.

The [official NYSE fee schedule](https://www.nyse.com/markets/nyse/trading-info/fees)
shows venue-specific per-share charges and credits tied to transaction type
and activity tier. No single exchange rate can substitute for a user's
all-in broker costs. The example commission is an assumed fixed per-fill amount,
not a quotation of that schedule. Short borrow, financing, taxes, venue routing,
rebates, partial fills and permanent impact are not modeled; real testing needs
licensed executable data and explicit instrument-specific extensions.

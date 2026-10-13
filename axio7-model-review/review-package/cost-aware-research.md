# Cost-aware quantitative research

Argus implements a public research stack: HMM / Baum–Welch / causal regime
filtering, 12-dimensional same-regime kernel regression, Markov-switching
diffusion, and VWAP-residual Ornstein–Uhlenbeck shadow models. This revision
improves how candidate forecasts are evaluated against execution constraints.
It does not replace the statistical models or claim new fitted parameters.

## Public institutional research methods

[HRT's public explanation](https://www.hudsonrivertrading.com/hrtbeat/ai-trading/)
decomposes one trading problem into prediction, portfolio optimization, and
execution. It also explains why paper gains may not be realizable when
positions are large. [Optiver's public market-making explanation](https://prod-www.optiver.com/insights/explainers/market-making/)
connects theoretical value, risk compensation, and continuously updated quotes.
These sources motivate evaluating a forecast together with costs and liquidity;
they do not disclose either firm's proprietary production strategies.

[HRT's machine-learning page](https://www.hudsonrivertrading.com/machine-learning/)
identifies weak signal, overfitting, changing distributions, and latency as
research challenges. Argus should therefore compare its existing candidate
models against simple baselines on chronological held-out data, rather than
select a more complex model because it resembles a firm's marketing language.

## Economics and causality

The implementation treats commissions, full quoted spread, slippage, execution
delay, and liquidity/size assumptions explicitly. A full quoted spread means
half a spread paid on each side of a two-sided round trip. Where executable
bid/ask prices already contain the spread, it is attributed once rather than
charged again as a separate fill adjustment.

Legacy configuration names retain their existing units: Python's
`commission_per_trade` and `estimated_spread_bps` were per-side assumptions,
whereas Rust's legacy underlying commission is per one-unit round trip. Use
the explicit example profiles and package documentation rather than copying a
legacy numeric setting from one engine into another.

Gross return, execution friction, and net return must reconcile in the same
units. Entry orders cannot use prices or completed-bar features that were not
available at their decision time. Liquidity at a later exit must not determine
how many units could have been bought earlier. An unliquidated option position
does not have a completed round-trip net P&L.

Minute input timestamps identify interval starts. A signal using that bar's
OHLC/features becomes available at the interval's close, one minute later.
Zero-latency research may use that boundary's next open as an idealized case;
positive latency uses a subsequent eligible open. Holding horizons contain
exactly H bars, including the entry bar. Labels with incomplete, discontinuous,
or cross-session windows are withheld. Python records label maturity and uses
it when purging the next fit/evaluation boundary.

The Python bar backtest and Rust research replay have different input
granularity. Volume-based research assumptions do not establish NBBO depth,
queue position, fill probability, or the executable capacity of an index.
Impact coefficients are explicit hypotheses to stress and calibrate with
appropriate data; they are not institutionally estimated constants.

## Implementation entry points

The original Python data adapter, cleaning, ingestion, and session-integrity
sources have been restored from the existing same-stack platform. The public
review package's placeholder entry points previously prevented its offline
pipeline from running. Restoration preserves session coverage checks and does
not import raw market observations, provider credentials, or production state.

- [Python configuration](../source/intraday_quant/src/intraday_quant/config.py)
  and [underlying replay](../source/intraday_quant/src/intraday_quant/backtest/underlying.py).
- [Python option fills](../source/intraday_quant/src/intraday_quant/backtest/execution.py).
- [Python usage and assumptions](../source/intraday_quant/docs/cost-aware-research.md)
  and [example profile](../source/intraday_quant/configs/cost_aware_research.yaml).
- [Rust configuration](../source/quant_engine_rs/src/config.rs),
  [underlying replay](../source/quant_engine_rs/src/engine/backtest.rs), and
  [option fills](../source/quant_engine_rs/src/engine/execution.rs).
- [Rust usage and assumptions](../source/quant_engine_rs/COST_AWARE_RESEARCH.md)
  and [example profile](../source/quant_engine_rs/configs/research-cost-aware.yaml).
- [Chronological candidate generation](../source/intraday_quant/src/intraday_quant/candidates/pipeline.py)
  and [online selection](../source/intraday_quant/src/intraday_quant/portfolio/selector.py)
  consume daily limits in timestamp order. A later, stronger candidate cannot
  replace a decision already made earlier in the session.
- [Probability calibration](../source/quant_engine_rs/src/probability_calibration.rs)
  excludes labels whose forecast horizon crosses the fit/OOS boundary, and
  purges the internal method-fit / method-selection boundary. Horizon maturity
  is an earliest-availability estimate; vendor label availability is still
  needed for complete point-in-time evidence.

## Evidence required for model comparison

1. Fit transforms, model parameters, and calibration only inside the training
   and validation periods of an embargoed chronological split. Preserve the
   existing causal-filter / diagnostic-only Viterbi distinction.
2. Lock candidate choices and cost assumptions before examining the final test
   interval. Purge labels whose outcome windows overlap a later split.
3. Report gross and net results together, with turnover, rejected/unfilled
   trades, exposure, drawdown, and sample coverage. Compare the four components
   and simple baselines using the same data and execution assumptions.
4. Stress costs on a fixed trade list separately from rerunning selection under
   a new cost scenario. The former measures cost sensitivity; the latter is a
   different strategy experiment.
5. Calibrate liquidity and impact assumptions with authorized point-in-time
   quotes/trades or suitable execution evidence before asserting capacity.

The Python analog-kernel bridge and classical challengers currently use
different training-window policies. Their reported results must not be
presented as a controlled model-family ablation until the observation sets and
fit windows are aligned. The causal selection and calibration fixes do not
establish that additional comparison evidence.

The analog bridge also distinguishes raw up-frequency from the probability of
a direction-specific, profitable trade after costs. Short-side return moments
are converted into the candidate's direction. Raw, unvalidated frequency
outputs remain research diagnostics and are excluded from the strategy's
calibrated-probability ensemble until their label semantics and calibration
are validated.

## Verification and remaining evidence

Behavior tests exercise accounting, invalid-input rejection, latency, and
liquidity constraints. Test commands and final results are recorded below after
the implementation is complete.

The public repository deliberately excludes raw historical/live market data.
Synthetic fixtures verify software behavior and cannot establish alpha,
calibration quality, achievable live returns, or a new trained model. Frozen
candidate artifacts are not retrained or promoted by this revision. Existing
live-data and production-promotion gates remain in force.

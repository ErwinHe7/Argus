# Forecast Contract and Evidence Boundary

The native Rust engine now treats forecasting, trade policy, option valuation,
and execution as four separate systems. A regime label is context, not an order.

## Layers

1. **Underlying prediction (D0)** produces point-in-time return distributions
   for 5, 15, 30, and 60 minutes. The production label is next-minute open to
   horizon close. Because that future entry price is unknown at the observation
   cutoff, any current-close price transformation is exposed only as a clearly
   named arithmetic reference scenario, never as a label-aligned expected or
   executable terminal price.
2. **Decision policy** applies validation-locked cost, confidence, freshness,
   sample-size, OOD, and state-entropy gates. It may return `NO_TRADE` even when
   the expected return is non-zero.
3. **Option surface (D3)** is disabled until point-in-time IV/Greeks/OI or an
   auditable calculation over licensed quotes exists.
4. **Option execution (D2)** is disabled until point-in-time SPXW definitions
   and consolidated OPRA NBBO with size exist. No theoretical or midpoint PnL
   is substituted.

The current Massive archive is D0 one-minute aggregate data. SPY is explicitly
an underlying proxy; it is not SPX, OPRA, NBBO, or order flow.

## Forecast contract v4.4

Each immutable prediction contains:

- `observation_cutoff`, `decision_as_of`, `latest_input_available_at`, and
  `earliest_executable_time`;
- expected/median return with
  `return_definition=NEXT_1M_OPEN_TO_HORIZON_CLOSE_SIMPLE_RETURN` and
  5/10/25/50/75/90/95% return quantiles. Ambiguous `expected_price` and legacy
  price quantiles are withheld. Rust may also emit a separately named
  `current_close_reference_scenario_*` arithmetic transformation, whose status
  states that it is not label-aligned or executable;
- a 12-dimensional, same-regime kernel-regression evidence block containing
  selected dimensions, shrinkage-Mahalanobis metric, Gaussian-RBF bandwidth,
  neighbor count, Kish effective sample size, Nadaraya-Watson mean, and the
  distance-local-linear intercept;
- raw up/flat/down kernel-weighted historical event frequencies and separate
  95% Wilson estimate intervals using Kish effective sample size. These are
  explicitly uncalibrated exploratory frequency intervals, not promoted
  probabilities and not strategy confidence;
- 80% and 90% kernel-weighted historical analogue outcome ranges over return,
  plus separately named current-close reference-scenario price transformations.
  These are empirical conditional ranges, not conformal intervals or
  frequentist coverage guarantees;
- a decision-neutral Markov-switching log-return diffusion / VWAP-residual OU
  shadow. It emits Gaussian moment-matched up/flat/down model-implied mass and
  central 80/90/95% log-return prediction ranges, all marked uncalibrated,
  jump-tail-excluded, and `affects_decision=false`. Its lower and upper
  log-return event thresholds are asymmetric
  (`ln(1-c)` and `ln(1+c)`) so they exactly match the kernel's symmetric
  simple-return cost band;
- expected volatility and absolute move;
- MFE/MAE distributions and explicit unavailable status for ordered barrier
  probabilities when the required path label is absent;
- HMM filtered and horizon-predicted state probabilities plus state entropy;
- epistemic uncertainty, OOD score, model/feature/data hashes, capability and
  evidence grade;
- a separate decision object with action, post-cost edge, eligibility, and all
  rejection reasons.

Predictions and later settlements are separate append-only SQLite rows. Database
triggers reject updates and deletes, preventing post-hoc rewriting.

Generic `p_up`, `p_down`, and `p_flat` are nullable. A matching immutable
`PromotedOos` binary-up calibration artifact may publish `p_up` only.
`p_down` and `p_flat` remain null until a separately validated joint
multiclass calibrator exists. A promoted binary-up runtime may also expose a
95% Wilson sampling interval from the matching OOS reliability bin; this
interval describes bin sampling error and excludes drift and model-selection
uncertainty.

The web layer only renders these Rust fields. It does not reconstruct a price,
synthesize complementary class probabilities, or turn raw historical
frequencies into a directional headline.

## HMM mathematics and causal use

For observation vector \(x_t\), hidden state \(z_t\), transition matrix \(A\),
and diagonal Gaussian emission \(b_j(x_t)\), the filter is

\[
\alpha_t(j) \propto b_j(x_t)\sum_i \alpha_{t-1}(i)A_{ij}.
\]

The implementation includes scaled forward/backward recursions, posterior
\(\gamma_t(i)\), pair posterior \(\xi_t(i,j)\), log-space Viterbi, and soft-EM
training with multiple deterministic initializations. Live and replay forecasts
use the forward filter only. Smoothing and full-path Viterbi are diagnostic and
never used as live features.

Each fold fits its scaler and HMM only on training sessions. State identities are
canonicalized from train-only emission statistics, avoiding label switching
across folds. Horizon state probabilities are \(\pi_{t+h}=\pi_t A^h\) and are
rejected across session boundaries.

## Validation and promotion

The validation engine uses chronological expanding folds with four disjoint
segments: train, validation, calibration, and test, with purge and embargo.
Overlapping labels are sampled at non-overlapping horizon intervals. Platt
calibration is fit only on the calibration partition. OOS log loss is primary;
Brier score and directional accuracy are secondary.

The unconditional direction rate is the baseline. Required diagnostics include
a shuffled-target negative control, a future-feature schema sentinel, and an
ablation comparing unconditional, base, and base-plus-cross-asset features.
HMM/AR-HMM/Kalman/change-point challengers remain disabled until their own
completed out-of-fold comparison exists.

No candidate is promoted from this contaminated exploratory archive. Promotion
requires an untouched forward-shadow period with a predeclared minimum sample.

## Operator commands

Run from `quant_engine_rs`:

```powershell
.\target\release\quantctl.exe data capability
.\target\release\quantctl.exe predictor train
.\target\release\quantctl.exe predictor walk-forward
.\target\release\quantctl.exe research negative-controls --horizon 30
.\target\release\quantctl.exe predictor forecast --record-shadow
.\target\release\quantctl.exe predictor shadow-status
```

Read-only control-plane endpoints:

- `GET /api/v1/data/capabilities`
- `GET /api/v1/predictor/forecast`
- `GET /api/v1/predictor/model`
- `GET /api/v1/predictor/walk-forward`
- `GET /api/v1/predictor/calibration`
- `GET /api/v1/predictor/shadow`
- `GET /api/v1/predictor/regime`

Current honest conclusion labels are `NO EDGE`, `NO_TRADE`, `RESEARCH ONLY`,
`UNDERLYING EDGE NOT YET CONFIRMED`, and `OPTION BACKTEST BLOCKED BY D2 DATA`.

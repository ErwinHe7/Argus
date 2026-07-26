# Mathematical models

For each horizon \(h \in \{1,5,15,30,60\}\), the return target is observed directly:

\[
r_{t,h}=\log(P_{t+h}/P_t).
\]

The signal exists only after bar \(t\) finalizes. Entry is no earlier than the next eligible bar or quote.

## Baselines and supervised heads

Clock-time frequency, unconditional direction, last-bar momentum, last-bar reversal, and VWAP mean reversion are mandatory baselines. The regularized logistic model estimates direction probability. Feature scaling is fit on the training interval only, and Platt or isotonic calibration is fit on a disjoint validation interval. Direct regression heads estimate return, MFE, and MAE; multi-horizon forecasts are trained directly, not produced by recursively applying a one-step model.

The constrained gradient-boosted model is a nonlinear comparator, not an oracle. Depth, leaves, learning rate, and iterations are selected only within walk-forward training/validation data. Calibration and trading thresholds remain outside the fitting interval.

## Historical analog kernel

The analog engine uses predeclared features, train-only scaling, shrinkage Mahalanobis distance, adaptive k-nearest bandwidth, and at most one retained observation per historical trading day. A neighbor is eligible only if its entire response window ended before the query, its session predates the query session, its dominant raw HMM state matches the query, both dominant probabilities exceed the configured floor, and full-posterior cosine similarity exceeds the configured threshold. There is no cross-regime fallback.

With normalized kernel weights \(w_i\), effective sample size is:

\[
N_{eff}=\frac{(\sum_i w_i)^2}{\sum_i w_i^2}.
\]

The decision layer abstains when \(N_{eff}\) is too small or one historical day dominates the weight. Reports retain timestamps, distances, weights, forward returns, MFE, and MAE for every selected analog.

## Hidden-state model

The diagonal-Gaussian HMM uses scaled forward-backward and Baum-Welch updates with deterministic restarts. Candidate state counts `[2, 3, 4, 5, 6, 7, 8, 9, 10]` are compared on a chronological held-out suffix by average predictive log likelihood; BIC is only the explicitly reported fallback when there are too few validation sessions. Eight is a mandatory challenger, not a hard-coded production truth. Live inference emits filtered probabilities

\[
p(z_t \mid x_{1:t}),
\]

never retrospectively smoothed probabilities \(p(z_t \mid x_{1:T})\). Viterbi paths are diagnostics and are not future labels.

## Decision and execution

For a candidate action \(a\):

\[
EV_{net}(a)=E[r\mid x_t,a]-spread-slippage-fees-decay.
\]

An order requires a positive conservative lower bound, sufficient effective evidence, acceptable calibration, fresh executable quotes, model agreement, and all portfolio risk checks. Otherwise the correct action is `NO_TRADE`.

There is no public "Jim Simons formula" in this project. The implemented ideas are granular point-in-time data, hidden states, nonparametric historical analogs, multiple-testing control, cost-aware execution, and strict rejection of results that do not survive untouched data.

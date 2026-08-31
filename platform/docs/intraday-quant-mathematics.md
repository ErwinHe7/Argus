# AXIO7 Intraday Quant: Mathematical Contract

This document is the executable research contract for the SPX intraday system. It is intentionally narrower than a discretionary “chart looks similar” claim: every prediction must be measurable at minute `t`, reproducible, and testable out of sample.

## 1. Information and execution timing

Let \(\mathcal F_t\) contain only observations timestamped at or before the close of minute \(t\). A candidate is generated from \(\mathcal F_t\). The earliest underlying fill is minute \(t+1\) open; the earliest option fill is the first valid NBBO strictly after \(t\).

This ordering is enforced by both label generation and execution code. Current-bar close signals never receive current-bar close fills.

## 2. Forecast targets

For horizons \(h \in \{15,30,60\}\):

\[
r_{t,h}=s\left(\frac{P_{t+h}}{P_{t+1,open}}-1\right),\qquad
p_{t,h}=\Pr(r_{t,h}-c>0\mid\mathcal F_t)
\]

where \(s\in\{-1,+1\}\) is direction and \(c\) is executable cost. The regression heads estimate expected return, MFE, and MAE. Triple-barrier labels use an upper profit barrier, lower stop barrier, and time barrier; ATR or fixed-bps distances are configuration controlled.

## 3. Historical analog model

Training-fold features are imputed and standardized using training statistics only. For an eligible historical state \(i\), where \(t_i<t\):

\[
d_i(x)=\sqrt{\frac{1}{m}\sum_{j=1}^m(z_j-z_{ij})^2},\qquad
w_i=\frac{\exp[-\tfrac12(d_i/b)^2]}{\sum_k\exp[-\tfrac12(d_k/b)^2]}
\]

The analog forecast is \(\hat\mu=\sum_iw_ir_i\). Its displayed win probability, MFE, MAE, uncertainty, nearest dates, and similarity are all functions of eligible past samples only. The dedicated 15:50 comparison also compares only prior sessions at 15:50; target-day 15:50-to-close return is an audit outcome, never a distance input.

## 4. Ensemble and calibration

Three model families are used: logistic/Ridge, Gaussian-kernel analog, and histogram gradient boosting. Each walk-forward fold fits preprocessing and models on train, fits Platt/isotonic probability calibration on validation, and evaluates on test. Classification reliability is reported with Brier score. Model outputs are averaged only across available out-of-sample predictions.

## 5. Candidate utility and abstention

With expected return \(\hat\mu\), calibrated probability \(\hat p\), predicted excursions, uncertainty \(\hat\sigma\), and modeled round-trip market cost \(c\):

\[
\hat\mu_{net}=\hat\mu-c
\]

\[
Score=\frac{w_r\hat\mu_{net}(p_0+\hat p)+w_{mfe}\widehat{MFE}}
{\max(\widehat{MAE}+w_u\hat\sigma,\;riskFloor)}
\]

The expected return must also exceed a threshold selected on validation and modeled costs. Daily caps, cooldown, same-direction limits, and the score gate are hard constraints. Zero trades is a valid output.

## 6. Fill and option model

Underlying entries/exits are moved against the strategy by configured slippage, plus commission. If stop and target are both observed in one minute bar, the stop is assumed first.

Long options enter at `ask + slippage` and exit at `bid - slippage`. Quotes with nonpositive bid, crossed market, excessive spread, insufficient size, invalid DTE/delta, or staleness are rejected. Theoretical option values may be diagnostics only and are never reported as executable P&L.

## 7. What constitutes evidence

Synthetic runs validate software plumbing only. Short unofficial price windows are hypothesis checks, not production backtests. A production claim requires licensed multi-year minute bars, genuine historical option NBBO/Greeks, corporate-action metadata, event calendar data, and out-of-sample results across multiple regimes. Win rate alone is never sufficient; confidence interval, payoff ratio, cost sensitivity, sample count, and drawdown must be reported together.

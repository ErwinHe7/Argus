# Market-State Transition Video Review

Date: 2026-07-26
Status: source audit and research specification; not a promoted model
Source: user-supplied transcript, which ends mid-sentence at 20:54, and four
user-supplied screenshots

## Scope and conclusion

The video is a useful visual introduction to state classification, transition
matrices, and regime persistence. It is not evidence that today's state is the
largest predictor of tomorrow, and it does not model investor psychology,
sentiment, participant identity, or "what most people will do."

The concrete method shown in the video is a price-derived, three-state Markov
baseline. AXIO7 may reproduce a corrected version as an auditable research
benchmark. It must not copy the video's probability arithmetic, confidence
language, allocation logic, universal-asset claims, or automated-trading
instructions.

No model is promoted by this review. Automatic execution remains disabled.

## Claims and numerical rules extracted from the source

### Price-defined market state

The video defines a state from the trailing 20-bar return:

\[
r_t^{(20)} = \frac{P_t}{P_{t-20}} - 1.
\]

Its stated labels are:

- `BULL` when \(r_t^{(20)} > 5\%\);
- `SIDEWAYS` when \(-5\% \le r_t^{(20)} \le 5\%\);
- `BEAR` when \(r_t^{(20)} < -5\%\).

The demonstration later uses daily SPY and Bitcoin bars, so this is primarily a
20-day example. It is not an intraday 5-, 15-, 30-, or 60-minute
specification. The video later acknowledges that the \(+/-5\%\) thresholds
were chosen arbitrarily.

### Transition counts and probabilities

For three states, the video proposes counting nine possible one-step
transitions:

\[
N_{ij} = \sum_t \mathbf{1}(Z_t=i, Z_{t+1}=j)
\]

and row-normalizing them:

\[
\widehat A_{ij} = \frac{N_{ij}}{\sum_j N_{ij}}.
\]

One screenshot presents this illustrative transition matrix, with each row
marked \(n=100\):

| Current state / next state | Bear | Sideways | Bull |
| --- | ---: | ---: | ---: |
| Bear | 65% | 25% | 10% |
| Sideways | 20% | 45% | 35% |
| Bull | 15% | 30% | 55% |

The diagonal values, 65%, 45%, and 55%, are described as state "stickiness."

The preceding count screenshot appears to show:

\[
\begin{bmatrix}
22 & 56 & 13 \\
26 & 36 & 20 \\
25 & 12 & 1
\end{bmatrix}.
\]

If those visually readable counts are intended to generate the percentage
matrix, they do not. Their row-normalized values are approximately:

\[
\begin{bmatrix}
24.2\% & 61.5\% & 14.3\% \\
31.7\% & 43.9\% & 24.4\% \\
65.8\% & 31.6\% & 2.6\%
\end{bmatrix}.
\]

The two screenshots may be separate illustrations. Without provenance, they
must not be treated as one empirical dataset or copied into a model artifact.

### Markov claim

The video describes the Markov property as:

> Where the market goes is entirely dependent on the state today, not on what
> happened in the past.

It then elevates this to the claim that today's state is the "biggest
indicator" of tomorrow.

The actual first-order Markov assumption is narrower:

\[
P(Z_{t+1}\mid Z_t,Z_{t-1},\ldots) = P(Z_{t+1}\mid Z_t).
\]

This is a hypothesis about conditional dependence, not proof of predictive
strength. The video's current state also embeds the previous 20 bars, so it
does not remove the past; it compresses a selected portion of the past into a
state label.

### Direction score, confidence, and allocation

The video forms a signed score by subtracting the next-state Bear probability
from the next-state Bull probability:

\[
s_i = P(Z_{t+1}=\text{Bull}\mid Z_t=i)
      - P(Z_{t+1}=\text{Bear}\mid Z_t=i).
\]

It treats \(s_i>0\) as bullish, \(s_i<0\) as bearish, and the magnitude as
"confidence." Its examples are:

- Bull 80% and Bear 10% produce \(+70\) percentage points;
- Bull 20% and Bear 50% produce \(-30\) percentage points.

At approximately 08:46, the transcript mistakenly calls the first result a
"70% likelihood of a bear state" before the surrounding explanation returns
to a bullish interpretation.

For the screenshot matrix, the resulting raw signed scores would be:

- current Bear: \(10\%-65\%=-55\) percentage points;
- current Sideways: \(35\%-20\%=+15\) percentage points;
- current Bull: \(55\%-15\%=+40\) percentage points.

These differences are not calibrated probabilities and are not confidence
estimates. They omit the Sideways probability and contain no estimate of
sampling error, regime drift, calibration error, costs, or out-of-sample
performance.

The video recommends allocating more capital to a larger score and less
capital to a smaller score. The allocation screenshot and transcript provide
no sizing equation, risk budget, loss constraint, or cost model. One frame
also places a marker labelled `1%` near the middle of a 0-to-100 visual scale,
so the visual is not a reliable quantitative specification.

AXIO7 must not translate this raw score or raw entropy into continuous
position sizing. Pre-registered entropy limits may only impose a fail-closed
`NO_TRADE` veto; they cannot create a trade or increase size. Personalized
recommendations and automatic execution are outside the product boundary.

### Multiple horizons and holding duration

The video claims that a one-day probability \(p=0.6\) can be extended by
raising it to a power:

- one day: \(0.6\);
- two days: \(0.6^2=0.36\);
- three days: \(0.6^3\);
- 28 days: \(0.6^{28}\).

The corresponding screenshot shows `0.6 -> 1 DAY`, `0.36 -> 2 DAYS`, a
shrinking sequence, and `NO SIGNAL 20 DAYS`. The 20-day screenshot and 28-day
transcript are not the same cutoff.

For terminal state occupancy, scalar exponentiation is incorrect. Given a
current filtered state distribution \(p_t\) and a row-stochastic transition
matrix \(A\), the correct homogeneous-chain calculation is:

\[
p_{t+h} = p_t A^h.
\]

For example, starting in Bull with the screenshot matrix:

\[
(A^2)_{\text{Bull},\text{Bull}} = 42.25\%,
\]

not \(55\%^2=30.25\%\). The scalar square counts only the uninterrupted
`Bull -> Bull -> Bull` path and omits paths that leave Bull and return before
the target horizon.

Scalar powers do have a valid, narrower duration interpretation. If
\(a_i=A_{ii}\) and the transition matrix is homogeneous, the probability of
surviving in state \(i\) for the next \(h\) transitions without leaving is:

\[
P(\text{survive next }h\text{ transitions}\mid Z_t=i)=a_i^h.
\]

If \(L_i\) counts the run length including the current observation, then:

\[
P(L_i\ge \ell)=a_i^{\ell-1},
\qquad
E[L_i]=\frac{1}{1-a_i}.
\]

This is a state-duration statistic, not the probability of occupying the state
at horizon \(h\), and not by itself a trade holding-period rule. The video's
20- or 28-day `NO SIGNAL` cutoff is arbitrary.

### Overlap and "non-overlap" correction

The video correctly notices that adjacent trailing-20-day returns share 19 of
20 daily observations. This mechanical overlap can make adjacent hard labels
look unusually persistent.

Its proposed fix is to wait 20 days before observing the next state. That
changes the estimand: it measures a 20-day transition, not a tomorrow
transition. It cannot be presented as a correction to a one-day transition
matrix without also changing the forecast horizon.

AXIO7 must keep these questions separate:

- a next-bar transition for a rolling 20-bar state;
- a 20-bar-ahead transition;
- an uninterrupted state-duration distribution;
- train/test purging and embargo for overlapping labels.

Non-overlapping sampling is not a universal substitute for causal
walk-forward evaluation.

### Walk-forward claims

The useful principle in the video is that a historical prediction may use only
information available at that historical cutoff.

The source also gives unverified performance anecdotes:

- an earlier version allegedly showed the S&P 500 losing over roughly 30
  years, while the revised version showed a profit;
- a Bitcoin result allegedly changed from approximately 23x to almost 60x;
- the demonstration reports 2,767 daily SPY bars over 11 years and a 10-year
  walk-forward run.

None of these claims includes an artifact, dataset lineage, dividends, costs,
slippage, train/test boundaries, hyperparameter history, untouched test
period, or reproducible result. Correcting look-ahead bias also does not
mechanically improve returns. These anecdotes are not promotion evidence.

A valid AXIO7 evaluation would require point-in-time data, rolling or expanding
fits, purging and embargo where labels overlap, explicit costs, an untouched
out-of-sample result, and immutable artifacts.

### HMM claims

The video proposes an HMM to avoid manually choosing the \(+/-5\%\) boundaries,
describing it as observing price history and assigning its own unlabeled
states. It then calls agreement between the hard-threshold state and HMM state
"subjective and objective confirmation."

Important corrections:

- an HMM still requires a state count, features, emission family, transition
  assumptions, priors, fitting procedure, and a post-fit semantic mapping;
- optimizing thresholds for the best historical performance without nested
  validation is data snooping;
- two state estimates derived from the same price history are correlated, not
  independent confirmation;
- online output must use the filtered posterior available at the cutoff;
  full-sample smoothing or a Viterbi path computed with future observations is
  not causal online evidence.

## AXIO7 implementation boundary

### Appropriate research implementation

The corrected research implementation should:

1. retain the full filtered HMM posterior \(p_t\), not reduce it prematurely to
   a hard Bull/Sideways/Bear label;
2. estimate transition counts with soft two-slice responsibilities
   \(\xi_t(i,j)\) in offline point-in-time training:

   \[
   \widehat N_{ij}=\sum_t \xi_t(i,j),
   \qquad
   \widehat A_{ij}
   =\frac{\widehat N_{ij}}{\sum_j\widehat N_{ij}};
   \]

3. materialize an immutable, row-stochastic \(A\) with support, lineage,
   training cutoff, feature/model version, and shrinkage metadata;
4. calculate same-session multi-horizon state occupancy as \(p_t A^h\);
5. expose geometric uninterrupted-state survival and expected duration
   separately from terminal occupancy;
6. publish state entropy only as raw descriptive uncertainty unless and until
   separate out-of-sample calibration validates a probability claim;
7. fail closed for cross-session horizons until a separately specified and
   validated overnight/session-boundary model exists;
8. keep all outputs research-only and decision-neutral during challenger and
   forward-shadow evaluation.

Soft \(\xi\) responsibilities may use the next observation only after its
availability time and only for offline estimation. The online forecast must
use the frozen artifact and information available at its own observation
cutoff.

### Required validation

Before any promotion claim, tests must cover:

- rows of \(A\) are finite, nonnegative, and sum to one;
- \(h=0\) returns \(p_t\), \(h=1\) returns \(p_tA\), and larger horizons use
  matrix powers rather than element-wise or scalar powers;
- state distributions remain finite, nonnegative, and normalized;
- geometric survival and terminal occupancy are serialized as distinct
  quantities;
- future, stale, incomplete, or cross-session inputs fail closed;
- hard labels are not substituted when filtered posterior data are absent;
- raw signed contrasts cannot affect a decision or allocation, while raw
  entropy may only trigger a pre-registered fail-closed `NO_TRADE` veto and
  cannot continuously size or create a trade;
- legacy serialization defaults remain unavailable rather than fabricating
  evidence;
- purged walk-forward and untouched out-of-sample evaluation preserve
  point-in-time availability.

## Rejected claims and behaviors

AXIO7 must not adopt:

- "today's state is the biggest indicator of tomorrow" as an established fact;
- "the market is entirely dependent on today's state";
- \(p^h\) as an \(h\)-step terminal-state probability;
- `P(Bull) - P(Bear)` as a calibrated probability or confidence;
- direct position sizing from raw score magnitude or raw entropy;
- a 20-day non-overlap calculation labelled as a next-day transition;
- hard-state/HMM agreement described as independent confirmation;
- universal \(+/-5\%\), 20-bar parameters across assets and timeframes;
- claims that the method works on every asset and every timeframe;
- unverified backtest multiples as evidence;
- automatic orders, personalized long/short instructions, or allocation.

## Current status

The source review is complete. A corrected transition forecast interface is an
implementation-in-progress research change, not a validated edge. Until its
causal tests, serialization tests, walk-forward evaluation, and forward-shadow
evidence are complete, it must remain unavailable or descriptive,
`affects_decision=false`, with no promotion and no automatic execution.

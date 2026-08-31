# AXIO7 Market Memory and Research Factory

Date: 2026-07-21

This document is the implementation contract for the sixteen Market Memory
blocks.  It deliberately separates an implemented research mechanism from an
empirical edge.  More source code, a more complex model, or an attractive
historical chart is never evidence by itself.

The manifest for the 2024-07-18 through 2026-07-17 Massive archive has been
inspected.  The repository does not currently contain the source archive or a
materialized `data/state/market_memory.sqlite3`, so the schema/store can be
tested but archive coverage and reconstruction cannot be claimed.  The
manifest also marks this history contaminated for exploratory OOS use, not an
untouched final holdout.  Unless a result passes the full registered OOS and
forward-shadow gates, the measured user-facing conclusion is:

```text
MARKET MEMORY SCHEMA/STORE IMPLEMENTED
MARKET MEMORY ARCHIVE NOT MATERIALIZED
LEGACY ANALOG BASELINE AVAILABLE; MEMORY-LINKED ANALOG TRACE PENDING
NO REPRODUCIBLE EDGE FOUND
PROBABILITIES NOT TRADE-ELIGIBLE
CONTINUE FORWARD SHADOW
```

These are artifact states, not marketing labels.  Code presence never upgrades
an `UNAVAILABLE` empirical result.

## Shared causal contract

Every record has three distinct times:

- `event_time`: when the market event occurred;
- `information_available_as_of`: when the engine could actually know it;
- `decision_as_of`: the forecast cutoff.

Features require `information_available_as_of <= decision_as_of`.  Forward
labels are separate append-only settlements with their own
`label_available_at`; they are never embedded into the feature payload used by
the model.  Real-time state probabilities are forward-filtered probabilities,
not full-history smoothing.  Analog outcomes must be fully known before the
query timestamp.  A signal computed from minute `t` cannot fill at that same
minute's close.

## Block 1 — Market Memory

Implementation: `quant_engine_rs/src/market_memory/mod.rs`.

`MarketSnapshotRecord` is the immutable decision-time schema.  It includes:

- identity, session, minute, decision/availability timestamps, and reference
  price;
- 1/2/3/5/10/15/30/60-minute returns;
- overnight, VWAP, open, prior close/high/low, and session-range distances;
- realized volatility, upside/downside semivariance, RVOL, volume
  acceleration, signed-volume proxy, and trade intensity;
- relative strength, cross-asset returns, and breadth;
- filtered HMM probabilities, regime entropy, volatility percentile,
  liquidity/spread states;
- data-quality, scheduled-event, and unscheduled-event flags;
- source record IDs, provider/version, manifest hash, availability semantics,
  dataset version, and feature version.

Every possibly missing value is a `PointInTimeValue<T>` containing observed vs
imputed status, method, uncertainty, original availability status, source, and
availability time.  The adapter from the legacy `MarketState` leaves genuinely
unavailable fields missing; it does not reinterpret warm-up zeroes as observed
history.

Snapshot identity is deterministic and content-addressed.  The store preserves
the snapshot ID, content hash, feature hash, and lineage hash.  Duplicate
content is idempotent.  Different content cannot overwrite an existing record;
it must be appended as a correction with an explicit predecessor and reason.

Forward labels are separate records for 5/15/30/60 minutes.  They cover
terminal return, MFE, MAE, upper/lower/neither first barrier, time to barrier,
future realized volatility, and next-session open/close when applicable.
Unsettled horizons remain visibly pending.

SQLite is the implemented authoritative append-only store format.  Database
triggers reject `UPDATE` and `DELETE`, and explicit reconstruction rechecks
every stored content hash and correction chain.  Fast bounded queries report
latest active identity and symbol/day/label coverage without loading every
payload.  In this checkout the production archive database is absent, so its
actual snapshot count, day count, reconstruction status, and dataset hash are
`UNAVAILABLE_NOT_MATERIALIZED`; only fixture databases are exercised by tests.

Parquet/Arrow export is not falsely claimed.  The current manifest states:

```text
authoritative_store_format = SQLITE_APPEND_ONLY
export_status = SQLITE_AUTHORITATIVE_PARQUET_ARROW_EXPORT_PENDING
```

Columnar export becomes eligible only after a reproducible dependency and
round-trip hash test are added.  SQLite remains the immutable source of truth,
not a silent substitute presented as Parquet.

## Block 2 — Event Response Atlas

Implementation: `quant_engine_rs/src/event_library/mod.rs`.

The event taxonomy includes the requested endogenous and scheduled classes.
The causal detector currently implements events that can be inferred honestly
from aggregate bars: opening gap, abnormal volume, volatility
expansion/compression, VWAP reclaim/rejection, prior-day breaks, intraday
drawdown, rapid sell-off/rebound, price-volume and relative-strength
divergence, cross-asset disagreement, repeated bars, failed opening break,
power-hour acceleration, and closing-imbalance proxy.

`LIQUIDITY_SPREAD_SHOCK` is part of the taxonomy but is not manufactured when
historical bid/ask data is absent.  Calendar events require a versioned source
record whose `source_available_at` is no later than detection.  A CPI/FOMC or
earnings label added after the fact is rejected.

Each event stores start, detection, availability, severity, reference price,
pre-event state, optional snapshot and regime identities, liquidity and
cross-asset states, plus content-addressed provenance.

Responses are attached only after their horizon is observable.  The response
contract includes 1/5/15/30/60-minute terminal return, MFE, MAE, recovery time,
range exceedance and `label_available_at`.  Reaction features include the first
1/3/5-minute response, normalized surprise, volume, breadth, relative strength,
follow-through, reversal, price impact per unit RVOL, time to peak,
cross-asset confirmation/disagreement, and decay.

Atlas queries return mean, median, seven quantiles, probability up, MFE/MAE,
raw and independent-day sample counts, deterministic day-block bootstrap CI,
and year/regime/time-bucket breakdowns.  Tail probability is computed only
against an explicit pre-registered finite threshold; a missing or invalid
threshold returns an `UNAVAILABLE_*_TAIL_THRESHOLD` status instead of choosing
one after looking at outcomes.  Detection is symbol-local, minute-bucketed,
knowledge-time truncated, and responses attach only after label maturity.  A
stability and recent-decay score accompanies the distribution.  Fewer than ten
independent days or twenty observations returns
`INSUFFICIENT_INDEPENDENT_EVENT_SAMPLE`, not a signal.  No Event Atlas archive
has yet been materialized in this checkout.

## Block 3 — Historical analog and kernel distribution

Implementations:

- production baseline: `quant_engine_rs/src/engine/analog.rs`;
- research comparison: `quant_engine_rs/src/analog_engine/mod.rs`.

The baseline already enforces past-only, label-complete retrieval, same-time
conditioning, one observation per historical day, robust median/MAD scaling,
adaptive Gaussian weights, ESS, day concentration and OOD abstention.

The comparison engine supports:

1. standardized Euclidean distance;
2. shrinkage full-covariance Mahalanobis distance;
3. correlation distance;
4. DTW on normalized multi-horizon return paths;
5. regularized train-only metric weights;
6. Gaussian kernel conditional distributions;
7. adaptive, nearest-neighbor, and fixed bandwidth rules;
8. locally weighted linear intercepts;
9. kernel-weighted quantiles;
10. time-bucket and optional soft-regime conditioning.

Exact search is used today.  Approximate nearest-neighbor indexing is deferred
until scale profiling shows that it is needed; the application must not label
exact search as ANN.

Scaler, covariance, metric weights, selected dimensions, and the OOD threshold
are fitted only from declared training indices.  The query diagnostics report
nearest distance, train-calibrated OOD threshold, distance concentration, ESS,
analog age quantiles, dominant-year weight, overlap status, feature-level
similarity, complete subsequent path, and K/bandwidth sensitivity.

The mandatory abstentions are:

- `OUT_OF_DISTRIBUTION` when nearest distance exceeds the train threshold;
- `NO_RELIABLE_ANALOG_INSUFFICIENT_ESS` when kernel weight is too
  concentrated;
- `ANALOGS_OVERDEPEND_ON_ONE_PERIOD` when a single year dominates;
- `NEAREST_NEIGHBOR_DISTANCE_CONCENTRATION` when high-dimensional distances
  cease to discriminate.

## Block 4 — Motif and weak anomaly discovery

Implementation: `quant_engine_rs/src/motif_discovery/mod.rs`.

The motif engine accepts log-return, volatility-adjusted-return,
residual-return, relative-strength-return, volume-log-change, or
volatility-change paths.  Raw price levels are rejected.  Multivariate
price-volume joint paths are a requested extension, not a current claim.
Paths are normalized before comparison.  Matrix-profile-style non-overlapping
nearest-neighbor search covers 3/5/10/15/30/60-minute windows and carries
resolution metadata for 1m/5m/15m research.

Candidate existence, prototype, concentration, and deduplication are learned
from the declared discovery partition only.  Per-point availability cutoffs,
purge gaps, mature horizon labels, independent events, day-block bootstrap
intervals, costs, decay, and negative controls are recorded separately for
validation.  Change-point detection is a diagnostic; it is not silently
treated as a directional forecast.

A motif is always a `RESEARCH_CANDIDATE`, never a production signal.  It is
rejected if occurrences overlap, labels were unavailable at evaluation time,
independent events are below the minimum, one day/month dominates, OOS
direction is inconsistent, costs consume the effect, recent samples decay, or
random motif/path controls reproduce the effect.  Discovery and validation
data cannot share observations or the configured purge interval.  The engine,
fixtures, scalable projection-seeded runner, and JSON research catalog are now
materialized by `pattern_factory`; the catalog remains shadow-only.

## Block 5 — Market State Engine

Implementations:

- Gaussian HMM: `quant_engine_rs/src/engine/regime.rs`;
- economic-state mapping and live diagnostics:
  `quant_engine_rs/src/market_state.rs`.

The existing HMM uses diagonal Gaussian emissions, scaled forward/backward,
Baum-Welch, deterministic restarts, BIC, canonicalization, causal filtering,
horizon transition probabilities and diagnostic Viterbi.  Predictor fitting is
restricted to prior sessions; the current session is filtered with frozen
parameters.

`MarketStateEngineOutput` adds filtered and next probabilities, raw state ID,
train-statistic-derived standardized state name, entropy, normalized entropy,
expected duration, transition instability, and probability of regime change.
Before inference, dimensions, probability-simplex rows, finite means, positive
variances/scales, state permutation, and observation width are validated and
fail closed.  Output carries SHA-256 hashes for the exact model artifact and
registered four-feature schema.  The state names are the eight requested
labels.  They are mapped with fixed rules from train-period return, VWAP,
volatility, activity and persistence statistics; a human cannot relabel states
after seeing test performance.

Student-t HMM, sticky/min-duration HMM and regime-switching autoregression are
challengers, not claimed implementations.  They remain `UNAVAILABLE` until
their own purged OOF comparison beats both Gaussian HMM and no-HMM baselines.
HMM context is never presented as a price target by itself.

## Block 6 — Market reaction modeling

The Event Atlas explicitly separates:

1. event identity;
2. pre-event state;
3. first response;
4. continuation, reversal, or failure.

Conditional analysis keys are `event × filtered regime × time bucket ×
cross-asset state`.  Two abnormal-volume declines are therefore different
samples when one occurs during high-volatility liquidation and another is a
low-volatility break with immediate reclaim.  Event type alone never becomes a
fixed buy/sell instruction.

## Block 7 — Missing historical data

Implementations:

- field-level lineage: `market_memory::PointInTimeValue`;
- live eligibility and ablation: `quant_engine_rs/src/missing_data.rs`.

The audit schema names leave-missing, forward-fill, same-time historical
median, model-based, and multiple-imputation policies.  Naming a method is not
an implementation claim: this module currently implements audited observed,
missing, generic imputed values and a point-in-time seasonal median.  A model
imputer and multiple-imputation sampler remain unavailable.  Every emitted
value records observed/imputed status, method, uncertainty and original
availability.

Price, volume, option quotes and other critical market observations must be
genuinely observed for live qualification.  An imputed critical field is
always rejected even if a model reports low uncertainty.  Seasonal imputation
uses only caller-provided prior history, reports MAD uncertainty, and is
research-only by default; live use for a non-critical feature requires an
explicit threshold fixed outside the test period.  NaN values, NaN/negative
uncertainty, negative/NaN thresholds and zero sample minima fail closed.

The imputation ablation compares no, simple, and model imputation.  Missing one
arm yields `INCOMPLETE_ABLATION`; non-finite input yields
`INVALID_ABLATION_INPUT`; excessive metric spread yields
`UNSTABLE_IMPUTATION_SENSITIVE`.

## Block 8 — Nonlinear relationships and model comparison

Implementations:

- trainable logistic and boosted heads: `quant_engine_rs/src/engine/models.rs`;
- fold audit: `quant_engine_rs/src/nonlinear_models.rs`;
- analog/kernel distributions: `analog_engine`.

The comparison contract covers regularized linear/logistic, GAM, kernel,
boosted tree, quantile, analog, regime-switching and small-ensemble families.
Only families with actual predictions are marked available.  Selection uses
validation log loss.  Test is evaluated once and never used to tune weights.

Audits include OOS log loss/Brier, economically required monotonicity, partial
dependence, feature-importance cosine stability, interaction stability and
model disagreement.  Partial dependence and local contributions are
interpretations, not causal effects.

SDE/GBM is registered only as a scenario, volatility, barrier and residual
baseline.  It cannot be promoted as directional edge.

## Block 9 — Research Factory

Implementation: `quant_engine_rs/src/anomaly_research/mod.rs`.

`ResearchHypothesisRecord` stores deterministic hypothesis and dedup keys,
discovery timestamp, exact feature/target/symbol/horizon/regime/eligibility
specification, discovery/train/validation/test datasets, variants tried,
multiple-testing family, raw and FDR-adjusted p-value, effect, block-bootstrap
CI, turnover, costs, and status history.

The lifecycle implements:

```text
DISCOVERED -> SCREENED -> EXPERIMENTAL_SIGNAL -> FORWARD_SHADOW -> PAPER_ELIGIBLE
          \-> VALIDATION_FAILED / TEST_FAILED / DECAYED / REJECTED
```

Invalid transitions are rejected.  `DurableHypothesisRegistry` persists an
append-only SQLite version chain with content and chain hashes, idempotent
duplicate audit, reconstruction, and triggers that reject mutation.  Failed
experiments therefore remain records rather than being renamed until chance
produces a win.  Identity deduplication is based on the full specification,
not a human title.

Benjamini-Hochberg q-values and deterministic session-block bootstrap CIs are
first-class calculations.  Promotion requires a cost-positive effect,
direction-consistent CI, independent sample and stability minimums, full
negative-control coverage, and an untouched test/forward interval.  The
registry implementation is tested.  `quantctl research pattern-discover` now
materializes an end-to-end motif candidate artifact with test evidence, FDR,
current matching, and a conditional shadow strategy.  It does not silently
append replay results to the durable registry or claim paper eligibility.

## Block 10 — Weak-signal ensemble

Implementation: `quant_engine_rs/src/weak_signal.rs`.

The thirteen requested signal families have typed identities.  Each component
must have an independent audit, acceptable validation q-value and positive
validation net edge before receiving weight.  Weight is a deterministic
function of validation information ratio and cost-adjusted effect.  Correlated
families and individual signals are capped before normalization.

Output includes every raw score/weight/contribution, effective number of
signals, maximum weight, weighted disagreement, and leave-one-signal-out
forecasts.  Insufficient diversity, single-signal dominance, high disagreement,
OOD or high regime entropy forces `NO_TRADE`.  Test data never changes weights.

## Block 11 — Cross-asset research

Implementation: `quant_engine_rs/src/cross_asset.rs`.

The declared universe is SPY, QQQ, IWM, SOXX, TLT, HYG, UUP, GLD, NVDA, AMD,
AVGO and MU.  Coverage counts only finite, point-in-time-valid rows and returns
`MISSING_NO_FEATURE_FABRICATION` for absent symbols.

Lead/lag audit rejects delayed and duplicate rows and aligns observations in a
deterministic time order.  Positive lag is selected on an earlier discovery
partition and evaluated only on the later partition; the reversed direction
is tested as a placebo on that evaluation partition.  Time stability requires
at least two valid calendar years.  Residual momentum/reversion is the
lag-one correlation of time-ordered regression residuals, not the mechanically
near-zero correlation between a regressor and its fitted residual.  A reverse
placebo that is as strong as the proposed direction blocks the candidate.  The
output always states that correlation and temporal ordering are not causal
identification.

No futures, OPRA NBBO or order-book feature is synthesized from equity bars.

## Blocks 12 and 13 — Market Memory Card and explanation

Implementation: `quant_engine_rs/src/prediction_explanation.rs`; product UI is
under `components/quant/os/`.

The card contract contains the current snapshot, top analog times/similarity,
ESS and outcome distribution, regime probabilities/entropy, detected
events/motifs and their historical counts, model disagreement, OOD, stability,
decay, and all failure conditions.

Forecast evidence contains raw/calibrated/analog/baseline probability,
mean/median and central intervals, MFE/MAE and first-hit distributions, OOS
sample/Brier/log loss, baseline metrics, improvement CI and evidence grade.

The machine explanation adds component forecasts and weights, local feature
contributions, exact timestamps, model/data lineage and `no_trade_reasons`.
The Chinese human summary names the dominant state, analog sample strength,
model disagreement, evidence grade, and why the forecast remains shadow-only.
It never compresses the output to an unsupported phrase such as “60% chance”.

## Block 14 — Negative controls

Implementation: `anomaly_research::NegativeControlMatrix` plus motif-specific
controls.

The required matrix is:

1. label shuffle;
2. timestamp shuffle;
3. return-sign shuffle;
4. within-day block permutation;
5. cross-symbol placebo;
6. future-feature trap;
7. random motif;
8. random analog neighbor;
9. wrong-regime placebo;
10. reversed lead/lag;
11. delayed availability;
12. duplicated row;
13. synthetic gap.

The matrix reports missing, passed, failed, and matched-effect controls.  A
random motif/neighbor or placebo with an effect comparable to the real
candidate forces `REJECTED`.  Passing only one convenient control is never
called a complete negative-control suite.  The thirteen-control requirement,
coverage validation, and several block-specific executors/tests are
implemented; a production run executing all thirteen controls against one
frozen candidate artifact is not present.  Current empirical status is
`REQUIRED_NOT_EXECUTED`, not ???passed.???

## Block 15 — Implementation order

Phase 1 establishes immutable identity: MarketSnapshot, append-only memory,
events/reactions, baseline analog and prediction lineage.

Phase 2 adds conditional distributions: kernel analog, filtered state output,
event×state queries, Memory Card and machine explanation.

Phase 3 adds discovery and falsification: normalized matrix-profile motifs,
nonlinear challengers, weak-signal ensemble, negative-control contracts and
the durable Research Factory lifecycle.  These mechanisms are implemented in
stages; ???complete negative controls??? is reserved for a materialized run in
which all thirteen controls execute against the same frozen candidate.

Phase 4 is time-dependent and cannot be accelerated with code: long
forward-shadow collection, settlement, decay monitoring and paper eligibility.
No Phase 4 claim is made from replay.

Each phase has an explicit blocked state.  Advanced methods are not piled into
the production forecast merely because their type exists.

## Block 16 — Acceptance and reporting

Run from the repository root:

```powershell
cargo fmt --manifest-path quant_engine_rs/Cargo.toml -- --check
cargo clippy --manifest-path quant_engine_rs/Cargo.toml --all-targets --all-features -- -D warnings
cargo test --manifest-path quant_engine_rs/Cargo.toml --all
npm run typecheck
npm run build
```

Additional acceptance suites must cover:

- deterministic replay and byte-stable snapshot identity;
- Market Memory reconstruction and hash verification;
- analog future/label-availability leakage;
- HMM prefix filtering and no-smoothing semantics;
- normalized motif discovery plus random-motif controls;
- purged day-block walk-forward and bootstrap reproducibility;
- append-only forward-shadow settlement.

The final report must read measured artifacts, not infer success from code.  It
must answer snapshot/day coverage, symbol×horizon samples, analog vs baseline,
kernel vs kNN, HMM incremental OOS value, motif/control counts, event stability,
multiple-testing survivors, cost-positive results, current OOD state, analog
dates/paths, model contributions, whether improvement CI excludes zero, and
whether a reproducible edge actually exists.

If the data or forward sample cannot answer an item, report `UNAVAILABLE` with
the missing source/gate.  Never fill the blank with a backtest narrative.

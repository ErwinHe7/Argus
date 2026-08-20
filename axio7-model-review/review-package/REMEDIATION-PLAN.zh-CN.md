# AXIO7 Handoff Package Remediation Plan

> Path-prefix convention (repository root: `C:/Users/84119/Documents/GitHub/Argus`):
> `RS/` = `axio7-model-review/source/quant_engine_rs/`
> `PY/` = `axio7-model-review/source/intraday_quant/`
> `CPP/` = `axio7-model-review/source/quant_core_cpp/`
> delivery branch = `agent/axio7-model-review` (tip `8d18b73`); build-remediation branch = `fix/handoff-buildable` (tip `3df6111`, containing seven commits not yet merged back into the delivery branch).

---

## 1. Executive Summary

The delivery branch, `agent/axio7-model-review`, is currently **not an externally reviewable snapshot**: `.gitignore` rules matching the directory names `data/` and `reports/` swallowed three source packages; the Rust crate is missing its entire data-ingestion layer and therefore cannot compile; none of the 286 Rust tests has ever run; Python has a collection error; and C++ has never been built. The claim that "everything passes locally" was based on a dirty working tree; the repository itself has never been validated. The `fix/handoff-buildable` branch fixes `.gitignore`, the CMake target name, the Dockerfile, entrypoint supervision, and CI, but the replacement it adds for `RS/src/data/` consists entirely of **`unimplemented!()` stubs** (as stated in `RS/src/data/mod.rs:1-16`). Therefore, "it compiles" does not mean "it runs"; the real data-ingestion layer is still absent from the package.

Beneath the compilation problems, the model layer has three independent P0 issues. First, HMM emission probabilities are computed in linear space and hard-clamped to `1e-300` (`RS/src/engine/regime.rs:214-223`), constraining each time step's log-likelihood to `[-690.776, +14.746]`. With a finite lower bound and a positive upper bound, adding a state becomes a one-sided bet. Second, state-count selection is a bare argmax over holdout log-likelihood, with neither a complexity penalty nor an occupancy constraint; the same rule is duplicated in four places. For all 9/9 artifacts, validation likelihood increases strictly monotonically with K, every artifact selects the candidate-set boundary K=8, and every artifact is permanently marked DEGRADED. Third, the Rust and Python analog kernels differ across all eight dimensions—standardization, metric, feature set, bandwidth, weighting, neighbor filtering, and k selection—meaning **the estimator validated by the Python backtest is not the estimator that would be deployed in Rust**.

One boundary must be explicit: `RS/src/predictor.rs:2193` unconditionally pushes `RESEARCH_ONLY_NO_TRADE` for every forecast, and `:2185` also applies the `OOS_PROBABILITY_CALIBRATION_NOT_PROMOTED` gate. Therefore, the model defects above **cannot currently drive any live order**. What they damage is the credibility of the decision about whether this model should be promoted. Because this handoff package exists specifically to support that decision, these defects remain blockers.

---

## 2. Blocking Issues (An External Reviewer Cannot Begin Work)

Ordered by remediation sequence. B1→B2 has a strict dependency; B3–B6 can proceed in parallel.

### B1 — The Real `RS/src/data/` Implementation Never Entered the Delivery Snapshot; Only Stubs Exist

| Item | Details |
|---|---|
| **Severity** | Blocker |
| **Type** | Packaging / missing source code |
| **Exact location** | The entire `RS/src/data/` directory is absent from the delivery branch `agent/axio7-model-review`. The replacement implementation on `fix/handoff-buildable` is in `RS/src/data/mod.rs:1-16` (self-identified as a STUB), `RS/src/data/massive_live.rs`, `capability.rs`, `context.rs`, `csv_import.rs`, `databento.rs`, `dbn_decode.rs`, `market_store.rs`, `massive.rs`, `readiness.rs`, and `sample_plan.rs`. Similar omissions affect `PY/src/intraday_quant/data/{__init__,clean,ingest}.py` and `PY/src/intraday_quant/reports/{__init__,pattern_analog,report,theory_audit}.py`, which are likewise diagnostic stubs. |

**Minimal reproduction**
```bash
git clone <repo> && git checkout agent/axio7-model-review
cd axio7-model-review/source/quant_engine_rs && cargo check
# → unresolved module `crate::data` (`RS/src/lib.rs` declares `pub mod data`, but the directory does not exist)
```

**Why this matters**
`RS/src/engine/l1_order_flow.rs:5` directly uses `crate::data::massive_live::RealtimeStockTapeEvent;`, and `RS/src/api.rs`, `RS/src/live.rs`, and `RS/src/bin/quantctl.rs` all depend on this module. Its absence means the crate cannot compile at all, so none of the 286 tests can run. More dangerously, the current workaround derives the stub type signatures **backward from call sites** (`RS/src/data/mod.rs:8` explicitly says that all signatures were inferred from call sites). Consequently, no type-correctness conclusion obtained against the stub tree can be extrapolated to the original implementation—including the type issue discussed in B3 below.

**Minimal fix**
Do not write replacement code. Restore the original modules from the upstream working tree and commit them:
```bash
# On the machine that has the complete working tree
git checkout agent/axio7-model-review
git add -f axio7-model-review/source/quant_engine_rs/src/data \
           axio7-model-review/source/intraday_quant/src/intraday_quant/data \
           axio7-model-review/source/intraday_quant/src/intraday_quant/reports
git commit -m "Restore data/report source packages swallowed by .gitignore"
# After restoration, remove the stub version of src/data/ from fix/handoff-buildable in its entirety
```
**Do not merge anything except B2 before restoration**. Fix `.gitignore` first; otherwise, the next `git add .` after the forced add will omit these files again.

**Required new tests**
1. Add the existing `scripts/check-no-ignored-sources.sh` from `fix/handoff-buildable` to CI. Run `git check-ignore` on every path below `src/` and fail on any match.
2. Add an assertion that stubs must not enter the delivery: `grep -rn "unimplemented!()" RS/src/data/ && exit 1`.
3. `cargo test --locked` must run from a clean checkout (see B6).

**Blocks promotion**: Yes. Until this is fixed, it is impossible to answer whether the model code has any issues beyond the swallowed modules.

---

### B2 — `.gitignore` Matches Directory Names and Silently Swallows Source Packages

| Item | Details |
|---|---|
| **Severity** | Blocker |
| **Type** | Repository configuration / delivery integrity |
| **Exact location** | `.gitignore:30-33` (`data/`, `outputs/`, `reports/`, and `logs/`). The fix already exists at `.gitignore:35-45` on `fix/handoff-buildable`. |

**Minimal reproduction**
```bash
git checkout agent/axio7-model-review
git check-ignore -v axio7-model-review/source/quant_engine_rs/src/data/mod.rs
# → .gitignore:30:data/
```

**Why this matters**
Git exclusion applies at the directory level: once `data/` is excluded, files beneath it cannot be re-included individually with `!`; the directory itself must first be re-included. This directly caused B1, and it is **silent**: `git status` is clean and the local build passes, while only a clean clone exposes the omission.

**Minimal fix** (already implemented on `fix/handoff-buildable`; merge it into the delivery branch)
```diff
 data/
 outputs/
 reports/
 logs/
+
+# Re-include: directories with these names under source trees are Rust/Python modules, not data directories
+!**/src/data/
+!**/src/**/data/
+!**/src/reports/
+!**/src/**/reports/
+!**/src/outputs/
+!**/src/**/outputs/
+!**/src/logs/
+!**/src/**/logs/
+!**/include/data/
+!**/tests/data/
```

**Required new tests**
Add the `no-ignored-sources` CI job (`.github/workflows/ci.yml:21-27`). Any new ignore rule that matches a directory name must include a corresponding re-inclusion rule, enforced by the script.

**Blocks promotion**: Yes (prerequisite for B1).

---

### B3 — The Staleness Comparison at `l1_order_flow.rs:179`: Do Not "Fix" It Against the Stub Tree

| Item | Details |
|---|---|
| **Severity** | Blocker |
| **Type** | Type correctness / unknown contract |
| **Exact location** | `RS/src/engine/l1_order_flow.rs:177-180` (`ensure!(cutoff - latest.event_at <= max_age, ...)`), with the signature at `:138-144` and the dependent type in stub `RS/src/data/massive_live.rs:42` (`provider_timestamp: Option<DateTime<Utc>>`). |

**Minimal reproduction**
On the delivery branch, `cargo check` first fails at `l1_order_flow.rs:5` because the module is missing. After adding the stub, the stub infers `provider_timestamp` as `Option<DateTime<Utc>>`; `DateTime - DateTime` yields `chrono::TimeDelta`, which matches `max_age: Duration`, so the expression passes. **That is precisely the problem**: whether the types match depends entirely on how the original module defines the field, and the original module is not in the package.

**Why this matters**
The E0308 report conflicts with the observed behavior of the stub, demonstrating that this line's type correctness is determined by missing code. Any reviewer conclusion based on it is invalid. In addition, an expression such as `cutoff - x` silently becomes a `DateTime` when `x` changes to `Duration`, allowing the error to propagate far from its source before failing.

**Minimal fix** (apply only after B1 restores the original module; this is defensive hardening, not a speculative patch)
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/engine/l1_order_flow.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/engine/l1_order_flow.rs
@@ -176,10 +176,9 @@
     quotes.sort_by_key(|row| (row.event_at, row.sequence));
     let latest = *quotes.last().context("quote window is empty")?;
-    ensure!(
-        cutoff - latest.event_at <= max_age,
-        "latest quote is stale at cutoff"
-    );
+    // signed_duration_since constrains both operands to DateTime<Utc> and always
+    // returns TimeDelta; changing either type fails here instead of silently producing DateTime.
+    let staleness: Duration = cutoff.signed_duration_since(latest.event_at);
+    ensure!(staleness <= max_age, "latest quote is stale at cutoff");
```

**Required new tests**
```rust
#[test]
fn quote_event_time_is_a_timestamp_not_a_duration() {
    const _: fn(&RealtimeStockTapeEvent) -> Option<DateTime<Utc>> =
        |e| e.provider_timestamp;   // Lock the field type at compile time
}
#[test]
fn stale_latest_quote_is_rejected_at_the_boundary() { /* both sides of the max_age boundary, ±1 ms */ }
```

**Blocks promotion**: Yes.

---

### B4 — C++ Uses the Nonexistent Imported Target `SQLite3::SQLite3`

| Item | Details |
|---|---|
| **Severity** | Blocker for the C++ tree |
| **Type** | Build configuration |
| **Exact location** | `CPP/CMakeLists.txt:18` on the delivery branch; the corrected version is at `CPP/CMakeLists.txt:18-20` on `fix/handoff-buildable`. |

**Minimal reproduction**
```bash
cd axio7-model-review/source/quant_core_cpp
cmake -S . -B build -G Ninja   # No error during configure
# Generation fails: Target "axio_quant_core" links to "SQLite3::SQLite3" but no such target exists
```

**Why this matters**
CMake's official `Modules/FindSQLite3.cmake` exports the name `SQLite::SQLite3`. The wrong name **does not fail during configure**; it fails only during generation. This is direct evidence that the C++ project was never built and that this tree never entered any automation.

**Minimal fix** (already applied on `fix/handoff-buildable`)
```diff
-target_link_libraries(axio_quant_core PUBLIC SQLite3::SQLite3 OpenSSL::Crypto)
+# CMake's official FindSQLite3 exports SQLite::SQLite3, not SQLite3::SQLite3.
+target_link_libraries(axio_quant_core PUBLIC SQLite::SQLite3 OpenSSL::Crypto)
```

**Required new tests**
Add the `cpp` CI job (`.github/workflows/ci.yml:66-83`), retain `-Werror -Wall -Wextra -Wpedantic -Wconversion -Wshadow` (`CPP/CMakeLists.txt:28-30`), and run `ctest --test-dir build --output-on-failure` (`CPP/tests/test_main.cpp`, 243 lines, never previously executed).

**Blocks promotion**: No (C++ is not on the production inference path; see §5), but it blocks the claim that this package is internally coherent.

---

### B5 — Python's Hard Dependency on `torch` Is Undeclared, and the Module-Level Import Causes a Collection Error

| Item | Details |
|---|---|
| **Severity** | Blocker for the Python tree |
| **Type** | Dependency declaration |
| **Exact location** | `PY/src/intraday_quant/models/causal_tcn.py:6-8` (module-level `import torch`); `PY/pyproject.toml:36` places torch only in the optional `neural` extra; `PY/src/intraday_quant/training/cuda_challenger.py:440` imports lazily inside a function, so `PY/tests/test_cuda_challenger.py` skips rather than errors. |

**Minimal reproduction**
```bash
cd axio7-model-review/source/intraday_quant
python -m pip install -e ".[dev]"   # Does not include torch
python -m pytest
# → collection error: every path that imports models.causal_tcn immediately raises ModuleNotFoundError
```

**Why this matters**
Under the default installation, the TCN, regime-gated MoE, and Student-t head models **cannot be imported at all**, while the skip in `test_cuda_challenger.py` disguises this as a passing test. A reviewer would believe these are available candidates when they cannot even be loaded.

**Minimal fix** (choose one; option a is recommended)
```diff
# a) If TCN is within the delivery scope, promote torch to a hard dependency
 [project]
 dependencies = [
   ...
+  "torch>=2.4",
 ]
-neural = ["torch>=2.4"]
```
```diff
# b) If TCN is a research prototype, use a lazy import consistent with cuda_challenger.py:440
-import torch
-from torch import nn
-from torch.nn import functional as F
+def _torch():
+    import torch
+    return torch
```
Also remove the corresponding "known issue" comment at `.github/workflows/ci.yml:61-63`.

**Required new tests**
```python
def test_every_declared_model_is_importable(config):
    for name in config.models:            # PY/configs/default.yaml:20
        importlib.import_module(f"intraday_quant.models.{name}")
```
This test will also catch M5 in §3 (`analog_kernel` is listed in `config.models`).

**Blocks promotion**: Yes. No Python-side backtest evidence can be cited until the collection error is resolved.

---

### B6 — There Is No CI; "286 Tests Passed" Was a Conclusion From a Dirty Working Tree

| Item | Details |
|---|---|
| **Severity** | Blocker |
| **Type** | Process / verifiability |
| **Exact location** | `.github/workflows/` does not exist on the delivery branch; the patch is at `.github/workflows/ci.yml:1-96` on `fix/handoff-buildable`. |

**Minimal reproduction**
On the delivery branch, none of the three trees builds successfully from a clean checkout (B1/B4/B5), while the handoff document claims all tests pass.

**Why this matters**
The common root cause of B1–B5 is that validation occurred in a local, uncommitted working tree. Without clean-checkout CI, these four classes of problem will recur unchanged in the next delivery.

**Minimal fix**: Merge `.github/workflows/ci.yml` from `fix/handoff-buildable`, with five jobs: `no-ignored-sources`; `rust` (`cargo fmt --check`, `clippy -D warnings`, and `cargo test --locked`); `python`; `cpp`; and `docker`. Building the image from a clean context is itself a regression test for issues such as `COPY data ./data`.

**Required new tests**: CI is the test. An additional `git ls-files | wc -l` snapshot assertion is unnecessary because `no-ignored-sources` already covers the risk.

**Blocks promotion**: Yes.

---

## 3. Model and Numerical Issues

Build and packaging issues already covered in §2 are not repeated. The issues below are ordered P0 → P1 → P2, with severity reassessed according to whether the issue affects the production decision path (the original report's critical/high ratings are normalized to P0/P1).

**Shared premise**: `RS/src/predictor.rs:2193` unconditionally pushes `RESEARCH_ONLY_NO_TRADE` for every forecast, while `:2185` also applies `OOS_PROBABILITY_CALIBRATION_NOT_PROMOTED`. Therefore, the defects below **cannot currently cause an incorrect order**. Their harm is that they make the decision about which model to promote depend on incorrect numbers.

---

### M1 (P0) — `GaussianHmm::emission` Computes in Linear Space and Clamps at 1e-300; `normalize` Silently Substitutes a Uniform Distribution

**Type**: Numerical correctness / underflow

**Exact locations**
- `RS/src/engine/regime.rs:214-223` (`emission`, ending with `log_probability.exp().max(PROBABILITY_FLOOR)`)
- `RS/src/engine/regime.rs:41-52` (`normalize`; lines 43-47 call `values.fill(uniform)` and return `PROBABILITY_FLOOR` when the entire row underflows)
- Constants: `regime.rs:4` (`PROBABILITY_FLOOR = 1.0e-300`) and `regime.rs:5` (`VARIANCE_FLOOR = 1.0e-4`)
- Consumers: `regime.rs:225-268` (`forward_backward`), `:348-366` (`filtered_probabilities`), and `:507-532` (`average_log_likelihood`)
- **Correct** reference implementations in the same repository: `RS/src/engine/regime_competition.rs:223-245` (log space + logsumexp) and `RS/src/engine/tvtp_regime.rs:399-406` (max subtraction)

**Minimal reproduction**
The observation dimension is 4 (`RS/src/engine/regime_competition.rs:95-100`, `RS/src/predictor.rs:503-506`). With variance at the floor, the peak one-dimensional log-density is `-0.5*ln(2π*1e-4)=3.6865`, totaling `+14.746` across four dimensions. The clamp activates at `Σd² = (690.776+14.746)/5000 = 0.1411`, or approximately `0.188σ` per dimension. Therefore:
- Residual 0σ → log-likelihood `+14.746` (correct)
- Residual 0.2σ → reported `-690.776`, true value `-785.3`
- Residual 1.0σ → reported `-690.776`, true value `-19985.3`

**Why this matters**
1. **The per-step log-likelihood is trapped in `[-690.776, +14.746]`**: the lower bound is finite and the upper bound is positive. `best_hmm` (`regime_competition.rs:394-425`) uses exactly this quantity to select the number of states, turning "add another state" into a bet with bounded downside and positive upside. This drives M2.
2. **The same model is scored by two different forward algorithms**: `regime_competition.rs:515` scores `gaussian_hmm` with the linear-space `average_log_likelihood` from `regime.rs`, while `:537` scores `student_t_hmm` with the log-space `average_student_t_log_likelihood`. Without the clamp, the two are mathematically equivalent, so any difference comes entirely from the clamp. The repository contains an immediately observable internal contradiction: with `minimum_duration=1` (a candidate at `regime_competition.rs:549`), `minimum_duration_hsmm` reduces to an ordinary HMM and should equal `gaussian_hmm` within floating-point precision. Once the clamp activates, equality is impossible.
3. **Filtering history is silently erased**: when an entire row underflows, `normalize` overwrites `alpha[t]` with a uniform vector. The filter forgets all history without an error or flag. `validate_probability_vector` at `RS/src/market_state.rs:132-150` checks only length, finiteness, non-negativity, and sum-to-one, all of which a uniform vector satisfies. A uniform vector at the **final step** is not dangerous because the `REGIME_ENTROPY_WITHIN_POLICY` gate at `RS/src/allocation.rs:456` (threshold 0.80 at `allocation.rs:96`) fails closed. The real danger is a **mid-sequence reset**: history is erased, the filter reconverges, and the final step emits an apparently confident posterior with no indication that anything happened.

**Minimal fix**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
-fn emission(&self, observation: &[f64], state: usize) -> f64 {
+/// Return the log-density. The caller must subtract the maximum in log space before exponentiating.
+fn log_emission(&self, observation: &[f64], state: usize) -> f64 {
     let log_probability = (0..observation.len()).map(|column| {
         let variance = self.variances[state][column].max(VARIANCE_FLOOR);
         -0.5 * ((2.0 * std::f64::consts::PI * variance).ln()
             + (observation[column] - self.means[state][column]).powi(2) / variance)
     }).sum::<f64>();
-    log_probability.exp().max(PROBABILITY_FLOOR)
+    log_probability
 }
```
Change `forward_backward` (`:225-268`) so that each step first takes `m = max_s log_alpha[s]`, normalizes with `exp(log_alpha[s] - m)`, and accumulates `m` into the running log-likelihood. This is exactly the approach already used at `tvtp_regime.rs:399-406`. Also change the signature of `normalize` (`:41-52`) to `Result<f64>`, return `Err` when an entire row underflows, and propagate it through `filtered_probabilities` → `infer_filtered`.

**Required new tests**
```rust
// The two forward algorithms must agree (variance at the floor, observation 1σ away;
// today they differ by thousands of nats).
assert_abs_diff_eq!(
    model.sequence_log_likelihood(&seq)?,
    hmm_log_likelihood_with_emission(&model, &seq, gaussian)?,
    epsilon = 1e-9);
// Underflow across all states must error instead of returning a uniform distribution.
assert!(model.filtered_probabilities(&degenerate_seq).is_err());
// Internal consistency: an HSMM with D=1 must equal gaussian_hmm.
```
**Blocks promotion**: Yes.

---

### M2 (P0) — State Count Uses a Bare Argmax of Holdout Log-Likelihood With 1e-12 Tolerance, No Complexity Penalty, and No Occupancy Constraint

**Type**: Model selection / complexity bias

**Exact locations** (the same rule is copied **four times**)
- `RS/src/engine/regime_competition.rs:399-424` (`best_hmm`, comparator at `:406-414`)
- `RS/src/predictor.rs:820-846` (`select_hmm_model`, comparator at `:837-843`, criterion at `:836`: `validation_score.unwrap_or(-model.bic)`)
- `RS/src/bin/quantctl.rs:3121-3143` (comparator at `:3134-3141`)
- `select_hmm_within_forward_fold` at `RS/src/bin/quantctl.rs:773`, comparator at `:811-825` (**the walk-forward fold path, which is easy to miss**)

**Minimal reproduction**
The default candidates are `state_candidates = (2..=10)` (`RS/src/config.rs:332`), and `config.rs:626-636` requires that 8 be included. Inspect the nine `universe/*.frozen.json` files in `model-artifacts/axio7-candidate-artifacts-2026-07-26.zip`: all have `candidate_state_counts: [2,3,4,5,8]`, `selected_state_count: 8`, and `selected_at_candidate_boundary: true`; validation log-likelihood is **strictly monotonic in K with no interior maximum** (AAPL `[-4.543, -4.167, -3.976, -3.776, -3.353]`; NVDA `[-4.097, -3.792, -3.540, -3.361, -2.968]`).

**Why this matters**
This mechanically causes all 9/9 artifacts to choose K=8. The system has **detected the symptom without treating the cause**: `predictor.rs:889-893` computes `selected_at_candidate_boundary`; `:914-918` emits `BEST_VALIDATION_SCORE_IS_AT_MAXIMUM_TESTED_K`; `:2175-2177` pushes `REGIME_STATE_COUNT_OPTIMUM_UNRESOLVED`; and `RS/src/research_api.rs:1515-1530` degrades the artifact to DEGRADED. Every artifact is therefore permanently released in DEGRADED state. Raising the candidate limit merely moves the selection to the new limit (`config.rs:630` already permits up to 12).

**Two common misdiagnoses must be corrected**: (a) the `1e-12` tolerance is **not** the cause—the actual differences between candidates are 0.2–0.4 nats/observation, ten orders of magnitude larger; and (b) switching to BIC **will not solve it**—`training_bic` in the artifacts also decreases monotonically with K (AAPL 278250 → 254151 → 240876 → 229473 → 202709). With roughly 30,000 training samples, a gain of 0.4 nats/observation is about 12,000 nats, overwhelming any BIC penalty. The real remedy is **a minimum occupancy constraint plus an expanded candidate grid that demonstrates an interior optimum exists**.

**Minimal fix**
First, consolidate the four copies into one function; otherwise, the remediation will inevitably miss one path.
```rust
// New file: RS/src/engine/state_selection.rs
pub struct SelectionPolicy {
    pub minimum_state_occupancy: f64,   // For example, 0.02: at least 2% posterior mass per state
    pub minimum_improvement: f64,       // 1-SE rule, derived from validation-score dispersion across sessions
}
pub fn select_state_count<'a>(
    candidates: impl Iterator<Item = (usize, Option<f64>, &'a GaussianHmm)>,
    policy: &SelectionPolicy,
) -> Option<(usize, f64, &'a GaussianHmm)> {
    // 1) Reject by occupancy first: if any state's effective sample share is below
    //    minimum_state_occupancy, reject the entire candidate.
    // 2) Find the highest-scoring surviving candidate.
    // 3) Return the smallest K among candidates scoring >= best - minimum_improvement.
}
```
Then replace all four sites—`regime_competition.rs:399-424`, `predictor.rs:820-846`, `quantctl.rs:3121-3143`, and `quantctl.rs:811-825`—with calls to this function. Note that occupancy statistics currently **do not exist anywhere in the Rust tree** (`grep -rni "occupancy" RS/src/` returns no matches). Add them by normalizing `state_weight` in `em_step` at `regime.rs:270-346`, attaching the result to the `GaussianHmm` struct at `regime.rs:7-23`, and serializing it.

**Required new tests**
```rust
// Candidate-limit invariance: for a known 3-regime process, both (2..=6) and (2..=10) must select 3.
// Occupancy rejection: when K=8 fits three-cluster data, candidates with empty states must be rejected.
// 1-SE: a candidate ahead by 1e-12 nats/observation must not replace a model with six fewer states.
```
**Blocks promotion**: Yes.

---

### M3 (P0) — The Rust and Python Analog Kernels Are Different Estimators: The Backtest Does Not Validate the Model That Would Be Deployed

**Type**: Train-serve skew

**Exact locations**
- Rust: `RS/src/analog_engine/mod.rs:704-715` (standardization), `:902-944` (metric), `:1027-1184` (neighbor search/bandwidth/weighting), `:10-40` (12-dimensional feature names), and `:134-154` (default configuration)
- Python: `PY/src/intraday_quant/models/analog_kernel.py:13-18,32,36,43`
- Rust production wiring: `RS/src/predictor.rs:594-611`, `:1661-1677`; `RS/configs/production.yaml:167-168,187-192`
- Python wiring: `PY/src/intraday_quant/models/walk_forward.py:29-42,152,175-187,196`; `PY/configs/default.yaml:20,22-23`; evidence consumption at `PY/src/intraday_quant/cli.py:49-64`
- Documentation conflates them: `MODEL_SOURCE_MAP.zh-CN.md:13` lists both files on one line, while `axio7-model-review/review-package/01-model-algorithm-inventory.md:73-133` describes only the Rust semantics but presents them as the definition of the model.

**Minimal reproduction**
Feed the same 12-dimensional features and labeled history to `AnalogKernelModel(25, 1.0)` and `AnalogEngine::fit(..., production config)`. Rust retains at most one neighbor per historical trading day and derives bandwidth from the 40th-nearest-neighbor distance. Python retains the globally nearest 25 rows with a fixed bandwidth of 1.0—which, on minute data, is usually 25 consecutive minutes from the same day.

**Why this matters**: Eight verified differences, none of which is an equivalent rewrite
| # | Dimension | Rust | Python |
|---|---|---|---|
| 1 | Standardization | median + 1.4826·MAD (`mod.rs:709-714`) | SimpleImputer(median) + StandardScaler, i.e. mean + standard deviation (`analog_kernel.py:13-18`) |
| 2 | Metric | ShrinkageMahalanobis, `sqrt(dᵀΣ⁻¹d)`, **without division by d** (`mod.rs:914-932`; the `StandardizedEuclidean` branch in the same function at `:911-913` does divide, showing that this is intentional) | Plain L2 / sqrt(d), no covariance (`:32`) |
| 3 | Feature set | Fixed at 12 dimensions (`mod.rs:10-40`, `maximum_dimensions: 12`) | Up to 51 columns (`walk_forward.py:29-42`) |
| 4 | Bandwidth | AdaptiveKthNeighbor: kth-nearest-neighbor distance × 0.9 (`mod.rs:1159-1169`, `production.yaml:168`), scale-independent | Fixed absolute h = 1.0 (`:36`, `default.yaml:23`) |
| 5 | Weight | Gaussian kernel × regime-posterior cosine (`mod.rs:1173-1174`) | No such factor |
| 6 | Neighbor pool | Strictly earlier than the current trading day; same 5-minute bucket; same dominant regime; cosine ≥ 0.90; label matured (`mod.rs:1032-1050,1054-1094`); at most one per day (`:1118-1128`); fewer than 10 independent days returns `NO_RELIABLE_ANALOG` (`:1132`) | Only `timestamps < timestamp` (`:28`) |
| 7 | k | 40 (`production.yaml:167`) | 25 (`default.yaml:22`) |
| 8 | `median_return` | — | Unweighted `np.median` (`:43`), while every other statistic in the same function (`:42,44,45,46,48,49`) is weighted |

Python writes its output to `models/predictions.parquet` at `walk_forward.py:196`; `score_and_select` / `run_underlying_backtest` at `cli.py:52-64` then produce the trade_blotter and selected_candidates. In other words, **the only quantitative backtest evidence in this handoff package measures a model that differs simultaneously in center, scale, metric, feature space, bandwidth rule, weighting, neighbor eligibility, and k value**.

**Minimal fix** (choose one; do not reconcile field by field)
```diff
# a) Recommended: remove the Python implementation and call the Rust engine through CLI/FFI,
#    so backtesting and production share one implementation.
# b) If option a cannot be done immediately, explicitly downgrade it to a research prototype.
--- a/axio7-model-review/source/intraday_quant/configs/default.yaml
+++ b/axio7-model-review/source/intraday_quant/configs/default.yaml
-models: [logistic, analog_kernel, gradient_boosting]
+# analog_kernel differs from the quant_engine_rs production implementation in eight dimensions.
+# Its backtest results are not evidence for the production model, so it is removed from the default model set.
+models: [logistic, gradient_boosting]
```
Also correct `MODEL_SOURCE_MAP.zh-CN.md:13`: place the two files on separate lines, label them "research implementation" and "production implementation," and state at the top of `01-model-algorithm-inventory.md:73-133` that the described semantics apply only to the Rust implementation.

**Required new tests**
Add a cross-language golden vector: check fixed synthetic states + outcomes into the repository (same k, h, and features) and assert that the two engines' `expected_return`, `win_probability`, and `uncertainty` agree within 1e-9. Fail CI on drift. See §5.

**Blocks promotion**: Yes.

---

### M4 (P1) — Family Competition Directly Compares Log-Densities in Standardized and Raw Space: The Change-of-Variables (Jacobian) Term Is Missing

**Type**: Scoring correctness / incomparable likelihoods

**Exact locations**
- Raw-space baseline: `RS/src/engine/regime_competition.rs:369-391` (`DiagonalGaussian::average_log_likelihood`), fitted at `:339-367`, with raw observations from `:95-100`
- Standardized space: `RS/src/engine/regime.rs:507-532` (`GaussianHmm::average_log_likelihood`, standardized at `:521`, with no `-Σ ln(scale_d)` anywhere)
- The other three families with the same defect: `regime_competition.rs:148-157` (`standardized()`), `:159-170` (`gaussian_log_emission`), `:200-221` (`student_t_log_emission`), and `RS/src/engine/tvtp_regime.rs:378-384` + `:472-473`
- Consumers: `regime_competition.rs:478-481`, `:515-516`; decision at `:671-689`
- Sole caller: `RS/src/bin/quantctl.rs:2794-2814` (offline research subcommand)

**Minimal reproduction**
The exact relationship is `log p_X(x) = log p_Z(z) - Σ_d ln(scale_d)`, but the HMM path never adds back `-Σ ln(scale_d)`. Recompute using the four production features (`active_5m_return`, `dist_vwap`, `rolling_realized_vol`, and `volume_zscore`, with scales approximately `[0.0020, 0.0022, 0.0009, 1.0]`): `Σ ln(scale_d) = -19.35`; the raw-space baseline is `+13.67`, while the standardized one-state HMM is `-5.68`. Their difference, `19.3455`, matches `-Σ ln(scale_d)` to four decimal places. Three of the four features are financial quantities on the order of 1e-3, so **the sign is structural, not a numerical coincidence**.

**Why this matters**
Every headline field in `RegimeCompetitionReport`—`selected_family`, `selected_family_mean_score`, `no_regime_mean_score`, and `promotion_status`—loses meaning, even though the report's own `scoring_rule` string claims that all families share one scoring rule. Because `no_regime_iid_gaussian` itself is a candidate in the `max_by` at `:671-680`, it always wins; `improvement` is always `0.0`; `enough_evidence`, which requires `> 0.0`, is always false; and the report always emits `NO_FAMILY_PROMOTED`. **This currently fails closed, which is exactly why it went undetected**—but it also means that the competition has always returned a fixed answer independent of the data.

**Additional independent defect (fixing the Jacobian will not fix this)**: `:671-689` includes the baseline in `max_by` and then subtracts the baseline from the winner. Whenever the baseline legitimately wins, `improvement` is identically 0.0 and can never satisfy `> 0.0`.

**Minimal fix**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
@@ (GaussianHmm::average_log_likelihood, ~:507-532)
     total += self.forward_backward(&sequence).log_likelihood;
+    // Change of variables: log p_X(x) = log p_Z(z) - Σ_d ln(scale_d)
+    total -= sequence.len() as f64
+        * self.scale.iter().map(|s| s.ln()).sum::<f64>();
     observations += sequence.len();
```
Apply the same treatment to `regime_competition::gaussian_log_emission` (`:159-170`), `student_t_log_emission` (`:200-221`), and `NonHomogeneousGaussianHmm::filter` (`tvtp_regime.rs:472-473`). **Reporting every density in raw space** is preferable to standardizing the baseline because it also makes the resulting numbers comparable across refits with different scale vectors. In addition, remove the baseline from the `max_by` candidate set and use a two-level "winner versus baseline" structure.

**Required new tests**
```rust
// Reduction consistency: a one-state GaussianHmm and DiagonalGaussian must agree
// within 1e-9 on the same data.
// Scale invariance: multiplying one input feature by 1000 must change each family's
// reported average log-likelihood/observation by exactly -ln(1000).
// Today, the HMM changes by 0 and the baseline changes by -6.9.
```
**Blocks promotion**: Yes. It blocks the research conclusion that no regime family outperforms no-regime, not the online path.

---

### M5 (P1) — The HSMM Forward Recursion Double-Counts Emissions Along the Duration-Advance Path; `minimum_duration=1` Does Not Reduce to an Ordinary HMM

**Type**: Correctness / miscomputed likelihood

**Exact location**: `RS/src/engine/regime_competition.rs:283-311` (`hsmm_sequence_log_likelihood`, declared at `:268`). Double-counting occurs at **`:288`** and **`:293`**; the final loop that applies a single emission is at `:304-309`.

**Minimal reproduction**
Let `D = minimum_duration` and `index(s,d) = s*D + d`:
- At `duration = D-2`, the inner loop at `:286-289` has already written a value containing the emission into `next[last]`.
- `:290-293` then applies `log_sum_exp` to that value and **adds the emission again**.
- When `D = 1`, the inner loop is empty and `last == index(state,0) == the destination cell`, so `:293` adds the emission once and `:307` adds it again. Cross-state transitions (`:294-301`) also write values without emissions into cells that are mixed with values containing emissions. **The result therefore depends on `state` iteration order**, making state 0 and state 1 asymmetric.

For K=2, five observations, and identical parameters, recomputation gives ordinary forward `-6.298141`; hsmm(D=1) `-7.178606`; hsmm(D=2) `-6.527184`; and hsmm(D=3) `-20.438980`. Mathematically, D=1 must equal `-6.298141` exactly, and D=1 is included in the tuning grid (`[1,2,3,4,6]` at `:549`).

**Why this matters**
`average_hsmm_log_likelihood` (`:315-330`) is used at `:552` for within-family hyperparameter scanning (argmax at `:556`), at `:560` to populate `scores["minimum_duration_hsmm"]` (`:562-566`), and ultimately in the family ranking at `:671-680`. **Both hyperparameter selection and family ranking consume this biased number**, and the bias changes non-monotonically with the hyperparameter. Magnitude matters: at D=1, approximately one extra emission is added per time step, O(T). At D≥2, duplication occurs only on the `d=D-2 → d=D-1` advance and grows with the number of state entries rather than T. The original report's O(T) is the worst case, not the typical case.

**Minimal fix**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/engine/regime_competition.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/engine/regime_competition.rs
@@ -286,10 +286,9 @@
         for duration in 0..minimum_duration - 1 {
-            next[index(state, duration + 1)] =
-                alpha[index(state, duration)] + gaussian_log_emission(model, row, state)?;
+            next[index(state, duration + 1)] = alpha[index(state, duration)];
         }
         let last = index(state, minimum_duration - 1);
         let stay = alpha[last] + model.transition[state][state].max(1.0e-300).ln();
-        next[last] =
-            log_sum_exp(&[next[last], stay]) + gaussian_log_emission(model, row, state)?;
+        next[last] = log_sum_exp(&[next[last], stay]);
@@ -304,9 +303,12 @@
-    // The old code adds emissions only to index(state, 0)
+    // Add emissions uniformly here, exactly once per destination cell
+    for state in 0..states {
+        for duration in 0..minimum_duration {
+            let cell = index(state, duration);
+            if next[cell].is_finite() {
+                next[cell] += gaussian_log_emission(model, row, state)?;
+            }
+        }
+    }
```

**Related defect in the same function that must also be fixed (independent issue)**: when every input is `-inf`, `log_sum_exp` (`:134-146`) returns the **finite value** `LOG_FLOOR = -690.78`. As a result, the `is_finite()` guard at `:306` admits cells with truly zero mass at t=1 and injects spurious probability. It should return `f64::NEG_INFINITY` when all inputs are `-inf`.

**Required new tests**
```rust
// Reduction identity
assert_abs_diff_eq!(
    hsmm_sequence_log_likelihood(&model, &seq, 1)?,
    hmm_log_likelihood_with_emission(&model, &seq, |r,s| gaussian_log_emission(&model,r,s))?,
    epsilon = 1e-10);
// Normalization: on a discrete observation grid with two states, one dimension,
// and length three, the expanded-state kernel's total probability mass must equal 1.
```
**Blocks promotion**: Yes (as with M4, it blocks the research conclusion).

---

### M6 (P1) — The 1e-9 MAD Scale Floor Lets a Near-Constant Feature Dominate the Entire Metric and Contaminate the Isotropic Shrinkage Target

**Type**: Numerical stability

**Exact locations**: `RS/src/analog_engine/mod.rs:714` (`scale[feature] = (1.4826 * quantile(&deviations, 0.5)).max(1.0e-9);`) and `:747-760` (`target_variance` is the **mean** of the covariance diagonal; the shrinkage loop adds `s*target_variance` to diagonal entries while only multiplying off-diagonal entries by `(1-s)`).

**Minimal reproduction**
Use 12 features and 400 samples, with feature 9 equal to exactly 0.0 in 70% of rows and production `shrinkage = 0.20`. `scale[9]` falls to `1.000e-09`, making the standardized column reach `1.0e9`. The raw diagonal consists of eleven healthy features near 1.0 plus a degenerate feature at 1.65e17; `target_variance = 1.38e16`. After shrinkage, the diagonal of **every healthy feature** becomes `2.76e15` (true value approximately 1.0). Contributions to squared Mahalanobis distance are 7.41 from the degenerate feature and 3.99e-15 from all eleven healthy features combined, a ratio of approximately `1.9e15`. The healthy features are numerically erased.

**Degeneracy is not hypothetical; the code creates it**: `cross_asset_breadth_score` at `RS/src/engine/features.rs:380-384` is **exactly 0.0** whenever any of the six BREADTH_SYMBOLS is missing (`collect::<Option<Vec<_>>>()...unwrap_or_default()`). Even with complete context, it is only the mean of six values in {-1,0,+1}, so its natural mode is 0.0. Similar constant fallbacks include `session_range_position` being exactly 0.5 when `range == 0.0` (`features.rs:313-317`), `volume_zscore` being exactly 0.0 when `volume_sd == 0.0` (`features.rs:297-301`), and `normalized_range` being exactly 0.0 when `high == low`.

**Why this matters**
All three potential defenses fail: (1) the identity fallback (`mod.rs:767-781`) does not activate because shrinkage instead makes the matrix **well-conditioned** (observed condition number 49, pivots around 1e15), so the absolute 1e-12 pivot threshold in `invert_matrix` (`:346-394`) passes and the contaminated metric is actually used; (2) the non-finite guard (`:761-766`) does not activate because 1.65e17 is finite; and (3) frozen-artifact validation (`:629-651`) checks only `scale <= 0.0`, making 1e-9 valid. This is also on the production path: `fit_frozen_predictor` at `RS/src/predictor.rs:1127` calls `AnalogEngine::fit` with `metric: ShrinkageMahalanobis` + `..AnalogEngineConfig::default()` (`predictor.rs:594-611`). It **fails open** with no error or warning.

**Minimal fix**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs
@@ -709,7 +709,13 @@
-        scale[feature] = (1.4826 * quantile(&deviations, 0.5)).max(1.0e-9);
+        // Use a relative floor rather than an absolute one: an absolute 1e-9 floor amplifies
+        // a constant feature by 1e9 and lets it dominate the entire metric.
+        // This file already uses a relative tolerance at :578; :714 is the only exception.
+        let mad = 1.4826 * quantile(&deviations, 0.5);
+        let typical = values.iter().map(|v| v.abs()).sum::<f64>() / values.len() as f64;
+        if mad < 1.0e-6 * (1.0 + typical) {
+            return None;   // Fail closed: reject the fit instead of emitting a metric dominated by one column.
+        }
+        scale[feature] = mad;
```
Independently, change the shrinkage target to the **correlation structure**: normalize the covariance to a unit diagonal before applying the isotropic target, so `target_variance` cannot be hijacked by the highest-variance column.

**Required new tests**
```rust
// When a feature is constant in >50% of training rows, fit() must return None
// (or exclude that dimension from selected_dimensions) instead of returning an engine
// whose distances are dominated by that column.
// Note that this file's own test fixture at mod.rs:1572 hard-codes session_range_position to 0.5.
```
**Blocks promotion**: Yes.

---

### M7 (P1) — `locally_weighted_linear_intercept` Extrapolates a Near-Equidistant Cluster to distance=0; the 1e-12 Determinant Guard Does Not Stop It, and the Value Is Published

**Type**: Numerical stability

**Exact locations**: Calculation at `RS/src/analog_engine/mod.rs:1236-1251` (field declared at `:185`, assigned at `:1261`); published at `RS/src/predictor.rs:2268` (`KernelRegressionEvidence.local_linear_intercept`); its only consumer is the finiteness check at `RS/src/api.rs:2056`.

**Minimal reproduction**
Use 40 candidates with distances uniformly distributed on `[0.97, 1.03]` (`distance_concentration = 0.06`, passing the < 0.05 gate at `mod.rs:1390`) and `terminal_return` as `N(0, 0.002)` noise independent of distance. Across 20,000 Monte Carlo trials, `sd(intercept) = 185bp` and `sd(Nadaraya-Watson mean) = 3.15bp`, a **58.8×** ratio. `determinant = 3.7e-4`, four orders of magnitude above the 1e-12 threshold, so the fallback **never activates**.

**Why this matters**
The weights are normalized (`mod.rs:1181-1184, :1212`), so `sum_w == 1` and `determinant == Var_w(d)` exactly, while `local_intercept = ȳ - slope·d̄`. Under adaptive bandwidth, `d̄/sd(d)` is commonly 30–60. This extrapolates to zero from a cluster whose distances never approach zero. More fundamentally, regression on the **norm** rather than the signed displacement vector `(x_i - x_q)` **is not** local-linear regression. The first-order bias term is `E[x_i - x_q]`; taking the norm cannot cancel it, so the method does not deliver the bias correction its name promises. Yet `locally_weighted_linear_regression` in `supported_method_comparison` at `mod.rs:1427` presents it as an improvement over the NW mean and **does not publish a standard error**, leaving human consumers unable to see the 59-fold noise amplification.

**Minimal fix**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs
@@ -1240,7 +1240,13 @@
-    let local_intercept = if determinant.abs() > 1.0e-12 {
+    // determinant == Var_w(d) because weights are normalized. An absolute threshold is
+    // scale-insensitive; use a relative criterion plus a leverage cap. The larger
+    // mean_w(d)/sd_w(d), the more extrapolation to d=0 amplifies variance.
+    let mean_d = sum_wx;                       // sum_w == 1
+    let sd_d = determinant.max(0.0).sqrt();
+    let well_posed = determinant > 1.0e-6 * mean_d * mean_d
+        && sd_d > 0.0
+        && mean_d / sd_d < 5.0;
+    let local_intercept = if well_posed {
         (sum_wxx * sum_wy - sum_wx * sum_wxy) / determinant
     } else {
         mean
     };
```
Then **either remove this field** or replace it with genuine ridge-regularized local-linear regression on the d-dimensional standardized displacement, and publish its own standard error.

**Required new tests**
```rust
// Property test: on random candidate sets whose returns are independent of distance, assert
// |local_linear_intercept - kernel_weighted_mean| <= 3 * dispersion / sqrt(effective_sample_size)
// or assert that fallback activated. The 58.8× scenario above must be rejected by the leverage cap.
```
**Blocks promotion**: No (there is no decision consumer), but it blocks the claim that the evidence fields in this report are trustworthy.

---

### M8 (P1) — The OOD Threshold Is Calibrated on an Approximately 256-Point Fixed-Strided Subsample With Filters That Differ From Query Time, and the Stride Aliases With the Trading-Day Period

**Type**: Correctness / calibration

**Exact locations**: Calibration at `RS/src/analog_engine/mod.rs:864-890` (stride at `:866`, nearest-neighbor loop at `:873-886`); usage at `:1330-1331` (`nearest = distances[0]`, `ood_score = nearest / threshold`) and `:1381-1383` (`ood_score > 1.0` is a hard NO_TRADE); emitted again at `RS/src/predictor.rs:2181` (`ANALOG_OOD`).

**Minimal reproduction**
There are three mismatches:
1. **Sample size**: the threshold is the 0.95 quantile of within-training nearest-neighbor distances among **at most 256** training points, while the query-time numerator is the nearest-neighbor distance over the **full candidate pool**. NN distance scales approximately as `n^(-1/d)`; at d=12, moving from 256 to 100,000 points differs by about `390^(1/12) ≈ 1.6×`. The threshold is systematically about 60% too high, making the OOD gate correspondingly too permissive.
2. **Filtering conditions**: the calibration loop excludes only the same `session_date`. It **does not apply** `same_time_bucket` (`:1038`) or regime filtering (`:1054-1094`), both of which apply at query time and **remove** candidates, raising the query-time minimum distance. The numerator and denominator come from different populations, so their ratio is not a probability of anything.
3. **Stride aliasing**: `stride = len.div_ceil(256)`. With approximately one trading year (99,585–99,840 states and 390 bars per session), `div_ceil(99700/256) = 390`, exactly the daily bar count. **Every calibration point lands on the same session minute**, while `minute_of_session` is itself one of the 12 distance features.

**Why this matters**
`ood_score > 1.0` directly determines availability rate: an overly permissive threshold fails to reject cases that should be rejected, while aliasing makes the threshold jump discontinuously with training-set length.

**Minimal fix**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/analog_engine/mod.rs
@@ -864,8 +864,12 @@
-    let stride = engine.train_indices.len().div_ceil(256).max(1);
-    let sampled = engine.train_indices.iter().step_by(stride).copied().collect::<Vec<_>>();
+    // step_by aliases with the strict 390-bars/session period, causing every calibration
+    // point to land on the same minute. Use a deterministic shuffle seeded by the
+    // restart/training-set hash to preserve reproducibility while eliminating periodicity.
+    let mut sampled = engine.train_indices.clone();
+    deterministic_shuffle(&mut sampled, calibration_seed(engine));
+    sampled.truncate(CALIBRATION_SAMPLE.min(sampled.len()));
```
Calibration nearest neighbors must pass **the same candidate-filtering chain as query time** (same bucket / same dominant regime / one per day / matured label), and the 0.95 quantile must be taken over those minimum distances. Record `calibration_sample_size` in `AnalogDiagnostics`.

**Required new tests**
```rust
// The calibration sample must cover at least N distinct minute_of_session values (today it covers one).
// Doubling the training set must change ood_distance_threshold by no more than 10%.
```
**Blocks promotion**: Yes (it determines availability rate, which is part of the promotion evidence).

---

### M9 (P1) — Restarts Search Only One Basin: Mean Perturbations Are K-Periodic in Restart and Capped at 7e-3σ; Only Self-Transition Probability Actually Changes

**Type**: Optimization / initialization

**Exact location**: `initialized` at `RS/src/engine/regime.rs:163-212`, particularly `:179` (`ordered[rank][column] + ((state + restart) % states) as f64 * 1.0e-3`) and `:184` (`(0.82 + 0.02 * (restart % 5) as f64).min(0.94)`).

**Minimal reproduction**
- `(state + restart) % states` has period `states` with respect to restart, so restarts `r` and `r+K` produce **byte-identical** means. Across restarts, the same multiset of offsets `{0, 1e-3, …, (K-1)e-3}` is merely rotated. The same scalar is added to every dimension, so even the diagonal structure is unperturbed.
- `persistence` has period 5 and only takes values `{0.82, 0.84, 0.86, 0.88, 0.90}`; `.min(0.94)` is dead code.
- Everything else is restart-independent: `initial: vec![1.0/states; states]` (`:201`) and `variances: vec![vec![1.0; dimensions]; states]` (`:204`).
- Across all restarts, mean perturbations span at most `(K-1)*1e-3 = 0.007` standardized units, while quantile spacing between adjacent states is O(1). `grep -n restart RS/src/engine/regime.rs` matches only `101,127,132,167,179,184`; `rand` is not a dependency in `Cargo.toml`—**there is no RNG at all**.
- The production default is `restarts: 3` (`RS/src/config.rs:336`), so only three persistence values are reachable and the periodic wraparound (3 < 8) never occurs.

**Why this matters**
EM on a K=8 diagonal Gaussian HMM has many local optima. `restarts` is the only defense, and it does not work. This couples directly to M2: every K lands in the same deterministic basin, so K-versus-K comparison becomes a comparison among arbitrary local optima rather than among the attainable fitting capacities of the models. The ranking of K is not reproducible under any perturbation of the data. Meanwhile, the determinism test at `regime.rs:629-651` (`assert_eq!(first, second)` at `:636`) **passes vacuously**: it proves determinism, not that any search occurred.

**Minimal fix**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
@@ -176,10 +176,12 @@
-        (0..dimensions)
-            .map(|column| {
-                ordered[rank][column] + ((state + restart) % states) as f64 * 1.0e-3
-            })
-            .collect::<Vec<_>>()
+        // The seed is a pure function of restart: determinism is preserved while diversity increases.
+        // Restart 0 keeps the original quantile ladder as the regression baseline;
+        // restart >= 1 uses k-means++ seeding.
+        let mut rng = SplitMix64::seeded(splitmix64(restart as u64));
+        if restart == 0 { quantile_ladder(&ordered, rank, dimensions) }
+        else { kmeanspp_seed(&mut rng, normalized_sequences, states)[state].clone() }
```
Sample variances log-uniformly and transition rows from a Dirichlet distribution. Do not add a `rand` dependency: a hand-written `splitmix64` takes roughly twenty lines and keeps `Cargo.toml` unchanged.

**Required new tests**
```rust
// With restarts=8, initialized() must produce at least eight pairwise-distinct mean
// configurations whose pairwise L2 distances exceed 0.1 standardized units.
// Recovery test: for a known three-regime process with an intentionally adversarial
// quantile layout, fit(..., restarts=10) must recover the true means while restarts=1 cannot.
```
**Blocks promotion**: No (it does not crash or miscompute, and EM still converges to a valid local optimum), but it contributes to M2's non-reproducible conclusion and should be fixed together with M2.

---

### M10 (P2) — `model.log_likelihood` and `model.bic` Describe Parameters From **Before the Final M-Step**

**Type**: Correctness / off-by-one

**Exact locations**: The fit loop at `RS/src/engine/regime.rs:137-158` (`:142` stores likelihood, `:150-151` calculates BIC, `:152-158` compares restarts) and `em_step` at `:270-346` (`:279-280` calculates likelihood using current parameters, `:326-344` applies the M-step update, and `:345` returns the old likelihood).

**Minimal reproduction**
`em_step` runs forward_backward with θ_k and accumulates `L(θ_k)`, then overwrites `self` with θ_{k+1} and returns `L(θ_k)`. After the loop, the stored parameters are θ_{n+1}, while `log_likelihood = L(θ_n)`, and fit never recomputes after the loop. The sibling implementation in the same codebase, `RS/src/engine/gmm.rs:157-170`, **intentionally** reruns the E-step after the M-step to obtain the score (`:160`). This is an inconsistency, not a design choice.

**Why this matters**
BIC is calculated from stale likelihood. The BIC fallback paths at `RS/src/predictor.rs:836` (`validation_score.unwrap_or(-model.bic)`) and `RS/src/bin/quantctl.rs:3134` rank models using a score that belongs to a different parameter set; restart selection at `:152-158` does the same. `RS/src/market_state.rs:221-224` checks only finiteness and cannot detect this.

**Reason for downgrade (P1 → P2)**: the loop exit condition is `|L_k - L_{k-1}| <= 1e-6*(1+|L|)`, so the missing final increment is on the order of the convergence tolerance and cannot reverse rankings separated by hundreds of BIC nats. Only exhaustion of `max_iterations` can produce a materially stale value, and EM monotonicity makes the bias point in the same direction for all candidates. BIC is only a **fallback** path (the status string is literally `BIC_FALLBACK`); production uses `average_log_likelihood(validation)`, which scores the final parameters. Also, the non-finite break branch is effectively unreachable: `normalize` (`:41-52`) clamps any non-finite or underflowed sum to 1e-300, while `.max(PROBABILITY_FLOOR)` in `emission` (`:222`) also swallows NaN in Rust.

**Minimal fix**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
@@ (fit, after the convergence loop and before calculating BIC)
+    // Match gmm.rs:157-170: the reported score must belong to the returned parameters.
+    model.log_likelihood = normalized_sequences
+        .iter()
+        .map(|seq| model.sequence_log_likelihood(seq))
+        .sum::<Result<f64>>()?;
     model.bic = ...;
```
Change the non-finite branch to **invalidate the entire restart** rather than breaking with stale metadata. Note that the previously suggested `model.sequences_log_likelihood(...)` method does not exist in this repository; use `sequence_log_likelihood` at `regime.rs:387` or `average_log_likelihood` at `:507`.

**Required new tests**
```rust
// After fit(): |model.log_likelihood - Σ_seq model.sequence_log_likelihood(seq)| < 1e-9.
// Today, they differ by exactly one EM step.
```
**Blocks promotion**: No.

---

### M11 (P2) — The Production EM Path Has No Monotonicity Guard, and Its `abs()` Convergence Test Treats a Likelihood **Decrease** as Convergence

**Type**: Missing invariant / EM

**Exact locations**: `RS/src/engine/regime.rs:144-147` (`if (likelihood - previous).abs() <= 1.0e-6 * (1.0 + likelihood.abs()) { break; }`) and `:324` (the only assertion is `debug_assert!(fb.scales.iter().all(|v| v.is_finite()))`, which is compiled out in release and checks only finiteness, not monotonicity). **The same structural defect is duplicated** at `RS/src/engine/gmm.rs:165-169` (the same `abs()` criterion, the same missing monotonicity guard, and the same push to `training_likelihoods`).

**Minimal reproduction**
`.abs()` makes the criterion symmetric: a decrease within the tolerance band is indistinguishable from convergence and exits silently. A repository-wide search finds no likelihood-decrease guard on any EM path; the only `cannot decrease` bail! is at `RS/src/anomaly_research/mod.rs:981` and is unrelated.

**Why this matters**
Non-decreasing likelihood is the only signal that Baum-Welch is implemented correctly. M1's clamp can violate this guarantee (`.exp().max(PROBABILITY_FLOOR)` at `regime.rs:222` plus the floor return at `:43-47`), in which case the fit silently degrades instead of failing. `training_likelihoods` is serialized into the artifact, but `RS/src/market_state.rs:225-231` checks only that its elements are finite. This is on the production path: `GaussianHmm::fit` → `select_hmm_model` at `predictor.rs:796` → frozen artifact construction at `predictor.rs:1124` / `:1296` → `validate_static` at `predictor.rs:641` → `market_state::validate_model_artifact`.

**Two statements require correction**: (a) a monotonicity assertion **does exist**, but only under `#[cfg(test)]`: `first.training_likelihoods.windows(2).all(|p| p[1] + 1e-7 >= p[0])` at `regime.rs:645-650`. It provides no protection today only because the crate does not compile and the tests have never run. (b) `abs()` masks only decreases **within the tolerance band**; a larger decrease produces a large absolute value, so the loop continues rather than exits.

**Minimal fix**
```diff
--- a/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
+++ b/axio7-model-review/source/quant_engine_rs/src/engine/regime.rs
@@ -144,6 +144,11 @@
-        if (likelihood - previous).abs() <= 1.0e-6 * (1.0 + likelihood.abs()) {
+        // Check invariant violations separately from convergence; otherwise, a decrease
+        // within the tolerance band masquerades as convergence.
+        if likelihood + 1.0e-9 * (1.0 + likelihood.abs()) < previous {
+            bail!("EM likelihood decreased: {previous} -> {likelihood}");
+        }
+        if likelihood - previous <= 1.0e-6 * (1.0 + likelihood.abs()) {
             break;
         }
```
Apply the same change at `gmm.rs:165-169`. Also reject artifacts with non-monotonic `training_likelihoods` in `market_state::validate_model_artifact` (`:225-231`).

**Required new tests**
Promote the `windows(2)` monotonicity assertion at `regime.rs:645-650` from the test module to a hard error inside `fit()`. Add a test that intentionally breaks the M-step—for example, by not renormalizing transition rows—and requires `fit()` to return `Err` instead of a silently degraded model.

**Blocks promotion**: No (defense in depth).

---

### M12 (P2) — Python Neighbor Eligibility Checks Only Feature Timestamps, Not Label Maturity Time

**Type**: Look-ahead / leakage (potential)

**Exact locations**: `PY/src/intraday_quant/models/analog_kernel.py:27-28` (comment plus `eligible = np.flatnonzero((self.timestamps < timestamp).to_numpy())`); label reads at `:38-40`; the correct Rust implementation at `RS/src/analog_engine/mod.rs:1048` (`if realized_path.label_available_at > query.timestamp { continue }`).

**Minimal reproduction**
`:28` filters only by feature time, while the `return`/`mfe`/`mae` read at `:38-40` come from `forward_return_{h}m` / `MFE_{h}m` / `MAE_{h}m` at `walk_forward.py:177` (`PY/src/intraday_quant/labels/pipeline.py:26-38`) and are forward outcomes from h minutes **after** the neighbor timestamp.

**Why this is P2 rather than critical**
1. The only caller is `walk_forward.py:176-179`, while `make_folds` (`:45-57`) produces slices that are **split by complete session, ordered, and disjoint**. Every training timestamp precedes every test timestamp, so the `eligible` mask is a tautology on the actual execution path and **never filters any row**.
2. The original report claimed that any change to an expanding/rolling window or to `purge_minutes` would silently reintroduce look-ahead. That mechanism is **incorrect**. Labels cannot cross a session boundary: `labels/pipeline.py:28` requires the horizon window to remain within the candidate's own date, otherwise the label is NaN, and `walk_forward.py:82` then drops those rows. A training neighbor's label must therefore mature within its own session and structurally precedes any query in a later session. `purge_minutes` and `expanding` are unrelated to this leakage.
3. `joblib.dump` does exist at `walk_forward.py:187`, but a project-wide search excluding `.venv` finds no `joblib.load`. Reuse elsewhere after persistence is a hypothesis, not an existing path.
4. It is not on the production decision path; production uses Rust, where the guard is already implemented correctly.

**Minimal fix**
```diff
--- a/axio7-model-review/source/intraday_quant/src/intraday_quant/models/analog_kernel.py
+++ b/axio7-model-review/source/intraday_quant/src/intraday_quant/models/analog_kernel.py
-        # The caller already supplies prior-fold history; this guard also makes direct use safe.
-        eligible = np.flatnonzero((self.timestamps < timestamp).to_numpy())
+        # Only neighbors with matured labels are eligible (align with quant_engine_rs analog_engine/mod.rs:1048).
+        eligible = np.flatnonzero((self.label_available_at <= timestamp).to_numpy())
```
During `fit`, record `self.label_available_at = timestamps + pd.Timedelta(minutes=self.horizon)`, and make the constructor accept `horizon`. **The comment on line 27 must be removed regardless**: it claims a safety property the code does not provide, which is itself a defect in a leakage-sensitive codebase.

**Required new tests**
```python
def test_neighbours_have_matured_labels():
    # Fit on t0..t100 with a 60-minute horizon and predict at t101.
    # Assert every selected neighbor index satisfies timestamps[idx] + 60min <= t101.
```
**Blocks promotion**: No. If M3 adopts option (b) and downgrades this class to a research prototype, this item requires only removing the comment and adding the test.

---

## 4. Real-Time and Deployment Issues (Including Railway-Specific Findings)

**Scope statement**: This section audits only the **container and platform configuration layer** (`RS/Dockerfile`, `RS/railway.json`, `RS/container-entrypoint.sh`, and `RS/DEPLOY.railway.md`) and the **state-persistence path** (prediction ledger). **Not covered**: Moomoo bridge / WebSocket reconnection and backpressure, API authentication middleware and rate limiting, the `tower-http` CORS policy, TLS termination, or memory/handle leaks in real-time subprocesses. These areas require a separate review; this section makes no assumptions about them.

---

### D1 — Railway's Filesystem Is Ephemeral, While the Prediction Ledger Is Local SQLite

| Item | Details |
|---|---|
| **Severity** | Blocker for production deployment |
| **Type** | State persistence |
| **Exact locations** | `RS/src/api.rs:834` (`root.join("state/prediction_ledger.sqlite3")`), `:838` (`PredictionLedger::open`), `:4196`, and `:4212`; CLI default path in `RS/src/bin/quantctl.rs:154, 203, 226, 456, 476, 480` (`data/state/prediction_ledger.sqlite3`); `RS/Dockerfile:30-31` only runs `mkdir` for `/app/data/{live/options,state,reports}`; `RS/Cargo.toml:21-45` has **no PostgreSQL driver** (only `rusqlite = "0.38"` at `:34`); `RS/railway.json` declares no volume |

**Minimal reproduction**: Deploy → create several pending predictions → redeploy with `railway up` → `/api/v1/predictor/settlements` (`RS/src/api.rs:182, 4205`) returns an empty result.

**Why it matters**: The JSONL spool and pending ledger under `/app/data/state` and `/app/data/live` are lost on every redeploy. Meanwhile, the gate in `RS/src/api.rs:893-936` requires `settled >= minimum_settled` and `minimum_settled >= 250`—**a ledger that is periodically reset can never accumulate 250 settled predictions**. In other words, this promotion gate is **structurally impossible to satisfy** under the current deployment model.

**Minimal fix** (a for the short term, b as the proper solution)
```diff
# a) Short term: mount a Railway Volume at /app/data and declare it explicitly in railway.json
 {
   "deploy": {
     "healthcheckPath": "/health",
+    "volumes": [{ "mountPath": "/app/data" }],
     "numReplicas": 1
   }
 }
```
b) Proper solution: persist normalized records and the prediction ledger in PostgreSQL (`DEPLOY.railway.md:11` already lists Postgres in the service topology, but the crate does not even include a driver). Until b is complete, this service is **suitable only for deployment as a read-only research API**; do not use it to host any stateful real-time prediction records.

**Required new test**: An integration test proving that the pending ledger survives a container restart—write N pending entries, restart the process, and assert that `pending_forecasts()` (`RS/src/live.rs:688`) still returns N entries. This test **does not currently exist**.

**Blocks promotion**: Yes (it makes the `settled >= 250` gate permanently impossible to pass).

---

### D2 — A Single `massive-check` Gate Covers Both Equity and Options Entitlements

| Item | Details |
|---|---|
| **Severity** | High |
| **Type** | Availability coupling |
| **Exact location** | `RS/container-entrypoint.sh:46-54` (both `massive-model` and `massive-options-watch` are started only after `if quantctl live massive-check; then`) |

**Minimal reproduction**: Use an account with SIP (equity) but not OPRA (options) entitlement → `massive-check` fails → **the real-time equity model does not start either**, and the log contains only one line: `SIP/OPRA readiness failed` (`:53`).

**Why it matters**: An options-entitlement issue silently stops the entire real-time equity path while `/health` still returns 200 (quantd itself remains alive). This directly reduces availability, and availability is part of the promotion evidence.

**Minimal fix**
```diff
--- a/axio7-model-review/source/quant_engine_rs/container-entrypoint.sh
+++ b/axio7-model-review/source/quant_engine_rs/container-entrypoint.sh
-if quantctl --config "$config" live massive-check \
-  --output data/live/massive_readiness.json; then
-  quantctl --config "$config" live massive-model &
-  model_pid=$!
-  quantctl --config "$config" live massive-options-watch &
-  options_pid=$!
-else
-  echo "SIP/OPRA readiness failed; live model/watchers were not started" >&2
-fi
+if quantctl --config "$config" live equity-check \
+  --output data/live/equity_readiness.json; then
+  quantctl --config "$config" live massive-model &
+  model_pid=$!
+else
+  echo "SIP readiness failed; live equity model was not started" >&2
+fi
+if quantctl --config "$config" live options-check \
+  --output data/live/options_readiness.json; then
+  quantctl --config "$config" live massive-options-watch &
+  options_pid=$!
+else
+  echo "OPRA readiness failed; options watcher was not started" >&2
+fi
```
Prerequisite: The `equity-check` / `options-check` subcommands must be implemented in `RS/src/data/readiness.rs`—**that file is currently a stub**, so this item is blocked by B1.

**Required new tests**: Two readiness fixtures (equity OK / options FAIL and the reverse), asserting that only the corresponding subprocess is started.

**Blocks promotion**: No, but it blocks confidence in the reported availability figure.

---

### D3 — `numReplicas: 1` Is a Correctness Constraint, and the Ledger Has No Idempotency Key to Remove It

| Item | Details |
|---|---|
| **Severity** | Medium (harmless at present, but a hard scalability ceiling) |
| **Type** | Concurrency / data integrity |
| **Exact locations** | `RS/railway.json` (`"numReplicas": 1`); rationale recorded in `RS/DEPLOY.railway.md:29-32`; write sites in `RS/src/bin/quantctl.rs:2615-2616` (`prediction_ledger.append_prediction(contract)`) and `:2619-2620` (`live::settle_pending`); settlement implementation in `RS/src/live.rs:670-796` |

**Minimal reproduction**: Set `numReplicas` to 2 → both replicas subscribe to the same feed, write duplicate ledger entries, and settle the same batch of expired predictions twice.

**Why it matters**: This is a correctness setting, not a cost-saving setting, yet the constraint is hidden in a JSON number—anyone who increases it to handle load will corrupt the prediction record. The constraint should be expressed **in code**, not enforced through a deployment document.

**Minimal fix**: Add a per-prediction idempotency key to the ledger table (`UNIQUE(symbol, as_of, horizon, model_version)`), change `append_prediction` to `INSERT ... ON CONFLICT DO NOTHING`, and return whether a row was inserted; deduplicate settlements in `settle_pending` the same way. Only then can the `numReplicas` restriction be lifted. Until then, add at least a CI assertion alongside `railway.json` that fails whenever `numReplicas` is not 1.

**Required new test**: A concurrent-write test—two writers call `append_prediction` with the same contract at the same time, and the ledger is asserted to contain only one row.

**Blocks promotion**: No.

---

### D4 — Deployment Documentation Conflicts with the Code: `DEPLOY.railway.md` Says Pending Predictions Are Not Settled Automatically, but the Real-Time Loop Already Settles Them

| Item | Details |
|---|---|
| **Severity** | Medium (handoff-package consistency) |
| **Type** | Documentation drift |
| **Exact locations** | `RS/DEPLOY.railway.md:58-59` ("pending predictions are not settled automatically ... after they are written, they are not currently settled in the same live loop") versus the actual code in `RS/src/bin/quantctl.rs:2619-2620` (`let settlements = live::settle_pending(&prediction_ledger, &finalized_output)?;`, in the same live loop, four lines after `append_prediction`) |

**Minimal reproduction**: Read `DEPLOY.railway.md:58-59` and `quantctl.rs:2615-2626` side by side.

**Why it matters**: This is the first file an external reviewer is likely to read (the heading at `DEPLOY.railway.md:48` is "Issues Still Blocking Production Deployment"). An obsolete blocker will mislead the reviewer's prioritization and cast doubt on the credibility of the **other three items** in the same document (D1/D2/D3, which are valid).

**Minimal fix**
```diff
--- a/axio7-model-review/source/quant_engine_rs/DEPLOY.railway.md
+++ b/axio7-model-review/source/quant_engine_rs/DEPLOY.railway.md
-3. **Pending predictions are not settled automatically.** Expired predictions require a causal settlement loop,
-   but after they are written, they are not currently settled in the same live loop. Whether the pending ledger survives a restart is also unverified.
+3. **Whether the pending ledger survives a restart is unverified.** Settlement itself already occurs in the real-time loop
+   (`src/bin/quantctl.rs:2619` calls `live::settle_pending`), but it depends on an SQLite file
+   that remains alive with the process. Until item 1 (ephemeral filesystem) is resolved,
+   no test covers whether pending entries can be recovered after a restart; see `src/live.rs:670-796`.
```

**Required new test**: The same restart-recovery test as D1.

**Blocks promotion**: No, but it blocks handoff.

---

### D5 — The Image Contains Neither a Frozen Artifact nor a `models/` Directory; Absence Silently Degrades to `UNAVAILABLE`

| Item | Details |
|---|---|
| **Severity** | Medium |
| **Type** | Deployment completeness / silent degradation |
| **Exact locations** | `RS/src/api.rs:3385-3392` (`model_contract_projection` reads `root.join("models/frozen_predictor_latest.json")` and uses `.ok().and_then(...).unwrap_or_else(\|\| json!({"status":"UNAVAILABLE"}))`); `RS/Dockerfile:30` creates only `/app/data/{live/options,state,reports}`, with **no** `models/`; `RS/Dockerfile:20-27` copies only `configs`, `risk_policy.yaml`, and the entrypoint, and copies no artifact |

**Minimal reproduction**: Build and start the image from a clean checkout → request the model contract endpoint → receive `{"status":"UNAVAILABLE"}` while the container is healthy and the logs show no errors.

**Why it matters**: **No file in the entire handoff package defines** how the model artifact enters the running container—not the Dockerfile, `railway.json`, or the environment-variable table at `DEPLOY.railway.md:40-46`. Meanwhile, `.ok()...unwrap_or_else` turns its absence into silent degradation rather than a startup failure. A reviewer cannot determine which artifact is actually running in production.

**Minimal fix**
```diff
--- a/axio7-model-review/source/quant_engine_rs/Dockerfile
+++ b/axio7-model-review/source/quant_engine_rs/Dockerfile
-    && mkdir -p /app/data/live/options /app/data/state /app/data/reports \
-    && chown -R axio:axio /app/data/live /app/data/state /app/data/reports
+    && mkdir -p /app/data/live/options /app/data/state /app/data/reports /app/data/models \
+    && chown -R axio:axio /app/data/live /app/data/state /app/data/reports /app/data/models
```
Add an explicit gate after the self-check section in `container-entrypoint.sh`: if `AXIO_REQUIRE_FROZEN_ARTIFACT=1` and `data/models/frozen_predictor_latest.json` does not exist, run `exit 74` instead of bringing the API online with `UNAVAILABLE`. The artifact-distribution path (mount a volume / fetch from object storage at startup / COPY an explicitly tracked `seed/` directory into the image, as already suggested at `Dockerfile:26`) must be specified unambiguously in `DEPLOY.railway.md`.

**Required new test**: A container smoke test in CI—start the image and assert that `/health` passes **and** the model contract endpoint's `status` is not `UNAVAILABLE` (with a fixture artifact mounted).

**Blocks promotion**: No, but it blocks production-model traceability.

---

## 5. Architecture-Convergence Recommendations

### 5.1 Roles and Governance of the Three Source Trees

The documented relationship among the three trees is incorrect (`MODEL_SOURCE_MAP.zh-CN.md:13` places the Rust and Python analog implementations on the same line and treats them as one model), which directly caused M3. Define the boundaries as a **unidirectional pipeline** and codify them in `PROJECT_CONTRACT.md`:

```
intraday_quant (Python)        quant_engine_rs (Rust)          web (TypeScript)
Research / training / labels ──► Production inference / real-time / API ──► Presentation / auth / routing
Produces: frozen artifact JSON   Consumes: artifact; produces: evidence envelope   Consumes: evidence envelope
Not persistently deployed        Sole persistent Railway service                  Railway frontend service
(CI job or research host)
```

Three hard rules:
1. **Python must not contain any inference implementation that could be presented as "production-model evidence."** It must either call Rust (see 5.3) or be explicitly labeled as a research toy and removed from `config.models` (`PY/configs/default.yaml:20`).
2. **Rust must not contain research-reporting logic outside training loops.** The only caller of `RS/src/engine/regime_competition.rs` is currently an offline CLI subcommand (`RS/src/bin/quantctl.rs:2794-2814`), so it belongs on the research side; move it behind a separate `research` feature gate to prevent defects in research code (M4/M5) from being mistaken for production defects.
3. **Artifacts are the sole cross-language interface.** Version the schema (the repository already follows this practice, as with `L1_ORDER_FLOW_SCHEMA_VERSION` at `RS/src/engine/l1_order_flow.rs:7`); every field change must increment the version, and each side must have a deserialization test.

### 5.2 C++: Retire and Preserve as Read-Only Reference

**Conclusion: retire it.** Rationale:
- It is small and not on the production path: the actual source consists only of `CPP/include/axio/quant_os.hpp` (417 lines), `CPP/src/quant_os.cpp` (1,600 lines), `CPP/tests/test_main.cpp` (243 lines), and three `apps/*/main.cpp` files.
- It has **never been built**: `SQLite3::SQLite3` at `CMakeLists.txt:18` fails during the generate stage (B4), while this error does not appear during the configure stage—evidence that this tree has never been part of any automation.
- Its functionality overlaps with the Rust tree: the three entry points `apps/axiod`, `apps/quantctl`, and `apps/moomoo_adapter` correspond respectively to `RS/src/bin/quantd.rs`, `RS/src/bin/quantctl.rs`, and the Moomoo bridge on the Rust side.
- Retaining it is not free: `CMakeLists.txt:28-30` enables `-Werror -Wall -Wextra -Wpedantic -Wconversion -Wshadow`. Once added to CI, a 1,600-line C++ tree that has never compiled will generate many warnings requiring remediation, and that work contributes nothing to the promotion decision.

**Execution approach**: First merge the B4 fix and run the CI `cpp` job successfully **once** (proving that it can actually build and that `ctest` passes), then record the result. Next, move the entire tree to `axio7-model-review/reference-docs/legacy-cpp/` and label it in `README.md` as "Historical reference implementation; excluded from builds and closed to changes." **Do not delete it outright**—it is the only material available for understanding the original design intent. If the C++ tree contains capabilities absent from the Rust side (to be confirmed by reviewing each `apps/*/main.cpp`), migrate those capabilities to Rust before retiring it.

### 5.3 How to Build Cross-Language Golden Tests

This is the only structural remedy for M3 (train-serve skew). It has three layers:

**Layer 0—Fixed fixtures (do this first; lowest cost)**
Check plain-text fixtures into `axio7-model-review/golden/` for both sides to share:
```
golden/analog_kernel/
  states.csv        # N rows × 12 columns; names exactly match FEATURE_NAMES in RS/src/analog_engine/mod.rs:10-40
  outcomes.csv      # terminal_return / mfe / mae / label_available_at
  query.csv         # several query points (including timestamp, session_date, and regime posterior)
  config.json       # k=40, bandwidth_multiplier=0.9, metric=ShrinkageMahalanobis,
                    # covariance_shrinkage=0.20, minimum_regime_similarity=0.90 ...
  expected.json     # expected_return / win_probability / uncertainty, generated by Rust and checked in
```
The fixtures must **deliberately include ill-conditioned samples** so that they also serve as regression tests for §3: a constant feature with MAD equal to 0 (M6), a candidate set with highly concentrated distances (M7), and a training set that crosses a 390-bar period boundary (M8).

**Layer 1—Rust-side generation + assertion**
Add the `quantctl golden analog --fixture golden/analog_kernel --output expected.json` subcommand; Rust tests read `expected.json` and assert that the current implementation agrees with it within 1e-12 (preventing drift within Rust itself).

**Layer 2—Python-side consumption**
Python tests **must no longer implement** kernel regression independently. Instead, they obtain results by invoking `quantctl golden analog` through a subprocess (or FFI) and assert agreement with `expected.json` within 1e-9. The CI `python` job depends on the output of the `rust` job.

**Why this order**: Layers 0+1 can be implemented in Rust alone without waiting for the architectural decision in M3. Once Layer 2 is connected, option (a) for M3 (Python calls Rust) is already 90% complete, while option (b) (downgrade it to a research toy) gains an enforceable criterion—if the Python implementation cannot pass Layer 2, it is not eligible to appear in `config.models`.

**CI gate**: Any change to `golden/expected.json` must be accompanied by a commit message explaining the reason for the change and must receive a separate review in the PR. Numerical drift in the artifact must not be able to pass silently.

### 5.4 Where to Draw the TypeScript Boundary

`RS/DEPLOY.railway.md:9-12` already lists `web` (Next.js frontend / API gateway) as a separate service. The boundary should be drawn at the **evidence envelope (`EvidenceEnvelope`)**, according to the following rules:

**Allowed on the TS side**:
- Render `EvidenceEnvelope` / `ModelContract` / `Settlements` returned by `RS/src/api.rs` (see endpoints at `api.rs:182`, `:3378-3383`, and `:4205`)
- User authentication, sessions, routing, and rate limiting
- Presentation-only sorting, filtering, and pagination
- **Format** values already calculated by Rust (units, decimal places, and time-zone display)

**Forbidden on the TS side (hard rules)**:
- Any numerical calculation: TS must not calculate edge, Sharpe, probabilities, position sizes, or z-scores
- Any threshold decision: decisions such as `ood_score > 1.0` (`RS/src/analog_engine/mod.rs:1381`), the entropy gate (`RS/src/allocation.rs:456`), or `settled >= 250` (`RS/src/api.rs:935-936`) must be emitted by Rust as booleans/enums; TS is responsible only for displaying them
- Any derivation of no-trade reasons: `no_trade_reasons` (`RS/src/predictor.rs:2178-2196`) must be provided in full by Rust, and TS must neither add nor remove entries. **Pay particular attention to `RESEARCH_ONLY_NO_TRADE`, which is pushed unconditionally at `predictor.rs:2193`—the frontend must not filter out this entry in any way**, or the UI will present research candidates as tradable signals.
- Direct reads from SQLite / Parquet / artifact JSON: TS accesses quantd only over HTTP

**Enforcement mechanism**: Generate TS type definitions from the response types in `RS/src/api.rs` (`ts-rs` or a handwritten schema + validation), and add frontend lint rules that forbid arithmetic operators from being applied to model fields in the rendering layer. This is not mere stylistic purity—the lesson from M3 is that "two implementations of the same concept" inevitably diverge, and TS is the third place where threshold logic is most likely to be duplicated.

---

## 6. Recommended Remediation Order

Items marked `‖` can proceed in parallel with one another; items within the same numbered sequence are strictly serial.

### Phase 0: Make the Repository Verifiable (Without This Phase, Everything That Follows Is Meaningless)
| Order | Item | Dependencies |
|---|---|---|
| 0.1 | **B2** Fix `.gitignore` (merge `fix/handoff-buildable`) | None |
| 0.2 | **B1** Restore the **real implementations** under `RS/src/data/`, `PY/.../data/`, and `PY/.../reports/`; remove the stubs | 0.1 (otherwise they will be swallowed again) |
| 0.3 | **B6** CI integration (five jobs) | 0.1 |
| 0.3 ‖ | **B4** CMake target name (merge the existing fix) | None |
| 0.3 ‖ | **B5** Declare the torch dependency | None |
| 0.4 | **B3** Harden `l1_order_flow.rs:179` + enforce compile-time type locking | 0.2 (must be verified against the real modules, not the stubs) |
| 0.5 | **Gate**: `cargo test --locked` is fully green on a clean checkout, and all 286 tests genuinely run for the first time | 0.2 + 0.3 + 0.4 |

> **Do not modify any item in §3 before 0.5.** Every numerical fix requires executable tests for validation; changing the HMM while the crate does not compile is working blind.

### Phase 1: Numerical-Correctness Foundation (Must Precede All Model-Selection Work)
| Order | Item | Dependencies | Notes |
|---|---|---|---|
| 1.1 | **M1** Move `emission` into log space + make `normalize` return `Err` | 0.5 | It drives M2 and amplifies the incomparability of M4/M5 scores, so it must be fixed first |
| 1.2 ‖ | **M4** Add the Jacobian term to family competition + remove the baseline from `max_by` | 0.5 | Same file family as 1.1 but different functions; changes can proceed in parallel and be merged serially |
| 1.2 ‖ | **M5** Remove duplicated HSMM emission accounting + make `log_sum_exp` return `-inf` when all inputs are `-inf` | 0.5 | Same as above |
| 1.3 | **Regression gate**: Both consistency tests required by M1 + M4 scale invariance + the M5 D=1 reduction identity must all pass | 1.1 + 1.2 | These three tests validate one another: the D=1 HSMM, `gaussian_hmm`, and single-state `DiagonalGaussian` must all agree |

### Phase 2: Model Selection (Must Follow Phase 1 Because It Consumes Phase 1 Scores)
| Order | Item | Dependencies |
|---|---|---|
| 2.1 | **M9** Change restart initialization to genuine randomized seeding (the seed is a pure function of the restart) | 1.3 |
| 2.2 | Add and serialize state occupancy on `GaussianHmm` (`em_step` already has `state_weight`; it is simply not persisted) | 1.3 |
| 2.3 | **M2** Consolidate the four argmax copies into `select_state_count`; add occupancy-based rejection + the 1-SE rule | 2.1 + 2.2 |
| 2.4 | Rerun all nine artifacts over an expanded candidate grid and verify that an **interior optimum exists** (currently 9/9 increase monotonically) | 2.3 |

> Critical reminder: The four copies in M2 include the easily missed `RS/src/bin/quantctl.rs:811-825` (the walk-forward fold path). The fix must cover all four locations at once; otherwise, the fold path will retain the old behavior and produce internally contradictory reports.

### Phase 3: Analog Kernel and Train-Serve Consistency (Can Run in Parallel with Phases 1/2; Different Subsystems)
| Order | Item | Dependencies |
|---|---|---|
| 3.1 ‖ | **M6** Relative MAD floor + shrink toward the correlation structure (fail closed) | 0.5 |
| 3.2 ‖ | **M8** Route OOD calibration through the same filtering chain + replace `step_by` with a deterministic shuffle | 0.5 |
| 3.3 ‖ | **M7** Relative-determinant criterion + leverage cap (or remove the field entirely) | 0.5 |
| 3.4 | §5.3 Layer 0+1 golden fixtures (including ill-conditioned M6/M7/M8 samples) | 3.1 + 3.2 + 3.3 |
| 3.5 | **M3** Decision: (a) Python calls Rust ‖ (b) remove it from `config.models` + correct `MODEL_SOURCE_MAP.zh-CN.md:13` and `01-model-algorithm-inventory.md:73-133` | 3.4 |
| 3.6 | **M12** Python label-maturity guard (if (a) is selected, this item disappears automatically; if (b) is selected, at minimum remove the incorrect comment at `analog_kernel.py:27` and add a test) | 3.5 |

### Phase 4: Deployment (Fully Parallel with Phases 1–3; Different Owners Can Proceed Concurrently)
| Order | Item | Dependencies |
|---|---|---|
| 4.1 ‖ | **D4** Correct the stale description at `DEPLOY.railway.md:58-59` | None (documentation only; five minutes) |
| 4.2 ‖ | **D5** Create `models/` in the Dockerfile + document the artifact-distribution path + fail closed when absent | None |
| 4.3 | **D1** Mount a Volume at `/app/data` (short term) → persist in PostgreSQL (proper solution) | 4.2 |
| 4.4 | **D2** Split `massive-check` into `equity-check` / `options-check` | **0.2** (requires the real `readiness.rs`) |
| 4.5 | **D3** Add ledger idempotency keys; only then consider lifting the `numReplicas` restriction | 4.3 |

### Phase 5: Defense in Depth (Non-Blocking; Can Be Done at Any Time)
| Order | Item | Dependencies |
|---|---|---|
| 5.1 ‖ | **M11** Hard guard for EM monotonicity (both `regime.rs` and `gmm.rs:165-169`) | 1.3 (monotonicity should genuinely hold only after M1 is fixed) |
| 5.2 ‖ | **M10** Recompute likelihood after the fit loop before calculating BIC (align with `gmm.rs:157-170`) | 0.5 |
| 5.3 | §5.2 C++ retirement (first run the CI `cpp` job successfully once and archive the evidence, then move it to `reference-docs/legacy-cpp/`) | 0.3 |
| 5.4 | Codify the §5.4 TS-boundary rules in `PROJECT_CONTRACT.md` + generate TS type definitions | None |

### Critical Path
`0.1 → 0.2 → 0.5 → 1.1 → 1.3 → 2.2 → 2.3 → 2.4`. Phases 3 and 4 intersect the main chain only at `0.5` (Phase 3) and `0.2` (item 4.4); everything else can proceed in parallel. With one engineer, execute serially in the order `Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5`. With three engineers, the recommended division of work is: "Phases 0+1+2 (numerical)", "Phase 3 (analog + golden)", and "Phase 4+5.3+5.4 (deployment + architecture convergence)."

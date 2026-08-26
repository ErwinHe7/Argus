# AXIO7 Model and Real-Time Inference Code Review Package

Date: 2026-07-26  
Intended recipients: To be forwarded by the project owner to ICPC gold-medalist-level engineers/algorithm engineers  
Review scope: Code, numerical methods, causality, real-time systems, and model-promotion review  
System boundary: Market research, backtesting, explanation, and monitoring only; automated trading remains disabled at all times

## Architecture in One Sentence

AXIO7 is not designed to hard-code historical market data. Instead, historical replay and entitled real-time market data pass through the same
standardized records, the same Rust feature logic, and the same frozen-model inference path. Python is responsible only for offline
training/validation, while TypeScript is responsible only for the UI, authentication, and Rust API proxying.

## Conclusions to Understand First

1. The current core stack is:
   **diagonal Gaussian HMM + Baum–Welch + causal forward filter + same-regime
   kernel regression + decision-neutral Markov-switching SDE/OU shadow head**.
2. All 9 universe v2 artifacts are candidates and have not yet been promoted. Their HMMs all selected the current
   search boundary `K=8`, so the optimal number of states has not been established.
3. An exact-symbol universe loader was added on 2026-07-26: the Massive and Moomoo live
   workers now load the registry by `model_symbol` instead of falling back to a single SPY artifact.
   Reviewers should verify its tests and failure isolation rather than treat this as an unresolved issue.
4. Current Massive entitlements are insufficient for real-time equities and options; point-in-time
   options history is also incomplete.
5. Massive real-time predictions still lack automated outcome settlement, persistent PostgreSQL archiving, and immutable
   calibration/promotion receipts.
6. TCN and regime-gated Mixture-of-Experts implementations exist in Python, but they are offline candidates.
   They have no Rust production runtime and must not be presented as deployed.
7. The repository does not implement Bayesian/PyMC/Stan, Naive Bayes, LSTM/GRU, LightGBM,
   XGBoost, or CatBoost. Baum–Welch is not a Bayesian algorithm.

## Package Contents

- Repository-root `REVIEWER_START_HERE.zh-CN.md`: How to clone the repository, locate the relevant code, and edit the source directly.
- Repository-root `MODEL_SOURCE_MAP.zh-CN.md`: A mapping from every item in this inventory to the actual code files.
- `01-model-algorithm-inventory.md`: Models, mathematical methods, training, and online usage.
- `02-technical-stack-and-runtime.md`: Rust/Python/C++/TypeScript, data, and deployment stack.
- `03-review-brief-and-checklist.md`: What reviewers are expected to inspect and fix.
- `04-evidence-index.md`: Key code, artifacts, tests, and evidence for known blockers.
- `inventory.csv`: A sortable model inventory.
- `../source/`: Rust, Python, and C++ model implementations and tests—not documentation alone.
- `../model-artifacts/`: 9 unpromoted candidate artifacts, the registry, and legacy references.

## Requested Review Deliverables

- Conclusions on the numerical correctness and causality of the HMM/EM, kernel, and SDE/OU implementations;
- Conclusions on state-count selection, calibration, purged walk-forward validation, and OOS evidence;
- Patch recommendations for real-time streams, persistence, restart recovery, and multi-symbol model routing;
- Benchmarks for performance hotspots, especially exact analog search;
- A minimal patch set prioritized as P0/P1/P2, with corresponding tests;
- A clear distinction among "code bugs," "insufficient evidence," "insufficient data entitlements," and "no incremental model value."

Do not conceal existing evidence gaps by adding new model names, and do not copy historical data rows into source code.

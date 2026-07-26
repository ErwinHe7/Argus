# Argus — AXIO7 model review handoff

This repository currently contains a focused, data-free AXIO7 model and
real-time inference review snapshot. It is intended for an external engineer to
inspect and modify from the populated default `main` branch.

## Model stack at a glance

**This is not an HMM-only repository.** The four primary statistical
components are visibly indexed as:

1. **HMM / Baum–Welch / causal regime filter**
2. **12D high-dimensional same-regime kernel regression**
3. **Markov-switching stochastic differential equation**
4. **VWAP-residual Ornstein–Uhlenbeck model**

Neural challengers, calibration, classical challengers, and research models are
also included.

Start with
[`00_START_HERE_MODEL_STACK__HMM_KERNEL_SDE_OU.md`](00_START_HERE_MODEL_STACK__HMM_KERNEL_SDE_OU.md)
or open [`MODEL_COMPONENTS/`](MODEL_COMPONENTS/) to see one plainly named
directory per model family. Then use
[`MODEL_SOURCE_MAP.zh-CN.md`](MODEL_SOURCE_MAP.zh-CN.md) for the complete
algorithm-to-source map. The current-source completeness receipt is
[`axio7-model-review/CURRENT_SOURCE_SYNC.md`](axio7-model-review/CURRENT_SOURCE_SYNC.md).

## What is included

- Rust production inference source and tests:
  `axio7-model-review/source/quant_engine_rs/`
- Python offline research/training source and tests:
  `axio7-model-review/source/intraday_quant/`
- C++20 native research source and tests:
  `axio7-model-review/source/quant_core_cpp/`
- Chinese model/algorithm inventory, technical stack, evidence index, and
  reviewer checklist:
  `axio7-model-review/review-package/`
- Selected mathematical and production-contract references:
  `axio7-model-review/reference-docs/`
- Sanitized universe registry and artifact summary:
  `axio7-model-review/artifact-metadata/`
- Nine exact-symbol unpromoted candidate artifacts plus the legacy comparison
  artifact at their directly loadable runtime paths:
  `axio7-model-review/source/quant_engine_rs/data/models/`
- The same 12 JSON files in a verified portable archive:
  `axio7-model-review/model-artifacts/axio7-candidate-artifacts-2026-07-26.zip`

## What is deliberately excluded

- historical or live market-data rows;
- databases, Parquet/CSV/JSONL archives, logs, reports, and outputs;
- API keys, access tokens, `.env` files, credentials, and provider sessions;
- frontend, billing, authentication, and unrelated product code;
- automatic order execution.

The model artifacts include parameters, hashes, training lineage, and analog
training-row indices, but no raw historical or realtime market observations.
They are unpromoted candidates and must not be treated as calibrated production
models.

## Core model stack

The current candidate stack is:

1. diagonal-Gaussian HMM;
2. scaled forward-backward;
3. Baum-Welch soft EM;
4. causal online filtering and diagnostic-only Viterbi;
5. 12-dimensional same-regime adaptive Gaussian-kernel regression;
6. Markov-switching log-return diffusion;
7. VWAP-residual Ornstein-Uhlenbeck shadow model;
8. Logistic/Ridge/Histogram Gradient Boosting challengers;
9. offline causal TCN and regime-gated Mixture-of-Experts challengers;
10. Platt/isotonic calibration and purged walk-forward validation.

Read `axio7-model-review/review-package/README.zh-CN.md` first.

## Current high-priority review targets

- HMM state selection reaches the tested boundary for all nine candidates.
- No candidate model or calibration artifact is promoted.
- Massive SIP/OPRA realtime entitlement is unavailable.
- The Massive model loop persists predictions but does not automatically
  settle matured horizons in the same loop.
- Rust live ingestion does not continuously archive normalized records to
  PostgreSQL.
- Equity/options readiness is coupled at container startup.
- Child model/options processes are not fully supervised by container health.
- Point-in-time options NBBO/trades/OI evidence is incomplete.
- PyTorch is used by Python code but is not pinned in `pyproject.toml`.

Exact-symbol universe loading was added on 2026-07-26. Treat it as a change to
verify, not as an unresolved single-SPY fallback bug.

## Checks

From `axio7-model-review/source/quant_engine_rs/`:

```powershell
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
```

The current snapshot passed 296 Rust library tests, 8 CLI tests, and 12
integration tests (316 total) on 2026-07-26.

From `axio7-model-review/source/intraday_quant/`:

```powershell
python -m pytest --basetemp .pytest-tmp -p no:cacheprovider
```

The Python snapshot passed 26 tests with 5 skipped. CMake was unavailable on
the source machine, so the C++ checks must be run by the reviewer.

## Product and safety boundary

AXIO7 is an impersonal market-research system. It may scan, explain, backtest,
and monitor deterministic research conditions. It must not place orders,
personalize recommendations, or call uncalibrated directional signals
risk-free arbitrage. Missing, stale, unentitled, incomplete, or non-causal data
must fail closed.

The original worktree base commit was
`bfc95815be9a212bbe75663df8af548bfb92f917`. The handoff contains a selected
snapshot from a dirty worktree, so this Argus commit is the authoritative
content hash for the delivered review files.

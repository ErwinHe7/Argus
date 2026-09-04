# Reviewer: Start Here

This is not a documentation-only Markdown package. The model implementations, tests, and current unpromoted frozen artifacts are all available on this repository's default `main` branch. Create your own working branch from `main`, then submit a PR when finished or push the mutually agreed changes directly.

The full stack includes HMM, 12-dimensional same-regime kernel regression,
Markov-switching SDE, VWAP residual Ornstein–Uhlenbeck, and research challengers.
Start with `00_START_HERE_MODEL_STACK__HMM_KERNEL_SDE_OU.md` and
`MODEL_COMPONENTS/`. `axio7-model-review/CURRENT_SOURCE_SYNC.md` records the
historical source-sync inventory and exclusions.

## Shortest Reading Path

1. `MODEL_SOURCE_MAP.zh-CN.md`: exact source file, purpose, and status for every model.
2. `axio7-model-review/review-package/03-review-brief-and-checklist.md`:
   P0/P1/P2 review and remediation tasks.
3. `axio7-model-review/review-package/04-evidence-index.md`: key implementation locations.
4. `axio7-model-review/source/`: editable Rust, Python, and C++ source code and tests.
5. `axio7-model-review/model-artifacts/axio7-candidate-artifacts-2026-07-26.zip`:
   9 unpromoted candidate artifacts plus the legacy benchmark; extract the archive to inspect them.

## What Can Be Edited Directly

- Production inference, realtime validation, HMM, Baum–Welch, kernel, and SDE/OU:
  `axio7-model-review/source/quant_engine_rs/`
- Offline training, walk-forward evaluation, conventional models, TCN/MoE, and calibration:
  `axio7-model-review/source/intraday_quant/`
- Native research/HMM/Logistic/OMS benchmarks:
  `axio7-model-review/source/quant_core_cpp/`

Frozen artifacts are generated outputs; do not edit their parameters or SHA values manually. After fixing an algorithm, retrain, validate, and export a new artifact, and keep it at `CANDIDATE_NOT_PROMOTED` until it passes independent calibration and promotion.

## Local Setup

```powershell
git clone https://github.com/ErwinHe7/Argus.git
Set-Location Argus
git switch main
git pull
git switch -c review/model-audit
```

Rust:

```powershell
Push-Location axio7-model-review/source/quant_engine_rs
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
Pop-Location
```

Python:

```powershell
Push-Location axio7-model-review/source/intraday_quant
python -m pytest --basetemp .pytest-tmp -p no:cacheprovider
Pop-Location
```

C++ (requires CMake):

```powershell
cmake -S axio7-model-review/source/quant_core_cpp -B axio7-model-review/source/quant_core_cpp/build
cmake --build axio7-model-review/source/quant_core_cpp/build
ctest --test-dir axio7-model-review/source/quant_core_cpp/build --output-on-failure
```

## Data Boundary

The repository does not include historical or realtime market observations, databases, Parquet, JSONL, API keys, or `.env` files. The artifact archive contains model parameters, a training-lineage hash, and the analog training index; it does not contain historical market-data rows. Data-level reproduction requires an entitled point-in-time data source feeding the same normalized record, Rust feature engine, and frozen inference path.

# AXIO7 repository operating contract

## Product boundary

AXIO7 is an impersonal market-research system. It may scan, explain, backtest,
and monitor deterministic research conditions. It must not place orders,
personalize recommendations, or describe directional signals as risk-free
arbitrage.

## Runtime ownership

- `quant_engine_rs/` is the canonical production inference and market-data
  validation service.
- `intraday_quant/` is offline research, training, validation, and artifact
  export only.
- `quant_core_cpp/` contains native research components and must not be
  duplicated in TypeScript.
- `app/`, `components/`, and `lib/` provide UI, authentication, orchestration,
  constrained natural-language parsing, and server-side proxies. They must not
  calculate probabilities, Greeks, GEX, expected return, risk, or arbitrage
  economics.
- An LLM may translate a question into the allow-listed query contract and
  explain engine output. It must never invent market observations or perform
  the quantitative calculation.

## Data and model rules

- Every market answer must expose source, observation cutoff, availability
  time, freshness, coverage, model/feature version, and material caveats.
- Missing, stale, incomplete, unentitled, delayed-as-realtime, or non-causal
  data fails closed. Never silently substitute Yahoo or synthetic values.
- Open interest does not reveal dealer identity or position sign. Gamma
  exposure is unsigned unless an explicit scenario assumption is named.
- Calibrated probabilities may be published only from a separately validated,
  promoted, immutable artifact. Raw analog frequencies must be labeled as raw.
- Historical evaluation must use point-in-time data, purged walk-forward
  splits where applicable, explicit costs, and untouched out-of-sample results.
- Secrets stay in environment variables and server-side code. Never put vendor
  keys or the research token in client bundles, logs, fixtures, or commits.

## Change discipline

- Preserve unrelated dirty-worktree changes.
- Add or update tests for query validation, data freshness/coverage rejection,
  causality, and serialization contracts.
- Keep automatic execution disabled in every production configuration.
- Production promotion requires passing Rust, Python, TypeScript, and available
  native checks plus a verified live-data readiness receipt.

## Standard checks

Run from the repository root:

```powershell
npm run typecheck
npm run build
Push-Location quant_engine_rs
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
Pop-Location
Push-Location intraday_quant
python -m pytest --basetemp .pytest-tmp -p no:cacheprovider
Pop-Location
```

If CMake is installed:

```powershell
cmake -S quant_core_cpp -B quant_core_cpp/build
cmake --build quant_core_cpp/build
ctest --test-dir quant_core_cpp/build --output-on-failure
```

## Active execution plan

The current production integration plan and evidence log live at
`docs/exec-plans/active/production-quant-inference.md`. Update it when a phase,
interface, blocker, deployment, or rollback condition changes.

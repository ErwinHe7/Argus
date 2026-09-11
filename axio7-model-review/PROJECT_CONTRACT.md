# AXIO7 repository operating contract

## Product boundary

AXIO7 is an impersonal market-research system. It may scan, explain, backtest,
and monitor deterministic research conditions. It must not place orders,
personalize recommendations, or describe directional signals as risk-free
arbitrage.

## Runtime ownership

The owner approved a separate paper-strategy extension on 2026-09-07 in the newer
`platform/` sources. Its local connectors may execute on moomoo SIMULATE accounts
under explicit user mandates; live-money and options execution remain disabled.
This does not change the archived research services' boundary. See
`platform/docs/strategy-lab/DELIVERY.md` for the scoped implementation and evidence.

- `axio7-model-review/source/quant_engine_rs` is the canonical production
  inference and market-data validation service.
- `axio7-model-review/source/intraday_quant` is offline research, training,
  validation, and artifact export only.
- `axio7-model-review/source/quant_core_cpp` contains native research
  components and must not be duplicated in TypeScript.
- `axio7-model-review/apps/spy-price-demo` is the checked-in TypeScript
  application package. TypeScript UI, authentication, orchestration,
  constrained natural-language parsing, and server-side proxy code must not
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
- Production promotion requires passing Rust, Python, TypeScript, Docker, and
  available native checks plus a verified live-data readiness receipt.

## Standard checks

Run from the repository root:

```powershell
npm --prefix axio7-model-review/apps/spy-price-demo ci
npm --prefix axio7-model-review/apps/spy-price-demo run typecheck
npm --prefix axio7-model-review/apps/spy-price-demo run build
Push-Location axio7-model-review/source/quant_engine_rs
cargo fmt --check
cargo clippy --all-targets --locked -- -D warnings
cargo test --locked
Pop-Location
Push-Location axio7-model-review/source/intraday_quant
python -m pip install -e ".[dev]"
python -m pytest --basetemp .pytest-tmp -p no:cacheprovider
Pop-Location
docker build --file axio7-model-review/source/quant_engine_rs/Dockerfile axio7-model-review/source
```

If CMake is installed:

```powershell
cmake -S axio7-model-review/source/quant_core_cpp -B axio7-model-review/source/quant_core_cpp/build
cmake --build axio7-model-review/source/quant_core_cpp/build
ctest --test-dir axio7-model-review/source/quant_core_cpp/build --output-on-failure
```

`.github/workflows/ci.yml` is the clean-checkout implementation of the AXIO7
source gates. `.github/workflows/ritual-investing-release-evidence.yml` reruns
the production evidence gates manually against one exact retained release; it
does not make them required checks for later pushes.

## Active execution plan

The authoritative production integration and evidence log is
`axio7-model-review/reference-docs/production-quant-inference.md`. Update it
when a phase, interface, blocker, deployment, or rollback condition changes.

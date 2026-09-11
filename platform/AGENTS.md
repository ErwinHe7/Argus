# AXIO7 repository operating contract

## Product boundary

AXIO7 is an impersonal market-research system. It may scan, explain, backtest,
and monitor deterministic research conditions. It must not place orders,
personalize recommendations, or describe directional signals as risk-free
arbitrage.

## Runtime ownership

### Authorized paper-strategy extension (2026-09-07)

The owner-approved Strategy Lab plan permits deterministic dry runs and moomoo
SIMULATE-account execution through per-user local connectors. This exception is
limited to `features/strategy-lab`, `connectors/strategy`, the Rust strategy module,
and the isolated `strategy-api`; existing research services retain their boundary.
Real-money execution and options execution remain disabled. Never route this
feature through the synthetic TypeScript execution service. The implementation
and release evidence live in `docs/strategy-lab/DELIVERY.md`.

The owner's 2026-09-11 broker request also permits an experimental per-user IBKR
Client Portal paper adapter in this same boundary. It requires explicit local
opt-in, exact account binding, and the actual execution session's `isPaper: true`
proof. TWS inspection stays read-only. This development path does not establish
IBKR approval for a public commercial integration or live-money authorization.

The same broker-connection request permits an isolated read-only moomoo REST
OAuth account link in `workers/broker-link` and `features/strategy-lab/brokers`.
Broker-hosted consent supplies account-scoped tokens; encrypted server storage
never grants execution authority. Do not accept write scopes or wildcard account
grants. Linking an account does not authorize the local runner or a live order.
The existing paper mandate, local credentials and execution boundary remain.

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

## Billing permanence

- Paddle Billing is permanent production infrastructure and the canonical
  payment provider for AXIO7 memberships.
- `/pricing` must always expose Paddle-powered purchase actions for Free,
  Pro, and Annual. Do not remove, hide, disable, or replace them with a
  manual/offline payment flow.
- Free and Pro use Paddle recurring monthly collection. Annual uses Paddle
  recurring yearly collection. Paid recurring plans renew automatically.
- The browser must request a server-created Paddle transaction and open Paddle
  Checkout. Access is granted only from a verified Paddle webhook or a
  server-side reconciliation path, never from client-side checkout state.
- Do not delete or archive Paddle products, prices, client tokens,
  notification destinations, transactions, subscriptions, checkout routes,
  billing migrations, or customer self-service paths as cleanup.
- Removing or replacing Paddle requires an explicit written instruction from
  the repository owner, a replacement billing migration plan, and passing
  billing contract tests. Every pricing or billing change must preserve the
  permanent purchase actions and their automatic-payment integration.

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

# Argus — live platform and model integration

The complete customer website and quantitative-model platform now lives under
[`platform/`](platform/) on branch `codex/live-model-integration`. It includes
the Next.js website, Rust live-inference service, Python training/validation
stack, C++ research components, nine current frozen model artifacts, tests, and
production Docker tooling.

Website engineers should start with
[`PLATFORM_START_HERE.md`](PLATFORM_START_HERE.md) and
[Issue #5](https://github.com/ErwinHe7/Argus/issues/5).

## Preserved review snapshot

This repository currently contains a focused, data-free AXIO7 model and
real-time inference review snapshot. It is intended for an external engineer to
inspect and modify from the populated default `main` branch.

**English documentation starts at [`ENGLISH.md`](ENGLISH.md).** The historical
`.zh-CN.md` filenames are retained so existing review links do not break, but
their contents are now fully English.

**Before anything else, read `HANDOFF.zh-CN.md`.** The previously excluded Rust
market-data sources, Python reports, and M1–M3 numerics fixes are now integrated
into `main`. The Python ingestion/cleaning stubs remain unresolved. The handoff
retains the historical review findings; integration does not establish model
promotion or live-data readiness.

Start with `REVIEWER_START_HERE.zh-CN.md`, then use
`MODEL_SOURCE_MAP.zh-CN.md` to jump from every listed algorithm to its
implementation.

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
- English model/algorithm inventory, technical stack, evidence index, and
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

## What the review snapshot deliberately excludes

This list applies to the `axio7-model-review/` snapshot only. The `platform/`
tree is the full product and does contain the website, billing, authentication,
and other product code.

- historical or live market-data rows;
- databases, Parquet/CSV/JSONL archives, logs, reports, and outputs;
- API keys, access tokens, `.env` files, credentials, and provider sessions;
- frontend, billing, authentication, and unrelated product code;
- automatic order execution.

The snapshot's model artifacts include parameters, hashes, training lineage,
and analog training-row indices, but no raw historical or realtime market
observations. They are unpromoted candidates and must not be treated as
calibrated production models.

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

## Return enhancement & exploration agents

This work lives under `platform/`. It has two offline Python parts and one Leo
page:

- `platform/intraday_quant/src/intraday_quant/overlay_lab/` backtests an
  options overlay on a long stock position that the owner already holds, in
  multiples of 100 shares. The structures are a covered call (short call), a
  collar (long put and short call) and a protective put (long put). Each one is
  compared with buy-and-hold over the same sessions.
- `platform/intraday_quant/src/intraday_quant/foundry/` holds the exploration
  agents: four deterministic roles that move a frozen research spec up a
  stage ladder and record every step in a hash-chained ledger.
- The Leo page `#/foundry` ("Return enhancement") in
  `platform/features/research-desk/foundry/` validates and displays the
  published record. It calculates nothing.

### Who does what

Ideas come from the owner. The agents do the mechanical research. The owner
alone decides what happens next.

- **Idea.** The owner writes a `leo-foundry-spec.v1` spec. It picks a template,
  a symbol, a local input file, the development and holdout windows, and the
  grid values to sweep. `foundry schema` prints the JSON Schema. Every swept
  value is an enum, so a drafting tool, including an external LLM, can only
  choose allowed values. The foundry code makes no LLM calls (`llmCalls: 0`)
  and no network calls.
- **Research.** The Prototype Builder, Sweeper, Grower and Maintainer run the
  steps below. Python computes every number. The Leo page only formats
  validated values.
- **Execution.** Nothing here can execute. The agents place no orders, options
  execution is disabled, and `executionAuthorized` is always `false`. The
  highest stage the agents can reach is PAPER: a proposal that waits for the
  owner, or a forward shadow. Any paper mandate is set up by the owner in
  Strategy Lab, under that feature's existing paper-only contract.

| Role | id | What it does | Boundary |
| --- | --- | --- | --- |
| Prototype Builder | `prototype_builder` | Validates the owner's spec against a fixed template and freezes it. The input file, an overlay's option quote file and, for MR/MOM/GRID, the Rust engine binary are bound by sha256. Overlay trials are bound to the overlay engine version string, not a code hash. | Allow-listed values only. Cannot change a frozen spec. |
| Sweeper | `sweeper` | PROBE: runs the baseline trial on development data only. BACKTEST: runs the full predeclared grid on development data and records every trial. Survivors are decided by a Benjamini–Hochberg family per spec, a positive statistic, and a bootstrap lower bound above zero. | Never sees the holdout. |
| Grower | `grower` | Selects a survivor by a predeclared rule, checks the gates (stable neighbours, observed evidence, executable quotes for overlays, the baseline point for MR/MOM), then evaluates the holdout exactly once. A later spec on the same frozen input with an overlapping holdout window is blocked (`HOLDOUT_ALREADY_CONSUMED`), so redrafting cannot buy a second look. A failed holdout ends the spec as `REJECTED_NO_DEPLOYABLE_EDGE`. | Can issue a paper proposal (MR/MOM) or start a forward shadow (overlay). Places no orders. |
| Maintainer | `maintainer` | `observe` checks for stale data, source revisions (bars and, for overlays, option quotes, dividends and IV marks) and forward decay, and requests a pause when a check fails. Rows not yet available at `--as-of` are rejected. | Can pause but never resume. Only the owner runs `resume`. A `STOP` file in the state directory blocks `advance` and `grow`. |

Every read of the ledger verifies its hash chain and the receipt, trial and
proposal files it references. Editing or removing an interior event raises an
integrity error. The newest event has no later link, so truncating the chain
is detected only by comparing with a head hash recorded elsewhere
(`head_sha256` in an export, `headSha256` in a publication).

### The ladder: implemented and locked

| Stage | Owner | Status |
| --- | --- | --- |
| PROBE | Sweeper | Implemented, automatic |
| BACKTEST | Sweeper | Implemented, automatic |
| PAPER | Grower | Implemented. MR/MOM writes `research-report.json` and `proposal.json` (mode `paper`, steps for the owner) and waits as `AWAITING_HUMAN_RESUME`. An overlay enters `FORWARD_SHADOW`. |
| LIVE_SMALL | Owner | **Locked.** Not in the transition table; no code path reaches it. |
| LIVE_SCALED | Owner | **Locked.** Not in the transition table; no code path reaches it. |

Unlocking either live stage would need all of these, none of which exist: a
written amendment to the owner's operating contract, an approved live broker
adapter, options-execution approval, a declared capital cap, a tested kill
switch, and a paper track record reviewed by the owner.

The templates and their stage caps are:

| Template | What is swept | Highest stage |
| --- | --- | --- |
| `MR-v1` | `mr_z_abs`, `mr_rsi_max`, `stop_multiple` around the 2.0/30/2.0 baseline | PAPER |
| `MOM-v1` | `momentum_lookback`, `stop_multiple` around the 55/3.0 baseline | PAPER |
| `OVERLAY-v1` | one structure, call and put out-of-the-money percentages, target DTE (at most 64 trials) | PAPER (forward shadow) |
| `GRID-R1` | `intervals` | BACKTEST |

Specs built on synthetic evidence, and model-priced overlays, stop at
BACKTEST.

### How the overlay lab prices options

- Decisions use the session-close snapshot. A quote or IV mark is used only if
  it was observed in the 30 minutes before the close and was available by the
  next session's open. Anything else is rejected.
- `EXECUTABLE_QUOTES` sells at the bid and buys at the ask from a local quote
  file bound by sha256. Daily marks are conservative.
- `MODEL_PRICED` uses Black–Scholes values with a stated half spread. These
  results are always labelled `MODEL_PRICED_NOT_EXECUTABLE`.
- The run fails closed on any of these: a held contract with no quote, an XNYS
  calendar gap, a stale IV mark, a bar that was available before its close, an
  unverified adjustment, a split, a contract multiplier other than 100, or a
  quote file whose sha256 does not match.
- Not modelled: early exercise and early assignment, interest on cash, margin,
  borrow, taxes and financing. The artifact lists these as caveats.

No overlay result has been published. The checked-in
`platform/features/research-desk/data/foundry.json` is the pending
publication: both sections read `ARTIFACT_PENDING` and `generatedAt` is
`null`. So far the code has only been run on synthetic test inputs. This
README makes no performance claim.

### Local commands

Run these from `platform/intraday_quant/` in its Python environment. They read
only local files and never download data.

```powershell
# Overlay backtest; refuses to overwrite an existing output file
python -m intraday_quant.overlay_lab --source SOURCE.json --config CONFIG.json --output ARTIFACT.json

# Foundry
python -m intraday_quant.foundry schema
python -m intraday_quant.foundry draft --spec SPEC.json --state-dir STATE_DIR
python -m intraday_quant.foundry advance --state-dir STATE_DIR --until-blocked
python -m intraday_quant.foundry observe --state-dir STATE_DIR --spec-id SPEC_ID --input SOURCE.json --as-of 2026-10-13T21:00:00Z
python -m intraday_quant.foundry resume --state-dir STATE_DIR --spec-id SPEC_ID
python -m intraday_quant.foundry export --state-dir STATE_DIR --output EXPORT.json

# Pending publication for the Leo page (no evidence supplied)
python -m intraday_quant.foundry publish --output ../features/research-desk/data/foundry.json

# Publish derived results; needs confirmed rights
python -m intraday_quant.foundry publish --output ../features/research-desk/data/foundry.json --state-dir STATE_DIR --overlay-artifact ARTIFACT.json --rights-confirmed

# Checks
python -m pytest tests/test_overlay_lab.py tests/test_foundry.py --basetemp .pytest-tmp -p no:cacheprovider
```

From `platform/`, the page contract test is
`node --import tsx --test features/research-desk/foundry/contract.test.ts`.

### Data rights and privacy

- Inputs are files the owner supplies: unadjusted daily bars, an option quote
  CSV bound by sha256, and optional IV marks. Keep licensed quote files and
  state directories on the owner's machine and out of the repository.
- `publish` refuses to publish derived results without `--rights-confirmed`.
  The page's schema also rejects any published section unless
  `derivedPublicationRightsConfirmed` is `true`.
- The public projection strips bids, asks, fill prices, closes, share counts
  and contract identifiers. Holdings show as "Redacted holding" unless
  `--public-symbols` is passed.
- The owner's idea text stays in the local state directory. Neither `export`
  nor `publish` includes it.
- Synthetic fixtures are never published. Python `publish` refuses any overlay
  artifact or ledger built from synthetic evidence. The desk build and the page
  also reject overlays labelled `SYNTHETIC_FIXTURE_NOT_MARKET_EVIDENCE` through
  `assertPublishable`. A synthetic model-priced run keeps the
  `MODEL_PRICED_NOT_EXECUTABLE` label, and ledgers carry no evidence label, so
  for those the Python refusal is the only gate. The fixture under
  `foundry/fixtures/` exists only for the contract drift test.
- Published results are historical backtests
  (`freshness: historical_backtest_not_live`), not live prices or
  recommendations. Evidence dated more than five minutes after `generatedAt`
  is rejected.

## Product and safety boundary

AXIO7 is an impersonal market-research system. It may scan, explain, backtest,
and monitor deterministic research conditions. It must not place orders,
personalize recommendations, or call uncalibrated directional signals
risk-free arbitrage. Missing, stale, unentitled, incomplete, or non-causal data
must fail closed.

The research agents and the overlay lab are paper-only. They place no orders,
options execution stays disabled, and both live stages are locked. Any paper
trading runs only through Strategy Lab's existing simulated-account boundary,
and only after the owner sets it up.

The original worktree base commit was
`bfc95815be9a212bbe75663df8af548bfb92f917`. The handoff contains a selected
snapshot from a dirty worktree, so this Argus commit is the authoritative
content hash for the delivered review files.

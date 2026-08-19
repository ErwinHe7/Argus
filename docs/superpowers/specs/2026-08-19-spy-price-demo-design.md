# SPY Five-Minute Price Demo Design

**Status:** Approved in conversation on 2026-08-19  
**Implementation:** New Vite + React + TypeScript application with Apache ECharts  
**Quantitative runtime:** Offline Python artifact generation only

## Summary

Build a small historical SPY forecasting demo from the downloaded Databento one-minute OHLCV data. Python owns data quality, feature construction, labels, model fitting, validation, predictions, scenario prices, intervals, outcomes, and artifact serialization. The browser only validates and visualizes immutable JSON artifacts.

The product is a graph-first historical replay. It is not a live quote, recommendation, trading system, or profitability claim. The approved visual reference is [`axio7-model-review/apps/spy-price-demo/docs/reference/spy-graph-first.html`](../../../axio7-model-review/apps/spy-price-demo/docs/reference/spy-graph-first.html).

## Goals

- Demonstrate whether the available SPY minute history is sufficient for a small five-minute forecasting example.
- Train simple, inspectable baseline models and report untouched out-of-sample results.
- Replay eligible test-session predictions without exposing future bars until the user reveals the outcome.
- Keep the interface almost entirely inside one ECharts graph.
- Preserve source, cutoff, coverage, quality, feature version, model version, and caveats with every forecast.
- Make local setup and execution reproducible from a Python virtual environment and terminal commands.

## Non-goals

- Live or delayed-live inference.
- Order entry, portfolio construction, PnL, Sharpe ratio, or trading recommendations.
- Options, Greeks, GEX, cross-asset features, deep learning, or hyperparameter searches.
- A FastAPI service, database, authentication, deployment, or background retraining.
- Browser-side probability, return, interval, or price calculations.

## Repository boundaries

The implementation will add three instruction files before feature work begins:

- Repository-root `AGENTS.md`: repository-wide change discipline, contract rules, and required checks.
- `/axio7-model-review/apps/spy-price-demo/AGENTS.md`: frontend boundaries, graph-first design rules, feature-first organization, and animation prohibition.
- `/axio7-model-review/source/intraday_quant/AGENTS.md`: causal data, validation, artifact, and Python testing rules.

Agents must read the nearest applicable `AGENTS.md` before editing within its scope. No `AGENTS.md` currently exists in this checkout, so these files are new implementation prerequisites.

The production code will be organized as follows:

```text
axio7-model-review/
├── contracts/spy-price-demo/v1/
│   ├── manifest.schema.json
│   ├── session.schema.json
│   ├── summary.schema.json
│   └── model-card.schema.json
├── apps/spy-price-demo/
│   ├── AGENTS.md
│   ├── docs/reference/spy-graph-first.html
│   ├── public/generated/                 # ignored
│   ├── public/fixtures/spy-demo/         # committed deterministic fixture
│   └── src/
│       ├── app/
│       ├── features/replay/
│       │   ├── ReplayPage/
│       │   ├── ReplayGraph/
│       │   ├── ReplayControls/
│       │   ├── OutcomeReveal/
│       │   └── artifact/
│       ├── features/theme/ThemeToggle/
│       └── shared/
└── source/intraday_quant/
    ├── AGENTS.md
    ├── src/intraday_quant/demo/
    │   ├── contracts.py
    │   ├── dataset.py
    │   ├── features.py
    │   ├── modeling.py
    │   ├── artifacts.py
    │   └── cli.py
    └── tests/demo/
```

Each React component directory owns its component, stylesheet, types, pure helpers, and tests when those files are specific to that component. Cross-feature utilities are allowed only when they have more than one real consumer.

## Source data

The current normalized input is:

```text
axio7-model-review/source/intraday_quant/data/normalized/
databento_SPY_ohlcv-1m_2024-07-18_2026-07-25_rth.parquet
```

Observed coverage is 196,539 rows from 2024-07-18 13:30 UTC through 2026-07-24 19:59 UTC across 506 sessions. Five hundred sessions contain 390 rows. The raw and normalized data remain ignored and are regenerated with `scripts/download_databento_spy.py`; neither is committed.

The artifact build must:

1. Treat source timestamps as UTC and map them to the XNYS calendar.
2. Enforce official XNYS opens and closes, including early closes.
3. Remove prints after an official early close. Known affected dates include 2024-11-29, 2024-12-24, 2025-07-03, 2025-11-28, and 2025-12-24.
4. Reindex each session to its official one-minute grid.
5. Permit a causal forward fill of at most two consecutive minutes, flag every filled value, and never fill from future observations.
6. Exclude an example when its 30-minute feature window or five-minute outcome window touches an unresolved gap.
7. Record row counts, session counts, exclusions, fills, source hash, calendar version, and effective coverage in the manifest.

The known missing minute on 2024-10-21 is handled by this policy rather than silently treated as a complete window.

## Target, features, and models

For every eligible minute `t`, the single horizon is five minutes:

- Direction target: `1` when `close[t+5] > close[t]`, otherwise `0`.
- Return target: `close[t+5] / close[t] - 1`.
- The latest eligible cutoff is five minutes before the official session close.

Features are causal and limited to:

- Returns over 1, 3, 5, 15, and 30 minutes.
- Rolling volatility, true-range/ATR-style measures, bar range, and close-location value.
- Distance from the official session open and causal session VWAP.
- Volume z-score and same-clock-minute relative volume using prior sessions only.
- Minute-of-session encodings.

The direction model is logistic regression. The return model is ridge regression. Scaling is fit on training data only. Baselines are majority direction, zero return, and five-minute momentum. No feature selection or parameter choice may use the test split.

The headline probability is the raw experimental logistic probability and is labeled `RAW_EXPERIMENTAL_PROBABILITY`. Optional Platt calibration may be evaluated using validation data, but it remains separately labeled `EXPERIMENTAL_VALIDATION_CALIBRATED` and is not substituted into the headline forecast.

Python calculates the scenario price from the ridge return prediction. The exploratory interval uses fixed lower and upper quantiles of validation residuals, transformed into prices by Python and labeled `EXPLORATORY_VALIDATION_RESIDUAL_INTERVAL`. It is not described as a calibrated confidence interval.

## Chronological validation

Sessions are first assigned chronologically using the 70/15/15 boundaries over all 506 observed sessions:

- Training boundary: 354 sessions, 2024-07-18 through 2025-12-12.
- Validation boundary: 76 sessions, 2025-12-15 through 2026-04-06.
- Test boundary: 76 sessions, 2026-04-07 through 2026-07-24.

A one-session embargo removes the first downstream session at each boundary. The effective validation split is therefore 75 sessions from 2025-12-16 through 2026-04-06, and the effective untouched test split is 75 sessions from 2026-04-08 through 2026-07-24. The manifest records exact dates and counts after quality exclusions.

Validation data locks feature choices, model parameters, residual interval quantiles, and any calibration experiment. The browser exposes predictions only from the effective untouched test split.

Reported metrics are:

- Direction: ROC AUC, Brier score, log loss, calibration error, accuracy, and deltas versus the majority baseline.
- Return: MAE, RMSE, and deltas versus the zero-return and momentum baselines.
- Coverage: eligible examples, excluded examples, session counts, gap flags, and cutoff range.

No trading-return or profitability metric is produced.

## Artifact contract

The CLI writes a versioned static bundle:

```text
public/generated/
├── manifest.json
├── summary.json
├── model-card.json
└── sessions/
    ├── index.json
    └── YYYY-MM-DD.json
```

`contracts.py` contains the canonical Pydantic models and emits the checked-in JSON Schemas under `contracts/spy-price-demo/v1/`. Python validates every output before writing it. The frontend validates every fetched document with Ajv. TypeScript artifact types are generated from the same schemas and are not handwritten.

Each session artifact contains source, source hash, calendar version, coverage, feature version, model versions, artifact hash, and concise caveat codes. Each replay row includes:

- Prediction timestamp, observation cutoff, and availability timestamp.
- OHLCV bar values visible at the cutoff.
- Raw direction probability and its status label.
- Expected five-minute return in basis points.
- Scenario price and exploratory interval bounds, already computed by Python.
- Realized five-minute timestamp, close, and return, stored for reveal behavior.
- Quality flags and references to the session-level provenance used by the graph tooltip.

The generated bundle is ignored. A small deterministic fixture with an explicit `UI_FIXTURE` status is committed for tests and `npm run dev:fixture`. The normal `npm run dev` path expects generated artifacts and never silently falls back to the fixture.

## Frontend experience

The application is a single graph-first page matching the saved reference:

- A compact header contains `SPY`, session date, `1M → 5M`, OOS status, and the light/dark toggle.
- One ECharts surface contains candlesticks, volume, cutoff marker, five-minute scenario path, residual interval whisker, and revealed future bars.
- All forecast, provenance, quality, and outcome details appear inside the graph tooltip or popover. There are no metric cards, evidence panels, explanatory paragraphs, or decorative dashboard sections.
- The only controls below the graph are the replay cutoff slider and `Reveal +5m` action.
- Future bars and realized outcomes remain hidden until reveal.
- Cutoff and session are reflected in URL query parameters. Theme is persisted locally; the initial fallback is light.

The interface uses only black and white for backgrounds, text, controls, borders, axes, grids, and tooltips. Green and red are reserved for up/down candlesticks, volume direction, and forecast direction inside the graph. Direction is also encoded by candle geometry, labels, and line style so color is not the only signal.

Every graph update snaps immediately. ECharts must set `animation: false`, `animationDuration: 0`, and `animationDurationUpdate: 0`. CSS transitions and animations are prohibited for replay, reveal, resizing, tooltip state, and theme changes.

The graph owns its ECharts lifecycle through a focused hook that initializes once, resizes with `ResizeObserver`, updates from pure option builders, and disposes on unmount. Option builders format artifact fields but perform no quantitative prediction or outcome calculation.

Keyboard-accessible controls, visible focus behavior, an ECharts ARIA description, and a visually hidden live summary expose the selected cutoff and tooltip values without adding visible copy.

## Loading and failure behavior

The application loads `manifest.json`, validates its contract version and hashes, then loads the session index and selected session chunk. Session requests use `AbortController`; the most recently validated session may remain in an in-memory cache.

The application fails closed when the manifest, schema version, artifact hash, requested session, required field, or quality status is missing or invalid. The failure state is a minimal monochrome screen naming the invalid artifact and remediation command. It does not render partial forecasts, use fixture data, or substitute another provider.

No Databento key or other secret appears in the browser bundle, fixture, logs, artifacts, or committed files.

## Saved visual reference

The standalone reference at `apps/spy-price-demo/docs/reference/spy-graph-first.html` is committed with the specification. Production code does not import or execute it. It is the visual acceptance reference for hierarchy, monochrome treatment, tooltip density, theme toggle, responsive behavior, and snap-only graph updates.

Implementation may differ only where required for truthful generated data, accessibility, validation errors, or maintainable React/ECharts composition.

## Local workflow

From `axio7-model-review`:

```bash
python3 -m venv .venv-spy-demo
source .venv-spy-demo/bin/activate
python -m pip install -e "source/intraday_quant[dev]"
python -m intraday_quant.demo.cli build \
  --input source/intraday_quant/data/normalized/databento_SPY_ohlcv-1m_2024-07-18_2026-07-25_rth.parquet \
  --output apps/spy-price-demo/public/generated

cd apps/spy-price-demo
npm install
npm run artifacts:types
npm run dev
```

`npm run dev:fixture` runs only the committed, visibly labeled fixture mode.

## Verification

Python tests cover calendar normalization, early closes, gap handling, causal fills, feature causality, label alignment, embargoed splits, train-only scaling, baseline metrics, artifact determinism, hashes, and schema serialization.

Vitest and React Testing Library cover Ajv rejection, generated types, URL state, replay state, reveal gating, theme persistence, tooltip formatting, ECharts lifecycle, and the invariant that every chart option disables animation.

Playwright smoke coverage checks light and dark modes, cutoff snapping, reveal snapping, tooltip contents, keyboard controls, no horizontal overflow, and responsive layouts at 360, 736, and 1024 pixels.

## Acceptance criteria

1. Root and scoped `AGENTS.md` files exist and define the approved boundaries.
2. The Python CLI deterministically generates a validated static artifact bundle from the downloaded Parquet input.
3. All prediction, scenario, interval, and realized-return calculations occur in Python.
4. The normal app never silently falls back to synthetic or fixture data.
5. The page matches the saved graph-first reference without cards or explanatory panels.
6. All market, forecast, provenance, quality, and outcome data is available in the graph tooltip.
7. Light and dark modes remain strictly monochrome outside trend marks.
8. Every chart and theme state change snaps with no interpolation or transition.
9. Only untouched effective test sessions are replayable.
10. Invalid or incomplete artifacts fail closed.
11. No secret or ignored market-data file is committed.
12. Python, frontend unit, frontend build, and browser smoke checks pass before completion is claimed.

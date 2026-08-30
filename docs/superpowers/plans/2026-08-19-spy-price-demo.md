# SPY Five-Minute Price Demo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local historical SPY five-minute forecast replay from the downloaded Databento one-minute data, with Python-generated immutable artifacts and a graph-first Vite/React/ECharts interface.

**Architecture:** A new offline Python `intraday_quant.demo` package normalizes the SPY Parquet input, builds causal features and targets, trains fixed logistic/ridge baselines, evaluates an embargoed chronological split, and writes versioned JSON artifacts. A separate Vite React application validates those artifacts with Ajv and renders them without performing quantitative calculations. The checked-in graph-first mock-up is a visual reference only.

**Tech Stack:** Python 3.11+, pandas, NumPy, scikit-learn, Pydantic 2, exchange-calendars, pytest; Node 22+, React 19.2.8, TypeScript 7.0.2, Vite 8.2.1, Apache ECharts 6.1.0, Ajv 8.20.0 with ajv-formats 3.0.1, Vitest 4.1.11, React Testing Library 16.3.2, Playwright 1.62.1.

**Spec:** `docs/superpowers/specs/2026-08-19-spy-price-demo-design.md`

## Global Constraints

- Read the repository-root and nearest scoped `AGENTS.md` before editing a file; Task 1 creates the instruction files because none existed when the spec was approved.
- Preserve the existing untracked `axio7-model-review/source/intraday_quant/scripts/download_databento_spy.py`; Task 3 intentionally brings it into version control without rewriting its behavior.
- Python owns data quality, targets, probability, expected return, scenario price, interval, outcome, metrics, and artifact hashes.
- TypeScript validates, selects, formats, and visualizes artifact fields; it must not calculate a probability, return, interval, scenario price, or realized result.
- The normal application fails closed and never falls back to fixture or alternate-provider data.
- The committed fixture is available only through `npm run dev:fixture` and displays `UI_FIXTURE`.
- Outside the graph's up/down marks, the UI uses only black and white.
- ECharts and CSS animation are disabled for initial render and every update; all state changes snap.
- Generated market artifacts, model binaries, and raw/normalized market data remain ignored.
- No Databento key or other secret may enter client code, artifacts, fixtures, logs, or commits.
- Do not add FastAPI, authentication, a database, live data, trading metrics, or additional forecast horizons.
- Use test-first red/green cycles and commit after every task.

---

### Task 1: Establish agent boundaries, the Python virtual environment, and a bootable Vite test harness

**Files:**
- Create: `AGENTS.md`
- Create: `axio7-model-review/apps/spy-price-demo/AGENTS.md`
- Create: `axio7-model-review/source/intraday_quant/AGENTS.md`
- Modify: `.gitignore`
- Create: `axio7-model-review/apps/spy-price-demo/package.json`
- Create: `axio7-model-review/apps/spy-price-demo/index.html`
- Create: `axio7-model-review/apps/spy-price-demo/tsconfig.json`
- Create: `axio7-model-review/apps/spy-price-demo/vite.config.ts`
- Create: `axio7-model-review/apps/spy-price-demo/.env.development`
- Create: `axio7-model-review/apps/spy-price-demo/.env.production`
- Create: `axio7-model-review/apps/spy-price-demo/.env.test`
- Create: `axio7-model-review/apps/spy-price-demo/.env.fixture`
- Create: `axio7-model-review/apps/spy-price-demo/src/test/setup.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/main.tsx`
- Create: `axio7-model-review/apps/spy-price-demo/src/app/App.tsx`
- Create: `axio7-model-review/apps/spy-price-demo/src/app/App.test.tsx`
- Create: `axio7-model-review/apps/spy-price-demo/src/app/global.css`

**Interfaces:**
- Consumes: the approved spec and saved `docs/reference/spy-graph-first.html`.
- Produces: a strict TypeScript/Vitest/Vite workspace; `App(): JSX.Element`; environment variable `VITE_SPY_ARTIFACT_BASE` with values `/generated` or `/fixtures/spy-demo`.

- [ ] **Step 1: Write the scoped development instructions**

Create the three `AGENTS.md` files with explicit scope. The root file must require preserving dirty work, reading `PROJECT_CONTRACT.md`, keeping quantitative math out of TypeScript, using feature-owned folders, and running scoped checks. The frontend file must require graph-first composition, black/white UI, up/down-only color, Ajv validation, no silent fixture fallback, and the following immutable chart settings:

```text
animation: false
animationDuration: 0
animationDurationUpdate: 0
```

The Python file must require official XNYS sessions, causal windows, train-only fitting, embargoed chronological splits, untouched test reporting, Pydantic validation, deterministic hashing, and tests for causality and serialization.

- [ ] **Step 2: Add generated-output ignore rules**

Append these exact rules to `.gitignore`:

```gitignore
axio7-model-review/.venv-spy-demo/
axio7-model-review/apps/spy-price-demo/node_modules/
axio7-model-review/apps/spy-price-demo/dist/
axio7-model-review/apps/spy-price-demo/playwright-report/
axio7-model-review/apps/spy-price-demo/test-results/
axio7-model-review/apps/spy-price-demo/public/generated/
axio7-model-review/apps/spy-price-demo/src/features/replay/artifact/generated/
```

- [ ] **Step 3: Create and populate the dedicated Python virtual environment**

Working directory: `axio7-model-review`

Run:

```bash
python3 -m venv .venv-spy-demo
source .venv-spy-demo/bin/activate
python -m pip install -e "source/intraday_quant[dev]"
python -c "import intraday_quant, pandas, pyarrow, sklearn, pydantic, exchange_calendars; print('spy-demo-python-ready')"
```

Expected: the final command prints `spy-demo-python-ready`. Use this activated environment for every Python command in Tasks 2–6 and 11.

- [ ] **Step 4: Create the frontend package and tool configuration**

Use this package manifest:

```json
{
  "name": "spy-price-demo",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "engines": { "node": ">=22" },
  "scripts": {
    "dev": "vite --mode development",
    "dev:fixture": "vite --mode fixture",
    "artifacts:types": "node scripts/generate-artifact-types.mjs",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest",
    "build": "npm run artifacts:types && npm run typecheck && vite build",
    "test:e2e": "playwright test"
  },
  "dependencies": {
    "ajv": "8.20.0",
    "ajv-formats": "3.0.1",
    "echarts": "6.1.0",
    "react": "19.2.8",
    "react-dom": "19.2.8"
  },
  "devDependencies": {
    "@playwright/test": "1.62.1",
    "@testing-library/jest-dom": "7.0.1",
    "@testing-library/react": "16.3.2",
    "@testing-library/user-event": "14.6.5",
    "@types/react": "19.2.18",
    "@types/react-dom": "19.2.4",
    "@vitejs/plugin-react": "6.0.5",
    "jsdom": "30.0.1",
    "json-schema-to-typescript": "15.0.4",
    "typescript": "7.0.2",
    "vite": "8.2.1",
    "vitest": "4.1.11"
  }
}
```

Set `VITE_SPY_ARTIFACT_BASE=/generated` in `.env.development`, `.env.production`, and `.env.test`; set `VITE_SPY_ARTIFACT_BASE=/fixtures/spy-demo` only in `.env.fixture`. Configure `tsconfig.json` with `strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `resolveJsonModule`, `moduleResolution: "Bundler"`, `jsx: "react-jsx"`, and test types `vitest/globals` plus `@testing-library/jest-dom`. Put `import "@testing-library/jest-dom/vitest";` in `src/test/setup.ts`. Configure Vitest in `vite.config.ts`:

```ts
import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    setupFiles: "./src/test/setup.ts",
    globals: true,
    css: true,
  },
});
```

- [ ] **Step 5: Install dependencies**

Working directory: `axio7-model-review/apps/spy-price-demo`

Run: `npm install`

Expected: `package-lock.json` is created and npm exits successfully.

- [ ] **Step 6: Write the failing app-shell test**

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { App } from "./App";

describe("App", () => {
  it("exposes a named SPY demo shell", () => {
    render(<App />);
    expect(screen.getByRole("main", { name: "SPY five-minute replay" })).toBeInTheDocument();
  });
});
```

- [ ] **Step 7: Run the test and verify the red state**

Working directory: `axio7-model-review/apps/spy-price-demo`

Run: `npm test -- src/app/App.test.tsx`

Expected: FAIL because `App.tsx` does not yet export `App`.

- [ ] **Step 8: Add the minimal app shell and entry point**

```tsx
// src/app/App.tsx
export function App() {
  return <main aria-label="SPY five-minute replay">SPY</main>;
}
```

```tsx
// src/main.tsx
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./app/App";
import "./app/global.css";

const root = document.getElementById("root");
if (!root) throw new Error("Missing #root mount point");
createRoot(root).render(<StrictMode><App /></StrictMode>);
```

Set `body { margin: 0; }`, `box-sizing: border-box`, and system sans-serif typography in `global.css`; do not add decorative app styling yet.

- [ ] **Step 9: Run the scoped checks**

Working directory: `axio7-model-review/apps/spy-price-demo`

Run: `npm test -- src/app/App.test.tsx`

Expected: PASS.

Run: `npm run typecheck`

Expected: PASS.

- [ ] **Step 10: Commit the harness**

```bash
git add AGENTS.md .gitignore axio7-model-review/apps/spy-price-demo axio7-model-review/source/intraday_quant/AGENTS.md
git commit -m "chore: scaffold SPY demo workspace"
```

### Task 2: Define the canonical Python artifact contracts and JSON Schemas

**Files:**
- Create: `axio7-model-review/source/intraday_quant/src/intraday_quant/demo/__init__.py`
- Create: `axio7-model-review/source/intraday_quant/src/intraday_quant/demo/contracts.py`
- Create: `axio7-model-review/source/intraday_quant/tests/demo/__init__.py`
- Create: `axio7-model-review/source/intraday_quant/tests/demo/test_contracts.py`
- Create: `axio7-model-review/contracts/spy-price-demo/v1/manifest.schema.json`
- Create: `axio7-model-review/contracts/spy-price-demo/v1/session-index.schema.json`
- Create: `axio7-model-review/contracts/spy-price-demo/v1/session.schema.json`
- Create: `axio7-model-review/contracts/spy-price-demo/v1/summary.schema.json`
- Create: `axio7-model-review/contracts/spy-price-demo/v1/model-card.schema.json`

**Interfaces:**
- Consumes: Pydantic 2 already declared in `source/intraday_quant/pyproject.toml`.
- Produces: `Manifest`, `SessionIndexArtifact`, `SessionArtifact`, `SummaryArtifact`, `ModelCard`, `ChartBar`, `ReplayRow`; `write_json_schemas(output_dir: Path) -> tuple[Path, ...]`; contract version `1.0.0`.

- [ ] **Step 1: Write failing contract tests**

```python
from datetime import datetime, timezone
from pathlib import Path

import pytest
from pydantic import ValidationError

from intraday_quant.demo.contracts import Manifest, write_json_schemas


def test_manifest_rejects_unknown_contract_version(manifest_payload: dict) -> None:
    manifest_payload["contract_version"] = "2.0.0"
    with pytest.raises(ValidationError):
        Manifest.model_validate(manifest_payload)


def test_schema_export_is_complete(tmp_path: Path) -> None:
    paths = write_json_schemas(tmp_path)
    assert {path.name for path in paths} == {
        "manifest.schema.json",
        "session-index.schema.json",
        "session.schema.json",
        "summary.schema.json",
        "model-card.schema.json",
    }
    assert all(path.read_text(encoding="utf-8").endswith("\n") for path in paths)
```

Add a `manifest_payload` fixture containing UTC datetimes, dataset hash, artifact hash, effective split dates/counts, quality totals, model versions, session index path, and `probability_status: "RAW_EXPERIMENTAL_PROBABILITY"`.

Use this concrete fixture shape:

```python
@pytest.fixture
def manifest_payload() -> dict[str, object]:
    return {
        "contract_version": "1.0.0",
        "status": "HISTORICAL_OOS",
        "symbol": "SPY",
        "generated_at": datetime(2026, 8, 19, 12, tzinfo=timezone.utc),
        "dataset_sha256": "a" * 64,
        "artifact_sha256": "b" * 64,
        "source_cutoff": datetime(2026, 7, 24, 19, 59, tzinfo=timezone.utc),
        "availability_cutoff": datetime(2026, 7, 24, 20, 0, tzinfo=timezone.utc),
        "feature_version": "spy-demo-features-v1",
        "direction_model_version": "logistic-v1",
        "return_model_version": "ridge-v1",
        "split": {
            "train_start": "2024-07-18", "train_end": "2025-12-12", "train_sessions": 354,
            "validation_start": "2025-12-16", "validation_end": "2026-04-06", "validation_sessions": 75,
            "test_start": "2026-04-08", "test_end": "2026-07-24", "test_sessions": 75,
            "embargo_sessions": ["2025-12-15", "2026-04-07"],
        },
        "quality": {
            "source_rows": 196539, "normalized_rows": 195000, "eligible_examples": 180000,
            "excluded_examples": 15000, "causal_fill_rows": 2, "unresolved_gap_rows": 1,
        },
        "session_index": {
            "path": "sessions/index.json",
            "sha256": "c" * 64,
        },
        "probability_status": "RAW_EXPERIMENTAL_PROBABILITY",
        "interval_status": "EXPLORATORY_VALIDATION_RESIDUAL_INTERVAL",
        "caveat_codes": ["HISTORICAL_ONLY", "NOT_A_TRADING_SIGNAL"],
    }
```

- [ ] **Step 2: Verify the contract tests fail**

Working directory: `axio7-model-review/source/intraday_quant`

Run: `python -m pytest tests/demo/test_contracts.py -q`

Expected: FAIL with `ModuleNotFoundError: intraday_quant.demo`.

- [ ] **Step 3: Implement strict Pydantic models**

Use `ConfigDict(extra="forbid", frozen=True)` on every model. Define these public shapes:

```python
from datetime import date, datetime
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

ContractVersion = Literal["1.0.0"]
ProbabilityStatus = Literal["RAW_EXPERIMENTAL_PROBABILITY"]
IntervalStatus = Literal["EXPLORATORY_VALIDATION_RESIDUAL_INTERVAL"]
BundleStatus = Literal["HISTORICAL_OOS", "UI_FIXTURE"]
Direction = Literal["UP", "DOWN", "FLAT"]


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class Forecast(StrictModel):
    probability_up: float = Field(ge=0.0, le=1.0)
    probability_status: ProbabilityStatus
    expected_return_bps: float
    scenario_price: float = Field(gt=0.0)
    interval_low: float = Field(gt=0.0)
    interval_high: float = Field(gt=0.0)
    interval_status: IntervalStatus
    direction: Direction


class Outcome(StrictModel):
    timestamp: datetime
    close: float = Field(gt=0.0)
    return_bps: float


class ChartBar(StrictModel):
    timestamp: datetime
    available_at: datetime
    open: float | None
    high: float | None
    low: float | None
    close: float | None
    volume: int | None
    direction: Direction
    quality_flags: tuple[str, ...]


class ReplayRow(StrictModel):
    bar_index: int = Field(ge=0)
    timestamp: datetime
    available_at: datetime
    open: float = Field(gt=0.0)
    high: float = Field(gt=0.0)
    low: float = Field(gt=0.0)
    close: float = Field(gt=0.0)
    volume: int = Field(ge=0)
    forecast: Forecast
    outcome: Outcome
    quality_flags: tuple[str, ...]
```

Define the remaining models with these exact fields:

```python
class SessionProvenance(StrictModel):
    source: str
    dataset: str
    dataset_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    artifact_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    source_cutoff: datetime
    availability_cutoff: datetime
    calendar_version: str
    feature_version: str
    direction_model_version: str
    return_model_version: str
    coverage: str
    caveat_codes: tuple[str, ...]


class SessionArtifact(StrictModel):
    contract_version: ContractVersion
    status: BundleStatus
    symbol: Literal["SPY"]
    session_date: date
    provenance: SessionProvenance
    bars: tuple[ChartBar, ...]
    rows: tuple[ReplayRow, ...]


class SessionIndexEntry(StrictModel):
    date: date
    path: str = Field(pattern=r"^sessions/\d{4}-\d{2}-\d{2}\.json$")
    sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    rows: int = Field(gt=0)


class ArtifactReference(StrictModel):
    path: Literal["sessions/index.json"]
    sha256: str = Field(pattern=r"^[0-9a-f]{64}$")


class SessionIndexArtifact(StrictModel):
    contract_version: ContractVersion
    artifact_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    sessions: tuple[SessionIndexEntry, ...]


class SplitSummary(StrictModel):
    train_start: date
    train_end: date
    train_sessions: int = Field(gt=0)
    validation_start: date
    validation_end: date
    validation_sessions: int = Field(gt=0)
    test_start: date
    test_end: date
    test_sessions: int = Field(gt=0)
    embargo_sessions: tuple[date, date]


class QualitySummary(StrictModel):
    source_rows: int = Field(ge=0)
    normalized_rows: int = Field(ge=0)
    eligible_examples: int = Field(ge=0)
    excluded_examples: int = Field(ge=0)
    causal_fill_rows: int = Field(ge=0)
    unresolved_gap_rows: int = Field(ge=0)


class Manifest(StrictModel):
    contract_version: ContractVersion
    status: BundleStatus
    symbol: Literal["SPY"]
    generated_at: datetime
    dataset_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    artifact_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    source_cutoff: datetime
    availability_cutoff: datetime
    feature_version: str
    direction_model_version: str
    return_model_version: str
    split: SplitSummary
    quality: QualitySummary
    session_index: ArtifactReference
    probability_status: ProbabilityStatus
    interval_status: IntervalStatus
    caveat_codes: tuple[str, ...]


class MetricValue(StrictModel):
    value: float
    baseline: float | None
    delta: float | None


class ReturnMetricValue(StrictModel):
    value: float
    zero_return_baseline: float
    zero_return_delta: float
    momentum_baseline: float
    momentum_delta: float


class DirectionMetrics(StrictModel):
    roc_auc: MetricValue
    brier_score: MetricValue
    log_loss: MetricValue
    calibration_error: MetricValue
    accuracy: MetricValue


class ReturnMetrics(StrictModel):
    mae: ReturnMetricValue
    rmse: ReturnMetricValue


class SummaryArtifact(StrictModel):
    contract_version: ContractVersion
    artifact_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    direction_metrics: DirectionMetrics
    return_metrics: ReturnMetrics
    coverage: QualitySummary


class ModelCard(StrictModel):
    contract_version: ContractVersion
    artifact_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    horizon_minutes: Literal[5]
    feature_columns: tuple[str, ...]
    direction_model: dict[str, str | float | int]
    return_model: dict[str, str | float | int]
    probability_status: ProbabilityStatus
    interval_status: IntervalStatus
    caveat_codes: tuple[str, ...]
```

Validate `interval_low <= scenario_price <= interval_high`, OHLC consistency for complete chart bars and every replay row, sorted chart/replay rows, and sorted session-index entries with Pydantic model validators. A `ChartBar` may use null OHLCV only when its quality flags include `UNRESOLVED_GAP`. Require each session-index path date to match its `date`, every replay row's `bar_index` to point to the matching complete chart bar, and its outcome timestamp to be exactly five chart minutes later. This separate complete `bars` sequence lets the graph reveal the final five candles even though those end-of-session bars are not themselves eligible forecast cutoffs.

- [ ] **Step 4: Implement deterministic schema export**

```python
import json

SCHEMA_MODELS = {
    "manifest.schema.json": Manifest,
    "session-index.schema.json": SessionIndexArtifact,
    "session.schema.json": SessionArtifact,
    "summary.schema.json": SummaryArtifact,
    "model-card.schema.json": ModelCard,
}


def write_json_schemas(output_dir: Path) -> tuple[Path, ...]:
    output_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for filename, model in SCHEMA_MODELS.items():
        path = output_dir / filename
        body = json.dumps(model.model_json_schema(), indent=2, sort_keys=True) + "\n"
        path.write_text(body, encoding="utf-8")
        written.append(path)
    return tuple(written)
```

- [ ] **Step 5: Run tests and export checked-in schemas**

Working directory: `axio7-model-review/source/intraday_quant`

Run: `python -m pytest tests/demo/test_contracts.py -q`

Expected: PASS.

Run:

```bash
python -c "from pathlib import Path; from intraday_quant.demo.contracts import write_json_schemas; write_json_schemas(Path('../../contracts/spy-price-demo/v1'))"
```

Expected: five sorted JSON Schema files are written. The extra session-index schema makes the separately fetched `sessions/index.json` document independently Ajv-validatable rather than relying on a handwritten TypeScript shape.

- [ ] **Step 6: Commit the contracts**

```bash
git add axio7-model-review/contracts/spy-price-demo/v1 axio7-model-review/source/intraday_quant/src/intraday_quant/demo axio7-model-review/source/intraday_quant/tests/demo
git commit -m "feat: define SPY demo artifact contracts"
```

### Task 3: Normalize the Databento input against a strict XNYS calendar

**Files:**
- Create: `axio7-model-review/source/intraday_quant/src/intraday_quant/demo/dataset.py`
- Create: `axio7-model-review/source/intraday_quant/tests/demo/conftest.py`
- Create: `axio7-model-review/source/intraday_quant/tests/demo/test_dataset.py`
- Add without behavioral rewrite: `axio7-model-review/source/intraday_quant/scripts/download_databento_spy.py`

**Interfaces:**
- Consumes: Parquet columns `timestamp,symbol,open,high,low,close,volume,source,data_quality`; `exchange_calendars.get_calendar("XNYS")`.
- Produces: `DatasetQualityReport`; `load_and_normalize_spy(path: Path, max_fill_minutes: int = 2) -> tuple[pd.DataFrame, DatasetQualityReport]`. Output timestamps are UTC and rows include `session_date`, `minute_of_session`, `is_causal_fill`, `is_unresolved_gap`, and `official_close`.

- [ ] **Step 1: Write failing calendar and gap tests**

```python
def bars_for(session: str, *, start: str = "09:30", periods: int = 390) -> pd.DataFrame:
    timestamps = pd.date_range(f"{session} {start}", periods=periods, freq="1min", tz="America/New_York")
    close = 700.0 + np.sin(np.arange(periods) / 7.0)
    return pd.DataFrame({
        "timestamp": timestamps.tz_convert("UTC"),
        "symbol": "SPY",
        "open": close,
        "high": close + 0.05,
        "low": close - 0.05,
        "close": close,
        "volume": np.arange(periods) + 100,
        "source": "TEST",
        "data_quality": "vendor_aggregate",
    })


def test_early_close_discards_post_close_prints() -> None:
    frame = bars_for("2025-07-03", periods=211)
    normalized, report = normalize_spy_frame(frame)
    assert normalized.loc[~normalized.is_unresolved_gap, "timestamp"].max().tz_convert("America/New_York").strftime("%H:%M") == "12:59"
    assert report.post_close_rows_removed == 1


def test_two_minute_gap_is_causally_filled() -> None:
    frame = bars_for("2026-01-05").drop(index=[1, 2])
    normalized, report = normalize_spy_frame(frame, max_fill_minutes=2)
    filled = normalized.loc[normalized.is_causal_fill]
    assert filled.close.tolist() == [frame.iloc[0].close, frame.iloc[0].close]
    assert filled.volume.tolist() == [0, 0]
    assert report.causal_fill_rows == 2


def test_three_minute_gap_remains_unresolved() -> None:
    frame = bars_for("2026-01-05").drop(index=[1, 2, 3])
    normalized, report = normalize_spy_frame(frame, max_fill_minutes=2)
    assert normalized.is_unresolved_gap.sum() == 3
    assert report.unresolved_gap_rows == 3
```

Place `bars_for` in `tests/demo/conftest.py`. Add `sample_parquet`, built from 40 consecutive XNYS sessions with deterministic sinusoidal prices and alternating drift. Forty sessions leave training examples after the shifted 20-session relative-volume feature becomes available and provide both direction classes without network or vendor data.

- [ ] **Step 2: Run the tests and verify failure**

Working directory: `axio7-model-review/source/intraday_quant`

Run: `python -m pytest tests/demo/test_dataset.py -q`

Expected: FAIL because `intraday_quant.demo.dataset` is missing.

- [ ] **Step 3: Implement strict schedule and source validation**

```python
REQUIRED_COLUMNS = {
    "timestamp", "symbol", "open", "high", "low", "close", "volume", "source", "data_quality"
}


def strict_xnys_schedule(start: date, end: date) -> pd.DataFrame:
    import exchange_calendars as xcals

    calendar = xcals.get_calendar("XNYS")
    sessions = calendar.sessions_in_range(pd.Timestamp(start), pd.Timestamp(end))
    return pd.DataFrame(
        {
            "open": [calendar.session_open(session) for session in sessions],
            "close": [calendar.session_close(session) for session in sessions],
        },
        index=pd.Index(pd.to_datetime(sessions).date, name="session_date"),
    )


def read_spy_parquet(path: Path) -> pd.DataFrame:
    if not path.is_file():
        raise FileNotFoundError(f"SPY Parquet input does not exist: {path}")
    frame = pd.read_parquet(path)
    missing = REQUIRED_COLUMNS.difference(frame.columns)
    if missing:
        raise ValueError(f"SPY Parquet input is missing columns: {sorted(missing)}")
    if set(frame["symbol"].dropna().unique()) != {"SPY"}:
        raise ValueError("SPY demo input must contain only symbol SPY")
    frame["timestamp"] = pd.to_datetime(frame["timestamp"], utc=True)
    return frame.sort_values("timestamp").reset_index(drop=True)
```

- [ ] **Step 4: Implement causal reindexing and quality reporting**

Create a frozen `DatasetQualityReport` dataclass with source rows, normalized rows, sessions, post-close removals, duplicate removals, causal fills, unresolved gaps, invalid rows, first timestamp, and last timestamp. Reindex each session to `[open, close)` one-minute timestamps. For a permitted gap, set OHLC to the immediately preceding close and volume to zero. Never use backward fill. Preserve unresolved rows with null OHLCV and `is_unresolved_gap=True` so feature eligibility can reject touching windows.

- [ ] **Step 5: Run dataset tests**

Working directory: `axio7-model-review/source/intraday_quant`

Run: `python -m pytest tests/demo/test_dataset.py -q`

Expected: PASS, including the 2025-07-03 early close and the two gap-length cases.

- [ ] **Step 6: Commit normalization and the existing downloader**

```bash
git add axio7-model-review/source/intraday_quant/src/intraday_quant/demo/dataset.py axio7-model-review/source/intraday_quant/tests/demo/conftest.py axio7-model-review/source/intraday_quant/tests/demo/test_dataset.py axio7-model-review/source/intraday_quant/scripts/download_databento_spy.py
git commit -m "feat: normalize Databento SPY sessions"
```

### Task 4: Build causal features, five-minute targets, and embargoed splits

**Files:**
- Create: `axio7-model-review/source/intraday_quant/src/intraday_quant/demo/features.py`
- Create: `axio7-model-review/source/intraday_quant/tests/demo/test_features.py`

**Interfaces:**
- Consumes: normalized frame from Task 3.
- Produces: `FEATURE_COLUMNS: tuple[str, ...]`; `SplitDefinition`; `build_examples(bars: pd.DataFrame, lookback_minutes: int = 30, horizon_minutes: int = 5) -> pd.DataFrame`; `chronological_split(session_dates: Sequence[date]) -> SplitDefinition`.

- [ ] **Step 1: Write failing causality, target, and split tests**

```python
def test_future_rows_do_not_change_existing_features(normalized_bars: pd.DataFrame) -> None:
    cutoff_session = sorted(normalized_bars.session_date.unique())[24]
    cutoff = normalized_bars.loc[normalized_bars.session_date == cutoff_session, "timestamp"].iloc[80]
    before = build_examples(normalized_bars.loc[normalized_bars.timestamp <= cutoff])
    after = build_examples(normalized_bars)
    columns = ["timestamp", *FEATURE_COLUMNS]
    pd.testing.assert_frame_equal(
        before[columns].reset_index(drop=True),
        after.loc[after.timestamp.isin(before.timestamp), columns].reset_index(drop=True),
    )


def test_target_is_exactly_five_minutes_forward(normalized_bars: pd.DataFrame) -> None:
    examples = build_examples(normalized_bars)
    row = examples.iloc[0]
    future = normalized_bars.loc[normalized_bars.timestamp == row.timestamp + pd.Timedelta(minutes=5)].iloc[0]
    assert row.target_return == pytest.approx(future.close / row.close - 1.0)
    assert row.target_up == int(future.close > row.close)


def test_506_session_split_has_two_embargoes() -> None:
    dates = pd.bdate_range("2024-01-02", periods=506).date.tolist()
    split = chronological_split(dates)
    assert len(split.train) == 354
    assert len(split.validation) == 75
    assert len(split.test) == 75
    assert split.train_validation_embargo == dates[354]
    assert split.validation_test_embargo == dates[430]
```

Add a test proving any example whose 30-minute lookback or five-minute outcome touches `is_unresolved_gap` is absent, while a causal fill is retained with `WINDOW_CONTAINS_CAUSAL_FILL`.

- [ ] **Step 2: Verify the tests fail**

Working directory: `axio7-model-review/source/intraday_quant`

Run: `python -m pytest tests/demo/test_features.py -q`

Expected: FAIL because the feature module is missing.

- [ ] **Step 3: Implement the fixed feature set**

Set `FEATURE_COLUMNS` to these exact names:

```python
FEATURE_COLUMNS = (
    "ret_1m", "ret_3m", "ret_5m", "ret_15m", "ret_30m",
    "realized_vol_15m", "true_range", "atr_14m", "bar_range", "close_location",
    "dist_session_open", "dist_session_vwap", "volume_zscore_30m", "rvol_same_minute_20d",
    "minute_sin", "minute_cos",
)
```

Compute return and rolling columns within each session. Compute session VWAP causally from cumulative typical-price times volume divided by cumulative volume. Compute same-minute relative volume by shifting each clock-minute history by one session before its rolling 20-session mean. Replace zero denominators with null, never infinity.

- [ ] **Step 4: Implement eligibility and targets**

Use session-local shifts for `close[t+5]`. Require at least 30 completed prior minutes, finite values for every fixed feature, and five available future minutes before the official close. Build a boolean contaminated-window mask from a 30-minute backward rolling maximum plus a five-minute forward rolling maximum of `is_unresolved_gap`. Retain causal-fill windows but add the quality flag. Compute the chronological split from all normalized official session dates before example-level exclusions, so coverage remains 354/75/75 on the observed 506-session dataset while excluded examples are reported separately.

- [ ] **Step 5: Implement the deterministic split**

```python
@dataclass(frozen=True)
class SplitDefinition:
    train: tuple[date, ...]
    train_validation_embargo: date
    validation: tuple[date, ...]
    validation_test_embargo: date
    test: tuple[date, ...]


def chronological_split(session_dates: Sequence[date]) -> SplitDefinition:
    ordered = tuple(sorted(set(session_dates)))
    if len(ordered) < 12:
        raise ValueError("At least 12 sessions are required for train/validation/test plus two embargoes")
    train_count = int(len(ordered) * 0.70)
    remaining_effective = len(ordered) - train_count - 2
    validation_count = remaining_effective // 2
    validation_start = train_count + 1
    validation_end = validation_start + validation_count
    return SplitDefinition(
        train=ordered[:train_count],
        train_validation_embargo=ordered[train_count],
        validation=ordered[validation_start:validation_end],
        validation_test_embargo=ordered[validation_end],
        test=ordered[validation_end + 1:],
    )
```

- [ ] **Step 6: Run feature tests and existing causal core tests**

Working directory: `axio7-model-review/source/intraday_quant`

Run: `python -m pytest tests/demo/test_features.py tests/test_core.py -q`

Expected: PASS.

- [ ] **Step 7: Commit the example builder**

```bash
git add axio7-model-review/source/intraday_quant/src/intraday_quant/demo/features.py axio7-model-review/source/intraday_quant/tests/demo/test_features.py
git commit -m "feat: build causal SPY forecast examples"
```

### Task 5: Fit fixed baseline models and untouched-test predictions

**Files:**
- Create: `axio7-model-review/source/intraday_quant/src/intraday_quant/demo/modeling.py`
- Create: `axio7-model-review/source/intraday_quant/tests/demo/test_modeling.py`

**Interfaces:**
- Consumes: examples and `FEATURE_COLUMNS` from Task 4.
- Produces: `ModelBundle`; `ValidationResidualInterval`; `fit_models(train: pd.DataFrame) -> ModelBundle`; `fit_residual_interval(bundle: ModelBundle, validation: pd.DataFrame) -> ValidationResidualInterval`; `predict_examples(bundle: ModelBundle, frame: pd.DataFrame, interval: ValidationResidualInterval) -> pd.DataFrame`; `evaluate_predictions(predictions: pd.DataFrame, train_up_rate: float) -> dict[str, float]`.

- [ ] **Step 1: Write failing model-isolation and metric tests**

```python
def model_frame(rows: int, seed: int) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    frame = pd.DataFrame(rng.normal(size=(rows, len(FEATURE_COLUMNS))), columns=FEATURE_COLUMNS)
    signal = frame["ret_5m"] + 0.25 * frame["dist_session_vwap"]
    frame["target_return"] = signal * 0.001
    frame["target_up"] = (frame["target_return"] > 0).astype(int)
    frame["close"] = 700.0
    frame["outcome_close"] = frame["close"] * (1.0 + frame["target_return"])
    frame["timestamp"] = pd.date_range("2026-01-05 10:00", periods=rows, freq="1min", tz="UTC")
    return frame


@pytest.fixture
def train_examples() -> pd.DataFrame:
    return model_frame(240, 7)


@pytest.fixture
def validation_examples() -> pd.DataFrame:
    return model_frame(120, 8)


def test_scalers_fit_training_rows_only(train_examples: pd.DataFrame, validation_examples: pd.DataFrame) -> None:
    bundle = fit_models(train_examples)
    expected = train_examples.loc[:, FEATURE_COLUMNS].mean().to_numpy()
    np.testing.assert_allclose(bundle.direction.named_steps["scale"].mean_, expected)
    np.testing.assert_allclose(bundle.return_model.named_steps["scale"].mean_, expected)


def test_prediction_fields_are_precomputed(train_examples: pd.DataFrame, validation_examples: pd.DataFrame) -> None:
    bundle = fit_models(train_examples)
    interval = fit_residual_interval(bundle, validation_examples)
    predictions = predict_examples(bundle, validation_examples, interval)
    assert predictions.probability_up.between(0.0, 1.0).all()
    assert (predictions.interval_low <= predictions.scenario_price).all()
    assert (predictions.scenario_price <= predictions.interval_high).all()
    assert set(predictions.probability_status) == {"RAW_EXPERIMENTAL_PROBABILITY"}
```

Add tests for the majority, zero-return, and five-minute-momentum baselines; 10th/90th validation residual quantiles; finite AUC/Brier/log-loss/MAE/RMSE; and no PnL or Sharpe keys.

- [ ] **Step 2: Verify the tests fail**

Working directory: `axio7-model-review/source/intraday_quant`

Run: `python -m pytest tests/demo/test_modeling.py -q`

Expected: FAIL because `intraday_quant.demo.modeling` is missing.

- [ ] **Step 3: Implement fixed model pipelines**

```python
direction = Pipeline([
    ("scale", StandardScaler()),
    ("model", LogisticRegression(C=1.0, max_iter=1000, solver="lbfgs", random_state=7)),
])
return_model = Pipeline([
    ("scale", StandardScaler()),
    ("model", Ridge(alpha=1.0)),
])
```

Fit both pipelines once on the training rows. Store the ordered features, training up rate, scikit-learn version, and fixed model parameters in `ModelBundle`. Reject non-finite features before fitting rather than imputing in the model layer.

- [ ] **Step 4: Implement interval and prediction output**

Fit residual quantiles at `0.10` and `0.90` on validation return residuals only. For each prediction, Python writes probability, expected return bps, current close, scenario price, interval prices, direction, realized close, and realized return bps. Set direction from the sign of expected return; do not leave that comparison to TypeScript.

- [ ] **Step 5: Implement metrics and baselines**

Use scikit-learn `roc_auc_score`, `brier_score_loss`, `log_loss`, `accuracy_score`, `mean_absolute_error`, and `mean_squared_error`. Compute ten equal-count-bin expected calibration error. Export explicit baseline deltas and coverage counts. Do not calculate strategy returns.

- [ ] **Step 6: Run model tests**

Working directory: `axio7-model-review/source/intraday_quant`

Run: `python -m pytest tests/demo/test_modeling.py -q`

Expected: PASS.

- [ ] **Step 7: Commit modeling**

```bash
git add axio7-model-review/source/intraday_quant/src/intraday_quant/demo/modeling.py axio7-model-review/source/intraday_quant/tests/demo/test_modeling.py
git commit -m "feat: train SPY baseline forecasts"
```

### Task 6: Serialize immutable bundles, expose the CLI, and commit a fixture

**Files:**
- Create: `axio7-model-review/source/intraday_quant/src/intraday_quant/demo/artifacts.py`
- Create: `axio7-model-review/source/intraday_quant/src/intraday_quant/demo/cli.py`
- Create: `axio7-model-review/source/intraday_quant/tests/demo/test_artifacts.py`
- Create: `axio7-model-review/apps/spy-price-demo/public/fixtures/spy-demo/manifest.json`
- Create: `axio7-model-review/apps/spy-price-demo/public/fixtures/spy-demo/summary.json`
- Create: `axio7-model-review/apps/spy-price-demo/public/fixtures/spy-demo/model-card.json`
- Create: `axio7-model-review/apps/spy-price-demo/public/fixtures/spy-demo/sessions/index.json`
- Create: `axio7-model-review/apps/spy-price-demo/public/fixtures/spy-demo/sessions/2026-07-24.json`

**Interfaces:**
- Consumes: contracts, normalized examples, split, models, predictions, and metrics from Tasks 2–5.
- Produces: `canonical_json_bytes(value: BaseModel | dict) -> bytes`; `content_hash(value: BaseModel | dict) -> str`; `build_bundle(input_path: Path, output_dir: Path, generated_at: datetime) -> Manifest`; command `python -m intraday_quant.demo.cli build --input PATH --output DIR [--generated-at ISO8601]`; `write_fixture(output_dir: Path) -> Manifest`.

- [ ] **Step 1: Write failing determinism and CLI tests**

```python
import hashlib

from intraday_quant.demo.contracts import SessionIndexArtifact


def test_canonical_hash_ignores_dictionary_insertion_order() -> None:
    left = {"b": 2, "a": 1}
    right = {"a": 1, "b": 2}
    assert content_hash(left) == content_hash(right)


def test_bundle_is_byte_stable_with_fixed_generation_time(tmp_path: Path, sample_parquet: Path) -> None:
    first = tmp_path / "first"
    second = tmp_path / "second"
    stamp = datetime(2026, 8, 19, 12, tzinfo=timezone.utc)
    build_bundle(sample_parquet, first, stamp)
    build_bundle(sample_parquet, second, stamp)
    assert bundle_bytes(first) == bundle_bytes(second)


def test_cli_fails_closed_for_missing_input(tmp_path: Path) -> None:
    result = run_cli("build", "--input", str(tmp_path / "missing.parquet"), "--output", str(tmp_path / "out"))
    assert result.returncode != 0
    assert "does not exist" in result.stderr
    assert not (tmp_path / "out" / "manifest.json").exists()


def test_manifest_hashes_the_written_index_and_index_hashes_each_session(
    tmp_path: Path, sample_parquet: Path
) -> None:
    output = tmp_path / "bundle"
    manifest = build_bundle(sample_parquet, output, datetime(2026, 8, 19, 12, tzinfo=timezone.utc))
    index_path = output / manifest.session_index.path
    assert hashlib.sha256(index_path.read_bytes()).hexdigest() == manifest.session_index.sha256
    index = SessionIndexArtifact.model_validate_json(index_path.read_bytes())
    assert index.artifact_sha256 == manifest.artifact_sha256
    for entry in index.sessions:
        assert hashlib.sha256((output / entry.path).read_bytes()).hexdigest() == entry.sha256
```

Define the test helpers without shell quoting ambiguity:

```python
def bundle_bytes(root: Path) -> dict[str, bytes]:
    return {str(path.relative_to(root)): path.read_bytes() for path in sorted(root.rglob("*.json"))}


def run_cli(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, "-m", "intraday_quant.demo.cli", *arguments],
        check=False,
        capture_output=True,
        text=True,
    )
```

- [ ] **Step 2: Verify the tests fail**

Working directory: `axio7-model-review/source/intraday_quant`

Run: `python -m pytest tests/demo/test_artifacts.py -q`

Expected: FAIL because the artifact and CLI modules are missing.

- [ ] **Step 3: Implement canonical serialization and atomic writes**

```python
def canonical_json_bytes(value: BaseModel | dict[str, object]) -> bytes:
    payload = value.model_dump(mode="json") if isinstance(value, BaseModel) else value
    return (json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode("utf-8")


def content_hash(value: BaseModel | dict[str, object]) -> str:
    return hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def atomic_write(path: Path, body: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(body)
    temporary.replace(path)
```

Compute the artifact hash from quantitative content and provenance without the self-referential hash field. Put that artifact hash in the session index and every session-level provenance block. Serialize and hash session files in ascending date/timestamp order, then serialize and hash `sessions/index.json`, then place that file reference in the manifest. Validate every model before writing the manifest last.

- [ ] **Step 4: Implement bundle orchestration and CLI parsing**

The CLI has subcommands `build`, `schemas`, and `fixture`. `build` requires input and output. `schemas` writes to `contracts/spy-price-demo/v1`. `fixture` writes the committed explicit fixture. Parse `--generated-at` as UTC; when absent, use the current UTC clock. Print only a compact JSON receipt containing artifact hash, source hash, rows, sessions, and output path.

- [ ] **Step 5: Generate and validate the committed fixture**

Working directory: `axio7-model-review/source/intraday_quant`

Run:

```bash
python -m intraday_quant.demo.cli fixture --output ../../apps/spy-price-demo/public/fixtures/spy-demo --generated-at 2026-08-19T12:00:00Z
```

Expected: all five fixture files validate; the manifest and session carry `status: "UI_FIXTURE"`; the bundle uses only the fixed 2026-07-24 sample bars embedded by the fixture builder.

- [ ] **Step 6: Run artifact tests and a real-data dry build**

Working directory: `axio7-model-review/source/intraday_quant`

Run: `python -m pytest tests/demo/test_artifacts.py -q`

Expected: PASS.

Run:

```bash
python -m intraday_quant.demo.cli build --input data/normalized/databento_SPY_ohlcv-1m_2024-07-18_2026-07-25_rth.parquet --output ../../apps/spy-price-demo/public/generated
```

Expected: receipt reports 506 observed source sessions, 75 effective test sessions before example-level quality exclusions, and no fixture status.

- [ ] **Step 7: Commit bundle generation and fixture**

```bash
git add axio7-model-review/source/intraday_quant/src/intraday_quant/demo/artifacts.py axio7-model-review/source/intraday_quant/src/intraday_quant/demo/cli.py axio7-model-review/source/intraday_quant/tests/demo/test_artifacts.py axio7-model-review/apps/spy-price-demo/public/fixtures/spy-demo
git commit -m "feat: export SPY replay artifacts"
```

### Task 7: Generate TypeScript types and fail-closed Ajv loaders

**Files:**
- Modify: `axio7-model-review/apps/spy-price-demo/package.json`
- Create: `axio7-model-review/apps/spy-price-demo/scripts/generate-artifact-types.mjs`
- Create generated: `axio7-model-review/apps/spy-price-demo/src/features/replay/artifact/generated/manifest.ts`
- Create generated: `axio7-model-review/apps/spy-price-demo/src/features/replay/artifact/generated/sessionIndex.ts`
- Create generated: `axio7-model-review/apps/spy-price-demo/src/features/replay/artifact/generated/session.ts`
- Create generated: `axio7-model-review/apps/spy-price-demo/src/features/replay/artifact/generated/summary.ts`
- Create generated: `axio7-model-review/apps/spy-price-demo/src/features/replay/artifact/generated/modelCard.ts`
- Create generated: `axio7-model-review/apps/spy-price-demo/src/features/replay/artifact/generated/contracts.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/artifact/schemas.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/artifact/validateArtifact.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/artifact/loadArtifact.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/artifact/ArtifactError.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/artifact/validateArtifact.test.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/artifact/loadArtifact.test.ts`

**Interfaces:**
- Consumes: JSON Schemas from Task 2 and static bundle from Task 6.
- Produces: generated `Manifest`, `SessionIndexArtifact`, `SessionArtifact`, `SummaryArtifact`, `ModelCard`; `validateManifest(value: unknown): Manifest`; `validateSessionIndex(value: unknown): SessionIndexArtifact`; `validateSession(value: unknown): SessionArtifact`; `loadManifest(signal?: AbortSignal): Promise<Manifest>`; `loadSessionIndex(manifest: Manifest, signal?: AbortSignal): Promise<SessionIndexArtifact>`; `loadSession(entry: SessionIndexEntry, signal?: AbortSignal): Promise<SessionArtifact>`; `ArtifactError` with codes `NETWORK`, `INVALID_SCHEMA`, `UNSUPPORTED_VERSION`, `HASH_MISMATCH`, `MISSING_SESSION`.

Define the injectable page boundary in `loadArtifact.ts`:

```ts
export interface ReplayLoaders {
  loadManifest(signal?: AbortSignal): Promise<Manifest>;
  loadSessionIndex(manifest: Manifest, signal?: AbortSignal): Promise<SessionIndexArtifact>;
  loadSession(entry: SessionIndexEntry, signal?: AbortSignal): Promise<SessionArtifact>;
}
```

- [ ] **Step 1: Write failing validator tests**

```ts
import fixtureManifest from "../../../../public/fixtures/spy-demo/manifest.json";
import { ArtifactError } from "./ArtifactError";
import { validateManifest } from "./validateArtifact";

it("accepts the committed fixture manifest", () => {
  expect(validateManifest(fixtureManifest).status).toBe("UI_FIXTURE");
});

it("rejects unknown fields and versions", () => {
  const invalid = { ...fixtureManifest, contract_version: "2.0.0", invented: true };
  expect(() => validateManifest(invalid)).toThrow(ArtifactError);
});
```

Write loader tests with `vi.stubGlobal("fetch", vi.fn())` proving a 404 becomes `MISSING_SESSION`, invalid JSON becomes `INVALID_SCHEMA`, an abort remains an `AbortError`, an index or session byte-hash mismatch becomes `HASH_MISMATCH`, an index with the wrong `artifact_sha256` becomes `HASH_MISMATCH`, and generated mode does not request `/fixtures/spy-demo`.

- [ ] **Step 2: Verify tests fail**

Working directory: `axio7-model-review/apps/spy-price-demo`

Run: `npm test -- src/features/replay/artifact`

Expected: FAIL because the artifact modules are missing.

- [ ] **Step 3: Implement the type-generation script**

Use `json-schema-to-typescript`'s `compileFromFile` for all five canonical schemas and write each result to its own generated module with a do-not-edit header. This prevents repeated aliases such as `ContractVersion` from colliding. Generate `contracts.ts` as a type-only barrel that exports `Manifest`, `SessionIndexArtifact`, `SessionIndexEntry`, `SessionArtifact`, `ChartBar`, `ReplayRow`, `SummaryArtifact`, and `ModelCard` from their owning modules. Resolve schema and output paths from `import.meta.url`, not the shell working directory. Delete only stale `.ts` files inside this exact generated directory before writing and exit nonzero when a schema is missing.

Because generated types are intentionally ignored, update package scripts at the same time so clean checkouts regenerate them before any command that typechecks:

```json
{
  "scripts": {
    "dev": "vite --mode development",
    "dev:fixture": "vite --mode fixture",
    "artifacts:types": "node scripts/generate-artifact-types.mjs",
    "test": "npm run artifacts:types && vitest run",
    "test:watch": "npm run artifacts:types && vitest",
    "typecheck": "npm run artifacts:types && tsc --noEmit",
    "build": "npm run typecheck && vite build",
    "pretest:e2e": "npm run artifacts:types",
    "test:e2e": "playwright test"
  }
}
```

- [ ] **Step 4: Generate types**

Working directory: `axio7-model-review/apps/spy-price-demo`

Run: `npm run artifacts:types`

Expected: five isolated generated schema modules exist and `generated/contracts.ts` exports the five root artifact interfaces plus the nested chart/replay/index types used by the application.

- [ ] **Step 5: Implement Ajv 2020 validators**

```ts
import Ajv2020 from "ajv/dist/2020";
import addFormats from "ajv-formats";
import manifestSchema from "../../../../../../contracts/spy-price-demo/v1/manifest.schema.json";
import sessionIndexSchema from "../../../../../../contracts/spy-price-demo/v1/session-index.schema.json";
import sessionSchema from "../../../../../../contracts/spy-price-demo/v1/session.schema.json";

const ajv = new Ajv2020({ allErrors: true, strict: true });
addFormats(ajv);
const manifestValidator = ajv.compile<Manifest>(manifestSchema);
const sessionValidator = ajv.compile<SessionArtifact>(sessionSchema);

export function validateManifest(value: unknown): Manifest {
  if (!manifestValidator(value)) {
    throw ArtifactError.invalidSchema("manifest", manifestValidator.errors);
  }
  return value;
}
```

Compile `sessionIndexSchema` directly and add equivalent session-index, summary, and model-card validators. Keep Ajv error details in the local error object but render only concise safe messages.

- [ ] **Step 6: Implement explicit-base loaders**

```ts
const artifactBase = import.meta.env.VITE_SPY_ARTIFACT_BASE;
if (!artifactBase) throw new Error("VITE_SPY_ARTIFACT_BASE is required");

async function getJson(path: string, expectedSha256?: string, signal?: AbortSignal): Promise<unknown> {
  const response = await fetch(`${artifactBase}/${path}`, { signal });
  if (!response.ok) throw ArtifactError.fromResponse(path, response.status);
  const body = new Uint8Array(await response.arrayBuffer());
  if (expectedSha256 && await sha256Hex(body) !== expectedSha256) {
    throw ArtifactError.hashMismatch(path);
  }
  try {
    return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(body)) as unknown;
  } catch (error) {
    throw ArtifactError.invalidJson(path, error);
  }
}
```

Implement `sha256Hex(body: Uint8Array)` with `crypto.subtle.digest("SHA-256", body)`; hash the exact response bytes before UTF-8 decoding or JSON parsing. `loadSessionIndex` verifies both `manifest.session_index.sha256` and equality between the index and manifest `artifact_sha256`. `loadSession` accepts the validated index entry so it can verify that session file's SHA-256 and artifact hash before returning. Validate before returning. Do not catch `AbortError`. Do not retry against another base path.

- [ ] **Step 7: Run artifact frontend tests and typecheck**

Working directory: `axio7-model-review/apps/spy-price-demo`

Run: `npm test -- src/features/replay/artifact`

Expected: PASS.

Run: `npm run typecheck`

Expected: PASS.

- [ ] **Step 8: Commit frontend contracts**

```bash
git add axio7-model-review/apps/spy-price-demo/package.json axio7-model-review/apps/spy-price-demo/scripts axio7-model-review/apps/spy-price-demo/src/features/replay/artifact
git commit -m "feat: validate SPY demo artifacts"
```

### Task 8: Implement replay state, URL state, and persistent monochrome themes

**Files:**
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayPage/replayReducer.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayPage/replayReducer.test.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayPage/useReplayUrl.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayPage/useReplayUrl.test.tsx`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/theme/ThemeToggle/useTheme.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/theme/ThemeToggle/ThemeToggle.tsx`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/theme/ThemeToggle/ThemeToggle.module.css`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/theme/ThemeToggle/ThemeToggle.test.tsx`

**Interfaces:**
- Consumes: validated session dates and rows.
- Produces: `ReplayState { sessionDate: string; cutoffIndex: number; revealed: boolean }`; `replayReducer`; `useReplayUrl`; `useTheme(): { theme: "light" | "dark"; toggleTheme(): void }`; `ThemeToggle`.

- [ ] **Step 1: Write failing replay reducer tests**

```ts
it("snaps to a new cutoff and hides the prior outcome", () => {
  const state = { sessionDate: "2026-07-24", cutoffIndex: 20, revealed: true } as const;
  expect(replayReducer(state, { type: "setCutoff", cutoffIndex: 21 })).toEqual({
    sessionDate: "2026-07-24",
    cutoffIndex: 21,
    revealed: false,
  });
});

it("resets cutoff and reveal when the session changes", () => {
  const state = { sessionDate: "2026-07-24", cutoffIndex: 20, revealed: true } as const;
  expect(replayReducer(state, { type: "setSession", sessionDate: "2026-07-23" })).toEqual({
    sessionDate: "2026-07-23",
    cutoffIndex: 0,
    revealed: false,
  });
});
```

- [ ] **Step 2: Write failing theme and URL tests**

Test that a stored `spy-demo-theme=dark` sets `data-theme="dark"`, the button's visible text is `Light`, its accessible name is `Switch to light mode`, toggling stores `light`, and no class name containing `transition` or `animate` is introduced. Test that `?session=2026-07-24&cutoff=20` initializes replay state and invalid values fall back to the first validated session and cutoff zero.

- [ ] **Step 3: Run tests and verify failure**

Working directory: `axio7-model-review/apps/spy-price-demo`

Run: `npm test -- src/features/replay/ReplayPage src/features/theme/ThemeToggle`

Expected: FAIL because reducer, URL, and theme modules are missing.

- [ ] **Step 4: Implement the pure reducer and URL adapter**

```ts
export type ReplayAction =
  | { type: "setSession"; sessionDate: string }
  | { type: "setCutoff"; cutoffIndex: number }
  | { type: "reveal" };

export function replayReducer(state: ReplayState, action: ReplayAction): ReplayState {
  if (action.type === "setSession") return { sessionDate: action.sessionDate, cutoffIndex: 0, revealed: false };
  if (action.type === "setCutoff") return { ...state, cutoffIndex: action.cutoffIndex, revealed: false };
  return { ...state, revealed: true };
}
```

`useReplayUrl` reads and writes only `session` and `cutoff` with `URLSearchParams` and `history.replaceState`; it validates against the loaded session index before applying values.

- [ ] **Step 5: Implement persistent light/dark mode**

Use CSS custom properties `--spy-bg` and `--spy-fg` with exact black/white inversions. Store the choice under `spy-demo-theme`; default to light. The toggle is a native button with visible action text (`Dark` in light mode, `Light` in dark mode), an explicit accessible name (`Switch to dark mode` or `Switch to light mode`), and no transition declaration.

- [ ] **Step 6: Run state and theme tests**

Working directory: `axio7-model-review/apps/spy-price-demo`

Run: `npm test -- src/features/replay/ReplayPage src/features/theme/ThemeToggle`

Expected: PASS.

- [ ] **Step 7: Commit replay state and theme**

```bash
git add axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayPage axio7-model-review/apps/spy-price-demo/src/features/theme
git commit -m "feat: add replay and theme state"
```

### Task 9: Build the pure ECharts option adapter and lifecycle hook

**Files:**
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayGraph/types.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayGraph/formatTooltip.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayGraph/formatTooltip.test.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayGraph/buildReplayChartOption.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayGraph/buildReplayChartOption.test.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayGraph/useECharts.ts`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayGraph/useECharts.test.tsx`

**Interfaces:**
- Consumes: validated `SessionArtifact`, selected `ReplayRow`, reveal boolean, and theme.
- Produces: `ChartTheme`; `ReplayChartInput`; `formatTooltip(input: TooltipInput) -> string`; `buildReplayChartOption(input: ReplayChartInput): EChartsOption`; `useECharts(option: EChartsOption): RefObject<HTMLDivElement | null>`.

Use these core graph types:

```ts
export interface ChartTheme {
  background: "#ffffff" | "#000000";
  foreground: "#000000" | "#ffffff";
  up: "#00a36c";
  down: "#e2382f";
}

export interface ReplayChartInput {
  session: SessionArtifact;
  row: ReplayRow;
  revealed: boolean;
  theme: ChartTheme;
  accessibleSummary: string;
}
```

- [ ] **Step 1: Write failing option invariants**

```ts
it("disables every animation path", () => {
  const option = buildReplayChartOption(makeReplayInput(false));
  expect(option.animation).toBe(false);
  expect(option.animationDuration).toBe(0);
  expect(option.animationDurationUpdate).toBe(0);
});

it("uses artifact scenario values without recomputing them", () => {
  const input = makeReplayInput(false);
  const option = buildReplayChartOption(input);
  expect(JSON.stringify(option)).toContain(String(input.row.forecast.scenario_price));
  expect(JSON.stringify(option)).toContain(String(input.row.forecast.interval_low));
  expect(JSON.stringify(option)).toContain(String(input.row.forecast.interval_high));
});

it("does not expose future candles before reveal", () => {
  const input = makeReplayInput(false);
  const hidden = buildReplayChartOption(input);
  const shown = buildReplayChartOption({ ...input, revealed: true });
  expect(visibleCandleCount(hidden)).toBe(input.row.bar_index + 1);
  expect(visibleCandleCount(shown)).toBe(input.row.bar_index + 6);
});
```

At the top of the test file, load the committed session fixture and define `makeReplayInput(revealed: boolean): ReplayChartInput` with `row: session.rows[30]`, light theme `{ background: "#ffffff", foreground: "#000000", up: "#00a36c", down: "#e2382f" }`, and an accessible summary from that selected fixture row. Define `visibleCandleCount` by locating the series with `type === "candlestick"` and counting data entries other than `"-"`.

- [ ] **Step 2: Write failing tooltip tests**

Assert the cutoff tooltip contains OHLCV, `P(UP,+5M)`, expected return, scenario, interval, source, cutoff, availability, coverage, quality flags, feature/model versions, artifact hash prefix, and caveat codes. After reveal, assert it contains realized close and return. Assert the returned markup uses only current foreground/background plus the graph up/down colors.

- [ ] **Step 3: Verify graph tests fail**

Working directory: `axio7-model-review/apps/spy-price-demo`

Run: `npm test -- src/features/replay/ReplayGraph`

Expected: FAIL because graph modules are missing.

- [ ] **Step 4: Implement formatter and pure option builder**

Use `session.bars` for the complete candlestick/volume timeline and `row.bar_index` for the current cutoff. Before reveal, replace all later candle/volume values with `"-"`; after reveal, expose exactly the next five bars. Use a dashed scenario line, a custom interval whisker, linked crosshairs, and an HTML tooltip confined to the graph. Choose forecast trend color from `row.forecast.direction`, never by comparing prices in TypeScript. Use `#00a36c` for `UP`, `#e2382f` for `DOWN`, and foreground black/white for `FLAT`. Use each chart bar's precomputed direction/quality representation for candle and volume styling; TypeScript must not derive financial outcomes. Set all axes, grid lines, controls, and tooltip surfaces from the monochrome theme.

The builder must begin with:

```ts
const option: EChartsOption = {
  animation: false,
  animationDuration: 0,
  animationDurationUpdate: 0,
  backgroundColor: input.theme.background,
  aria: {
    enabled: true,
    description: input.accessibleSummary,
  },
};
```

Populate the remainder without mutating the session artifact.

- [ ] **Step 5: Implement the lifecycle hook**

Initialize one SVG-renderer ECharts instance on mount, call `setOption(option, { notMerge: true, lazyUpdate: false })` on option changes, observe container size with `ResizeObserver`, and dispose on unmount. Do not call `clear()` between normal replay updates; the disabled ECharts animation makes replacement instantaneous.

- [ ] **Step 6: Run graph tests**

Working directory: `axio7-model-review/apps/spy-price-demo`

Run: `npm test -- src/features/replay/ReplayGraph`

Expected: PASS.

- [ ] **Step 7: Commit the graph adapter**

```bash
git add axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayGraph
git commit -m "feat: render SPY replay chart options"
```

### Task 10: Compose the graph-first replay page and fail-closed states

**Files:**
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayGraph/ReplayGraph.tsx`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayGraph/ReplayGraph.module.css`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayControls/ReplayControls.tsx`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayControls/ReplayControls.module.css`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayControls/ReplayControls.test.tsx`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/OutcomeReveal/OutcomeReveal.tsx`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayPage/ReplayPage.tsx`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayPage/ReplayPage.module.css`
- Create: `axio7-model-review/apps/spy-price-demo/src/features/replay/ReplayPage/ReplayPage.test.tsx`
- Create: `axio7-model-review/apps/spy-price-demo/src/app/ArtifactFailure.tsx`
- Modify: `axio7-model-review/apps/spy-price-demo/src/app/App.tsx`
- Modify: `axio7-model-review/apps/spy-price-demo/src/app/App.test.tsx`
- Modify: `axio7-model-review/apps/spy-price-demo/src/app/global.css`

**Interfaces:**
- Consumes: loaders, state, theme, graph option builder, and validated artifacts from Tasks 7–9.
- Produces: completed `ReplayPage`; minimal `ArtifactFailure`; no other visible panels.

- [ ] **Step 1: Write failing page behavior tests**

```tsx
import fixtureManifestJson from "../../../../public/fixtures/spy-demo/manifest.json";
import fixtureIndexJson from "../../../../public/fixtures/spy-demo/sessions/index.json";
import fixtureSessionJson from "../../../../public/fixtures/spy-demo/sessions/2026-07-24.json";
import type { Manifest, SessionArtifact, SessionIndexArtifact } from "../artifact/generated/contracts";
import type { ReplayLoaders } from "../artifact/loadArtifact";

const fixtureLoaders: ReplayLoaders = {
  loadManifest: async () => fixtureManifestJson as Manifest,
  loadSessionIndex: async () => fixtureIndexJson as SessionIndexArtifact,
  loadSession: async () => fixtureSessionJson as SessionArtifact,
};

it("renders only graph-first chrome after artifacts load", async () => {
  render(<ReplayPage loaders={fixtureLoaders} />);
  expect(await screen.findByRole("heading", { name: "SPY" })).toBeInTheDocument();
  expect(screen.getByRole("img", { name: /SPY candlestick and volume graph/i })).toBeInTheDocument();
  expect(screen.getByRole("slider", { name: "Replay cutoff minute" })).toBeInTheDocument();
  expect(screen.getByRole("button", { name: "Reveal +5m" })).toBeInTheDocument();
  expect(screen.queryByText(/performance|evidence|calibration/i)).not.toBeInTheDocument();
});

it("hides outcome until reveal and resets it on cutoff change", async () => {
  const user = userEvent.setup();
  render(<ReplayPage loaders={fixtureLoaders} />);
  await screen.findByRole("slider", { name: "Replay cutoff minute" });
  expect(screen.getByRole("status")).not.toHaveTextContent(/realized/i);
  await user.click(screen.getByRole("button", { name: "Reveal +5m" }));
  expect(screen.getByRole("status")).toHaveTextContent(/realized/i);
  screen.getByRole("slider", { name: "Replay cutoff minute" }).focus();
  await user.keyboard("{ArrowLeft}");
  expect(screen.getByRole("status")).not.toHaveTextContent(/realized/i);
});
```

Add a failure-state test where invalid manifest loading renders the artifact name, safe error code, and exact remediation command `python -m intraday_quant.demo.cli build --input source/intraday_quant/data/normalized/databento_SPY_ohlcv-1m_2024-07-18_2026-07-25_rth.parquet --output apps/spy-price-demo/public/generated`; assert no graph exists.

- [ ] **Step 2: Verify page tests fail**

Working directory: `axio7-model-review/apps/spy-price-demo`

Run: `npm test -- src/features/replay/ReplayPage src/features/replay/ReplayControls src/app`

Expected: FAIL because the composed page is missing.

- [ ] **Step 3: Implement graph, controls, and hidden live summary**

`ReplayGraph` receives a complete `ReplayChartInput` and owns no loading or replay state. Its ECharts host is `role="img"`, receives the accessible graph summary as its label, and carries `data-chart-animation="false"`. `ReplayControls` uses a native range input with `step=1` and calls `setCutoff` on `input`, not after a debounce. `OutcomeReveal` is the one black/white button. Add a `.srOnly` live region containing selected cutoff, forecast, quality, and revealed outcome for keyboard and screen-reader users.

- [ ] **Step 4: Implement asynchronous page orchestration**

Load manifest first, then the session index, then the URL-selected session. Abort the previous session request when selection changes. Keep only validated sessions in a `Map<string, SessionArtifact>`. Clamp the cutoff to the loaded row range. Route any `ArtifactError` to `ArtifactFailure`; do not render the last valid graph under an invalid new request.

- [ ] **Step 5: Match the approved visual reference**

Use the saved reference for exact hierarchy: square outer frame, compact `SPY` header, terse metadata, theme action, dominant graph, one divider, cutoff slider, and reveal button. Use no rounded cards, shadows, explanatory prose, status paragraphs, metric strip, or secondary panel. Keep all non-trend colors at exact black or white. Set global `animation: none !important` and `transition: none !important` inside the app root.

- [ ] **Step 6: Run page tests and build**

Working directory: `axio7-model-review/apps/spy-price-demo`

Run: `npm test -- src/features/replay/ReplayPage src/features/replay/ReplayControls src/app`

Expected: PASS.

Run: `npm run build`

Expected: type generation, typecheck, and Vite production build all PASS.

- [ ] **Step 7: Commit the completed page**

```bash
git add axio7-model-review/apps/spy-price-demo/src
git commit -m "feat: compose graph-first SPY replay"
```

### Task 11: Add browser acceptance coverage and runnable documentation

**Files:**
- Create: `axio7-model-review/apps/spy-price-demo/playwright.config.ts`
- Create: `axio7-model-review/apps/spy-price-demo/e2e/replay.spec.ts`
- Create: `axio7-model-review/apps/spy-price-demo/README.md`
- Modify: `axio7-model-review/source/intraday_quant/README.md`

**Interfaces:**
- Consumes: completed Python CLI, fixture, and frontend.
- Produces: repeatable setup commands and responsive browser acceptance coverage at 360, 736, and 1024 pixels.

- [ ] **Step 1: Write the failing Playwright acceptance test**

```ts
import { expect, test } from "@playwright/test";

for (const width of [360, 736, 1024]) {
  test(`graph-first replay at ${width}px`, async ({ page }) => {
    await page.setViewportSize({ width, height: 800 });
    await page.goto("/");
    await expect(page.getByRole("heading", { name: "SPY" })).toBeVisible();
    await expect(page.getByRole("img", { name: /candlestick and volume graph/i })).toBeVisible();
    const hasHorizontalOverflow = await page.evaluate(
      () => document.documentElement.scrollWidth > document.documentElement.clientWidth,
    );
    expect(hasHorizontalOverflow).toBe(false);

    await page.getByRole("button", { name: "Switch to dark mode" }).click();
    await expect(page.locator("[data-theme=dark]")).toBeVisible();

    const slider = page.getByRole("slider", { name: "Replay cutoff minute" });
    await slider.press("ArrowLeft");
    await expect(page.locator("[data-chart-animation=false]")).toBeVisible();

    await page.getByRole("button", { name: "Reveal +5m" }).click();
    await expect(page.locator("[aria-live=polite]")).toContainText("Realized");
  });
}
```

Add a tooltip test that hovers the selected candle and asserts OHLCV, forecast, provenance, model version, quality, and caveats. Add a request interception test returning a malformed manifest and assert the graph is absent.

- [ ] **Step 2: Configure the fixture server and verify the initial red state**

```ts
import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  use: { baseURL: "http://127.0.0.1:4173" },
  webServer: {
    command: "npm run dev:fixture -- --host 127.0.0.1 --port 4173",
    url: "http://127.0.0.1:4173",
    reuseExistingServer: false,
  },
});
```

Working directory: `axio7-model-review/apps/spy-price-demo`

Run: `npm run test:e2e`

Expected: FAIL until the page exposes the tested graph and animation-state attributes exactly.

- [ ] **Step 3: Add stable acceptance attributes without visual copy**

Set `data-chart-animation="false"` on the graph container and `data-theme` on the app frame. Ensure the theme button's accessible name reflects the action. Add no test-only visible text.

- [ ] **Step 4: Document exact terminal setup**

The app README must include:

```bash
cd axio7-model-review
python3 -m venv .venv-spy-demo
source .venv-spy-demo/bin/activate
python -m pip install -e "source/intraday_quant[dev]"
python -m intraday_quant.demo.cli build --input source/intraday_quant/data/normalized/databento_SPY_ohlcv-1m_2024-07-18_2026-07-25_rth.parquet --output apps/spy-price-demo/public/generated
cd apps/spy-price-demo
npm install
npm run dev
```

Document `npm run dev:fixture` separately and state that it is visibly labeled, non-market fixture mode. Link the saved reference and design spec. Add the demo CLI command to the Python README without changing its existing full-pipeline guidance.

- [ ] **Step 5: Run the complete scoped verification**

Working directory: `axio7-model-review/source/intraday_quant`

Run: `python -m pytest tests/demo -q`

Expected: PASS.

Working directory: `axio7-model-review/apps/spy-price-demo`

Run: `npm test`

Expected: PASS.

Run: `npm run build`

Expected: PASS.

Run: `npm run test:e2e`

Expected: PASS at 360, 736, and 1024 pixels in both themes.

- [ ] **Step 6: Confirm repository hygiene**

Working directory: repository root.

Run: `git status --short`

Expected: only intentionally modified source, tests, documentation, package lock, schemas, and fixture files are present; raw data, normalized data, generated artifacts, model binaries, reports, screenshots, and secrets are absent.

Run: `git diff --check`

Expected: no whitespace errors.

- [ ] **Step 7: Commit acceptance coverage and documentation**

```bash
git add axio7-model-review/apps/spy-price-demo/playwright.config.ts axio7-model-review/apps/spy-price-demo/e2e axio7-model-review/apps/spy-price-demo/README.md axio7-model-review/source/intraday_quant/README.md
git commit -m "test: verify SPY replay demo end to end"
```

## Final review gate

- [ ] Compare the running app with `axio7-model-review/apps/spy-price-demo/docs/reference/spy-graph-first.html` at 360, 736, and 1024 pixels.
- [ ] Confirm tooltip fields match the validated artifact and no displayed quantitative value is derived in TypeScript.
- [ ] Confirm slider, reveal, theme, and resize updates snap with no ECharts, CSS, or browser interpolation.
- [ ] Confirm generated artifacts are ignored, fixture mode is explicit, and no secret or market-data file is staged.
- [ ] Run `git log --oneline` and verify each task ended in its own reviewable commit.

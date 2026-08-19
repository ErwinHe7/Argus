"""Strict, versioned contracts for the offline SPY price-demo artifacts."""

from __future__ import annotations

import json
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Literal, Self

from pydantic import BaseModel, ConfigDict, Field, model_validator

ContractVersion = Literal["1.0.0"]
ProbabilityStatus = Literal["RAW_EXPERIMENTAL_PROBABILITY"]
IntervalStatus = Literal["EXPLORATORY_VALIDATION_RESIDUAL_INTERVAL"]
BundleStatus = Literal["HISTORICAL_OOS", "UI_FIXTURE"]
Direction = Literal["UP", "DOWN", "FLAT"]


class StrictModel(BaseModel):
    """Reject unknown fields and prevent mutation after validation."""

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

    @model_validator(mode="after")
    def contains_scenario_price(self) -> Self:
        if not self.interval_low <= self.scenario_price <= self.interval_high:
            raise ValueError("forecast interval must contain scenario_price")
        return self


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

    @model_validator(mode="after")
    def validates_ohlcv(self) -> Self:
        ohlcv = (self.open, self.high, self.low, self.close, self.volume)
        if any(value is None for value in ohlcv):
            if "UNRESOLVED_GAP" not in self.quality_flags:
                raise ValueError("null OHLCV requires the UNRESOLVED_GAP quality flag")
            if any(value is not None for value in ohlcv):
                raise ValueError("UNRESOLVED_GAP bars must have null OHLCV")
            return self

        assert self.open is not None
        assert self.high is not None
        assert self.low is not None
        assert self.close is not None
        assert self.volume is not None
        if min(self.open, self.high, self.low, self.close) <= 0.0:
            raise ValueError("complete chart bars require positive OHLC values")
        if self.volume < 0:
            raise ValueError("complete chart bars require non-negative volume")
        if self.low > min(self.open, self.close) or self.high < max(self.open, self.close):
            raise ValueError("chart bar OHLC values are inconsistent")
        return self

    @property
    def is_complete(self) -> bool:
        return all(value is not None for value in (self.open, self.high, self.low, self.close, self.volume))


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

    @model_validator(mode="after")
    def validates_ohlc(self) -> Self:
        if self.low > min(self.open, self.close) or self.high < max(self.open, self.close):
            raise ValueError("replay row OHLC values are inconsistent")
        return self


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

    @model_validator(mode="after")
    def validates_replay_alignment(self) -> Self:
        if any(left.timestamp >= right.timestamp for left, right in zip(self.bars, self.bars[1:])):
            raise ValueError("chart bars must be sorted by timestamp")
        if any(left.timestamp >= right.timestamp for left, right in zip(self.rows, self.rows[1:])):
            raise ValueError("replay rows must be sorted by timestamp")
        if any(left.bar_index >= right.bar_index for left, right in zip(self.rows, self.rows[1:])):
            raise ValueError("replay rows must be sorted by bar_index")

        for row in self.rows:
            if row.bar_index >= len(self.bars):
                raise ValueError("replay row bar_index must point to a complete chart bar")
            bar = self.bars[row.bar_index]
            if not bar.is_complete:
                raise ValueError("replay row bar_index must point to a complete chart bar")
            if (
                row.timestamp != bar.timestamp
                or row.available_at != bar.available_at
                or row.open != bar.open
                or row.high != bar.high
                or row.low != bar.low
                or row.close != bar.close
                or row.volume != bar.volume
            ):
                raise ValueError("replay row must match its complete chart bar")
            if row.outcome.timestamp != row.timestamp + timedelta(minutes=5):
                raise ValueError("replay outcome timestamp must be exactly five chart minutes later")
        return self


class SessionIndexEntry(StrictModel):
    date: date
    path: str = Field(pattern=r"^sessions/\d{4}-\d{2}-\d{2}\.json$")
    sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    rows: int = Field(gt=0)

    @model_validator(mode="after")
    def path_date_matches_date(self) -> Self:
        path_date = self.path.removeprefix("sessions/").removesuffix(".json")
        if path_date != self.date.isoformat():
            raise ValueError("session index path date must match date")
        return self


class ArtifactReference(StrictModel):
    path: Literal["sessions/index.json"]
    sha256: str = Field(pattern=r"^[0-9a-f]{64}$")


class SessionIndexArtifact(StrictModel):
    contract_version: ContractVersion
    artifact_sha256: str = Field(pattern=r"^[0-9a-f]{64}$")
    sessions: tuple[SessionIndexEntry, ...]

    @model_validator(mode="after")
    def validates_session_order(self) -> Self:
        if any(left.date >= right.date for left, right in zip(self.sessions, self.sessions[1:])):
            raise ValueError("session index entries must be sorted by date")
        return self


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


SCHEMA_MODELS: dict[str, type[StrictModel]] = {
    "manifest.schema.json": Manifest,
    "session-index.schema.json": SessionIndexArtifact,
    "session.schema.json": SessionArtifact,
    "summary.schema.json": SummaryArtifact,
    "model-card.schema.json": ModelCard,
}


def write_json_schemas(output_dir: Path) -> tuple[Path, ...]:
    """Write stable, newline-terminated schemas for each independently fetched artifact."""
    output_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for filename, model in SCHEMA_MODELS.items():
        path = output_dir / filename
        body = json.dumps(model.model_json_schema(), indent=2, sort_keys=True) + "\n"
        path.write_text(body, encoding="utf-8")
        written.append(path)
    return tuple(written)

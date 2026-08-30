"""Deterministic, validated artifact bundles for the SPY replay demo."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import pandas as pd
from pydantic import BaseModel

from intraday_quant.demo.contracts import (
    ArtifactReference,
    ChartBar,
    DirectionMetrics,
    Forecast,
    Manifest,
    MetricValue,
    ModelCard,
    Outcome,
    QualitySummary,
    ReplayRow,
    ReturnMetrics,
    ReturnMetricValue,
    SessionArtifact,
    SessionIndexArtifact,
    SessionIndexEntry,
    SessionProvenance,
    SplitSummary,
    SummaryArtifact,
)
from intraday_quant.demo.dataset import DatasetQualityReport, load_and_normalize_spy
from intraday_quant.demo.features import FEATURE_COLUMNS, SplitDefinition, build_examples
from intraday_quant.demo.modeling import (
    RAW_PROBABILITY_STATUS,
    VALIDATION_RESIDUAL_INTERVAL_STATUS,
    ModelBundle,
    evaluate_predictions,
    fit_models,
    fit_residual_interval,
    predict_examples,
)


CONTRACT_VERSION = "1.0.0"
CALENDAR_VERSION = "XNYS-exchange-calendars-v1"
FEATURE_VERSION = "spy-demo-features-v1"
DIRECTION_MODEL_VERSION = "sklearn-logistic-regression-v1"
RETURN_MODEL_VERSION = "sklearn-ridge-v1"
FIXTURE_GENERATED_AT = datetime(2026, 8, 19, 12, tzinfo=timezone.utc)
_EMPTY_HASH = "0" * 64
_HISTORICAL_CAVEATS = (
    "HISTORICAL_ONLY",
    "NOT_A_TRADING_SIGNAL",
    "RAW_EXPERIMENTAL_PROBABILITY",
    "EXPLORATORY_VALIDATION_RESIDUAL_INTERVAL",
)
_FIXTURE_CAVEATS = (
    "UI_FIXTURE",
    "EMBEDDED_SAMPLE_DATA",
    "NOT_A_TRADING_SIGNAL",
)


@dataclass(frozen=True)
class BundleBuildResult:
    """Internal build result used to create a truthful CLI receipt."""

    manifest: Manifest
    source_sessions: int


def canonical_json_bytes(value: BaseModel | dict[str, object]) -> bytes:
    """Serialize a contract model or JSON object with stable keys and whitespace."""
    payload = value.model_dump(mode="json") if isinstance(value, BaseModel) else value
    return (
        json.dumps(
            payload,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
            allow_nan=False,
        )
        + "\n"
    ).encode("utf-8")


def content_hash(value: BaseModel | dict[str, object]) -> str:
    """Return the SHA-256 digest of canonical JSON bytes."""
    return hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def atomic_write(path: Path, body: bytes) -> None:
    """Atomically replace one bundle file after its body is complete."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(body)
    temporary.replace(path)


def _file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _timestamp(value: object) -> datetime:
    parsed = pd.Timestamp(value)
    if parsed.tzinfo is None:
        parsed = parsed.tz_localize("UTC")
    else:
        parsed = parsed.tz_convert("UTC")
    return parsed.to_pydatetime()


def _direction(open_price: float, close_price: float) -> str:
    if close_price > open_price:
        return "UP"
    if close_price < open_price:
        return "DOWN"
    return "FLAT"


def _without_artifact_hash(value: Any) -> Any:
    if isinstance(value, dict):
        return {
            key: _without_artifact_hash(item)
            for key, item in value.items()
            if key != "artifact_sha256"
        }
    if isinstance(value, list):
        return [_without_artifact_hash(item) for item in value]
    if isinstance(value, tuple):
        return [_without_artifact_hash(item) for item in value]
    return value


def _replace_artifact_hash(model: BaseModel, artifact_sha256: str) -> dict[str, object]:
    payload = model.model_dump(mode="json")
    if "artifact_sha256" in payload:
        payload["artifact_sha256"] = artifact_sha256
    provenance = payload.get("provenance")
    if isinstance(provenance, dict) and "artifact_sha256" in provenance:
        provenance["artifact_sha256"] = artifact_sha256
    return payload


def _write_validated_bundle(
    *,
    output_dir: Path,
    generated_at: datetime,
    status: str,
    dataset_sha256: str,
    source_cutoff: datetime,
    availability_cutoff: datetime,
    split: SplitSummary,
    quality: QualitySummary,
    preliminary_summary: SummaryArtifact,
    preliminary_model_card: ModelCard,
    preliminary_sessions: tuple[SessionArtifact, ...],
    source_sessions: int,
) -> BundleBuildResult:
    """Finalize self hashes, validate every document, and publish the manifest last."""
    ordered_sessions = tuple(sorted(preliminary_sessions, key=lambda item: item.session_date))
    artifact_material: dict[str, object] = {
        "contract_version": CONTRACT_VERSION,
        "status": status,
        "dataset_sha256": dataset_sha256,
        "source_cutoff": _as_utc(source_cutoff).isoformat(),
        "availability_cutoff": _as_utc(availability_cutoff).isoformat(),
        "split": split.model_dump(mode="json"),
        "quality": quality.model_dump(mode="json"),
        "summary": _without_artifact_hash(preliminary_summary.model_dump(mode="json")),
        "model_card": _without_artifact_hash(preliminary_model_card.model_dump(mode="json")),
        "sessions": [
            _without_artifact_hash(session.model_dump(mode="json"))
            for session in ordered_sessions
        ],
    }
    artifact_sha256 = content_hash(artifact_material)

    summary = SummaryArtifact.model_validate(
        _replace_artifact_hash(preliminary_summary, artifact_sha256)
    )
    model_card = ModelCard.model_validate(
        _replace_artifact_hash(preliminary_model_card, artifact_sha256)
    )
    sessions = tuple(
        SessionArtifact.model_validate(_replace_artifact_hash(session, artifact_sha256))
        for session in ordered_sessions
    )
    if not sessions:
        raise ValueError("artifact bundle requires at least one replay session")

    session_documents: list[tuple[SessionArtifact, Path, bytes]] = []
    index_entries: list[SessionIndexEntry] = []
    for session in sessions:
        relative_path = Path("sessions") / f"{session.session_date.isoformat()}.json"
        body = canonical_json_bytes(session)
        session_documents.append((session, relative_path, body))
        index_entries.append(
            SessionIndexEntry(
                date=session.session_date,
                path=relative_path.as_posix(),
                sha256=hashlib.sha256(body).hexdigest(),
                rows=len(session.rows),
            )
        )

    index = SessionIndexArtifact(
        contract_version=CONTRACT_VERSION,
        artifact_sha256=artifact_sha256,
        sessions=tuple(index_entries),
    )
    index_body = canonical_json_bytes(index)
    manifest = Manifest(
        contract_version=CONTRACT_VERSION,
        status=status,
        symbol="SPY",
        generated_at=_as_utc(generated_at),
        dataset_sha256=dataset_sha256,
        artifact_sha256=artifact_sha256,
        source_cutoff=_as_utc(source_cutoff),
        availability_cutoff=_as_utc(availability_cutoff),
        feature_version=FEATURE_VERSION,
        direction_model_version=DIRECTION_MODEL_VERSION,
        return_model_version=RETURN_MODEL_VERSION,
        split=split,
        quality=quality,
        session_index=ArtifactReference(
            path="sessions/index.json",
            sha256=hashlib.sha256(index_body).hexdigest(),
        ),
        probability_status=RAW_PROBABILITY_STATUS,
        interval_status=VALIDATION_RESIDUAL_INTERVAL_STATUS,
        caveat_codes=_FIXTURE_CAVEATS if status == "UI_FIXTURE" else _HISTORICAL_CAVEATS,
    )

    expected_paths = {
        Path("manifest.json"),
        Path("summary.json"),
        Path("model-card.json"),
        Path("sessions/index.json"),
        *(relative_path for _, relative_path, _ in session_documents),
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    for existing in sorted(output_dir.rglob("*.json")):
        if existing.relative_to(output_dir) not in expected_paths:
            existing.unlink()

    atomic_write(output_dir / "summary.json", canonical_json_bytes(summary))
    atomic_write(output_dir / "model-card.json", canonical_json_bytes(model_card))
    for _, relative_path, body in session_documents:
        atomic_write(output_dir / relative_path, body)
    atomic_write(output_dir / "sessions" / "index.json", index_body)
    atomic_write(output_dir / "manifest.json", canonical_json_bytes(manifest))
    return BundleBuildResult(manifest=manifest, source_sessions=source_sessions)


def _split_summary(split: SplitDefinition) -> SplitSummary:
    return SplitSummary(
        train_start=split.train[0],
        train_end=split.train[-1],
        train_sessions=len(split.train),
        validation_start=split.validation[0],
        validation_end=split.validation[-1],
        validation_sessions=len(split.validation),
        test_start=split.test[0],
        test_end=split.test[-1],
        test_sessions=len(split.test),
        embargo_sessions=(split.train_validation_embargo, split.validation_test_embargo),
    )


def _quality_summary(
    report: DatasetQualityReport, eligible_examples: int, excluded_examples: int
) -> QualitySummary:
    return QualitySummary(
        source_rows=report.source_rows,
        normalized_rows=report.normalized_rows,
        eligible_examples=eligible_examples,
        excluded_examples=excluded_examples,
        causal_fill_rows=report.causal_fill_rows,
        unresolved_gap_rows=report.unresolved_gap_rows,
    )


def _summary(metrics: dict[str, float], quality: QualitySummary) -> SummaryArtifact:
    def direction_metric(name: str) -> MetricValue:
        return MetricValue(
            value=metrics[f"direction_{name}"],
            baseline=metrics[f"direction_{name}_baseline"],
            delta=metrics[f"direction_{name}_delta"],
        )

    def return_metric(name: str) -> ReturnMetricValue:
        return ReturnMetricValue(
            value=metrics[f"return_{name}"],
            zero_return_baseline=metrics[f"return_{name}_zero_return_baseline"],
            zero_return_delta=metrics[f"return_{name}_zero_return_delta"],
            momentum_baseline=metrics[f"return_{name}_momentum_baseline"],
            momentum_delta=metrics[f"return_{name}_momentum_delta"],
        )

    return SummaryArtifact(
        contract_version=CONTRACT_VERSION,
        artifact_sha256=_EMPTY_HASH,
        direction_metrics=DirectionMetrics(
            roc_auc=direction_metric("roc_auc"),
            brier_score=direction_metric("brier_score"),
            log_loss=direction_metric("log_loss"),
            calibration_error=direction_metric("calibration_error"),
            accuracy=direction_metric("accuracy"),
        ),
        return_metrics=ReturnMetrics(
            mae=return_metric("mae"),
            rmse=return_metric("rmse"),
        ),
        coverage=quality,
    )


def _model_card(bundle: ModelBundle, interval_examples: int) -> ModelCard:
    return ModelCard(
        contract_version=CONTRACT_VERSION,
        artifact_sha256=_EMPTY_HASH,
        horizon_minutes=5,
        feature_columns=FEATURE_COLUMNS,
        direction_model={
            "family": "LogisticRegression",
            "version": DIRECTION_MODEL_VERSION,
            "library": "scikit-learn",
            "library_version": bundle.sklearn_version,
            **bundle.direction_parameters,
        },
        return_model={
            "family": "Ridge",
            "version": RETURN_MODEL_VERSION,
            "library": "scikit-learn",
            "library_version": bundle.sklearn_version,
            "validation_examples": interval_examples,
            **bundle.return_parameters,
        },
        probability_status=RAW_PROBABILITY_STATUS,
        interval_status=VALIDATION_RESIDUAL_INTERVAL_STATUS,
        caveat_codes=_HISTORICAL_CAVEATS,
    )


def _source_label(bars: pd.DataFrame) -> str:
    labels = sorted(
        {
            str(value)
            for value in bars["source"].dropna().unique()
            if str(value) not in {"CAUSAL_FORWARD_FILL", "UNRESOLVED_GAP"}
        }
    )
    return "+".join(labels) if labels else "UNKNOWN_SOURCE"


def _chart_bars(session_bars: pd.DataFrame) -> tuple[ChartBar, ...]:
    result: list[ChartBar] = []
    for row in session_bars.itertuples(index=False):
        timestamp = _timestamp(row.timestamp)
        if bool(row.is_unresolved_gap):
            result.append(
                ChartBar(
                    timestamp=timestamp,
                    available_at=timestamp + timedelta(minutes=1),
                    open=None,
                    high=None,
                    low=None,
                    close=None,
                    volume=None,
                    direction="FLAT",
                    quality_flags=("UNRESOLVED_GAP",),
                )
            )
            continue

        open_price = float(row.open)
        close_price = float(row.close)
        volume = float(row.volume)
        if volume < 0.0 or not volume.is_integer():
            raise ValueError("complete chart bars require integral non-negative volume")
        flags = ("CAUSAL_FORWARD_FILL",) if bool(row.is_causal_fill) else ()
        result.append(
            ChartBar(
                timestamp=timestamp,
                available_at=timestamp + timedelta(minutes=1),
                open=open_price,
                high=float(row.high),
                low=float(row.low),
                close=close_price,
                volume=int(volume),
                direction=_direction(open_price, close_price),
                quality_flags=flags,
            )
        )
    return tuple(result)


def _session_artifact(
    *,
    session_date: date,
    session_bars: pd.DataFrame,
    predictions: pd.DataFrame,
    status: str,
    source: str,
    dataset: str,
    dataset_sha256: str,
) -> SessionArtifact:
    bars = _chart_bars(session_bars)
    bar_indices = {bar.timestamp: index for index, bar in enumerate(bars)}
    rows: list[ReplayRow] = []
    for prediction in predictions.sort_values("timestamp", kind="stable").itertuples(index=False):
        timestamp = _timestamp(prediction.timestamp)
        bar_index = bar_indices[timestamp]
        bar = bars[bar_index]
        if not bar.is_complete:
            raise ValueError("eligible replay prediction points to an unresolved chart bar")
        assert bar.open is not None
        assert bar.high is not None
        assert bar.low is not None
        assert bar.close is not None
        assert bar.volume is not None
        outcome_index = bar_index + 5
        if outcome_index >= len(bars) or not bars[outcome_index].is_complete:
            raise ValueError("eligible replay prediction requires a complete five-minute outcome bar")
        outcome_bar = bars[outcome_index]
        if _timestamp(prediction.outcome_timestamp) != outcome_bar.timestamp:
            raise ValueError("prediction outcome timestamp must match its five-minute chart bar")
        assert outcome_bar.close is not None
        rows.append(
            ReplayRow(
                bar_index=bar_index,
                timestamp=timestamp,
                available_at=bar.available_at,
                open=bar.open,
                high=bar.high,
                low=bar.low,
                close=bar.close,
                volume=bar.volume,
                forecast=Forecast(
                    probability_up=float(prediction.probability_up),
                    probability_status=str(prediction.probability_status),
                    expected_return_bps=float(prediction.expected_return_bps),
                    scenario_price=float(prediction.scenario_price),
                    interval_low=float(prediction.interval_low),
                    interval_high=float(prediction.interval_high),
                    interval_status=str(prediction.interval_status),
                    direction=str(prediction.direction),
                ),
                outcome=Outcome(
                    bar_index=outcome_index,
                    timestamp=outcome_bar.timestamp,
                    available_at=outcome_bar.available_at,
                    close=outcome_bar.close,
                    return_bps=float(prediction.outcome_return_bps),
                ),
                quality_flags=tuple(str(flag) for flag in prediction.quality_flags),
            )
        )

    unresolved = any("UNRESOLVED_GAP" in bar.quality_flags for bar in bars)
    filled = any("CAUSAL_FORWARD_FILL" in bar.quality_flags for bar in bars)
    coverage = (
        "PARTIAL_UNRESOLVED_GAPS"
        if unresolved
        else "COMPLETE_WITH_CAUSAL_FILLS"
        if filled
        else "COMPLETE"
    )
    caveats = _FIXTURE_CAVEATS if status == "UI_FIXTURE" else _HISTORICAL_CAVEATS
    actual_observations = session_bars.loc[
        ~session_bars["is_causal_fill"] & ~session_bars["is_unresolved_gap"],
        "timestamp",
    ]
    if actual_observations.empty:
        raise ValueError("replay session has no validated source observations")
    source_cutoff = _timestamp(actual_observations.max())
    return SessionArtifact(
        contract_version=CONTRACT_VERSION,
        status=status,
        symbol="SPY",
        session_date=session_date,
        provenance=SessionProvenance(
            source=source,
            dataset=dataset,
            dataset_sha256=dataset_sha256,
            artifact_sha256=_EMPTY_HASH,
            source_cutoff=source_cutoff,
            availability_cutoff=source_cutoff + timedelta(minutes=1),
            calendar_version=CALENDAR_VERSION,
            feature_version=FEATURE_VERSION,
            direction_model_version=DIRECTION_MODEL_VERSION,
            return_model_version=RETURN_MODEL_VERSION,
            coverage=coverage,
            caveat_codes=caveats,
        ),
        bars=bars,
        rows=tuple(rows),
    )


def _build_bundle(
    input_path: Path, output_dir: Path, generated_at: datetime
) -> BundleBuildResult:
    (output_dir / "manifest.json").unlink(missing_ok=True)
    if not input_path.is_file():
        raise FileNotFoundError(f"SPY Parquet input does not exist: {input_path}")

    dataset_sha256 = _file_sha256(input_path)
    normalized, report = load_and_normalize_spy(input_path)
    if report.first_timestamp is None or report.last_timestamp is None:
        raise ValueError("SPY Parquet input has no normalized XNYS minute bars")
    examples = build_examples(normalized)
    split = examples.attrs["split_definition"]
    train = examples.loc[examples["split"] == "train"].copy()
    validation = examples.loc[examples["split"] == "validation"].copy()
    test = examples.loc[examples["split"] == "test"].copy()
    if train.empty or validation.empty or test.empty:
        raise ValueError("normalized data must produce train, validation, and test examples")

    bundle = fit_models(train)
    interval = fit_residual_interval(bundle, validation)
    predictions = predict_examples(bundle, test, interval)
    metrics = evaluate_predictions(predictions, bundle.training_up_rate)
    quality = _quality_summary(
        report,
        eligible_examples=int(examples.attrs["eligible_examples"]),
        excluded_examples=int(examples.attrs["excluded_examples"]),
    )

    sessions: list[SessionArtifact] = []
    source = _source_label(normalized)
    for session_date in split.test:
        session_predictions = predictions.loc[predictions["session_date"] == session_date]
        if session_predictions.empty:
            continue
        session_bars = normalized.loc[normalized["session_date"] == session_date]
        sessions.append(
            _session_artifact(
                session_date=session_date,
                session_bars=session_bars,
                predictions=session_predictions,
                status="HISTORICAL_OOS",
                source=source,
                dataset=input_path.name,
                dataset_sha256=dataset_sha256,
            )
        )

    source_cutoff = _timestamp(report.last_timestamp)
    return _write_validated_bundle(
        output_dir=output_dir,
        generated_at=generated_at,
        status="HISTORICAL_OOS",
        dataset_sha256=dataset_sha256,
        source_cutoff=source_cutoff,
        availability_cutoff=source_cutoff + timedelta(minutes=1),
        split=_split_summary(split),
        quality=quality,
        preliminary_summary=_summary(metrics, quality),
        preliminary_model_card=_model_card(bundle, interval.validation_examples),
        preliminary_sessions=tuple(sessions),
        source_sessions=report.sessions,
    )


def build_bundle(input_path: Path, output_dir: Path, generated_at: datetime) -> Manifest:
    """Build the immutable historical replay bundle and return its manifest."""
    return _build_bundle(input_path, output_dir, generated_at).manifest


def _fixture_metrics() -> dict[str, float]:
    return {
        "direction_roc_auc": 0.5,
        "direction_roc_auc_baseline": 0.5,
        "direction_roc_auc_delta": 0.0,
        "direction_brier_score": 0.25,
        "direction_brier_score_baseline": 0.25,
        "direction_brier_score_delta": 0.0,
        "direction_log_loss": 0.6931471805599453,
        "direction_log_loss_baseline": 0.6931471805599453,
        "direction_log_loss_delta": 0.0,
        "direction_calibration_error": 0.1,
        "direction_calibration_error_baseline": 0.1,
        "direction_calibration_error_delta": 0.0,
        "direction_accuracy": 0.5,
        "direction_accuracy_baseline": 0.5,
        "direction_accuracy_delta": 0.0,
        "return_mae": 0.0002,
        "return_mae_zero_return_baseline": 0.0003,
        "return_mae_zero_return_delta": -0.0001,
        "return_mae_momentum_baseline": 0.0004,
        "return_mae_momentum_delta": -0.0002,
        "return_rmse": 0.00025,
        "return_rmse_zero_return_baseline": 0.00035,
        "return_rmse_zero_return_delta": -0.0001,
        "return_rmse_momentum_baseline": 0.00045,
        "return_rmse_momentum_delta": -0.0002,
    }


def _fixture_model_card() -> ModelCard:
    return ModelCard(
        contract_version=CONTRACT_VERSION,
        artifact_sha256=_EMPTY_HASH,
        horizon_minutes=5,
        feature_columns=FEATURE_COLUMNS,
        direction_model={
            "family": "UIFixtureLogistic",
            "version": DIRECTION_MODEL_VERSION,
            "library": "embedded-fixture",
            "library_version": "1",
        },
        return_model={
            "family": "UIFixtureRidge",
            "version": RETURN_MODEL_VERSION,
            "library": "embedded-fixture",
            "library_version": "1",
        },
        probability_status=RAW_PROBABILITY_STATUS,
        interval_status=VALIDATION_RESIDUAL_INTERVAL_STATUS,
        caveat_codes=_FIXTURE_CAVEATS,
    )


def _fixture_session(dataset_sha256: str) -> SessionArtifact:
    closes = (
        638.12,
        638.24,
        638.18,
        638.31,
        638.44,
        638.39,
        638.52,
        638.61,
        638.55,
        638.72,
        638.66,
        638.81,
        638.93,
        638.87,
        639.02,
        639.10,
    )
    start = datetime(2026, 7, 24, 14, 30, tzinfo=timezone.utc)
    bars: list[ChartBar] = []
    for index, close_price in enumerate(closes):
        open_price = closes[index - 1] if index else 638.05
        timestamp = start + timedelta(minutes=index)
        bars.append(
            ChartBar(
                timestamp=timestamp,
                available_at=timestamp + timedelta(minutes=1),
                open=open_price,
                high=max(open_price, close_price) + 0.06,
                low=min(open_price, close_price) - 0.06,
                close=close_price,
                volume=120_000 + index * 7_500,
                direction=_direction(open_price, close_price),
                quality_flags=(),
            )
        )

    rows: list[ReplayRow] = []
    for index, bar in enumerate(bars[:-5]):
        assert bar.open is not None
        assert bar.high is not None
        assert bar.low is not None
        assert bar.close is not None
        assert bar.volume is not None
        outcome_bar = bars[index + 5]
        assert outcome_bar.close is not None
        expected_return_bps = (2.5 + (index % 4)) * (1.0 if index % 3 else -1.0)
        expected_return = expected_return_bps / 10_000.0
        rows.append(
            ReplayRow(
                bar_index=index,
                timestamp=bar.timestamp,
                available_at=bar.available_at,
                open=bar.open,
                high=bar.high,
                low=bar.low,
                close=bar.close,
                volume=bar.volume,
                forecast=Forecast(
                    probability_up=0.58 if expected_return > 0.0 else 0.42,
                    probability_status=RAW_PROBABILITY_STATUS,
                    expected_return_bps=expected_return_bps,
                    scenario_price=bar.close * (1.0 + expected_return),
                    interval_low=bar.close * (1.0 + expected_return - 0.0008),
                    interval_high=bar.close * (1.0 + expected_return + 0.0009),
                    interval_status=VALIDATION_RESIDUAL_INTERVAL_STATUS,
                    direction="UP" if expected_return > 0.0 else "DOWN",
                ),
                outcome=Outcome(
                    bar_index=index + 5,
                    timestamp=outcome_bar.timestamp,
                    available_at=outcome_bar.available_at,
                    close=outcome_bar.close,
                    return_bps=(outcome_bar.close / bar.close - 1.0) * 10_000.0,
                ),
                quality_flags=(),
            )
        )

    last_timestamp = bars[-1].timestamp
    return SessionArtifact(
        contract_version=CONTRACT_VERSION,
        status="UI_FIXTURE",
        symbol="SPY",
        session_date=date(2026, 7, 24),
        provenance=SessionProvenance(
            source="EMBEDDED_UI_FIXTURE",
            dataset="spy-demo-ui-fixture-v1",
            dataset_sha256=dataset_sha256,
            artifact_sha256=_EMPTY_HASH,
            source_cutoff=last_timestamp,
            availability_cutoff=last_timestamp + timedelta(minutes=1),
            calendar_version=CALENDAR_VERSION,
            feature_version=FEATURE_VERSION,
            direction_model_version=DIRECTION_MODEL_VERSION,
            return_model_version=RETURN_MODEL_VERSION,
            coverage="UI_FIXTURE_COMPLETE",
            caveat_codes=_FIXTURE_CAVEATS,
        ),
        bars=tuple(bars),
        rows=tuple(rows),
    )


def _write_fixture(output_dir: Path, generated_at: datetime) -> BundleBuildResult:
    fixture_material: dict[str, object] = {
        "dataset": "spy-demo-ui-fixture-v1",
        "session_date": "2026-07-24",
        "closes": [
            638.12,
            638.24,
            638.18,
            638.31,
            638.44,
            638.39,
            638.52,
            638.61,
            638.55,
            638.72,
            638.66,
            638.81,
            638.93,
            638.87,
            639.02,
            639.10,
        ],
    }
    dataset_sha256 = content_hash(fixture_material)
    session = _fixture_session(dataset_sha256)
    quality = QualitySummary(
        source_rows=len(session.bars),
        normalized_rows=len(session.bars),
        eligible_examples=len(session.rows),
        excluded_examples=len(session.bars) - len(session.rows),
        causal_fill_rows=0,
        unresolved_gap_rows=0,
    )
    fixture_date = session.session_date
    split = SplitSummary(
        train_start=fixture_date,
        train_end=fixture_date,
        train_sessions=1,
        validation_start=fixture_date,
        validation_end=fixture_date,
        validation_sessions=1,
        test_start=fixture_date,
        test_end=fixture_date,
        test_sessions=1,
        embargo_sessions=(fixture_date, fixture_date),
    )
    return _write_validated_bundle(
        output_dir=output_dir,
        generated_at=generated_at,
        status="UI_FIXTURE",
        dataset_sha256=dataset_sha256,
        source_cutoff=session.provenance.source_cutoff,
        availability_cutoff=session.provenance.availability_cutoff,
        split=split,
        quality=quality,
        preliminary_summary=_summary(_fixture_metrics(), quality),
        preliminary_model_card=_fixture_model_card(),
        preliminary_sessions=(session,),
        source_sessions=1,
    )


def write_fixture(output_dir: Path) -> Manifest:
    """Write the fixed, visibly labeled UI fixture bundle."""
    return _write_fixture(output_dir, FIXTURE_GENERATED_AT).manifest


__all__ = [
    "atomic_write",
    "build_bundle",
    "canonical_json_bytes",
    "content_hash",
    "write_fixture",
]

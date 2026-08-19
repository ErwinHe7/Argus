from datetime import datetime, timezone
from pathlib import Path

import pytest
from pydantic import ValidationError

from intraday_quant.demo.contracts import (
    ChartBar,
    Manifest,
    SessionArtifact,
    SessionIndexArtifact,
    write_json_schemas,
)


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
            "train_start": "2024-07-18",
            "train_end": "2025-12-12",
            "train_sessions": 354,
            "validation_start": "2025-12-16",
            "validation_end": "2026-04-06",
            "validation_sessions": 75,
            "test_start": "2026-04-08",
            "test_end": "2026-07-24",
            "test_sessions": 75,
            "embargo_sessions": ["2025-12-15", "2026-04-07"],
        },
        "quality": {
            "source_rows": 196539,
            "normalized_rows": 195000,
            "eligible_examples": 180000,
            "excluded_examples": 15000,
            "causal_fill_rows": 2,
            "unresolved_gap_rows": 1,
        },
        "session_index": {"path": "sessions/index.json", "sha256": "c" * 64},
        "probability_status": "RAW_EXPERIMENTAL_PROBABILITY",
        "interval_status": "EXPLORATORY_VALIDATION_RESIDUAL_INTERVAL",
        "caveat_codes": ["HISTORICAL_ONLY", "NOT_A_TRADING_SIGNAL"],
    }


def _complete_bar(minute: int, **changes: object) -> dict[str, object]:
    payload: dict[str, object] = {
        "timestamp": f"2026-07-24T19:{minute:02d}:00Z",
        "available_at": f"2026-07-24T19:{minute:02d}:30Z",
        "open": 600.0,
        "high": 602.0,
        "low": 599.0,
        "close": 601.0,
        "volume": 100,
        "direction": "UP",
        "quality_flags": [],
    }
    payload.update(changes)
    return payload


def _session_payload() -> dict[str, object]:
    bars = [_complete_bar(minute) for minute in range(6)]
    return {
        "contract_version": "1.0.0",
        "status": "HISTORICAL_OOS",
        "symbol": "SPY",
        "session_date": "2026-07-24",
        "provenance": {
            "source": "Databento",
            "dataset": "spy-minute-bars",
            "dataset_sha256": "a" * 64,
            "artifact_sha256": "b" * 64,
            "source_cutoff": "2026-07-24T19:59:00Z",
            "availability_cutoff": "2026-07-24T20:00:00Z",
            "calendar_version": "XNYS-2026.1",
            "feature_version": "spy-demo-features-v1",
            "direction_model_version": "logistic-v1",
            "return_model_version": "ridge-v1",
            "coverage": "COMPLETE",
            "caveat_codes": ["HISTORICAL_ONLY"],
        },
        "bars": bars,
        "rows": [
            {
                "bar_index": 0,
                "timestamp": "2026-07-24T19:00:00Z",
                "available_at": "2026-07-24T19:00:30Z",
                "open": 600.0,
                "high": 602.0,
                "low": 599.0,
                "close": 601.0,
                "volume": 100,
                "forecast": {
                    "probability_up": 0.6,
                    "probability_status": "RAW_EXPERIMENTAL_PROBABILITY",
                    "expected_return_bps": 3.0,
                    "scenario_price": 601.2,
                    "interval_low": 600.5,
                    "interval_high": 602.0,
                    "interval_status": "EXPLORATORY_VALIDATION_RESIDUAL_INTERVAL",
                    "direction": "UP",
                },
                "outcome": {
                    "timestamp": "2026-07-24T19:05:00Z",
                    "close": 601.5,
                    "return_bps": 8.3,
                },
                "quality_flags": [],
            }
        ],
    }


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


def test_forecast_interval_must_contain_scenario_price() -> None:
    payload = _session_payload()
    payload["rows"][0]["forecast"]["scenario_price"] = 603.0  # type: ignore[index]
    with pytest.raises(ValidationError, match="interval"):
        SessionArtifact.model_validate(payload)


def test_chart_bar_requires_unresolved_gap_for_null_ohlcv() -> None:
    with pytest.raises(ValidationError, match="UNRESOLVED_GAP"):
        ChartBar.model_validate(_complete_bar(0, close=None))


def test_session_rejects_unsorted_bars() -> None:
    payload = _session_payload()
    payload["bars"] = list(reversed(payload["bars"]))
    with pytest.raises(ValidationError, match="sorted"):
        SessionArtifact.model_validate(payload)


def test_session_replay_must_match_chart_bar_and_five_minute_outcome() -> None:
    payload = _session_payload()
    payload["rows"][0]["close"] = 600.5  # type: ignore[index]
    with pytest.raises(ValidationError, match="match its complete chart bar"):
        SessionArtifact.model_validate(payload)

    payload = _session_payload()
    payload["rows"][0]["outcome"]["timestamp"] = "2026-07-24T19:04:00Z"  # type: ignore[index]
    with pytest.raises(ValidationError, match="five chart minutes"):
        SessionArtifact.model_validate(payload)


def test_session_index_paths_dates_and_order_must_match() -> None:
    payload = {
        "contract_version": "1.0.0",
        "artifact_sha256": "a" * 64,
        "sessions": [
            {"date": "2026-07-25", "path": "sessions/2026-07-24.json", "sha256": "b" * 64, "rows": 1}
        ],
    }
    with pytest.raises(ValidationError, match="path date"):
        SessionIndexArtifact.model_validate(payload)

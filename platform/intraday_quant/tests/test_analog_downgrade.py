from pathlib import Path

import pandas as pd
import pytest

from intraday_quant.config import AppConfig, ValidationEvidenceConfig, load_config
from intraday_quant.models.analog_kernel import (
    AnalogKernelModel,
    LegacyExploratoryEuclideanAnalogModel,
)
from intraday_quant.models.constants import (
    LEGACY_EXPLORATORY_ANALOG_MODEL_NAME,
    LEGACY_EXPLORATORY_ANALOG_PROMOTION_BLOCKER,
    RETIRED_PYTHON_ANALOG_MODEL_NAME,
)
from intraday_quant.models.specification import model_specification
from intraday_quant.portfolio.selector import score_and_select


def test_shipped_configs_exclude_both_legacy_and_retired_analog_names():
    config_dir = Path(__file__).parents[1] / "configs"
    for name in ("default.yaml", "yahoo_recent.yaml"):
        config = load_config(config_dir / name)
        assert RETIRED_PYTHON_ANALOG_MODEL_NAME not in config.models
        assert LEGACY_EXPLORATORY_ANALOG_MODEL_NAME not in config.models
        assert config.models == ["logistic", "gradient_boosting"]


def test_retired_ambiguous_analog_name_is_rejected(config):
    payload = config.model_dump()
    payload["models"] = [RETIRED_PYTHON_ANALOG_MODEL_NAME]
    with pytest.raises(ValueError, match="is retired"):
        AppConfig.model_validate(payload)


def test_validation_evidence_requires_complete_hash_manifest_pairs():
    with pytest.raises(ValueError, match="must be supplied together"):
        ValidationEvidenceConfig(
            untouched_holdout_trades_path="holdout.parquet"
        )
    with pytest.raises(ValueError, match="must be supplied together"):
        ValidationEvidenceConfig(
            point_in_time_market_manifest_path="market-baseline.json"
        )
    configured = ValidationEvidenceConfig(
        untouched_holdout_trades_path="holdout.parquet",
        untouched_holdout_manifest_path="holdout.json",
        point_in_time_market_grid_path="market.parquet",
        point_in_time_market_manifest_path="market.json",
    )
    assert configured.untouched_holdout_manifest_path == "holdout.json"


def test_legacy_estimator_is_explicitly_non_parity_and_non_promotion(config):
    assert AnalogKernelModel is LegacyExploratoryEuclideanAnalogModel
    assert LegacyExploratoryEuclideanAnalogModel.promotion_eligible is False
    assert LegacyExploratoryEuclideanAnalogModel.production_parity is False
    assert (
        LegacyExploratoryEuclideanAnalogModel.promotion_blocker
        == LEGACY_EXPLORATORY_ANALOG_PROMOTION_BLOCKER
    )

    payload = config.model_dump()
    payload["models"] = [LEGACY_EXPLORATORY_ANALOG_MODEL_NAME]
    explicit = AppConfig.model_validate(payload)
    specification = model_specification(explicit)
    legacy = specification[LEGACY_EXPLORATORY_ANALOG_MODEL_NAME]
    assert legacy["promotion_eligible"] is False
    assert legacy["production_parity"] is False
    assert specification["canonical_serving_analog"]["language"] == "Rust"
    assert LEGACY_EXPLORATORY_ANALOG_MODEL_NAME in specification["ensemble"]["excluded_from_aggregation"]


def test_non_promotion_legacy_rows_cannot_create_selected_candidates(config):
    timestamp = pd.Timestamp("2026-01-05 10:00", tz="America/New_York")
    candidates = pd.DataFrame([{
        "candidate_id": "legacy-only",
        "timestamp": timestamp,
        "session_date": timestamp.date(),
        "setup_type": "test",
        "direction": 1,
        "entry_reference": 100.0,
        "feature_snapshot": "{}",
        "reason_codes": "test",
    }])
    predictions = pd.DataFrame([{
        "candidate_id": "legacy-only",
        "timestamp": timestamp,
        "fold": 0,
        "horizon_minutes": 15,
        "model": LEGACY_EXPLORATORY_ANALOG_MODEL_NAME,
        "expected_return": 0.10,
        "median_return": 0.10,
        "win_probability": 0.99,
        "predicted_mfe": 0.12,
        "predicted_mae": 0.001,
        "uncertainty": 0.001,
        "similarity_score": 0.99,
        "validation_return_threshold": 0.001,
        "promotion_eligible": False,
        "production_parity": False,
        "promotion_blocker": LEGACY_EXPLORATORY_ANALOG_PROMOTION_BLOCKER,
    }])

    selected, rejected = score_and_select(predictions, candidates, config)

    assert selected.empty
    assert rejected["rejection_reason"].tolist() == [
        "no_promotion_eligible_out_of_sample_prediction"
    ]

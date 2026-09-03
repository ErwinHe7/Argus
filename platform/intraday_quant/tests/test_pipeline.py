from pathlib import Path

import pandas as pd

from intraday_quant.cli import run_all
from intraday_quant.models.constants import (
    LEGACY_EXPLORATORY_ANALOG_MODEL_NAME,
    RETIRED_PYTHON_ANALOG_MODEL_NAME,
)


def test_synthetic_pipeline_runs_end_to_end(config, tmp_path):
    cfg = config.model_copy(update={"data": config.data.model_copy(update={"output_dir": str(tmp_path), "synthetic_sessions": 50})})
    report = run_all(cfg)
    assert report.exists()
    assert (tmp_path / "cleaned" / "bars.parquet").exists()
    assert (tmp_path / "cleaned" / "session_integrity.csv").exists()
    assert (tmp_path / "cleaned" / "ingest_integrity.json").exists()
    assert (tmp_path / "models" / "predictions.parquet").exists()
    assert (tmp_path / "reports" / "trade_blotter.csv").exists()
    predictions = pd.read_parquet(tmp_path / "models" / "predictions.parquet")
    assert not predictions.empty
    assert RETIRED_PYTHON_ANALOG_MODEL_NAME not in set(predictions["model"])
    assert LEGACY_EXPLORATORY_ANALOG_MODEL_NAME not in set(predictions["model"])
    assert set(predictions["model"]) == {"logistic", "gradient_boosting"}
    assert "SYNTHETIC VALIDATION" in Path(report).read_text(encoding="utf-8")

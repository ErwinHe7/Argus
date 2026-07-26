from pathlib import Path

from intraday_quant.cli import run_all


def test_synthetic_pipeline_runs_end_to_end(config, tmp_path):
    cfg = config.model_copy(update={"data": config.data.model_copy(update={"output_dir": str(tmp_path), "synthetic_sessions": 50})})
    report = run_all(cfg)
    assert report.exists()
    assert (tmp_path / "cleaned" / "bars.parquet").exists()
    assert (tmp_path / "models" / "predictions.parquet").exists()
    assert (tmp_path / "reports" / "trade_blotter.csv").exists()
    assert "SYNTHETIC VALIDATION" in Path(report).read_text(encoding="utf-8")

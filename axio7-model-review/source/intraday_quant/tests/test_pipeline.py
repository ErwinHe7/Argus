from pathlib import Path
import json

import pandas as pd

from intraday_quant.cli import run_all
from intraday_quant.config import load_config


def test_synthetic_pipeline_runs_end_to_end(tmp_path):
    # The standalone Rust bridge integration is tested against the real binary
    # in test_analog_backtest_bridge.py. This local end-to-end test exercises the
    # complete documented cost-aware pipeline without pretending that its
    # cleaned parquet is a quantctl-normalized CSV.
    config = load_config(Path(__file__).parents[1] / "configs" / "cost_aware_research.yaml")
    cfg = config.model_copy(update={"data": config.data.model_copy(update={"output_dir": str(tmp_path)})})
    report = run_all(cfg)
    assert report.exists()
    assert (tmp_path / "cleaned" / "bars.parquet").exists()
    assert (tmp_path / "models" / "predictions.parquet").exists()
    assert (tmp_path / "reports" / "trade_blotter.csv").exists()
    assert "SYNTHETIC VALIDATION" in Path(report).read_text(encoding="utf-8")
    audit = json.loads((tmp_path / "reports" / "cost_audit.json").read_text(encoding="utf-8"))
    assert audit["status"] == "RESEARCH_ASSUMPTIONS_NOT_CALIBRATED"
    assert audit["assumptions"]["full_spread_bps"] == 2
    assert (tmp_path / "reports" / "execution_rejections.csv").exists()
    trades = pd.read_parquet(tmp_path / "reports" / "trade_blotter.parquet")
    if not trades.empty:
        assert trades.capacity_status.eq("prior_bar_proxy_checked").all()
        assert (trades.entry_time > trades.signal_time).all()
        assert (trades.exit_time > trades.entry_time).all()

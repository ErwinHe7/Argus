"""M3 fix: walk_forward.py's analog_kernel path calls the real production
kernel (quantctl research analog-backtest) instead of maintaining its own
divergent approximation. See models/analog_kernel.py's module docstring and
review-package/REMEDIATION-PLAN.zh-CN.md M3.

Skips cleanly if the quant_engine_rs binary isn't built -- same pattern as
test_cuda_challenger.py skipping when torch isn't installed. This is an
external-binary integration test, not something that should ever silently
fall back to the retired Python estimator on failure.
"""

from __future__ import annotations

import csv
import datetime as dt
import json
import shutil
from pathlib import Path

import pandas as pd
import pytest

from intraday_quant.config import AppConfig, DataConfig, ModelConfig
from intraday_quant.models.walk_forward import AnalogBacktestUnavailable, _run_analog_backtest


def _find_quantctl() -> str | None:
    found = shutil.which("quantctl")
    if found:
        return found
    guess = (
        Path(__file__).resolve().parents[2]
        / "quant_engine_rs"
        / "target"
        / "debug"
        / "quantctl.exe"
    )
    return str(guess) if guess.exists() else None


def _write_synthetic_bars(path: Path, sessions: int = 9) -> dt.date:
    """Two alternating regimes, `sessions` weekday sessions of 1-minute bars."""
    fieldnames = [
        "timestamp", "symbol", "open", "high", "low", "close", "volume",
        "vwap", "bid", "ask", "trade_count", "source", "data_quality",
    ]
    rows = []
    base = dt.date(2026, 6, 1)
    day = 0
    written = 0
    last_date = base
    while written < sessions:
        current = base + dt.timedelta(days=day)
        day += 1
        if current.weekday() >= 5:
            continue
        written += 1
        last_date = current
        regime = 1.0 if written % 2 == 0 else -1.0
        start = dt.datetime(current.year, current.month, current.day, 14, 30, tzinfo=dt.timezone.utc)
        price = 100.0
        for minute in range(390):
            ts = start + dt.timedelta(minutes=minute)
            price += regime * 0.01 + (0.001 if minute % 7 == 0 else -0.0005)
            rows.append({
                "timestamp": ts.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "symbol": "SPY",
                "open": round(price, 4), "high": round(price + 0.05, 4),
                "low": round(price - 0.05, 4), "close": round(price, 4),
                "volume": 1000 + (minute % 13) * 10,
                "vwap": round(price, 4), "bid": round(price - 0.01, 4),
                "ask": round(price + 0.01, 4), "trade_count": 10,
                "source": "TEST", "data_quality": "ok",
            })
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    return last_date


def test_bridge_calls_the_real_kernel_and_returns_one_row_per_queried_state(tmp_path: Path) -> None:
    quantctl = _find_quantctl()
    if quantctl is None:
        pytest.skip("quantctl binary not built (cargo build --bin quantctl in quant_engine_rs)")

    bars_dir = tmp_path / "normalized"
    bars_dir.mkdir()
    last_session = _write_synthetic_bars(bars_dir / "market_bars.csv", sessions=9)
    query_day = last_session

    production_config = (
        Path(__file__).resolve().parents[2] / "quant_engine_rs" / "configs" / "production.yaml"
    )
    config = AppConfig(
        target="SPY",
        symbols=["SPY"],
        setups=["momentum"],
        models=["analog_kernel"],
        start_date="2026-06-01",
        end_date=query_day.isoformat(),
        model=ModelConfig(
            analog_backtest_quantctl_binary=quantctl,
            analog_backtest_bars_path=str(bars_dir / "market_bars.csv"),
            analog_backtest_config_path=(
                str(production_config) if production_config.exists() else None
            ),
        ),
    )

    result = _run_analog_backtest(
        test_dates=[query_day.isoformat()],
        horizon=15,
        target="SPY",
        config=config,
    )

    # One row per one-minute state quantctl queried on the target session.
    # Not exactly 390: features::build_states trims rows near the session
    # boundary that don't yet have a full rolling-feature warm-up window --
    # that's real Rust-side feature engineering behavior, not something this
    # bridge should predict exactly.
    assert 300 <= len(result) <= 390
    expected_columns = {
        "timestamp", "expected_return", "median_return", "win_probability",
        "predicted_mfe", "predicted_mae", "neighbor_count", "similarity_score",
        "uncertainty", "neighbor_dates", "analog_backtest_status",
    }
    assert expected_columns.issubset(result.columns)
    # Every status quantctl can legitimately return here is a real,
    # documented gate outcome -- not silently defaulted or coerced.
    assert result["analog_backtest_status"].notna().all()
    assert (result["win_probability"].between(0.0, 1.0)).all()


def test_bridge_raises_rather_than_falling_back_when_bars_are_missing(tmp_path: Path) -> None:
    """The whole point of M3: no bars -> no silent fallback to the retired
    Python approximation, just a clear, actionable error."""
    config = AppConfig(
        target="SPY",
        symbols=["SPY"],
        setups=["momentum"],
        models=["analog_kernel"],
        start_date="2026-06-01",
        end_date="2026-06-11",
        model=ModelConfig(
            analog_backtest_quantctl_binary="quantctl",
            analog_backtest_bars_path=str(tmp_path / "does_not_exist.csv"),
        ),
    )
    with pytest.raises(AnalogBacktestUnavailable, match="normalized bars"):
        _run_analog_backtest(
            test_dates=["2026-06-10"],
            horizon=15,
            target="SPY",
            config=config,
        )


def test_research_export_cutoff_is_parsed_and_joined_to_completed_bar_label(tmp_path: Path, monkeypatch) -> None:
    """Unit-test only the transport decoder; real Rust integration remains above."""
    bars = tmp_path / "decoder-only-bars.csv"
    bars.write_text("timestamp,symbol\n", encoding="utf-8")

    def write_transport_fixture(command, **kwargs):
        path = Path(command[command.index("--output") + 1])
        path.write_text(json.dumps([{
            "decision_as_of": "2026-06-11T14:01:00Z", "status": "OK",
            "distribution": {"kernel_weighted_mean": .001, "probability_up": .6,
                             "average_mfe": .002, "average_mae": .001, "dispersion": .0005},
            "diagnostics": {}, "top_analogs": [],
        }]), encoding="utf-8")

    monkeypatch.setattr("intraday_quant.models.walk_forward.subprocess.run", write_transport_fixture)
    config = AppConfig(target="SPY", symbols=["SPY"], setups=[], models=["analog_kernel"],
                       start_date="2026-06-01", end_date="2026-06-11",
                       model=ModelConfig(analog_backtest_bars_path=str(bars)))
    result = _run_analog_backtest(["2026-06-11"], 5, "SPY", config)
    assert result.iloc[0].decision_as_of == pd.Timestamp("2026-06-11 10:01", tz="America/New_York")
    assert result.iloc[0].timestamp == pd.Timestamp("2026-06-11 10:00", tz="America/New_York")

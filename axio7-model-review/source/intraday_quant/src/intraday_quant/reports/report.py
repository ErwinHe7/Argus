from __future__ import annotations

import html
import json
import os
from pathlib import Path

os.environ.setdefault("MPLCONFIGDIR", str(Path(__file__).resolve().parents[3] / "data" / ".matplotlib"))

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from intraday_quant.backtest.metrics import performance_metrics
from intraday_quant.reports.cost_audit import cost_audit
from intraday_quant.config import AppConfig
from intraday_quant.reports.theory_audit import THEORY_MAP, hypothesis_event_audit, theory_performance_audit


def _table(frame: pd.DataFrame, limit: int = 20) -> str:
    if frame.empty:
        return "_None_"
    return frame.head(limit).to_markdown(index=False)


def _charts(trades: pd.DataFrame, report_dir: Path) -> list[str]:
    paths: list[str] = []
    if trades.empty:
        return paths
    daily = trades.groupby("date")["net_return"].sum().sort_index()
    equity = (1 + daily).cumprod()
    drawdown = equity / equity.cummax() - 1
    for name, series, title in [
        ("equity_curve.png", equity, "Out-of-sample net equity"),
        ("drawdown_curve.png", drawdown, "Drawdown"),
    ]:
        fig, ax = plt.subplots(figsize=(9, 3.5))
        ax.plot(pd.to_datetime(series.index), series.values, color="#2563eb", linewidth=1.5)
        ax.set_title(title)
        ax.grid(alpha=0.25)
        fig.tight_layout()
        fig.savefig(report_dir / name, dpi=140)
        plt.close(fig)
        paths.append(name)
    monthly = trades.assign(month=pd.to_datetime(trades["date"]).dt.to_period("M")).groupby("month")["net_return"].sum()
    fig, ax = plt.subplots(figsize=(9, 2.5))
    ax.bar(monthly.index.astype(str), monthly.values, color=np.where(monthly.values >= 0, "#16a34a", "#dc2626"))
    ax.set_title("Monthly net returns")
    ax.tick_params(axis="x", rotation=45)
    fig.tight_layout()
    fig.savefig(report_dir / "monthly_returns.png", dpi=140)
    plt.close(fig)
    paths.append("monthly_returns.png")
    return paths


def generate_report(config: AppConfig, ingest_stats: dict[str, int] | None = None, option_status: str | None = None) -> Path:
    report_dir = config.output_dir / "reports"
    report_dir.mkdir(parents=True, exist_ok=True)
    features = pd.read_parquet(config.output_dir / "features" / "features.parquet")
    candidates = pd.read_parquet(config.output_dir / "features" / "candidates.parquet")
    labels = pd.read_parquet(config.output_dir / "features" / "labels.parquet")
    predictions = pd.read_parquet(config.output_dir / "models" / "predictions.parquet")
    diagnostics_path = config.output_dir / "models" / "fold_diagnostics.csv"
    diagnostics = pd.read_csv(diagnostics_path) if diagnostics_path.exists() else pd.DataFrame()
    trades_path = report_dir / "trade_blotter.parquet"
    rejected_path = report_dir / "rejected_candidates.parquet"
    trades = pd.read_parquet(trades_path) if trades_path.exists() else pd.DataFrame()
    rejected = pd.read_parquet(rejected_path) if rejected_path.exists() else pd.DataFrame()
    metrics = performance_metrics(trades, sorted(candidates.get("session_date", pd.Series(dtype=object)).unique()))
    theory_audit = theory_performance_audit(trades)
    theory_audit.to_csv(report_dir / "theory_performance_audit.csv", index=False)
    hypothesis_audit = hypothesis_event_audit(labels)
    hypothesis_audit.to_csv(report_dir / "hypothesis_event_audit.csv", index=False)
    chart_paths = _charts(trades, report_dir)
    source_counts = features.get("source", pd.Series(dtype=str)).value_counts().rename_axis("source").reset_index(name="rows")
    quality_counts = features.get("feature_quality", pd.Series(dtype=str)).value_counts().rename_axis("quality").reset_index(name="rows")
    setup_counts = candidates.get("setup_type", pd.Series(dtype=str)).value_counts().rename_axis("setup").reset_index(name="candidates")
    setup_perf = trades.groupby("setup").agg(
        trades=("trade_id", "count"), net_return=("net_return", "sum"),
        win_rate=("net_return", lambda s: (s > 0).mean()),
    ).reset_index() if not trades.empty else pd.DataFrame()
    time_perf = pd.DataFrame()
    if not trades.empty:
        timed = trades.copy()
        hour = pd.to_datetime(timed["signal_time"]).dt.hour
        timed["time_bucket"] = np.select([hour < 11, hour < 14], ["morning", "midday"], default="afternoon")
        time_perf = timed.groupby("time_bucket").agg(trades=("trade_id", "count"), net_return=("net_return", "sum")).reset_index()
    best = trades.nlargest(5, "net_return") if not trades.empty else pd.DataFrame()
    worst = trades.nsmallest(5, "net_return") if not trades.empty else pd.DataFrame()
    cost_summary = pd.DataFrame([{
        "gross_pnl": float(trades["gross_pnl"].sum()) if not trades.empty else 0,
        "cost": float(trades["cost"].sum()) if not trades.empty else 0,
        "net_pnl": float(trades["net_pnl"].sum()) if not trades.empty else 0,
    }])
    costs = cost_audit(trades, config)
    (report_dir / "cost_audit.json").write_text(json.dumps(costs, indent=2, allow_nan=False), encoding="utf-8")
    cost_scenarios = pd.DataFrame(costs["cost_scenarios"])
    analog = predictions[predictions.get("model", "") == "analog_kernel"] if not predictions.empty else pd.DataFrame()
    sources = set(features.get("source", pd.Series(dtype=str)).dropna().astype(str))
    is_synthetic = not sources or sources == {"synthetic"}
    if is_synthetic:
        report_banner = "> **SYNTHETIC VALIDATION — NOT A REAL HISTORICAL PERFORMANCE CLAIM**"
        data_assumption = "Deterministic synthetic bars validate software behavior but cannot establish a tradable edge."
    else:
        report_banner = "> **RECENT UNOFFICIAL PRICE-DATA OOS CHECK — NOT A PRODUCTION-GRADE BACKTEST**"
        data_assumption = f"Sources: {sorted(sources)}. Coverage is short and lacks historical executable NBBO."
    assumptions = [
        data_assumption,
        "Minute labels identify interval starts; closing features become available at label + one minute. Fills use the first bar open at or after that actual cutoff plus latency (zero latency is an explicitly idealized boundary fill).",
        "Same-minute stop/target collisions resolve to the stop first (conservative).",
        "Transaction costs are explicit uncalibrated research assumptions. Capacity uses prior completed same-symbol share volume when enabled; it does not prove executable liquidity.",
        option_status or "Options backtest not executed: real historical NBBO data is absent.",
    ]
    lines = [
        "# Intraday Quant Research Report", "", report_banner, "",
        "## 1. Data coverage and quality", "",
        f"Coverage: `{features['timestamp'].min()}` to `{features['timestamp'].max()}`; rows: {len(features):,}.", "",
        _table(source_counts), "", _table(quality_counts), "",
        f"Ingest statistics: `{json.dumps(ingest_stats or {}, ensure_ascii=False)}`", "",
        "## 2. Feature definitions", "",
        "All price, same-minute RVOL, cross-asset, session-level, closing-pressure and time features use timestamp t or earlier only.", "",
        "## 3. Candidates", "", _table(setup_counts), "",
        f"Total candidates: **{len(candidates)}**; rejected OOS candidates: **{len(rejected)}**.", "",
        "## 4. Models and probability calibration", "", _table(diagnostics), "",
        "Validation Brier scores are calibration-fit diagnostics measured on the calibration fitting partition, not independent calibration evidence. Analog upward probabilities remain raw frequencies and are excluded from the strategy ensemble until cost-label semantics are separately validated.", "",
        "## 5. Walk-forward out-of-sample performance", "", "```json", json.dumps(metrics, indent=2), "```", "",
        "Only test-fold trades are included; validation data chooses thresholds without test-outcome tuning.", "",
        "## 6. Gross, costs, and net", "", _table(cost_summary), "",
        "### Cost stress and break-even", "", _table(cost_scenarios), "",
        f"Break-even cost multiplier: `{costs['break_even_cost_multiplier']}`; capacity status: `{costs['capacity_status']}`. Detailed component totals and assumptions: `cost_audit.json`.", "",
        "Stress holds the test trade sample and fills fixed. These scenarios do not retune models or prove realizable execution.", "",
        "## 7. Setup and time-of-day stability", "", _table(setup_perf), "", _table(time_perf), "",
        "## 8. Simons-style theory audit", "", _table(THEORY_MAP, 20), "",
        "### Strict OOS selected trades", "", _table(theory_audit, 20), "",
        "### Hypothesis-formation event diagnostics (not OOS)", "", _table(hypothesis_audit, 20), "",
        "Win rate alone is not an edge. Compare it with break-even win rate, payoff ratio, costs and the confidence interval. `insufficient_sample` is not a positive finding.", "",
        "## 9. Charts", "",
    ]
    lines.extend([f"![{path}]({path})" for path in chart_paths])
    lines.extend([
        "", "## 10. Analog historical cases", "",
        _table(analog[[c for c in ["timestamp", "direction", "expected_return", "raw_up_probability", "win_probability", "probability_semantics", "strategy_eligibility", "similarity_score", "uncertainty", "neighbor_dates"] if c in analog]], 10), "",
        "## 11. Best and worst trades", "", "### Best", "", _table(best), "", "### Worst", "", _table(worst), "",
        "## 12. Rejected candidates", "",
        _table(rejected[[c for c in ["timestamp", "setup_type", "direction", "score", "rejection_reason"] if c in rejected]], 30), "",
        "## 13. Assumptions and limitations", "",
    ])
    lines.extend([f"- {item}" for item in assumptions])
    lines.extend([
        "", "Baseline comparison: zero-return cash. A durable conclusion requires years of licensed minute data across regimes.",
        "Feature stability is represented by fold diagnostics; the recent Yahoo window is far too short for annual or crisis-regime claims.",
    ])
    markdown = "\n".join(lines)
    md_path = report_dir / "research_report.md"
    md_path.write_text(markdown, encoding="utf-8")
    html_path = report_dir / "research_report.html"
    html_path.write_text(
        f"<!doctype html><meta charset='utf-8'><title>Intraday Quant Report</title>"
        f"<style>body{{font:15px system-ui;max-width:1100px;margin:40px auto;line-height:1.5}}pre{{white-space:pre-wrap}}</style>"
        f"<pre>{html.escape(markdown)}</pre>", encoding="utf-8",
    )
    (report_dir / "metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    return md_path

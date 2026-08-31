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
from intraday_quant.backtest.validation import build_validation_metrics
from intraday_quant.config import AppConfig
from intraday_quant.models.constants import LEGACY_EXPLORATORY_ANALOG_MODEL_NAME
from intraday_quant.reports.theory_audit import THEORY_MAP, hypothesis_event_audit, theory_performance_audit


def _evidence_path(config: AppConfig, value: str | None) -> Path | None:
    if value is None:
        return None
    path = Path(value)
    return path if path.is_absolute() else config.project_dir / path


def _read_evidence_frame(config: AppConfig, value: str | None) -> pd.DataFrame | None:
    path = _evidence_path(config, value)
    if path is None:
        return None
    if not path.is_file():
        raise FileNotFoundError(f"configured validation evidence does not exist: {path}")
    suffix = path.suffix.lower()
    if suffix in {".parquet", ".pq"}:
        return pd.read_parquet(path)
    if suffix in {".csv", ".txt"}:
        return pd.read_csv(path)
    raise ValueError(
        f"unsupported validation evidence table format {suffix!r} at {path}; "
        "use Parquet or CSV"
    )


def _read_evidence_manifest(
    config: AppConfig, value: str | None
) -> dict[str, object] | None:
    path = _evidence_path(config, value)
    if path is None:
        return None
    if not path.is_file():
        raise FileNotFoundError(f"configured validation manifest does not exist: {path}")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"validation manifest must be a JSON object: {path}")
    return payload


def _market_baseline_narrative(status: object) -> str:
    if status == "available_from_verified_point_in_time_grid":
        return (
            "A verified regular point-in-time market grid provides a descriptive "
            "full-market unconditional baseline in the validation envelope. The "
            "candidate-universe baseline remains model-free but candidate-conditioned; "
            "neither baseline is promotion evidence."
        )
    if status == "point_in_time_grid_supplied_but_failed_or_insufficient":
        return (
            "The candidate-universe baseline includes every finite direction-signed "
            "candidate label before model-score selection and remains model-free but "
            "candidate-conditioned. A supplied point-in-time market grid failed its "
            "contract or coverage threshold, so no full-market unconditional baseline "
            "is published."
        )
    return (
        "The candidate-universe baseline includes every finite direction-signed "
        "candidate label before model-score selection. It is model-free but "
        "candidate-conditioned; a full-market unconditional baseline is unavailable "
        "from candidate-only artifacts."
    )


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
    candidate_dates = sorted(
        candidates.get("session_date", pd.Series(dtype=object)).unique()
    )
    metrics = performance_metrics(trades, candidate_dates)
    configured_round_trip_cost_bps = 2 * (
        config.costs.underlying_slippage_bps + config.costs.estimated_spread_bps
    )
    evidence = config.validation_evidence
    validation = build_validation_metrics(
        trades,
        candidates=candidates,
        labels=labels,
        predictions=predictions,
        hypothesis_tests=_read_evidence_frame(
            config, evidence.hypothesis_tests_path
        ),
        untouched_holdout_trades=_read_evidence_frame(
            config, evidence.untouched_holdout_trades_path
        ),
        untouched_holdout_manifest=_read_evidence_manifest(
            config, evidence.untouched_holdout_manifest_path
        ),
        point_in_time_market_grid=_read_evidence_frame(
            config, evidence.point_in_time_market_grid_path
        ),
        point_in_time_market_manifest=_read_evidence_manifest(
            config, evidence.point_in_time_market_manifest_path
        ),
        forecast_horizons=config.forecast_horizons,
        candidate_dates=candidate_dates,
        configured_round_trip_cost_bps=configured_round_trip_cost_bps,
        commission_per_round_trip_currency=2 * config.costs.commission_per_trade,
    )
    metrics["validation"] = validation
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
        "gross_compounded_return": validation["return_metrics"][
            "gross_compounded_total_return"
        ],
        "net_compounded_return": validation["return_metrics"][
            "net_compounded_total_return"
        ],
        "breakeven_round_trip_cost_bps": validation["cost_analysis"][
            "breakeven_round_trip_cost_bps"
        ],
    }])
    cost_sensitivity = pd.DataFrame(validation["cost_analysis"]["sensitivity"])
    baseline_summary = pd.DataFrame(
        validation["baselines"]["candidate_universe_no_model_selection"]
    )
    label_accounting = pd.DataFrame(
        validation["label_exclusion_accounting"]["horizons"]
    )
    market_baseline_narrative = _market_baseline_narrative(
        validation["baselines"].get("market_unconditional_baseline_status")
    )
    analog = predictions[
        predictions.get("model", "") == LEGACY_EXPLORATORY_ANALOG_MODEL_NAME
    ] if not predictions.empty else pd.DataFrame()
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
        "Signals are produced after minute t closes and fills begin at t+1 or the first later valid quote.",
        "Same-minute stop/target collisions resolve to the stop first (conservative).",
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
        "Validation Brier scores measure calibrated probabilities. Any legacy exploratory Euclidean analog rows are a distinct non-serving estimator, excluded from selection, trade blotters, and promotion evidence; they are not evidence for the Rust analog engine.", "",
        "## 5. Walk-forward out-of-sample performance", "", "```json", json.dumps(metrics, indent=2, allow_nan=False), "```", "",
        "Only test-fold trades are included; validation data chooses thresholds without test-outcome tuning.", "",
        "The confidence interval resamples contiguous session blocks, not individual trades. Effective sample size is estimated from daily net-return autocorrelation. Neither statistic is promotion evidence.", "",
        "## 6. Gross, costs, net, and sensitivity", "", _table(cost_summary), "",
        _table(cost_sensitivity, 30), "",
        "Break-even round-trip cost is the additive per-trade cost that reduces mean gross return to zero. Latency, impact, capacity, and size-dependent fills remain unmeasured without historical executable quotes and order size.", "",
        "## 7. Baselines, overlap, and label exclusions", "",
        market_baseline_narrative, "",
        _table(baseline_summary, 20), "", _table(label_accounting, 20), "",
        "```json", json.dumps(validation["overlap_accounting"], indent=2, allow_nan=False), "```", "",
        "Missing forward labels remain in the denominator. New artifacts expose exact per-horizon exclusion statuses; legacy artifacts are explicitly marked as reason-unavailable.", "",
        "## 8. Setup and time-of-day stability", "", _table(setup_perf), "", _table(time_perf), "",
        "## 9. Simons-style theory audit", "", _table(THEORY_MAP, 20), "",
        "### Strict OOS selected trades", "", _table(theory_audit, 20), "",
        "### Hypothesis-formation event diagnostics (not OOS)", "", _table(hypothesis_audit, 20), "",
        "Win rate alone is not an edge. Compare it with break-even win rate, payoff ratio, costs and the confidence interval. `insufficient_sample` is not a positive finding.", "",
        "## 10. Charts", "",
    ]
    lines.extend([f"![{path}]({path})" for path in chart_paths])
    lines.extend([
        "", "## 11. Legacy exploratory Euclidean analog cases (not Rust-serving parity)", "",
        _table(analog[[c for c in ["timestamp", "expected_return", "win_probability", "similarity_score", "uncertainty", "neighbor_dates"] if c in analog]], 10), "",
        "## 12. Best and worst trades", "", "### Best", "", _table(best), "", "### Worst", "", _table(worst), "",
        "## 13. Rejected candidates", "",
        _table(rejected[[c for c in ["timestamp", "setup_type", "direction", "score", "rejection_reason"] if c in rejected]], 30), "",
        "## 14. Assumptions and limitations", "",
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
    (report_dir / "metrics.json").write_text(
        json.dumps(metrics, indent=2, allow_nan=False), encoding="utf-8"
    )
    (report_dir / "validation_metrics.json").write_text(
        json.dumps(validation, indent=2, allow_nan=False), encoding="utf-8"
    )
    return md_path

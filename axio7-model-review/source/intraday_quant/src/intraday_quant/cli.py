from __future__ import annotations

import argparse
import json
from pathlib import Path

import pandas as pd

from intraday_quant.backtest.options import run_options_backtest
from intraday_quant.backtest.underlying import run_underlying_backtest
from intraday_quant.backtest.costs import minimum_round_trip_cost_return
from intraday_quant.candidates.pipeline import generate_candidates, save_candidates
from intraday_quant.config import AppConfig, load_config
from intraday_quant.data.ingest import ingest, load_cleaned
from intraday_quant.features.pipeline import build_features, save_features
from intraday_quant.labels.pipeline import build_labels, save_labels
from intraday_quant.models.walk_forward import train_walk_forward
from intraday_quant.portfolio.selector import score_and_select
from intraday_quant.reports.report import generate_report
from intraday_quant.reports.pattern_analog import closing_state_analogs


def _features(config: AppConfig) -> pd.DataFrame:
    features = build_features(load_cleaned(config), config)
    save_features(features, config)
    return features


def _candidates(config: AppConfig) -> pd.DataFrame:
    features = pd.read_parquet(config.output_dir / "features" / "features.parquet")
    candidates = generate_candidates(features, config)
    save_candidates(candidates, config)
    return candidates


def _labels(config: AppConfig) -> pd.DataFrame:
    features = pd.read_parquet(config.output_dir / "features" / "features.parquet")
    candidates = pd.read_parquet(config.output_dir / "features" / "candidates.parquet")
    labels = build_labels(candidates, features, config)
    save_labels(labels, config)
    return labels


def _train(config: AppConfig) -> tuple[pd.DataFrame, pd.DataFrame]:
    features = pd.read_parquet(config.output_dir / "features" / "features.parquet")
    labels = pd.read_parquet(config.output_dir / "features" / "labels.parquet")
    return train_walk_forward(labels, features, config)


def _backtest(config: AppConfig) -> tuple[pd.DataFrame, pd.DataFrame, str]:
    features = pd.read_parquet(config.output_dir / "features" / "features.parquet")
    candidates = pd.read_parquet(config.output_dir / "features" / "candidates.parquet")
    predictions = pd.read_parquet(config.output_dir / "models" / "predictions.parquet")
    selected, rejected = score_and_select(predictions, candidates, config)
    trades = run_underlying_backtest(selected, features, config)
    execution_rejections = pd.DataFrame(trades.attrs.pop("execution_rejections", []))
    if not execution_rejections.empty:
        rejected = pd.concat([rejected, execution_rejections], ignore_index=True)
    options, option_status = run_options_backtest(trades, config)
    report_dir = config.output_dir / "reports"
    report_dir.mkdir(parents=True, exist_ok=True)
    selected.to_parquet(report_dir / "selected_candidates.parquet", index=False)
    rejected.to_parquet(report_dir / "rejected_candidates.parquet", index=False)
    execution_rejections.to_csv(report_dir / "execution_rejections.csv", index=False)
    trades.to_parquet(report_dir / "trade_blotter.parquet", index=False)
    trades.to_csv(report_dir / "trade_blotter.csv", index=False)
    options.to_parquet(report_dir / "option_trade_blotter.parquet", index=False)
    (report_dir / "option_status.txt").write_text(option_status, encoding="utf-8")
    return trades, rejected, option_status


def run_all(config: AppConfig) -> Path:
    _, stats = ingest(config)
    _features(config)
    _candidates(config)
    _labels(config)
    _train(config)
    _, _, option_status = _backtest(config)
    return generate_report(config, stats, option_status)


def _analog(config: AppConfig, target_date: str | None) -> Path:
    features = pd.read_parquet(config.output_dir / "features" / "features.parquet")
    if target_date is None:
        target_date = str(max(features["session_date"]))
    analogs = closing_state_analogs(features, target_date)
    path = config.output_dir / "reports" / f"closing_analogs_{target_date}.csv"
    path.parent.mkdir(parents=True, exist_ok=True)
    analogs.to_csv(path, index=False)
    returns = analogs["return_1550_to_close"].astype(float)
    market_cost = minimum_round_trip_cost_return(config)
    july2 = analogs.loc[analogs["date_string"] == "2026-07-02", "rank"]
    summary = {
        "target_date": target_date,
        "signal_minute": "15:50 ET",
        "distance_uses_target_future": False,
        "analog_count": len(analogs),
        "gross_positive_rate": float((returns > 0).mean()),
        "mean_gross_return_to_close": float(returns.mean()),
        "median_gross_return_to_close": float(returns.median()),
        "estimated_round_trip_market_cost": market_cost,
        "cost_basis": "pre_trade_baseline_includes_commission_excludes_size_impact",
        "mean_return_after_market_cost": float(returns.mean() - market_cost),
        "july_2_rank": int(july2.iloc[0]) if len(july2) else None,
        "options_result": "not_tested_no_historical_nbbo",
    }
    path.with_suffix(".json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return path


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Leakage-safe intraday SPX research pipeline")
    parser.add_argument("command", choices=["ingest", "features", "candidates", "labels", "train", "backtest", "report", "analog", "run-all", "serve"])
    parser.add_argument("--config")
    parser.add_argument("--date", help="Target YYYY-MM-DD for the closing-state analog command")
    args = parser.parse_args(argv)
    if args.command == "serve":
        import uvicorn
        uvicorn.run("intraday_quant.api.app:app", host="127.0.0.1", port=8001, reload=False)
        return
    if not args.config:
        parser.error("--config is required for research pipeline commands")
    config = load_config(args.config)
    if args.command == "ingest":
        result = ingest(config)[1]
    elif args.command == "features":
        result = {"rows": len(_features(config))}
    elif args.command == "candidates":
        result = {"rows": len(_candidates(config))}
    elif args.command == "labels":
        result = {"rows": len(_labels(config))}
    elif args.command == "train":
        pred, diag = _train(config)
        result = {"prediction_rows": len(pred), "fold_rows": len(diag)}
    elif args.command == "backtest":
        trades, rejected, status = _backtest(config)
        result = {"trades": len(trades), "rejected": len(rejected), "options": status}
    elif args.command == "report":
        status_path = config.output_dir / "reports" / "option_status.txt"
        result = {"report": str(generate_report(config, option_status=status_path.read_text(encoding="utf-8") if status_path.exists() else None))}
    elif args.command == "analog":
        result = {"analogs": str(_analog(config, args.date))}
    else:
        result = {"report": str(run_all(config))}
    print(json.dumps(result, ensure_ascii=False, default=str))


if __name__ == "__main__":
    main()

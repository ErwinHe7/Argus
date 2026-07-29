from __future__ import annotations

import json
import threading
import uuid
from pathlib import Path
from typing import Any

import pandas as pd

from intraday_quant.cli import run_all
from intraday_quant.config import AppConfig, load_config
from intraday_quant.reports.pattern_analog import closing_state_analogs
from intraday_quant.storage.repository import ResearchRepository


PROJECT_DIR = Path(__file__).resolve().parents[2]
PROFILE_PATHS = {
    "synthetic": PROJECT_DIR / "configs" / "default.yaml",
    "yahoo_recent": PROJECT_DIR / "configs" / "yahoo_recent.yaml",
}


class ResearchService:
    """Single-worker orchestration around the deterministic research pipeline."""

    _pipeline_lock = threading.Lock()

    def __init__(self, repository: ResearchRepository):
        self.repository = repository

    @staticmethod
    def profiles() -> list[dict[str, Any]]:
        return [
            {
                "id": "synthetic",
                "label": "Synthetic pipeline validation",
                "network_required": False,
                "evidence_tier": "synthetic_validation",
            },
            {
                "id": "yahoo_recent",
                "label": "Recent unofficial SPX price check",
                "network_required": True,
                "evidence_tier": "unofficial_recent_price_check",
            },
        ]

    def queue(self, profile: str) -> str:
        config = self.load_profile(profile)
        return self.repository.create_run(profile, config)

    def execute(self, profile: str, run_id: str) -> None:
        config = self.load_profile(profile)
        self.repository.mark_running(run_id)
        try:
            with self._pipeline_lock:
                report_path = run_all(config)
                self._write_latest_analogs(config)
                self.register_artifacts(profile, config, run_id, report_path)
        except Exception as exc:
            self.repository.mark_failed(run_id, f"{type(exc).__name__}: {exc}")
            raise

    def run_sync(self, profile: str) -> str:
        run_id = self.queue(profile)
        self.execute(profile, run_id)
        return run_id

    def bootstrap_existing(self) -> list[str]:
        imported: list[str] = []
        for profile in PROFILE_PATHS:
            if self.repository.has_completed_profile(profile):
                continue
            config = self.load_profile(profile)
            report_path = config.output_dir / "reports" / "research_report.md"
            if not report_path.exists():
                continue
            base_run_id = f"import-{profile}"
            run_id = base_run_id if self.repository.get_run(base_run_id) is None else f"{base_run_id}-{uuid.uuid4().hex[:8]}"
            run_id = self.repository.create_run(profile, config, run_id=run_id)
            self.repository.mark_running(run_id)
            try:
                self.register_artifacts(profile, config, run_id, report_path)
            except Exception as exc:
                self.repository.mark_failed(run_id, f"bootstrap failed: {exc}")
                continue
            imported.append(run_id)
        return imported

    @staticmethod
    def load_profile(profile: str) -> AppConfig:
        path = PROFILE_PATHS.get(profile)
        if path is None:
            raise ValueError(f"unknown profile: {profile}")
        return load_config(path)

    @staticmethod
    def _write_latest_analogs(config: AppConfig) -> Path | None:
        feature_path = config.output_dir / "features" / "features.parquet"
        if not feature_path.exists():
            return None
        features = pd.read_parquet(feature_path)
        if features.empty:
            return None
        target_date = str(max(features["session_date"]))
        try:
            analogs = closing_state_analogs(features, target_date)
        except ValueError:
            return None
        path = config.output_dir / "reports" / f"closing_analogs_{target_date}.csv"
        path.parent.mkdir(parents=True, exist_ok=True)
        analogs.to_csv(path, index=False)
        return path

    def register_artifacts(
        self, profile: str, config: AppConfig, run_id: str, report_path: Path
    ) -> None:
        report_dir = config.output_dir / "reports"
        feature_dir = config.output_dir / "features"
        model_dir = config.output_dir / "models"
        metrics = self._read_json(report_dir / "metrics.json")
        features = self._read_parquet(feature_dir / "features.parquet")
        coverage = {
            "rows": int(len(features)),
            "start": str(features["timestamp"].min()) if not features.empty else None,
            "end": str(features["timestamp"].max()) if not features.empty else None,
            "sessions": int(features["session_date"].nunique()) if "session_date" in features else 0,
            "sources": (
                features["source"].value_counts().to_dict() if "source" in features else {}
            ),
        }
        selected = self._read_parquet(report_dir / "selected_candidates.parquet")
        rejected = self._read_parquet(report_dir / "rejected_candidates.parquet")
        trades = self._read_parquet(report_dir / "trade_blotter.parquet")
        diagnostics = self._read_csv(model_dir / "fold_diagnostics.csv")
        analog_candidates = sorted(report_dir.glob("closing_analogs_*.csv"))
        analogs = self._read_csv(analog_candidates[-1]) if analog_candidates else pd.DataFrame()
        option_status_path = report_dir / "option_status.txt"
        option_status = (
            option_status_path.read_text(encoding="utf-8")
            if option_status_path.exists()
            else "期权回测未执行：没有真实历史 NBBO"
        )
        audits = {
            "theory_performance": self._read_csv(report_dir / "theory_performance_audit.csv"),
            "hypothesis_event": self._read_csv(report_dir / "hypothesis_event_audit.csv"),
        }
        manifest = {
            path.name: {"path": str(path), "bytes": path.stat().st_size}
            for path in report_dir.glob("*")
            if path.is_file()
        }
        self.repository.persist_artifacts(
            run_id,
            report_path=report_path,
            metrics=metrics,
            coverage=coverage,
            option_status=option_status,
            manifest=manifest,
            selected=selected,
            rejected=rejected,
            trades=trades,
            analogs=analogs,
            diagnostics=diagnostics,
            audits=audits,
        )

    @staticmethod
    def _read_json(path: Path) -> dict[str, Any]:
        return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}

    @staticmethod
    def _read_parquet(path: Path) -> pd.DataFrame:
        return pd.read_parquet(path) if path.exists() else pd.DataFrame()

    @staticmethod
    def _read_csv(path: Path) -> pd.DataFrame:
        return pd.read_csv(path) if path.exists() else pd.DataFrame()

from __future__ import annotations

import json
import math
import threading
import uuid
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Iterable

import duckdb
import numpy as np
import pandas as pd

from intraday_quant.config import AppConfig


RUN_JSON_FIELDS = {
    "config_json",
    "metrics_json",
    "data_coverage_json",
    "artifact_manifest_json",
}


def _json_default(value: Any) -> Any:
    if isinstance(value, (datetime, date, pd.Timestamp)):
        return value.isoformat()
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, (np.integer,)):
        return int(value)
    if isinstance(value, (np.floating,)):
        return None if not np.isfinite(value) else float(value)
    if isinstance(value, np.bool_):
        return bool(value)
    return str(value)


def _json(value: Any) -> str:
    return json.dumps(_clean_json(value), ensure_ascii=False, allow_nan=False, default=_json_default)


def _clean_json(value: Any) -> Any:
    if isinstance(value, dict):
        return {str(key): _clean_json(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_clean_json(item) for item in value]
    if isinstance(value, (float, np.floating)):
        return float(value) if np.isfinite(value) else None
    if value is pd.NA or value is pd.NaT:
        return None
    return value


def _scalar(value: Any) -> Any:
    if value is None or value is pd.NA:
        return None
    if isinstance(value, (float, np.floating)) and (math.isnan(float(value)) or math.isinf(float(value))):
        return None
    if isinstance(value, (datetime, date, pd.Timestamp)):
        return value.isoformat()
    if isinstance(value, np.generic):
        return value.item()
    if isinstance(value, (dict, list, tuple)):
        return _json(value)
    return value


class ResearchRepository:
    """Stores experiment metadata and query-ready artifacts in one local DuckDB file."""

    _write_lock = threading.RLock()

    def __init__(self, path: str | Path):
        self.path = Path(path).resolve()
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.initialize()

    def connect(self) -> duckdb.DuckDBPyConnection:
        return duckdb.connect(str(self.path))

    def initialize(self) -> None:
        ddl = """
        CREATE TABLE IF NOT EXISTS research_runs (
            run_id VARCHAR PRIMARY KEY,
            profile VARCHAR NOT NULL,
            status VARCHAR NOT NULL,
            source_mode VARCHAR NOT NULL,
            evidence_tier VARCHAR NOT NULL,
            created_at VARCHAR NOT NULL,
            started_at VARCHAR,
            completed_at VARCHAR,
            config_path VARCHAR NOT NULL,
            output_dir VARCHAR NOT NULL,
            report_path VARCHAR,
            option_status VARCHAR,
            error_message VARCHAR,
            config_json VARCHAR NOT NULL,
            metrics_json VARCHAR,
            data_coverage_json VARCHAR,
            artifact_manifest_json VARCHAR
        );
        CREATE TABLE IF NOT EXISTS candidate_decisions (
            run_id VARCHAR NOT NULL,
            candidate_id VARCHAR,
            timestamp VARCHAR,
            session_date VARCHAR,
            setup_type VARCHAR,
            direction INTEGER,
            decision VARCHAR NOT NULL,
            score DOUBLE,
            expected_return DOUBLE,
            expected_net_return DOUBLE,
            win_probability DOUBLE,
            predicted_mfe DOUBLE,
            predicted_mae DOUBLE,
            uncertainty DOUBLE,
            rejection_reason VARCHAR,
            reason_codes VARCHAR,
            feature_snapshot VARCHAR
        );
        CREATE TABLE IF NOT EXISTS trades (
            run_id VARCHAR NOT NULL,
            trade_id VARCHAR,
            trade_date VARCHAR,
            setup VARCHAR,
            direction INTEGER,
            signal_time VARCHAR,
            entry_time VARCHAR,
            exit_time VARCHAR,
            underlying_entry DOUBLE,
            underlying_exit DOUBLE,
            gross_pnl DOUBLE,
            cost DOUBLE,
            net_pnl DOUBLE,
            gross_return DOUBLE,
            net_return DOUBLE,
            mfe DOUBLE,
            mae DOUBLE,
            holding_minutes INTEGER,
            exit_reason VARCHAR,
            model_probability DOUBLE,
            score DOUBLE,
            fold INTEGER
        );
        CREATE TABLE IF NOT EXISTS analog_cases (
            run_id VARCHAR NOT NULL,
            target_date VARCHAR,
            rank INTEGER,
            analog_date VARCHAR,
            distance DOUBLE,
            similarity DOUBLE,
            forward_return DOUBLE,
            target_actual_return DOUBLE,
            ret_5m DOUBLE,
            ret_15m DOUBLE,
            volume_zscore DOUBLE,
            buy_pressure_proxy DOUBLE,
            breadth_score DOUBLE,
            closing_short_cover_score DOUBLE
        );
        CREATE TABLE IF NOT EXISTS model_diagnostics (
            run_id VARCHAR NOT NULL,
            fold INTEGER,
            model VARCHAR,
            train_rows INTEGER,
            validation_rows INTEGER,
            test_rows INTEGER,
            validation_brier DOUBLE
        );
        CREATE TABLE IF NOT EXISTS research_audits (
            run_id VARCHAR NOT NULL,
            audit_type VARCHAR NOT NULL,
            row_number INTEGER NOT NULL,
            payload_json VARCHAR NOT NULL
        );
        """
        with self._write_lock, self.connect() as connection:
            connection.execute(ddl)

    def create_run(self, profile: str, config: AppConfig, run_id: str | None = None) -> str:
        identifier = run_id or str(uuid.uuid4())
        source_mode = config.data.adapter
        evidence_tier = (
            "synthetic_validation"
            if source_mode == "synthetic"
            else "unofficial_recent_price_check"
            if source_mode == "yahoo"
            else "historical_research"
        )
        now = datetime.now(timezone.utc).isoformat()
        with self._write_lock, self.connect() as connection:
            connection.execute(
                """
                INSERT INTO research_runs (
                    run_id, profile, status, source_mode, evidence_tier, created_at,
                    config_path, output_dir, config_json
                ) VALUES (?, ?, 'queued', ?, ?, ?, ?, ?, ?)
                """,
                [
                    identifier,
                    profile,
                    source_mode,
                    evidence_tier,
                    now,
                    str(config.config_path or ""),
                    str(config.output_dir),
                    _json(config.model_dump(mode="json", exclude={"config_path"})),
                ],
            )
        return identifier

    def mark_running(self, run_id: str) -> None:
        self._update_status(run_id, "running", started_at=datetime.now(timezone.utc).isoformat())

    def mark_failed(self, run_id: str, error: str) -> None:
        self._update_status(
            run_id,
            "failed",
            completed_at=datetime.now(timezone.utc).isoformat(),
            error_message=error[:4_000],
        )

    def _update_status(self, run_id: str, status: str, **fields: Any) -> None:
        allowed = {"started_at", "completed_at", "error_message"}
        assignments = ["status = ?"]
        values: list[Any] = [status]
        for key, value in fields.items():
            if key not in allowed:
                raise ValueError(f"unsupported run field: {key}")
            assignments.append(f"{key} = ?")
            values.append(value)
        values.append(run_id)
        with self._write_lock, self.connect() as connection:
            connection.execute(
                f"UPDATE research_runs SET {', '.join(assignments)} WHERE run_id = ?",
                values,
            )

    def persist_artifacts(
        self,
        run_id: str,
        *,
        report_path: Path,
        metrics: dict[str, Any],
        coverage: dict[str, Any],
        option_status: str,
        manifest: dict[str, Any],
        selected: pd.DataFrame,
        rejected: pd.DataFrame,
        trades: pd.DataFrame,
        analogs: pd.DataFrame,
        diagnostics: pd.DataFrame,
        audits: dict[str, pd.DataFrame],
    ) -> None:
        completed_at = datetime.now(timezone.utc).isoformat()
        with self._write_lock, self.connect() as connection:
            connection.execute("BEGIN TRANSACTION")
            try:
                for table in (
                    "candidate_decisions",
                    "trades",
                    "analog_cases",
                    "model_diagnostics",
                    "research_audits",
                ):
                    connection.execute(f"DELETE FROM {table} WHERE run_id = ?", [run_id])
                self._insert_candidates(connection, run_id, selected, "selected")
                self._insert_candidates(connection, run_id, rejected, "rejected")
                self._insert_trades(connection, run_id, trades)
                self._insert_analogs(connection, run_id, analogs)
                self._insert_diagnostics(connection, run_id, diagnostics)
                self._insert_audits(connection, run_id, audits)
                connection.execute(
                    """
                    UPDATE research_runs SET status='completed', completed_at=?, report_path=?,
                        option_status=?, metrics_json=?, data_coverage_json=?,
                        artifact_manifest_json=?, error_message=NULL
                    WHERE run_id=?
                    """,
                    [
                        completed_at,
                        str(report_path),
                        option_status,
                        _json(metrics),
                        _json(coverage),
                        _json(manifest),
                        run_id,
                    ],
                )
                connection.execute("COMMIT")
            except Exception:
                connection.execute("ROLLBACK")
                raise

    @staticmethod
    def _records(frame: pd.DataFrame, columns: Iterable[str]) -> list[list[Any]]:
        normalized = frame.reindex(columns=list(columns))
        return [[_scalar(value) for value in row] for row in normalized.itertuples(index=False, name=None)]

    def _insert_candidates(
        self, connection: duckdb.DuckDBPyConnection, run_id: str, frame: pd.DataFrame, decision: str
    ) -> None:
        if frame.empty:
            return
        columns = [
            "candidate_id", "timestamp", "session_date", "setup_type", "direction", "score",
            "expected_return", "expected_net_return", "win_probability", "predicted_mfe",
            "predicted_mae", "uncertainty", "rejection_reason", "reason_codes", "feature_snapshot",
        ]
        records = [[run_id, *row[:5], decision, *row[5:]] for row in self._records(frame, columns)]
        connection.executemany(
            "INSERT INTO candidate_decisions VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            records,
        )

    def _insert_trades(self, connection: duckdb.DuckDBPyConnection, run_id: str, frame: pd.DataFrame) -> None:
        if frame.empty:
            return
        columns = [
            "trade_id", "date", "setup", "direction", "signal_time", "entry_time", "exit_time",
            "underlying_entry", "underlying_exit", "gross_pnl", "cost", "net_pnl", "gross_return",
            "net_return", "MFE", "MAE", "holding_minutes", "exit_reason", "model_probability", "score", "fold",
        ]
        records = [[run_id, *row] for row in self._records(frame, columns)]
        connection.executemany(
            "INSERT INTO trades VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            records,
        )

    def _insert_analogs(self, connection: duckdb.DuckDBPyConnection, run_id: str, frame: pd.DataFrame) -> None:
        if frame.empty:
            return
        columns = [
            "target_date", "rank", "date_string", "distance", "similarity", "return_1550_to_close",
            "target_actual_return_1550_to_close", "ret_5m", "ret_15m", "volume_zscore",
            "buy_pressure_proxy", "cross_asset_breadth_score", "closing_short_cover_score",
        ]
        records = [[run_id, *row] for row in self._records(frame, columns)]
        connection.executemany(
            "INSERT INTO analog_cases VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", records
        )

    def _insert_diagnostics(
        self, connection: duckdb.DuckDBPyConnection, run_id: str, frame: pd.DataFrame
    ) -> None:
        if frame.empty:
            return
        columns = ["fold", "model", "train_rows", "validation_rows", "test_rows", "validation_brier"]
        records = [[run_id, *row] for row in self._records(frame, columns)]
        connection.executemany("INSERT INTO model_diagnostics VALUES (?, ?, ?, ?, ?, ?, ?)", records)

    def _insert_audits(
        self,
        connection: duckdb.DuckDBPyConnection,
        run_id: str,
        audits: dict[str, pd.DataFrame],
    ) -> None:
        records: list[list[Any]] = []
        for audit_type, frame in audits.items():
            for row_number, payload in enumerate(frame.to_dict(orient="records"), start=1):
                records.append([run_id, audit_type, row_number, _json(payload)])
        if records:
            connection.executemany("INSERT INTO research_audits VALUES (?, ?, ?, ?)", records)

    def list_runs(self, limit: int = 25) -> list[dict[str, Any]]:
        with self.connect() as connection:
            frame = connection.execute(
                "SELECT * FROM research_runs ORDER BY created_at DESC LIMIT ?", [max(1, min(limit, 100))]
            ).fetchdf()
        return self._run_records(frame)

    def get_run(self, run_id: str) -> dict[str, Any] | None:
        with self.connect() as connection:
            frame = connection.execute("SELECT * FROM research_runs WHERE run_id = ?", [run_id]).fetchdf()
        records = self._run_records(frame)
        return records[0] if records else None

    def latest_run(self, preferred_profile: str | None = None) -> dict[str, Any] | None:
        with self.connect() as connection:
            if preferred_profile:
                frame = connection.execute(
                    """SELECT * FROM research_runs
                    WHERE status='completed' AND profile=? ORDER BY completed_at DESC LIMIT 1""",
                    [preferred_profile],
                ).fetchdf()
                records = self._run_records(frame)
                if records:
                    return records[0]
            frame = connection.execute(
                "SELECT * FROM research_runs WHERE status='completed' ORDER BY completed_at DESC LIMIT 1"
            ).fetchdf()
        records = self._run_records(frame)
        return records[0] if records else None

    def has_completed_profile(self, profile: str) -> bool:
        with self.connect() as connection:
            count = connection.execute(
                "SELECT count(*) FROM research_runs WHERE profile=? AND status='completed'", [profile]
            ).fetchone()[0]
        return bool(count)

    @staticmethod
    def _run_records(frame: pd.DataFrame) -> list[dict[str, Any]]:
        records = frame.astype(object).where(pd.notna(frame), None).to_dict(orient="records")
        for record in records:
            for field in RUN_JSON_FIELDS:
                raw = record.get(field)
                if isinstance(raw, str) and raw:
                    try:
                        record[field.removesuffix("_json")] = json.loads(raw)
                    except json.JSONDecodeError:
                        record[field.removesuffix("_json")] = None
                record.pop(field, None)
        return records

    def table_rows(self, table: str, run_id: str, limit: int = 100) -> list[dict[str, Any]]:
        allowed = {
            "candidate_decisions", "trades", "analog_cases", "model_diagnostics", "research_audits"
        }
        if table not in allowed:
            raise ValueError("unsupported artifact table")
        order = {
            "candidate_decisions": "timestamp DESC",
            "trades": "signal_time DESC",
            "analog_cases": "rank ASC",
            "model_diagnostics": "fold ASC, model ASC",
            "research_audits": "audit_type ASC, row_number ASC",
        }[table]
        with self.connect() as connection:
            frame = connection.execute(
                f"SELECT * EXCLUDE(run_id) FROM {table} WHERE run_id=? ORDER BY {order} LIMIT ?",
                [run_id, max(1, min(limit, 1_000))],
            ).fetchdf()
        records = frame.astype(object).where(pd.notna(frame), None).to_dict(orient="records")
        if table == "research_audits":
            for record in records:
                record["payload"] = json.loads(record.pop("payload_json"))
        return records

    def overview(self, run_id: str) -> dict[str, Any]:
        run = self.get_run(run_id)
        if run is None:
            raise KeyError(run_id)
        trades = self.table_rows("trades", run_id, 200)
        equity = self._equity_series(trades)
        return {
            "run": run,
            "metrics": run.get("metrics") or {},
            "equity": equity,
            "trades": trades,
            "candidates": self.table_rows("candidate_decisions", run_id, 300),
            "analogs": self.table_rows("analog_cases", run_id, 50),
            "diagnostics": self.table_rows("model_diagnostics", run_id, 100),
            "audits": self.table_rows("research_audits", run_id, 200),
        }

    @staticmethod
    def _equity_series(trades: list[dict[str, Any]]) -> list[dict[str, Any]]:
        if not trades:
            return []
        frame = pd.DataFrame(trades)
        frame["trade_date"] = frame["trade_date"].astype(str)
        daily = frame.groupby("trade_date")["net_return"].sum().sort_index()
        equity = (1 + daily).cumprod()
        drawdown = equity / equity.cummax() - 1
        return [
            {"date": index, "equity": float(equity.loc[index]), "drawdown": float(drawdown.loc[index])}
            for index in equity.index
        ]

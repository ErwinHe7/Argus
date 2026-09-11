"""Bounded, local, deterministic research queue. No network, broker, or LLM client.

STOP pauses admission; SHUTDOWN requests exit after the current read-only operation.
SQLite records distinct content-addressed jobs and every attempted experiment.
An OS-held lock, immutable receipts, and atomic status publication permit restart.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import os
import re
import signal
import sqlite3
import stat
import sys
import tempfile
import threading
import time
from contextlib import closing, contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator

from . import research

CONFIG_VERSION = "leo-continuous-research-config.v1"
STATUS_VERSION = "leo-continuous-research-status.v1"
RESULT_VERSION = "leo-continuous-research-result.v1"
MAX_JOBS = 32
MAX_CONFIG_BYTES = 128 * 1024
MAX_INPUT_BYTES = 32 * 1024 * 1024
MAX_REGISTRATION_BYTES = 128 * 1024
MAX_ENGINE_BYTES = 256 * 1024 * 1024
MAX_ARTIFACT_BYTES = 128 * 1024 * 1024
HEARTBEAT_SECONDS = 5.0


@dataclass(frozen=True)
class Job:
    id: str
    kind: str
    input: Path
    sensitivity: bool = False
    registration: Path | None = None


@dataclass(frozen=True)
class Config:
    state_dir: Path
    engine: Path
    jobs: tuple[Job, ...]
    interval_seconds: float = 30


class RunnerLocked(RuntimeError):
    pass


class IntegrityError(RuntimeError):
    pass


class ResearchInterrupted(RuntimeError):
    """Graceful shutdown preserves the current trial for explicit restart."""


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _json_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()


def _sha(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON object key")
        result[key] = value
    return result


def _parse(payload: bytes) -> dict[str, Any]:
    def reject_constant(_value: str) -> None:
        raise ValueError("non-finite JSON value")

    value = json.loads(payload.decode("utf-8-sig"), object_pairs_hook=_pairs, parse_constant=reject_constant)
    if not isinstance(value, dict):
        raise ValueError("JSON root must be an object")
    return value


def _read_bytes(path: Path, limit: int) -> bytes:
    # A FIFO must not block before its type can be checked. O_NONBLOCK has no
    # effect on regular POSIX files; Windows lacks the flag and uses O_BINARY.
    flags = os.O_RDONLY | getattr(os, "O_BINARY", 0) | getattr(os, "O_NONBLOCK", 0)
    descriptor = os.open(path, flags)
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or before.st_size > limit:
            raise ValueError("file must be regular and within the byte limit")
        with os.fdopen(descriptor, "rb", closefd=False) as handle:
            payload = handle.read(limit + 1)
        after = os.fstat(descriptor)
    finally:
        os.close(descriptor)
    if len(payload) > limit or (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise ValueError("file oversized or changed while reading; publish inputs atomically")
    return payload


def _absolute(value: Any, field: str) -> Path:
    if not isinstance(value, str) or not value.strip() or not Path(value).is_absolute():
        raise ValueError(f"{field} must be an absolute local path")
    # Network shares are not a reliable home for the state lock or SQLite.
    if value.startswith(("\\\\", "//")):
        raise ValueError(f"{field} must be a local filesystem path")
    return Path(value).resolve()


def _fields(raw: dict[str, Any], allowed: set[str], required: set[str]) -> None:
    if set(raw) - allowed or required - set(raw):
        raise ValueError("unknown or missing configuration fields")


def load_config(path: Path) -> Config:
    if not path.is_absolute():
        raise ValueError("--config must be an absolute path")
    raw = _parse(_read_bytes(path, MAX_CONFIG_BYTES))
    _fields(raw, {"schema_version", "state_dir", "engine", "interval_seconds", "jobs"},
            {"schema_version", "state_dir", "engine", "jobs"})
    if raw["schema_version"] != CONFIG_VERSION:
        raise ValueError("unsupported continuous research config schema")
    interval = raw.get("interval_seconds", 30)
    if type(interval) not in (int, float) or not 5 <= interval <= 86400:
        raise ValueError("interval_seconds must be between 5 and 86400")
    entries = raw["jobs"]
    if not isinstance(entries, list) or not 1 <= len(entries) <= MAX_JOBS:
        raise ValueError(f"jobs must contain 1 to {MAX_JOBS} entries")
    jobs = []
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError("each job must be an object")
        _fields(entry, {"id", "kind", "input", "sensitivity", "registration"}, {"id", "kind", "input"})
        if not isinstance(entry["id"], str) or not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}", entry["id"]):
            raise ValueError("job id must be a bounded ASCII identifier")
        if entry["kind"] not in ("source-capability", "research"):
            raise ValueError("unsupported job kind")
        if type(entry.get("sensitivity", False)) is not bool:
            raise ValueError("sensitivity must be a boolean")
        if entry["kind"] == "source-capability" and ({"registration", "sensitivity"} & set(entry)):
            raise ValueError("source-capability jobs do not accept research controls")
        jobs.append(Job(entry["id"], entry["kind"], _absolute(entry["input"], "input"),
                        entry.get("sensitivity", False),
                        _absolute(entry["registration"], "registration") if "registration" in entry else None))
    if len({job.id for job in jobs}) != len(jobs):
        raise ValueError("job ids must be unique")
    state_dir = _absolute(raw["state_dir"], "state_dir")
    engine = _absolute(raw["engine"], "engine")
    if engine.name != ("strategy-lab.exe" if os.name == "nt" else "strategy-lab"):
        raise ValueError("engine must be the canonical native strategy-lab binary")
    if state_dir.exists() and not state_dir.is_dir():
        raise ValueError("state_dir must be a directory")
    return Config(state_dir, engine, tuple(jobs), interval)


def _sync_directory(directory: Path) -> None:
    if os.name != "nt":
        descriptor = os.open(directory, os.O_RDONLY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)


def _write_bytes(path: Path, payload: bytes, *, replace: bool = False, executable: bool = False) -> None:
    """Install a fully flushed file; exclusive hard-link publication never clobbers."""
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=".pending-", dir=path.parent)
    temporary_path = Path(temporary)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        if executable:
            temporary_path.chmod(0o700)
        if replace:
            # Windows readers can briefly deny delete sharing. Keep the previous
            # complete snapshot visible while retrying its atomic replacement.
            for attempt in range(25):
                try:
                    os.replace(temporary_path, path)
                    break
                except PermissionError as error:
                    if os.name != "nt" or getattr(error, "winerror", None) not in (5, 32, 33) or attempt == 24:
                        raise
                    time.sleep(0.02)
        else:
            os.link(temporary_path, path)
        _sync_directory(path.parent)
    finally:
        temporary_path.unlink(missing_ok=True)


def _write_new(path: Path, value: Any) -> None:
    payload = _json_bytes(value)
    if len(payload) > MAX_ARTIFACT_BYTES:
        raise ValueError("research artifact exceeds the bounded storage limit")
    _write_bytes(path, payload)


@contextmanager
def exclusive_lock(state_dir: Path) -> Iterator[None]:
    """Lock ownership ends when the OS closes the descriptor, including on crash."""
    state_dir.mkdir(parents=True, exist_ok=True)
    handle = (state_dir / "runner.lock").open("a+b")
    try:
        handle.seek(0, os.SEEK_END)
        if handle.tell() == 0:
            handle.write(b"\0")
            handle.flush()
        handle.seek(0)
        try:
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as error:
            raise RunnerLocked("another continuous research runner owns state_dir") from error
        try:
            yield
        finally:
            handle.seek(0)
            if os.name == "nt":
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
    finally:
        handle.close()


def read_status(state_dir: Path) -> dict[str, Any] | None:
    """Read one complete status snapshot; callers must check heartbeat freshness."""
    try:
        value = _parse(_read_bytes(state_dir / "status.json", MAX_CONFIG_BYTES))
    except FileNotFoundError:
        return None
    if value.get("schema_version") != STATUS_VERSION:
        raise ValueError("unexpected continuous research status schema")
    return value


def _runtime_identity() -> dict[str, Any]:
    sources = {name: _sha(_read_bytes(Path(__file__).parent / name, MAX_INPUT_BYTES))
               for name in ("continuous.py", "research.py")}
    dependencies = {dist.metadata["Name"]: dist.version for dist in importlib.metadata.distributions()
                    if dist.metadata["Name"]}
    return {"python": sys.version, "sources": sources, "dependencies": dependencies}


def _reason(error: Exception) -> str:
    # Pydantic messages normally echo source input. Keep only field and error type.
    if hasattr(error, "errors"):
        errors = error.errors(include_input=False, include_context=False, include_url=False)
        return ("source validation rejected: " + "; ".join(
            f"{'.'.join(map(str, item['loc']))}: {item['type']}" for item in errors[:5]))[:512]
    if isinstance(error, json.JSONDecodeError):
        return "invalid JSON input"
    if isinstance(error, OSError):
        return f"local file unavailable: {type(error).__name__}"
    return f"{type(error).__name__}: {str(error)[:450]}"


def _source(path: Path, limit: int) -> tuple[dict[str, Any], dict[str, Any] | None, str | None]:
    try:
        payload = _read_bytes(path, limit)
    except (OSError, ValueError) as error:
        # No unbounded hashing of rejected files. This is a rejected-input identity,
        # not a data hash or a claim that the oversized input was inspected.
        return {"unreadable_path": str(path), "rejection": _reason(error)}, None, _reason(error)
    try:
        raw = _parse(payload)
        return {"sha256": _sha(_json_bytes(raw))}, raw, None
    except (ValueError, UnicodeError, RecursionError) as error:
        return {"invalid_bytes_sha256": _sha(payload)}, None, _reason(error)


def _validate_capability(raw: dict[str, Any]) -> None:
    if not isinstance(raw.get("provider"), str) or not raw["provider"].strip() or len(raw["provider"]) > 128:
        raise ValueError("retained provider name required")
    if raw.get("retrievedAt") is not None and (not isinstance(raw["retrievedAt"], str) or len(raw["retrievedAt"]) > 64):
        raise ValueError("invalid retained retrieval timestamp metadata")
    symbols = raw.get("symbols")
    if not isinstance(symbols, list) or not 1 <= len(symbols) <= 64:
        raise ValueError("retained source requires 1 to 64 symbols")
    for item in symbols:
        if not isinstance(item, dict) or not isinstance(item.get("symbol"), str) or not item["symbol"] or len(item["symbol"]) > 32:
            raise ValueError("invalid retained symbol metadata")
        history = item.get("history", {})
        if not isinstance(history, dict) or not isinstance(history.get("bars", []), list):
            raise ValueError("invalid retained history metadata")
        bars = history.get("bars", [])
        if len(bars) > 20_000 or any(not isinstance(bar, dict) for bar in bars):
            raise ValueError("retained history exceeds bounded session metadata")
        if any(not isinstance(bar.get("date", ""), str) or len(bar.get("date", "")) > 32 for bar in bars):
            raise ValueError("invalid retained session date metadata")
        if not isinstance(history.get("adjustmentPolicy", "unknown"), str) or len(history.get("adjustmentPolicy", "unknown")) > 256:
            raise ValueError("invalid retained adjustment policy metadata")


class Runner:
    def __init__(self, config: Config):
        self.config = config
        self.started_at = _now()
        self.stop_event = threading.Event()
        self.guard = threading.RLock()
        self.active_job: str | None = None
        self.error: str | None = None
        self.engine: dict[str, Any] = {"path": str(config.engine), "sha256": None}
        self.runtime = _runtime_identity()
        self.jobs = {job.id: {"id": job.id, "kind": job.kind, "state": "pending", "reason": "awaiting_input_scan",
                              "trial_key": None, "result_path": None} for job in config.jobs}
        self.counters = {"trials": 0, "completed": 0, "rejected": 0, "running": 0, "recovered": 0,
                         "experiments": 0, "experiments_rejected": 0, "replay_trials": 0, "replay_rejected": 0}

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.config.state_dir / "trials.sqlite3", timeout=30)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA journal_mode=WAL")
        connection.execute("PRAGMA synchronous=FULL")
        connection.executescript("""
            CREATE TABLE IF NOT EXISTS trials (
                trial_key TEXT PRIMARY KEY, kind TEXT NOT NULL, state TEXT NOT NULL,
                started_at TEXT NOT NULL, finished_at TEXT, attempts INTEGER NOT NULL DEFAULT 1,
                result_path TEXT, reason TEXT, result_sha256 TEXT
            );
            CREATE TABLE IF NOT EXISTS experiments (
                trial_key TEXT NOT NULL, experiment_id TEXT NOT NULL, state TEXT NOT NULL,
                result_path TEXT NOT NULL, artifact_sha256 TEXT NOT NULL,
                PRIMARY KEY (trial_key, experiment_id)
            );
        """)
        connection.commit()
        return connection

    def _counts(self, db: sqlite3.Connection) -> None:
        counts = {row["state"]: row["n"] for row in db.execute("SELECT state, COUNT(*) n FROM trials GROUP BY state")}
        with self.guard:
            self.counters = {"trials": sum(counts.values()), "completed": counts.get("completed", 0),
                             "rejected": counts.get("rejected", 0), "running": counts.get("running", 0),
                             "recovered": db.execute("SELECT COALESCE(SUM(attempts - 1), 0) FROM trials").fetchone()[0],
                             "experiments": db.execute("SELECT COUNT(*) FROM experiments").fetchone()[0],
                             "experiments_rejected": db.execute("SELECT COUNT(*) FROM experiments WHERE state = 'rejected'").fetchone()[0],
                             "replay_trials": db.execute("SELECT COUNT(*) FROM experiments WHERE experiment_id LIKE 'replay:%'").fetchone()[0],
                             "replay_rejected": db.execute("SELECT COUNT(*) FROM experiments WHERE experiment_id LIKE 'replay:%' AND state = 'rejected'").fetchone()[0]}

    def _stopping(self) -> bool:
        return self.stop_event.is_set() or (self.config.state_dir / "SHUTDOWN").exists()

    def _publish(self, *, stopped: bool = False) -> None:
        paused = (self.config.state_dir / "STOP").exists()
        shutdown = (self.config.state_dir / "SHUTDOWN").exists()
        with self.guard:
            state = "error" if self.error else "running" if self.active_job else "paused" if paused or stopped or shutdown else "waiting"
            value = {"schema_version": STATUS_VERSION, "pid": os.getpid(), "started_at": self.started_at,
                     "heartbeat_at": _now(), "state": state, "active_job": self.active_job,
                     "reason": self.error or ("runner_stopped" if stopped else "shutdown_requested_active_job_finishing" if shutdown and self.active_job
                                             else "shutdown_requested" if shutdown else "pause_requested_active_job_finishing" if paused and self.active_job
                                             else "paused_by_STOP" if paused else "awaiting_changed_input" if not self.active_job else "research_in_progress"),
                     "interval_seconds": self.config.interval_seconds, "state_dir": str(self.config.state_dir),
                     "engine": dict(self.engine), "counters": dict(self.counters), "jobs": [dict(job) for job in self.jobs.values()],
                     "execution_authorized": False, "promotion_eligible": False, "llm_calls": 0}
        _write_bytes(self.config.state_dir / "status.json", _json_bytes(value), replace=True)

    def _engine_snapshot(self) -> tuple[dict[str, Any], Path]:
        payload = _read_bytes(self.config.engine, MAX_ENGINE_BYTES)
        native = payload.startswith(b"MZ") if os.name == "nt" else payload.startswith((b"\x7fELF", b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe"))
        if not native or len(payload) < 4:
            raise ValueError("engine must be a native build of canonical Rust strategy-lab")
        identity = {"path": str(self.config.engine), "sha256": _sha(payload)}
        snapshot = self.config.state_dir / "engines" / identity["sha256"] / self.config.engine.name
        if snapshot.exists():
            if _sha(_read_bytes(snapshot, MAX_ENGINE_BYTES)) != identity["sha256"]:
                raise IntegrityError("immutable engine snapshot hash mismatch")
        else:
            _write_bytes(snapshot, payload, executable=True)
        with self.guard:
            self.engine = identity
        return identity, snapshot

    def _receipt(self, directory: Path, name: str, value: Any) -> Path:
        path = directory / name
        if path.exists():
            if _read_bytes(path, MAX_ARTIFACT_BYTES) != _json_bytes(value):
                raise IntegrityError("immutable receipt differs from its recorded identity")
        else:
            _write_new(path, value)
        return path

    def _experiment(self, db: sqlite3.Connection, trial_key: str, directory: Path, name: str, operation: Any) -> dict[str, Any]:
        if self._stopping():
            raise ResearchInterrupted("shutdown requested; retain completed operations for restart")
        path = directory / ("experiment-" + _sha(name.encode()) + ".json")
        row = db.execute("SELECT * FROM experiments WHERE trial_key = ? AND experiment_id = ?", (trial_key, name)).fetchone()
        if path.exists():
            payload = _read_bytes(path, MAX_ARTIFACT_BYTES)
            outcome = _parse(payload)
            if ((row and row["artifact_sha256"] and _sha(payload) != row["artifact_sha256"])
                    or outcome.get("experiment_id") != name or outcome.get("trial_key") != trial_key):
                raise IntegrityError("immutable experiment receipt hash or identity mismatch")
        elif row and row["state"] != "running":
            raise IntegrityError("completed experiment receipt is missing; refusing a replacement")
        else:
            # Persist admission before launching a replay, so a process crash does
            # not erase an attempted experiment from the trial registry.
            db.execute("INSERT OR IGNORE INTO experiments VALUES (?, ?, 'running', ?, '')", (trial_key, name, str(path)))
            db.commit()
            self._counts(db)
            try:
                if self._stopping():
                    raise ResearchInterrupted("shutdown requested before operation admission")
                value = operation()
                outcome = {"trial_key": trial_key, "experiment_id": name, "state": "completed", "result": value,
                           "execution_authorized": False, "promotion_eligible": False}
            except (IntegrityError, ResearchInterrupted):
                raise
            except Exception as error:
                outcome = {"trial_key": trial_key, "experiment_id": name, "state": "rejected", "reason": _reason(error),
                           "execution_authorized": False, "promotion_eligible": False}
            _write_new(path, outcome)
            payload = _json_bytes(outcome)
        db.execute("INSERT INTO experiments VALUES (?, ?, ?, ?, ?) ON CONFLICT(trial_key, experiment_id) DO UPDATE SET state = excluded.state, artifact_sha256 = excluded.artifact_sha256",
                   (trial_key, name, outcome["state"], str(path), _sha(payload)))
        db.commit()
        self._counts(db)
        return outcome

    def _recover(self, db: sqlite3.Connection) -> None:
        for row in db.execute("SELECT * FROM trials").fetchall():
            directory = self.config.state_dir / "results" / row["trial_key"]
            final = directory / "result.json"
            if final.exists():
                if row["result_sha256"] and _sha(_read_bytes(final, MAX_ARTIFACT_BYTES)) != row["result_sha256"]:
                    raise IntegrityError("immutable final result hash mismatch")
                result = self._read_result(final, row["trial_key"])
                self._finish(db, result, final)
            elif row["state"] in ("completed", "rejected"):
                raise IntegrityError("completed trial artifact is missing; refusing to overwrite history")
            else:
                # Resume only when the exact input/runtime identity is seen again.
                db.execute("UPDATE trials SET state = 'pending', reason = 'interrupted_safe_to_resume' WHERE trial_key = ?", (row["trial_key"],))
        db.commit()
        self._counts(db)

    def _read_result(self, path: Path, trial_key: str) -> dict[str, Any]:
        result = _parse(_read_bytes(path, MAX_ARTIFACT_BYTES))
        if (result.get("schema_version") != RESULT_VERSION or result.get("trial_key") != trial_key
                or result.get("state") not in ("completed", "insufficient_evidence", "rejected")
                or result.get("execution_authorized") is not False or result.get("promotion_eligible") is not False):
            raise IntegrityError("invalid immutable trial result identity")
        for artifact in result["artifacts"]:
            name = artifact["file"]
            if not isinstance(name, str) or Path(name).name != name:
                raise IntegrityError("unsafe artifact name in immutable manifest")
            if _sha(_read_bytes(path.parent / name, MAX_ARTIFACT_BYTES)) != artifact["sha256"]:
                raise IntegrityError("immutable trial artifact hash mismatch")
        return result

    def _finish(self, db: sqlite3.Connection, result: dict[str, Any], path: Path) -> None:
        state = "rejected" if result["state"] == "rejected" else "completed"
        db.execute("UPDATE trials SET state = ?, finished_at = ?, result_path = ?, reason = ?, result_sha256 = ? WHERE trial_key = ?",
                   (state, result["finished_at"], str(path), result["reason"], _sha(_read_bytes(path, MAX_ARTIFACT_BYTES)), result["trial_key"]))
        db.commit()

    def _execute(self, db: sqlite3.Connection, job: Job, key: str, directory: Path, raw: dict[str, Any] | None,
                 registration: dict[str, Any] | None, rejection: str | None, engine: Path) -> dict[str, Any]:
        state, reason = "completed", "exploratory_research_only_no_promotion"
        if rejection:
            self._experiment(db, key, directory, "input-validation", lambda: (_ for _ in ()).throw(ValueError(rejection)))
            state, reason = "rejected", rejection
        elif job.kind == "source-capability":
            def capability() -> dict[str, Any]:
                _validate_capability(raw)
                return research.assess_retained_source(raw)

            outcome = self._experiment(db, key, directory, "source-capability", capability)
            state = "insufficient_evidence" if outcome["state"] == "completed" else "rejected"
            reason = outcome.get("reason", "Retained observations lack verified adjustments, complete sessions, and historical availability; strategy evaluation is unavailable.")
            if outcome["state"] == "completed":
                result = self._final_result(directory, key, state, reason)
                result["source_capability"] = outcome["result"]
                return result
        else:
            prepared = self._experiment(db, key, directory, "prepare", lambda: research.prepare(raw))
            if prepared["state"] == "rejected":
                state, reason = "rejected", prepared["reason"]
            elif prepared["result"]["evidence"]["classification"] != "observed":
                state, reason = "rejected", "synthetic_fixture is engineering evidence and cannot enter market performance reports"
            else:
                request = prepared["result"]
                # Registration is validated before any replay; it cannot authorize promotion.
                if registration is not None:
                    validation = self._experiment(db, key, directory, "registration-validation",
                                                  lambda: research.Registration.model_validate(registration).model_dump(mode="json"))
                    if validation["state"] == "rejected":
                        return self._final_result(directory, key, "rejected", validation["reason"])
                requests = [("baseline", request)]
                if job.sensitivity:
                    requests += research.sensitivity_requests(request)
                outcomes = []
                for name, variant in requests:
                    # STOP permits an active batch to finish. SHUTDOWN or SIGTERM
                    # preserves completed operations and admits no later replay.
                    replay = self._experiment(db, key, directory, "replay:" + name,
                                              lambda variant=variant: research.run_engine(engine, variant))
                    if replay["state"] == "completed":
                        evaluation = self._experiment(db, key, directory, "evaluation:" + name,
                                                      lambda replay=replay: research.evaluate_result(replay["result"], registration))
                        outcomes.append({"experiment_id": name, "state": evaluation["state"],
                                         "replay_run_id": replay["result"].get("run_id"),
                                         **({"reason": evaluation["reason"]} if evaluation["state"] == "rejected" else {})})
                    else:
                        outcomes.append({"experiment_id": name, "state": "rejected", "reason": replay["reason"]})
                if any(item["state"] == "rejected" for item in outcomes):
                    state, reason = "rejected", "one_or_more_predeclared_experiments_rejected; all attempts retained"
                self._receipt(directory, "batch.json", {"experiments": outcomes, "complete": all(item["state"] == "completed" for item in outcomes),
                                                        "selection_performed": False, "promotion_eligible": False, "execution_authorized": False})
        return self._final_result(directory, key, state, reason)

    def _final_result(self, directory: Path, key: str, state: str, reason: str) -> dict[str, Any]:
        artifacts = [{"file": path.name, "sha256": _sha(_read_bytes(path, MAX_ARTIFACT_BYTES))}
                     for path in sorted(directory.glob("*.json")) if path.name != "result.json"]
        replay_count = sum(_parse(_read_bytes(path, MAX_ARTIFACT_BYTES)).get("experiment_id", "").startswith("replay:")
                           for path in directory.glob("experiment-*.json"))
        return {"schema_version": RESULT_VERSION, "trial_key": key, "state": state, "reason": reason,
                "finished_at": _now(), "artifacts": artifacts,
                "replay_trial_count": replay_count, "selection_performed": False,
                "execution_authorized": False, "promotion_eligible": False, "llm_calls": 0}

    def _cycle(self, db: sqlite3.Connection) -> None:
        if (self.config.state_dir / "STOP").exists() or self._stopping():
            return
        if _runtime_identity() != self.runtime:
            raise IntegrityError("runner/evaluator source or dependency changed; restart before further research")
        engine_identity, engine_snapshot = self._engine_snapshot()
        for job in self.config.jobs:
            if (self.config.state_dir / "STOP").exists() or self._stopping():
                return
            input_identity, raw, rejection = _source(job.input, MAX_INPUT_BYTES)
            registration_identity, registration, registration_error = (None, None, None)
            if job.registration:
                registration_identity, registration, registration_error = _source(job.registration, MAX_REGISTRATION_BYTES)
            identity = {"kind": job.kind, "input": input_identity, "registration": registration_identity,
                        "sensitivity": job.sensitivity, "engine_sha256": engine_identity["sha256"], "runtime": self.runtime}
            key = _sha(_json_bytes(identity))
            row = db.execute("SELECT * FROM trials WHERE trial_key = ?", (key,)).fetchone()
            directory = self.config.state_dir / "results" / key
            final = directory / "result.json"
            if row and row["state"] in ("completed", "rejected"):
                if _sha(_read_bytes(final, MAX_ARTIFACT_BYTES)) != row["result_sha256"]:
                    raise IntegrityError("immutable final result hash mismatch")
                result = self._read_result(final, key)
            else:
                with self.guard:
                    self.active_job = job.id
                    self.jobs[job.id].update(state="running", reason="research_in_progress", trial_key=key, result_path=None)
                if row:
                    db.execute("UPDATE trials SET state = 'running', attempts = attempts + 1 WHERE trial_key = ?", (key,))
                else:
                    db.execute("INSERT INTO trials (trial_key, kind, state, started_at) VALUES (?, ?, 'running', ?)", (key, job.kind, _now()))
                db.commit()
                self._counts(db)
                self._receipt(directory, "identity.json", identity)
                try:
                    result = self._execute(db, job, key, directory, raw, registration, rejection or registration_error, engine_snapshot)
                except ResearchInterrupted:
                    reason = "shutdown_requested_resume_retained_experiments"
                    db.execute("UPDATE trials SET state = 'pending', reason = ? WHERE trial_key = ?", (reason, key))
                    db.commit()
                    with self.guard:
                        self.jobs[job.id].update(state="pending", reason=reason, trial_key=key, result_path=None)
                        self.active_job = None
                    self._counts(db)
                    raise
                self._receipt(directory, "result.json", result)
                self._finish(db, result, final)
            with self.guard:
                self.jobs[job.id].update(state=result["state"], reason=result["reason"], trial_key=key, result_path=str(final))
                self.active_job = None
            self._counts(db)

    def _work(self, once: bool) -> None:
        try:
            with closing(self._connect()) as db:
                self._recover(db)
                while not self._stopping():
                    self._cycle(db)
                    if once:
                        break
                    # Short waits notice STOP removal and process shutdown promptly.
                    deadline = time.monotonic() + self.config.interval_seconds
                    while time.monotonic() < deadline and not self._stopping():
                        self.stop_event.wait(min(0.5, max(0, deadline - time.monotonic())))
        except ResearchInterrupted:
            pass
        except Exception as error:
            with self.guard:
                self.error = _reason(error)
                self.active_job = None

    def run(self, *, once: bool = False) -> int:
        with exclusive_lock(self.config.state_dir):
            self._publish()
            worker = threading.Thread(target=self._work, args=(once,), name="continuous-research", daemon=False)
            worker.start()
            handlers = {}
            if threading.current_thread() is threading.main_thread():
                for signum in (signal.SIGINT, signal.SIGTERM):
                    handlers[signum] = signal.signal(signum, lambda _signal, _frame: self.stop_event.set())
            try:
                while worker.is_alive():
                    worker.join(HEARTBEAT_SECONDS)
                    self._publish()
                self._publish(stopped=not once)
            finally:
                self.stop_event.set()
                worker.join()
                for signum, handler in handlers.items():
                    signal.signal(signum, handler)
            return 1 if self.error else 0


def run(config: Config, *, once: bool = False) -> int:
    return Runner(config).run(once=once)


def main() -> None:
    parser = argparse.ArgumentParser(description="Local continuous research; no LLM calls, data downloads, trading, or automatic promotion")
    parser.add_argument("operation", choices=("run", "status", "pause", "resume", "stop"))
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--once", action="store_true", help="scan each configured job once, retaining content deduplication")
    args = parser.parse_args()
    try:
        config = load_config(args.config)
        if args.once and args.operation != "run":
            raise ValueError("--once applies only to run")
        if args.operation == "run":
            raise SystemExit(run(config, once=args.once))
        if args.operation == "pause":
            config.state_dir.mkdir(parents=True, exist_ok=True)
            (config.state_dir / "STOP").touch(exist_ok=True)
        elif args.operation == "resume":
            (config.state_dir / "STOP").unlink(missing_ok=True)
        elif args.operation == "stop":
            config.state_dir.mkdir(parents=True, exist_ok=True)
            (config.state_dir / "SHUTDOWN").touch(exist_ok=True)
        print(json.dumps(read_status(config.state_dir), allow_nan=False))
    except (OSError, ValueError, RunnerLocked) as error:
        parser.exit(2, _reason(error) + "\n")


if __name__ == "__main__":
    main()

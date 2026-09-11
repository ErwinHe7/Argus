from __future__ import annotations

import ast
import copy
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from contextlib import closing
from pathlib import Path
from unittest.mock import patch

from intraday_quant.strategy_lab import continuous, research


def retained():
    return {"provider": "retained IBKR test metadata", "retrievedAt": "2026-09-07T00:00:00Z", "symbols": [
        {"symbol": "TEST", "history": {"bars": [{"date": "2026-09-04", "close": 123.456}], "adjustmentPolicy": "unknown"}}]}


def fixture_source():
    return {"schema_version": "leo-strategy-source.v1", "symbol": "TEST", "strategy": "MR-v1", "code_revision": "test-only",
            "evidence": {"source": "synthetic unit fixture", "dataset_sha256": "a" * 64, "calendar_source": "pending",
                         "adjustment_verified": True, "coverage_verified": False, "availability_verified": True,
                         "classification": "synthetic_fixture", "license_scope": "unit_test_only"},
            "bars": [{"session_date": day, "available_at": day + "T21:01:00Z", "open": "100", "high": "101", "low": "99", "close": "100", "volume": 100}
                     for day in ("2024-07-02", "2024-07-03", "2024-07-05")]}


class ContinuousResearchTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name).resolve()
        self.source = self.root / "source.json"
        self.source.write_text(json.dumps(retained()), encoding="utf-8")
        self.engine = self.root / ("strategy-lab.exe" if os.name == "nt" else "strategy-lab")
        # A native-header stub is never launched; actual execution is patched only
        # in orchestration unit tests, which never claim market performance.
        self.engine.write_bytes((b"MZ" if os.name == "nt" else b"\x7fELF") + b"unit test binary bytes")
        self.config_path = self.root / "config.json"
        self.raw_config = {"schema_version": continuous.CONFIG_VERSION, "state_dir": str(self.root / "state"),
                           "engine": str(self.engine), "interval_seconds": 5,
                           "jobs": [{"id": "retained", "kind": "source-capability", "input": str(self.source)}]}
        self.save_config()

    def tearDown(self):
        self.temporary.cleanup()

    def save_config(self):
        self.config_path.write_text(json.dumps(self.raw_config), encoding="utf-8")
        self.config = continuous.load_config(self.config_path)

    def once(self):
        self.assertEqual(continuous.run(self.config, once=True), 0)
        return continuous.read_status(self.config.state_dir)

    def result(self, status):
        path = Path(status["jobs"][0]["result_path"])
        return path, json.loads(path.read_text(encoding="utf-8"))

    def research_job(self, *, sensitivity=False):
        self.source.write_text(json.dumps(fixture_source()), encoding="utf-8")
        self.raw_config["jobs"] = [{"id": "research", "kind": "research", "input": str(self.source), "sensitivity": sensitivity}]
        self.save_config()

    def test_capability_is_explicit_insufficient_evidence_with_options_separate(self):
        status = self.once()
        self.assertEqual(status["jobs"][0]["state"], "insufficient_evidence")
        path, result = self.result(status)
        capability = result["source_capability"]
        self.assertFalse(capability["strategy_evaluation_available"])
        self.assertNotIn("123.456", json.dumps(capability))
        self.assertIn("fewer_than_220_completed_sessions", capability["symbols"][0]["blockers"])
        self.assertNotIn("historical_executable_option_chain_missing", capability["symbols"][0]["blockers"])
        self.assertIn("historical_executable_option_chain_missing", capability["symbols"][0]["options_only_limitations"])
        self.assertFalse(result["execution_authorized"])
        self.assertFalse(result["promotion_eligible"])
        self.assertEqual(status["llm_calls"], 0)

    def test_semantically_unchanged_inputs_and_restart_do_not_create_trials(self):
        first = self.once()
        first_path, _ = self.result(first)
        first_bytes = first_path.read_bytes()
        self.source.write_text(json.dumps(retained(), indent=4), encoding="utf-8")
        with patch.object(research, "assess_retained_source", side_effect=AssertionError("must reuse receipt")):
            second = self.once()
        self.assertEqual(second["counters"]["trials"], 1)
        self.assertEqual(second["counters"]["experiments"], 1)
        self.assertEqual(second["jobs"][0]["trial_key"], first["jobs"][0]["trial_key"])
        self.assertEqual(first_bytes, first_path.read_bytes())

    def test_duplicate_content_across_jobs_deduplicates_and_new_content_replays(self):
        self.raw_config["jobs"].append({**self.raw_config["jobs"][0], "id": "alias"})
        self.save_config()
        self.assertEqual(self.once()["counters"]["trials"], 1)
        raw = retained()
        raw["retrievedAt"] = "2026-09-08T00:00:00Z"
        self.source.write_text(json.dumps(raw), encoding="utf-8")
        self.assertEqual(self.once()["counters"]["trials"], 2)

    def test_engine_byte_identity_invalidates_cache_without_mutating_prior_snapshot(self):
        first = self.once()
        snapshot = self.config.state_dir / "engines" / first["engine"]["sha256"] / self.engine.name
        original = snapshot.read_bytes()
        self.engine.write_bytes(self.engine.read_bytes() + b"changed")
        second = self.once()
        self.assertEqual(second["counters"]["trials"], 2)
        self.assertNotEqual(first["engine"]["sha256"], second["engine"]["sha256"])
        self.assertEqual(snapshot.read_bytes(), original)

    def test_runtime_dependency_identity_invalidates_cache(self):
        self.once()
        identity = continuous._runtime_identity()
        identity["dependencies"]["test-runtime"] = "changed"
        with patch.object(continuous, "_runtime_identity", return_value=identity):
            second = self.once()
        self.assertEqual(second["counters"]["trials"], 2)

    def test_invalid_json_missing_input_and_capability_limits_are_durable_rejects(self):
        for payload in ('{"provider":"a","provider":"b"}', '{"a":NaN}', '[]'):
            self.source.write_text(payload, encoding="utf-8")
            status = self.once()
            self.assertEqual(status["jobs"][0]["state"], "rejected")
        prior = status["counters"]["trials"]
        self.assertEqual(self.once()["counters"]["trials"], prior)
        self.source.unlink()
        status = self.once()
        self.assertEqual(status["jobs"][0]["state"], "rejected")
        self.source.write_text(json.dumps({"provider": "test", "symbols": [{}] * 65}), encoding="utf-8")
        status = self.once()
        self.assertEqual(status["jobs"][0]["state"], "rejected")
        self.assertIn("64 symbols", status["jobs"][0]["reason"])

    def test_bounded_input_rejects_without_engine_call(self):
        with patch.object(continuous, "MAX_INPUT_BYTES", 1024):
            # Source/runtime modules exceed this test limit too, so keep their
            # previously computed identity constant while exercising input bounds.
            identity = {"python": "test", "sources": {}, "dependencies": {}}
            with patch.object(continuous, "_runtime_identity", return_value=identity):
                self.source.write_text(" " * 1025, encoding="utf-8")
                status = self.once()
        self.assertEqual(status["jobs"][0]["state"], "rejected")

    @unittest.skipUnless(hasattr(os, "mkfifo"), "POSIX FIFO coverage; Windows descriptor checks run separately")
    def test_fifo_input_is_rejected_without_waiting_for_a_writer(self):
        fifo = self.root / "source.fifo"
        os.mkfifo(fifo)
        # A timeout turns regressions into a bounded failure instead of hanging
        # the entire test run on open() before fstat() can inspect the FIFO.
        code = ("from pathlib import Path\nfrom intraday_quant.strategy_lab.continuous import _read_bytes\n"
                "import sys\ntry:\n _read_bytes(Path(sys.argv[1]), 1024)\n"
                "except ValueError:\n sys.exit(0)\nsys.exit(1)\n")
        result = subprocess.run([sys.executable, "-c", code, str(fifo)], capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr.decode())

    def test_rejected_descriptor_is_closed_before_reading(self):
        opened = os.open(self.source, os.O_RDONLY | getattr(os, "O_BINARY", 0))
        metadata = os.stat_result((0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        with patch.object(os, "open", return_value=opened), patch.object(os, "fstat", return_value=metadata), \
             patch.object(os, "fdopen", side_effect=AssertionError("must reject descriptor before reading")):
            with self.assertRaisesRegex(ValueError, "regular"):
                continuous._read_bytes(self.source, 1024)
        with self.assertRaises(OSError):
            os.fstat(opened)

    @unittest.skipUnless(os.name == "nt", "Windows delete-sharing semantics")
    def test_atomic_status_retries_transient_windows_reader_conflict(self):
        status = self.root / "status.json"
        status.write_bytes(b"old complete snapshot")
        original_replace = os.replace
        attempts = []

        def replace(source, target):
            attempts.append(1)
            if len(attempts) < 3:
                self.assertEqual(status.read_bytes(), b"old complete snapshot")
                error = PermissionError("test reader temporarily denies delete sharing")
                error.winerror = 32
                raise error
            return original_replace(source, target)

        with patch.object(os, "replace", side_effect=replace), patch.object(time, "sleep"):
            continuous._write_bytes(status, b"new complete snapshot", replace=True)
        self.assertEqual(len(attempts), 3)
        self.assertEqual(status.read_bytes(), b"new complete snapshot")

    def test_strict_configuration_and_canonical_binary_name(self):
        cases = []
        for key, value in (("interval_seconds", True), ("interval_seconds", 4), ("interval_seconds", 86401),
                           ("engine", "relative/strategy-lab"), ("state_dir", "relative"),
                           ("engine", str(self.root / "python.exe")), ("extra", 1), ("jobs", [])):
            raw = copy.deepcopy(self.raw_config)
            raw[key] = value
            cases.append(raw)
        raw = copy.deepcopy(self.raw_config)
        raw["jobs"] *= 33
        cases.append(raw)
        for value in ({"id": "../escape"}, {"sensitivity": "true"}, {"extra": 1}, {"registration": "relative.json"}):
            raw = copy.deepcopy(self.raw_config)
            raw["jobs"][0].update(value)
            cases.append(raw)
        for raw in cases:
            with self.subTest(raw=raw):
                self.config_path.write_text(json.dumps(raw), encoding="utf-8")
                with self.assertRaises(ValueError):
                    continuous.load_config(self.config_path)

    def test_non_native_engine_fails_before_processing(self):
        self.engine.write_bytes(b"#!/bin/sh\necho unsafe script")
        self.assertEqual(continuous.run(self.config, once=True), 1)
        status = continuous.read_status(self.config.state_dir)
        self.assertEqual(status["state"], "error")
        self.assertEqual(status["counters"]["trials"], 0)

    def test_stop_file_pauses_and_resume_reuses_trials(self):
        self.config.state_dir.mkdir()
        stop = self.config.state_dir / "STOP"
        stop.touch()
        paused = self.once()
        self.assertEqual(paused["state"], "paused")
        self.assertEqual(paused["counters"]["trials"], 0)
        stop.unlink()
        self.assertEqual(self.once()["counters"]["trials"], 1)
        stop.touch()
        self.assertEqual(self.once()["counters"]["trials"], 1)

    def test_shutdown_is_preserved_by_ordinary_restart(self):
        self.config.state_dir.mkdir()
        shutdown = self.config.state_dir / "SHUTDOWN"
        shutdown.touch()
        status = self.once()
        self.assertTrue(shutdown.exists())
        self.assertEqual(status["state"], "paused")
        self.assertEqual(status["reason"], "shutdown_requested")
        self.assertEqual(status["counters"]["trials"], 0)

    def test_competing_process_cannot_enter_os_held_lock(self):
        with continuous.exclusive_lock(self.config.state_dir):
            result = subprocess.run([sys.executable, "-m", "intraday_quant.strategy_lab.continuous", "run", "--config", str(self.config_path), "--once"],
                                    capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 2)
        self.assertIn("another continuous research runner", result.stderr)
        self.assertIsNone(continuous.read_status(self.config.state_dir))
        self.assertEqual(self.once()["counters"]["trials"], 1)

    def test_completed_artifact_recovers_if_process_dies_before_sqlite_completion(self):
        original_finish = continuous.Runner._finish
        with patch.object(continuous.Runner, "_finish", side_effect=RuntimeError("simulated process crash after immutable publication")):
            self.assertEqual(continuous.run(self.config, once=True), 1)
        final = next((self.config.state_dir / "results").glob("*/result.json"))
        original = final.read_bytes()
        with patch.object(research, "assess_retained_source", side_effect=AssertionError("must not repeat completed work")):
            status = self.once()
        self.assertEqual(status["counters"]["trials"], 1)
        self.assertEqual(status["counters"]["completed"], 1)
        self.assertEqual(original, final.read_bytes())
        self.assertIs(continuous.Runner._finish, original_finish)

    def test_tampered_or_missing_completed_artifact_fails_closed_without_overwrite(self):
        status = self.once()
        path, _ = self.result(status)
        capability_path = next(path.parent.glob("experiment-*.json"))
        original = capability_path.read_bytes()
        capability_path.write_bytes(b"{}")
        self.assertEqual(continuous.run(self.config, once=True), 1)
        self.assertEqual(capability_path.read_bytes(), b"{}")
        capability_path.write_bytes(original)
        path.unlink()
        self.assertEqual(continuous.run(self.config, once=True), 1)
        self.assertFalse(path.exists())

    def test_tampered_final_result_cannot_change_reported_evidence(self):
        path, result = self.result(self.once())
        result["source_capability"]["strategy_evaluation_available"] = True
        path.write_text(json.dumps(result), encoding="utf-8")
        tampered = path.read_bytes()
        self.assertEqual(continuous.run(self.config, once=True), 1)
        self.assertEqual(path.read_bytes(), tampered)
        self.assertIn("final result hash mismatch", continuous.read_status(self.config.state_dir)["reason"])

    def test_synthetic_fixture_never_reaches_performance_evaluator(self):
        self.research_job()
        with patch.object(research, "run_engine", side_effect=AssertionError("no performance replay of fixture")):
            status = self.once()
        self.assertEqual(status["jobs"][0]["state"], "rejected")
        self.assertIn("synthetic_fixture", status["jobs"][0]["reason"])

    def test_unverified_source_rejected_without_echoing_private_input_values(self):
        self.research_job()
        raw = fixture_source()
        raw["evidence"]["adjustment_verified"] = False
        raw["private_secret_marker"] = "SECRET_SHOULD_NOT_BE_LOGGED"
        self.source.write_text(json.dumps(raw), encoding="utf-8")
        with patch.object(research, "run_engine", side_effect=AssertionError("unverified source must fail before replay")):
            status = self.once()
        self.assertEqual(status["jobs"][0]["state"], "rejected")
        self.assertNotIn("SECRET_SHOULD_NOT_BE_LOGGED", json.dumps(status))

    def test_full_shared_sensitivity_retains_every_failure_and_success(self):
        self.research_job(sensitivity=True)
        prepared = {"strategy": "MR-v1", "commission_per_order": "1", "slippage_bps": 10,
                    "evidence": {"classification": "observed"}}
        requests = research.sensitivity_requests(prepared)
        calls = []

        def replay(_engine, request):
            calls.append(copy.deepcopy(request))
            if len(calls) == 3:
                raise ValueError("bounded replay rejection")
            return {"run_id": f"test-fixture-{len(calls)}", "input_manifest": request}

        with patch.object(research, "prepare", return_value=prepared), patch.object(research, "run_engine", side_effect=replay), \
             patch.object(research, "evaluate_result", return_value={"unit_test_only": True, "promotion_eligible": False}):
            status = self.once()
        path, _ = self.result(status)
        batch = json.loads((path.parent / "batch.json").read_text())
        self.assertEqual(len(calls), 1 + len(requests))
        self.assertEqual(len(batch["experiments"]), 1 + len(requests))
        self.assertEqual(sum(item["state"] == "rejected" for item in batch["experiments"]), 1)
        self.assertFalse(batch["complete"])
        self.assertFalse(batch["selection_performed"])
        self.assertFalse(batch["promotion_eligible"])
        self.assertEqual(status["jobs"][0]["state"], "rejected")

    def test_partial_research_recovery_reuses_successful_replay(self):
        self.research_job()
        prepared = {"evidence": {"classification": "observed"}}
        original_experiment = continuous.Runner._experiment

        def interrupted(runner, db, key, directory, name, operation):
            if name == "evaluation:baseline":
                raise RuntimeError("simulated interruption before evaluation")
            return original_experiment(runner, db, key, directory, name, operation)

        with patch.object(research, "prepare", return_value=prepared), patch.object(research, "run_engine", return_value={"run_id": "unit-test"}) as replay:
            with patch.object(continuous.Runner, "_experiment", new=interrupted):
                self.assertEqual(continuous.run(self.config, once=True), 1)
            self.assertEqual(replay.call_count, 1)
            with patch.object(research, "evaluate_result", return_value={"unit_test_only": True}):
                status = self.once()
            self.assertEqual(replay.call_count, 1)
        self.assertEqual(status["counters"]["trials"], 1)
        self.assertEqual(status["counters"]["recovered"], 1)

    def test_replay_admission_is_durable_before_engine_starts(self):
        self.research_job()

        def replay(_engine, _request):
            with closing(sqlite3.connect(self.config.state_dir / "trials.sqlite3")) as db:
                self.assertEqual(db.execute("SELECT state FROM experiments WHERE experiment_id = 'replay:baseline'").fetchone()[0], "running")
            raise ValueError("deliberate replay rejection")

        with patch.object(research, "prepare", return_value={"evidence": {"classification": "observed"}}), \
             patch.object(research, "run_engine", side_effect=replay):
            status = self.once()
        self.assertEqual(status["counters"]["replay_trials"], 1)
        self.assertEqual(status["counters"]["replay_rejected"], 1)

    def _check_shutdown_and_resume(self, *, marker):
        self.research_job(sensitivity=True)
        prepared = {"strategy": "MR-v1", "commission_per_order": "1", "slippage_bps": 10,
                    "evidence": {"classification": "observed"}}
        runner = continuous.Runner(self.config)
        calls = []

        def replay(_engine, request):
            calls.append(copy.deepcopy(request))
            if len(calls) == 1:
                if marker:
                    (self.config.state_dir / "SHUTDOWN").touch()
                else:
                    # SIGINT and SIGTERM handlers set exactly this event.
                    runner.stop_event.set()
            return {"run_id": f"unit-test-replay-{len(calls)}", "input_manifest": request}

        with patch.object(research, "prepare", return_value=prepared), patch.object(research, "run_engine", side_effect=replay), \
             patch.object(research, "evaluate_result", return_value={"unit_test_only": True}) as evaluation:
            self.assertEqual(runner.run(once=True), 0)
            status = continuous.read_status(self.config.state_dir)
            self.assertEqual(len(calls), 1)
            evaluation.assert_not_called()
            self.assertEqual(status["jobs"][0]["state"], "pending")
            self.assertEqual(status["counters"]["rejected"], 0)
            self.assertIsNone(status["jobs"][0]["result_path"])
            directory = self.config.state_dir / "results" / status["jobs"][0]["trial_key"]
            self.assertFalse((directory / "result.json").exists())
            replay_path = directory / ("experiment-" + continuous._sha(b"replay:baseline") + ".json")
            original_replay = replay_path.read_bytes()
            with closing(sqlite3.connect(self.config.state_dir / "trials.sqlite3")) as db:
                self.assertEqual(db.execute("SELECT state FROM trials").fetchone()[0], "pending")
            (self.config.state_dir / "SHUTDOWN").unlink(missing_ok=True)
            resumed = self.once()
        self.assertEqual(len(calls), 1 + len(research.sensitivity_requests(prepared)))
        self.assertEqual(replay_path.read_bytes(), original_replay)
        self.assertEqual(resumed["counters"]["trials"], 1)
        self.assertEqual(resumed["counters"]["recovered"], 1)
        self.assertEqual(resumed["jobs"][0]["state"], "completed")

    def test_shutdown_stops_after_current_replay_and_explicit_restart_resumes(self):
        self._check_shutdown_and_resume(marker=True)

    def test_signal_event_stops_after_current_replay_and_restart_resumes(self):
        self._check_shutdown_and_resume(marker=False)

    def test_changed_registration_invalidates_identity_even_when_rejected(self):
        self.research_job()
        registration = self.root / "registration.json"
        registration.write_text('{"invalid_registration":1}', encoding="utf-8")
        self.raw_config["jobs"][0]["registration"] = str(registration)
        self.save_config()
        first = self.once()
        registration.write_text('{"invalid_registration":2}', encoding="utf-8")
        second = self.once()
        self.assertNotEqual(first["jobs"][0]["trial_key"], second["jobs"][0]["trial_key"])
        self.assertEqual(second["counters"]["trials"], 2)

    def test_heartbeat_continues_during_replay_and_pause_blocks_next_job(self):
        self.research_job()
        self.raw_config["jobs"].append({"id": "second", "kind": "source-capability", "input": str(self.root / "missing.json")})
        self.save_config()
        entered, release = threading.Event(), threading.Event()
        prepared = {"evidence": {"classification": "observed"}}

        def replay(_engine, _request):
            entered.set()
            self.assertTrue(release.wait(10))
            return {"run_id": "unit-test"}

        with patch.object(continuous, "HEARTBEAT_SECONDS", 0.05), patch.object(research, "prepare", return_value=prepared), \
             patch.object(research, "run_engine", side_effect=replay), patch.object(research, "evaluate_result", return_value={"unit_test_only": True}):
            runner = continuous.Runner(self.config)
            thread = threading.Thread(target=runner.run, kwargs={"once": True})
            thread.start()
            try:
                self.assertTrue(entered.wait(10))
                (self.config.state_dir / "STOP").touch()
                deadline = time.monotonic() + 5
                snapshots = []
                while time.monotonic() < deadline and len(snapshots) < 2:
                    current = continuous.read_status(self.config.state_dir)
                    if current["active_job"] == "research" and (not snapshots or current["heartbeat_at"] != snapshots[-1]["heartbeat_at"]):
                        snapshots.append(current)
                    time.sleep(0.03)
                self.assertEqual(len(snapshots), 2)
                self.assertEqual(snapshots[-1]["state"], "running")
                self.assertEqual(snapshots[-1]["pid"], os.getpid())
            finally:
                release.set()
                thread.join(15)
            self.assertFalse(thread.is_alive())
        status = continuous.read_status(self.config.state_dir)
        self.assertEqual(status["state"], "paused")
        self.assertEqual(status["jobs"][1]["state"], "pending")
        self.assertEqual(status["counters"]["trials"], 1)

    def test_no_network_or_llm_client_is_part_of_runner(self):
        tree = ast.parse(Path(continuous.__file__).read_text(encoding="utf-8"))
        imports = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imports.update(alias.name.split(".")[0] for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                imports.add(node.module.split(".")[0])
        self.assertFalse(imports & {"openai", "anthropic", "requests", "httpx", "socket", "urllib", "moomoo", "ib_insync"})
        with patch("socket.create_connection", side_effect=AssertionError("network forbidden")), \
             patch("subprocess.run", side_effect=AssertionError("capability must not invoke processes")):
            status = self.once()
        self.assertEqual(status["llm_calls"], 0)
        self.assertFalse(status["execution_authorized"])


if __name__ == "__main__":
    unittest.main()

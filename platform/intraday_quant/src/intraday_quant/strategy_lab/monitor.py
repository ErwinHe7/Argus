"""Loopback-only research monitor. No broker, AI, arbitrary file or command API."""
from __future__ import annotations

import argparse
import hmac
import json
import secrets
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

MAX_JSON = 2 * 1024 * 1024
PLATFORM = Path(__file__).resolve().parents[4]
WEB = PLATFORM / "connectors/research-runner/web"


def read_json(path: Path, maximum: int = MAX_JSON) -> dict:
    with path.open("rb") as stream:
        payload = stream.read(maximum + 1)
    if len(payload) > maximum:
        raise ValueError("File exceeds the monitor limit")
    result = json.loads(payload)
    if not isinstance(result, dict):
        raise ValueError("Expected a JSON object")
    return result


def state_directory(config_path: Path) -> Path:
    raw = read_json(config_path, 64 * 1024)
    if raw.get("schema_version") != "leo-continuous-research-config.v1":
        raise ValueError("Unsupported research configuration")
    state = Path(raw["state_dir"])
    if not state.is_absolute():
        raise ValueError("The state directory must be absolute")
    return state.resolve()


def snapshot(state: Path) -> dict:
    """Expose bounded operational metadata, never raw market histories or paths."""
    base = {"schema_version": "leo-research-monitor.v1", "execution_authorized": False,
            "promotion_eligible": False, "llm_calls": 0, "state": "unavailable",
            "heartbeat_age_seconds": None, "fresh": False, "jobs": [], "coverage": []}
    try:
        raw = read_json(state / "status.json")
        if raw.get("schema_version") != "leo-continuous-research-status.v1":
            raise ValueError("Unsupported worker status")
        if raw.get("execution_authorized") is not False or raw.get("promotion_eligible") is not False or raw.get("llm_calls") != 0:
            raise ValueError("Unexpected worker authority")
        stamp = datetime.fromisoformat(raw["heartbeat_at"].replace("Z", "+00:00"))
        if stamp.tzinfo is None:
            raise ValueError("Heartbeat needs a timezone")
        age = (datetime.now(timezone.utc) - stamp).total_seconds()
        if age < -5:
            raise ValueError("Worker clock is ahead; status cannot be verified")
        base.update(state=str(raw.get("state", "unavailable"))[:32], heartbeat_age_seconds=max(0, round(age)),
                    heartbeat_at=raw["heartbeat_at"], started_at=raw.get("started_at"),
                    fresh=age <= 20, active_job=raw.get("active_job"),
                    interval_seconds=raw.get("interval_seconds"),
                    pause_requested=(state / "STOP").exists(), shutdown_requested=(state / "SHUTDOWN").exists())
        if raw.get("state") == "error":
            base["reason"] = ("The worker stopped after a source or dependency change. Restart it after updates finish."
                              if "source or dependency changed" in str(raw.get("reason", ""))
                              else "The worker stopped with an error. Inspect its local logs before restarting.")
        if not isinstance(raw.get("jobs", []), list) or not isinstance(raw.get("counters", {}), dict):
            raise ValueError("Malformed worker records")
        base["counters"] = {key: value for key, value in raw.get("counters", {}).items()
                            if key in {"trials", "completed", "rejected", "running", "recovered", "experiments", "replay_trials", "replay_rejected"}
                            and type(value) is int and value >= 0}
        for item in raw.get("jobs", [])[:32]:
            if not isinstance(item, dict):
                raise ValueError("Malformed job record")
            row = {key: str(item.get(key) or "")[:2000] for key in ("id", "kind", "state", "reason")}
            row["trial_key"] = str(item.get("trial_key") or "")[:64]
            base["jobs"].append(row)
            if item.get("kind") != "source-capability" or not item.get("result_path"):
                continue
            result_path = Path(item["result_path"]).resolve()
            if not result_path.is_relative_to(state):
                continue
            try:
                report = read_json(result_path)
                if report.get("schema_version") == "leo-continuous-research-result.v1":
                    report = report.get("source_capability", {})
                if report.get("schema_version") != "leo-strategy-source-capability.v1":
                    continue
                base["source"] = str(report.get("source", ""))[:200]
                base["retrieved_at"] = str(report.get("retrieved_at", ""))[:60]
                for symbol in report.get("symbols", [])[:64]:
                    base["coverage"].append({key: symbol.get(key) for key in (
                        "symbol", "observed_sessions", "first_session", "last_session", "blockers")})
            except (OSError, ValueError, TypeError, KeyError):
                continue
        base["attention_count"] = sum(row["state"] in {"rejected", "insufficient_evidence"} for row in base["jobs"])
        return base
    except (OSError, ValueError, TypeError, KeyError) as error:
        base["reason"] = "Worker status is unavailable. Start the runner or inspect its local logs."
        base["error_type"] = type(error).__name__
        return base


class MonitorServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, port: int, state: Path):
        self.state_dir = state
        self.control_token = secrets.token_urlsafe(32)
        super().__init__(("127.0.0.1", port), Handler)


class Handler(BaseHTTPRequestHandler):
    server: MonitorServer

    def log_message(self, format: str, *args) -> None:
        # Never log headers, tokens, state paths, request bodies or market files.
        pass

    def trusted(self, *, control: bool = False) -> bool:
        port = self.server.server_port
        hosts = {f"127.0.0.1:{port}", f"localhost:{port}"}
        if self.headers.get("Host") not in hosts:
            return False
        origin = self.headers.get("Origin")
        if origin is not None and origin not in {f"http://{host}" for host in hosts}:
            return False
        if self.path.startswith("/api/") and self.headers.get("Sec-Fetch-Site") == "cross-site":
            return False
        if control:
            return origin is not None and hmac.compare_digest(
                self.headers.get("X-Leo-Control", ""), self.server.control_token)
        return True

    def send(self, status: int, body: bytes, content_type: str = "application/json") -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; font-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
        self.end_headers()
        self.wfile.write(body)

    def data(self, status: int, value: dict) -> None:
        self.send(status, json.dumps(value, allow_nan=False).encode())

    def do_GET(self) -> None:
        if not self.trusted():
            self.data(403, {"error": "Local requests only"})
            return
        path = urlsplit(self.path).path
        if path == "/api/status":
            self.data(200, snapshot(self.server.state_dir))
            return
        files = {
            "/": (WEB / "index.html", "text/html; charset=utf-8"),
            "/monitor.js": (WEB / "monitor.js", "text/javascript; charset=utf-8"),
            "/monitor.css": (WEB / "monitor.css", "text/css; charset=utf-8"),
            "/assets/inter.ttf": (PLATFORM / "public/app/research-desk/inter.ttf", "font/ttf"),
            "/assets/lion.png": (PLATFORM / "public/app/research-desk/lion.png", "image/png"),
        }
        if path not in files:
            self.data(404, {"error": "Not found"})
            return
        file, content_type = files[path]
        try:
            body = file.read_bytes()
            if path == "/":
                body = body.replace(b"__CONTROL_TOKEN__", self.server.control_token.encode())
            self.send(200, body, content_type)
        except OSError:
            self.data(503, {"error": "Monitor assets are unavailable"})

    def do_POST(self) -> None:
        if not self.trusted(control=True):
            self.data(403, {"error": "Open the local monitor to use research controls"})
            return
        if self.path != "/api/control" or self.headers.get("Content-Type") != "application/json":
            self.data(400, {"error": "Unsupported research control"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= 128:
                raise ValueError("Invalid control size")
            request = json.loads(self.rfile.read(length))
            if request not in ({"action": "pause"}, {"action": "resume"}):
                raise ValueError("Only research pause and resume are supported")
            marker = self.server.state_dir / "STOP"
            if request["action"] == "pause":
                marker.parent.mkdir(parents=True, exist_ok=True)
                with marker.open("a", encoding="utf-8"):
                    pass
            else:
                current = snapshot(self.server.state_dir)
                if not current.get("fresh") or current.get("shutdown_requested") or current.get("state") in {"error", "stopped", "stopping", "unavailable"}:
                    self.data(409, {"error": "Start the worker and wait for a fresh heartbeat before resuming"})
                    return
                marker.unlink(missing_ok=True)
            self.data(202, {"requested": request["action"], "scope": "research_only"})
        except (OSError, ValueError, TypeError):
            self.data(400, {"error": "Research control could not be recorded"})


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--port", type=int, default=3119)
    args = parser.parse_args()
    if not args.config.is_absolute() or not 1024 <= args.port <= 65535:
        parser.error("Use an absolute config path and an unprivileged local port")
    state = state_directory(args.config)
    server = MonitorServer(args.port, state)
    server.timeout = 0.5
    print(f"Leo research monitor: http://127.0.0.1:{args.port}", flush=True)
    try:
        while not (state / "MONITOR_SHUTDOWN").exists():
            server.handle_request()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

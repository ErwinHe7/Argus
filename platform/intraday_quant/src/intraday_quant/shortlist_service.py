"""Continuously export the existing descriptive shortlist without LLM calls.

Only ``public_dir/current.json`` is the atomic publication contract. The input
and private immutable receipts are never web resources. This is a file watcher,
not a market-data downloader, performance model, or broker connector.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import date, datetime, timezone
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import re
import signal
import stat
import sys
import tempfile
import threading
import time
from typing import Any, Iterator
import urllib.error
import urllib.request
from zoneinfo import TZPATH

from . import iv_lab, shortlist

CONFIG_VERSION = "astra-shortlist-service-config.v1"
PUBLICATION_VERSION = "astra-shortlist-publication.v1"
STATUS_VERSION = "astra-shortlist-publisher-status.v1"
RECEIPT_VERSION = "astra-shortlist-receipt.v1"
MAX_SOURCE_BYTES = 32 * 1024 * 1024
MAX_ARTIFACT_BYTES = 8 * 1024 * 1024
MAX_CONFIG_BYTES = 16 * 1024
MAX_CALENDAR_BYTES = 128 * 1024
MAX_ASSETS = 2000
HEARTBEAT_SECONDS = 5
PUBLISH_URL = "https://leo-shortlist-feed.axio7.workers.dev/publication"
PUBLISH_TOKEN_ENV = "LEO_SHORTLIST_PUBLISH_TOKEN"
ERROR_MESSAGES = {
    "source_unavailable": "The observed source is unavailable. The last valid shortlist is retained.",
    "source_invalid": "The source failed validation. The last valid shortlist is retained.",
    "source_regressed": "The source is older than the published observations. The last valid shortlist is retained.",
    "source_future": "The source contains future observation or retrieval dates. The last valid shortlist is retained.",
    "cache_invalid": "The saved publication failed its integrity check. It has not been replaced.",
    "generator_changed": "The generator changed while running. Restart the publisher to use the updated code.",
    "publication_failed": "The publication could not be saved. The previous complete publication remains available.",
}


class ServiceError(ValueError):
    def __init__(self, code: str):
        self.code = code
        super().__init__(ERROR_MESSAGES[code])


@dataclass(frozen=True)
class Config:
    input: Path
    calendar: Path | None
    state_dir: Path
    public_dir: Path
    interval_seconds: int = 30
    publish_url: str | None = None


def json_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False,
                       allow_nan=False) + "\n").encode("utf8")


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _pairs(entries: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in entries:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def parse_json(raw: bytes) -> dict[str, Any]:
    def reject_constant(_value: str) -> None:
        raise ValueError("nonfinite JSON value")
    value = json.loads(raw.decode("utf8"), object_pairs_hook=_pairs, parse_constant=reject_constant)
    if not isinstance(value, dict):
        raise ValueError("expected a JSON object")
    return value


def read_bytes(path: Path, limit: int) -> bytes:
    # Same bounded regular-file approach as strategy_lab.continuous. Do not
    # import the research engine/dependencies into this small stdlib publisher.
    descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_BINARY", 0) | getattr(os, "O_NONBLOCK", 0))
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or before.st_size > limit:
            raise ValueError("expected a bounded regular file")
        with os.fdopen(descriptor, "rb", closefd=False) as handle:
            payload = handle.read(limit + 1)
        after = os.fstat(descriptor)
    finally:
        os.close(descriptor)
    if len(payload) > limit or (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise ValueError("source changed while reading")
    return payload


def write_bytes(path: Path, payload: bytes, *, immutable: bool = False, public: bool = False) -> None:
    if len(payload) > MAX_ARTIFACT_BYTES:
        raise ValueError("artifact exceeds size bound")
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor, temporary = tempfile.mkstemp(prefix=".pending-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        if public:
            os.chmod(temporary, 0o644)
        if immutable:
            os.link(temporary, path)
        else:
            for attempt in range(25):
                try:
                    os.replace(temporary, path)
                    break
                except PermissionError as error:
                    if os.name != "nt" or getattr(error, "winerror", None) not in (5, 32, 33) or attempt == 24:
                        raise
                    time.sleep(0.02)
        if os.name != "nt":
            directory = os.open(path.parent, os.O_RDONLY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)
    finally:
        Path(temporary).unlink(missing_ok=True)


@contextmanager
def exclusive_lock(directory: Path) -> Iterator[None]:
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (directory / "publisher.lock").open("a+b") as handle:
        handle.seek(0, os.SEEK_END)
        if handle.tell() == 0:
            handle.write(b"\0")
            handle.flush()
        handle.seek(0)
        if os.name == "nt":
            import msvcrt
            lock = lambda: msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            unlock = lambda: msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl
            lock = lambda: fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            unlock = lambda: fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
        try:
            lock()
        except OSError as error:
            raise RuntimeError("another shortlist publisher owns this state directory") from error
        try:
            yield
        finally:
            handle.seek(0)
            unlock()


def _absolute(value: Any) -> Path:
    if not isinstance(value, str) or not Path(value).is_absolute() or value.startswith(("\\\\", "//")):
        raise ValueError("absolute local paths required")
    return Path(value).resolve()


def load_config(path: Path) -> Config:
    if not path.is_absolute():
        raise ValueError("--config requires an absolute path")
    raw = parse_json(read_bytes(path, MAX_CONFIG_BYTES))
    required = {"schemaVersion", "input", "calendar", "state_dir", "public_dir"}
    if required - raw.keys() or raw.keys() - (required | {"interval_seconds", "publish_url"}) or raw["schemaVersion"] != CONFIG_VERSION:
        raise ValueError("invalid shortlist service configuration")
    interval = raw.get("interval_seconds", 30)
    if type(interval) is not int or not 5 <= interval <= 3600:
        raise ValueError("interval_seconds must be an integer between 5 and 3600")
    publish_url = raw.get("publish_url")
    if publish_url is not None and publish_url != PUBLISH_URL:
        raise ValueError("publish_url must be the configured Leo HTTPS publication endpoint")
    config = Config(_absolute(raw["input"]), _absolute(raw["calendar"]) if raw["calendar"] is not None else None,
                    _absolute(raw["state_dir"]), _absolute(raw["public_dir"]), interval, publish_url)
    for directory in (config.state_dir, config.public_dir):
        if directory == Path(directory.anchor) or (directory.exists() and not directory.is_dir()):
            raise ValueError("dedicated output directories required")
    if config.state_dir.is_relative_to(config.public_dir) or config.public_dir.is_relative_to(config.state_dir):
        raise ValueError("public and private state directories must be separate")
    for input_path in (path.resolve(), config.input, config.calendar):
        if input_path is not None and (input_path.is_relative_to(config.public_dir) or input_path.is_relative_to(config.state_dir)):
            raise ValueError("source and configuration must remain outside output directories")
    return config


def code_identity() -> dict[str, Any]:
    modules = {"publisher": Path(__file__), "shortlist": Path(shortlist.__file__), "iv_helpers": Path(iv_lab.__file__)}
    hashes = {name: digest(read_bytes(path, 4 * 1024 * 1024)) for name, path in modules.items()}
    timezone_hash = None
    for root in TZPATH:
        zone = Path(root) / "America/New_York"
        if zone.is_file():
            timezone_hash = digest(read_bytes(zone, MAX_CALENDAR_BYTES))
            break
    try:
        tzdata = importlib.metadata.version("tzdata")
    except importlib.metadata.PackageNotFoundError:
        tzdata = None
    return {"modules": hashes, "python": list(sys.version_info[:3]), "timezoneHash": timezone_hash, "tzdata": tzdata}


def _stamp(value: str) -> datetime:
    return iv_lab._timestamp(value, "timestamp").astimezone(timezone.utc)


def _text(value: Any, limit: int = 1024) -> None:
    if not isinstance(value, str) or not 1 <= len(value) <= limit or any(ord(char) < 32 for char in value):
        raise ValueError("invalid public text")


def validate_source(data: dict[str, Any], now: datetime) -> None:
    assets = data.get("symbols")
    if not isinstance(assets, list) or not 1 <= len(assets) <= MAX_ASSETS:
        raise ValueError("invalid source universe")
    for row in assets:
        if not isinstance(row, dict) or not re.fullmatch(r"[A-Z0-9.\-]{1,16}", str(row.get("symbol", ""))):
            raise ValueError("invalid source symbol")
        # These are the only source text fields that the existing exporter copies.
        # Private extra input objects are ignored by the canonical generator.
        _text(row.get("name"), 256)
        _text(row.get("source"), 256)
        for key in ("observedAt", "retrievedAt"):
            if _stamp(row.get(key)) > now:
                raise ServiceError("source_future")
        if date.fromisoformat(row.get("dailyBarLastDate")) > now.date():
            raise ServiceError("source_future")
        coverage = row.get("coverage")
        allowed = {"state", "observedSessions", "sourceSessions", "validationExcludedPrefixSessions", "startDate",
                   "endDate", "expectedSessions", "invalidDates", "validationNote", "adjustmentPolicy"}
        if not isinstance(coverage, dict) or set(coverage) != allowed:
            raise ValueError("coverage contains fields outside the public summary contract")
        _text(coverage.get("state"), 120)
        _text(coverage.get("adjustmentPolicy"), 200)
        if "validationNote" in coverage:
            _text(coverage["validationNote"], 1000)
        for key in ("observedSessions", "sourceSessions", "validationExcludedPrefixSessions", "expectedSessions"):
            if key in coverage and not (key == "expectedSessions" and coverage[key] is None):
                if type(coverage[key]) is not int or not 0 <= coverage[key] <= 1000000:
                    raise ValueError("invalid coverage count")
        for key in ("startDate", "endDate"):
            if key in coverage:
                date.fromisoformat(coverage[key])
        invalid_dates = coverage.get("invalidDates", [])
        if not isinstance(invalid_dates, list) or len(invalid_dates) > 10000:
            raise ValueError("invalid coverage dates")
        for value in invalid_dates:
            date.fromisoformat(value)
        if not isinstance(row.get("series"), list) or len(row["series"]) > 120:
            raise ValueError("source exceeds retained series bound")


def _validate_result(result: dict[str, Any]) -> None:
    if result.get("schemaVersion") != "astra-shortlist.v1" or result.get("executionEnabled") is not False or result.get("predictionEnabled") is not False:
        raise ValueError("unexpected shortlist contract")
    if not result.get("stocks") and not result.get("funds"):
        raise ValueError("no eligible observations")
    if len(json_bytes(result)) > MAX_ARTIFACT_BYTES // 2:
        raise ValueError("public shortlist exceeds bound")


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise urllib.error.HTTPError(req.full_url, code, "publication redirects are disabled", headers, fp)


def upload(config: Config, envelope: dict[str, Any]) -> bool:
    """Optional bounded one-way publication; failures never change market facts.

    No proxy environment is consulted and no redirected request can forward the
    token to another host. Diagnostics contain no response body, paths, or token.
    """
    if config.publish_url is None:
        return True
    diagnostic = {"schemaVersion": "astra-shortlist-delivery-status.v1",
                  "lastAttemptAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
                  "state": "failed", "errorCode": "upload_failed", "revision": envelope["publisher"]["revision"]}
    try:
        token = os.environ.get(PUBLISH_TOKEN_ENV)
        if not token or not 24 <= len(token) <= 4096 or any(ord(char) < 33 or ord(char) > 126 for char in token):
            diagnostic["errorCode"] = "token_unavailable"
        elif config.publish_url != PUBLISH_URL:
            diagnostic["errorCode"] = "endpoint_not_allowed"
        else:
            payload = json_bytes(envelope)
            if len(payload) > MAX_ARTIFACT_BYTES:
                raise ValueError("publication exceeds bound")
            request = urllib.request.Request(config.publish_url, data=payload, method="POST",
                                             headers={"Authorization": "Bearer " + token, "Content-Type": "application/json",
                                                      "Accept": "application/json", "User-Agent": "LeoShortlistPublisher/1.0"})
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), _NoRedirect())
            with opener.open(request, timeout=10) as response:
                if not 200 <= response.status < 300 or len(response.read(65537)) > 65536:
                    raise ValueError("publication response rejected")
            diagnostic.update(state="delivered", errorCode=None)
    except (OSError, ValueError, urllib.error.HTTPError) as error:
        # The public heartbeat becomes stale if delivery repeatedly fails. Do
        # not rewrite the shortlist or turn a delivery failure into bad prices.
        if isinstance(error, urllib.error.HTTPError):
            error.close()
    write_bytes(config.state_dir / "delivery-status.json", json_bytes(diagnostic))
    return diagnostic["state"] == "delivered"


class Publisher:
    def __init__(self, config: Config):
        self.config = config
        self.identity = code_identity()
        self.current: dict[str, Any] | None = None
        self.status: dict[str, Any] = {
            "schemaVersion": STATUS_VERSION, "state": "waiting", "heartbeatAt": None,
            "lastCheckedAt": None, "publishedAt": None, "inputSha256": None,
            "artifactSha256": None, "revision": None, "lastError": None,
            "intervalSeconds": config.interval_seconds, "llmCalls": 0,
            "executionEnabled": False, "predictionEnabled": False,
        }
        self.startup_error: ServiceError | None = None
        try:
            latest_path = config.state_dir / "latest.json"
            if latest_path.exists():
                latest = parse_json(read_bytes(latest_path, MAX_CONFIG_BYTES))
                if set(latest) != {"revision", "receiptSha256"} or not re.fullmatch("[0-9a-f]{64}", latest["revision"]):
                    raise ValueError("invalid saved reference")
                raw = read_bytes(config.state_dir / "receipts" / (latest["revision"] + ".json"), MAX_ARTIFACT_BYTES)
                if digest(raw) != latest["receiptSha256"]:
                    raise ValueError("saved receipt digest differs")
                self._accept(self._receipt(raw, latest["revision"]))
        except (OSError, ValueError, TypeError, KeyError):
            self.startup_error = ServiceError("cache_invalid")

    def _receipt(self, raw: bytes, revision: str) -> dict[str, Any]:
        value = parse_json(raw)
        if set(value) != {"schemaVersion", "revision", "identity", "shortlist", "artifactSha256", "publishedAt"} or value["schemaVersion"] != RECEIPT_VERSION:
            raise ValueError("invalid receipt contract")
        if value["revision"] != revision or digest(json_bytes(value["identity"])) != revision:
            raise ValueError("receipt identity mismatch")
        result = value["shortlist"]
        _validate_result(result)
        if digest(json_bytes(result)) != value["artifactSha256"] or result["inputSha256"] != value["identity"]["inputSha256"]:
            raise ValueError("receipt artifact mismatch")
        _stamp(value["publishedAt"])
        return value

    def _accept(self, receipt: dict[str, Any]) -> None:
        self.current = receipt["shortlist"]
        for key in ("publishedAt", "artifactSha256", "revision"):
            self.status[key] = receipt[key]
        self.status["inputSha256"] = self.current["inputSha256"]

    def _advance(self, now: datetime) -> None:
        if self.startup_error:
            raise self.startup_error
        if code_identity() != self.identity:
            raise ServiceError("generator_changed")
        try:
            raw = read_bytes(self.config.input, MAX_SOURCE_BYTES)
            calendar = read_bytes(self.config.calendar, MAX_CALENDAR_BYTES) if self.config.calendar else None
        except OSError as error:
            raise ServiceError("source_unavailable") from error
        data = parse_json(raw)
        validate_source(data, now)
        identity = {"inputSha256": digest(raw), "calendarSha256": digest(calendar) if calendar is not None else None,
                    "generator": self.identity}
        revision = digest(json_bytes(identity))
        if self.status["revision"] == revision:
            return
        path = self.config.state_dir / "receipts" / (revision + ".json")
        if path.exists():
            try:
                receipt = self._receipt(read_bytes(path, MAX_ARTIFACT_BYTES), revision)
            except (OSError, ValueError, TypeError, KeyError) as error:
                raise ServiceError("cache_invalid") from error
        else:
            calendar_path = None
            if calendar is not None:
                calendar_path = self.config.state_dir / "calendars" / (digest(calendar) + ".ts")
                if calendar_path.exists():
                    if read_bytes(calendar_path, MAX_CALENDAR_BYTES) != calendar:
                        raise ServiceError("cache_invalid")
                else:
                    write_bytes(calendar_path, calendar, immutable=True)
            result = shortlist.build_shortlist(data, calendar_path, raw)
            _validate_result(result)
            receipt = {"schemaVersion": RECEIPT_VERSION, "revision": revision, "identity": identity,
                       "shortlist": result, "artifactSha256": digest(json_bytes(result)),
                       "publishedAt": now.isoformat().replace("+00:00", "Z")}
        result = receipt["shortlist"]
        if self.current is not None:
            if result["asOf"] < self.current["asOf"] or _stamp(result["sourceRetrievedAt"]) < _stamp(self.current["sourceRetrievedAt"]):
                raise ServiceError("source_regressed")
            previous = {row["symbol"]: row for row in self.current["stocks"] + self.current["funds"]}
            for row in result["stocks"] + result["funds"]:
                old = previous.get(row["symbol"])
                if old and (_stamp(row["sourceRetrievedAt"]) < _stamp(old["sourceRetrievedAt"]) or _stamp(row["priceObservedAt"]) < _stamp(old["priceObservedAt"])):
                    raise ServiceError("source_regressed")
        if not path.exists():
            write_bytes(path, json_bytes(receipt), immutable=True)
        # The private pointer commits only after the complete immutable receipt.
        # A crash before public publication is replayed without rerunning scoring.
        write_bytes(self.config.state_dir / "latest.json", json_bytes({"revision": revision, "receiptSha256": digest(read_bytes(path, MAX_ARTIFACT_BYTES))}))
        self._accept(receipt)

    def publish(self, now: datetime) -> dict[str, Any]:
        if self.startup_error is not None:
            # Do not replace a previously visible shortlist with null after a
            # damaged private journal. Its heartbeat becomes stale instead.
            raise self.startup_error
        self.status["heartbeatAt"] = now.isoformat().replace("+00:00", "Z")
        envelope = {"schemaVersion": PUBLICATION_VERSION, "shortlist": self.current, "publisher": self.status.copy()}
        # Consumers use current.json, a single atomic write of data and status.
        # Convenience files may differ briefly and must not be joined by clients.
        if self.current is not None:
            target = self.config.public_dir / "shortlist.json"
            payload = json_bytes(self.current)
            if not target.exists() or digest(read_bytes(target, MAX_ARTIFACT_BYTES)) != self.status["artifactSha256"]:
                write_bytes(target, payload, public=True)
        write_bytes(self.config.public_dir / "status.json", json_bytes(self.status), public=True)
        write_bytes(self.config.public_dir / "current.json", json_bytes(envelope), public=True)
        return envelope

    def tick(self, now: datetime | None = None) -> dict[str, Any]:
        now = now or datetime.now(timezone.utc)
        self.status["lastCheckedAt"] = now.isoformat().replace("+00:00", "Z")
        if (self.config.state_dir / "SHUTDOWN").exists():
            self.status.update(state="stopped", lastError=None)
        elif (self.config.state_dir / "STOP").exists():
            self.status.update(state="paused", lastError=None)
        else:
            try:
                self._advance(now)
                self.status.update(state="waiting", lastError=None)
            except ServiceError as error:
                self.status.update(state="error", lastError={"code": error.code, "message": str(error)})
            except OSError:
                self.status.update(state="error", lastError={"code": "publication_failed", "message": ERROR_MESSAGES["publication_failed"]})
            except (ValueError, TypeError, KeyError, AttributeError, OverflowError):
                self.status.update(state="error", lastError={"code": "source_invalid", "message": ERROR_MESSAGES["source_invalid"]})
        # A failed atomic write propagates: supervisors see an exited process or
        # stale heartbeat, and the prior complete envelope is never zeroed out.
        return self.publish(now)


def run(config: Config, *, once: bool = False) -> None:
    shutdown = threading.Event()
    previous_handlers = {}
    if threading.current_thread() is threading.main_thread():
        for kind in (signal.SIGINT, signal.SIGTERM):
            previous_handlers[kind] = signal.signal(kind, lambda *_args: shutdown.set())
    try:
        with exclusive_lock(config.state_dir):
            publisher = Publisher(config)
            next_scan = 0.0
            next_heartbeat = 0.0
            previous_markers = None
            while not shutdown.is_set():
                clock = time.monotonic()
                markers = ((config.state_dir / "STOP").exists(), (config.state_dir / "SHUTDOWN").exists())
                if clock >= next_scan or markers != previous_markers:
                    envelope = publisher.tick()
                    if once and publisher.status["state"] == "waiting":
                        publisher.status.update(state="stopped", lastError=None)
                        envelope = publisher.publish(datetime.now(timezone.utc))
                    upload(config, envelope)
                    next_scan = clock + config.interval_seconds
                    next_heartbeat = clock + HEARTBEAT_SECONDS
                    previous_markers = markers
                elif clock >= next_heartbeat:
                    publisher.publish(datetime.now(timezone.utc))
                    next_heartbeat = clock + HEARTBEAT_SECONDS
                if once or publisher.status["state"] == "stopped" or (publisher.status["lastError"] or {}).get("code") == "generator_changed":
                    return
                shutdown.wait(0.5)
            publisher.status.update(state="stopped", lastError=None)
            upload(config, publisher.publish(datetime.now(timezone.utc)))
    finally:
        for kind, handler in previous_handlers.items():
            signal.signal(kind, handler)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("run", "status", "pause", "resume", "stop"))
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    config = load_config(args.config)
    if args.once and args.command != "run":
        parser.error("--once is supported only by run")
    if args.command == "run":
        run(config, once=args.once)
    elif args.command == "status":
        print(read_bytes(config.public_dir / "current.json", MAX_ARTIFACT_BYTES).decode("utf8"))
    elif args.command == "resume":
        if (config.state_dir / "SHUTDOWN").exists():
            raise RuntimeError("restart the stopped publisher before resuming")
        (config.state_dir / "STOP").unlink(missing_ok=True)
        print("Resume requested; wait for the publisher heartbeat to acknowledge.")
    else:
        write_bytes(config.state_dir / ("STOP" if args.command == "pause" else "SHUTDOWN"), b"requested\n")
        print("Pause requested." if args.command == "pause" else "Shutdown requested.")


if __name__ == "__main__":
    main()

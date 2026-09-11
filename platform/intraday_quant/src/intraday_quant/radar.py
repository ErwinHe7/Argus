"""Offline primary-source calendar export and tamper-evident research journal.

This module makes no network or model calls and computes no market economics.
The hosted calendar collector owns polling. Re-exporting observations never
renews their verification time. Journal timestamps are assigned on append,
not accepted from a caller; a local journal is not a trusted public timestamp.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from copy import deepcopy
from datetime import date, datetime, time, timedelta, timezone
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import sqlite3
import sys
import time as clock
from typing import Any
from urllib.parse import urlsplit
from zoneinfo import ZoneInfo

VERSION = "astra-event-radar.v1"
MAX_BYTES = 1024 * 1024
PRIMARY_HOSTS = frozenset({
    "www.federalreserve.gov", "www.bls.gov", "www.bea.gov", "www.sec.gov",
    "www.adobe.com", "news.adobe.com", "investors.micron.com", "investor.oracle.com",
})
EVENT_KEYS = frozenset({"id", "kind", "title", "symbols", "startDate", "endDate",
    "scheduledAt", "timing", "sourceId", "sourceUrl", "availableAt", "referencePeriod",
    "summary", "watchFor", "limitation", "scenarios"})
SOURCE_KEYS = frozenset({"id", "title", "url", "mode", "state", "lastAttemptAt",
    "retrievedAt", "reviewAfter", "contentSha256", "error"})
RECORD_KEYS = frozenset({"id", "sequence", "kind", "eventId", "registeredAt", "statement",
    "sourceUrl", "sourceAvailableAt", "hypothesisId", "previousSha256", "contentSha256"})


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def iso(value: datetime) -> str:
    if value.tzinfo is None:
        raise ValueError("timezone-aware timestamp required")
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def stamp(value: Any) -> datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise ValueError("UTC ISO timestamp required")
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("timezone-aware timestamp required")
    return parsed


def text(value: Any, maximum: int = 1200) -> str:
    if not isinstance(value, str) or not value.strip() or len(value) > maximum:
        raise ValueError("nonempty bounded text required")
    if any(ord(char) < 32 and char not in "\n\t" for char in value):
        raise ValueError("text contains control characters")
    return value


def identifier(value: Any) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[a-z0-9][a-z0-9._-]{0,99}", value):
        raise ValueError("invalid identifier")
    return value


def day(value: Any) -> date:
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        raise ValueError("YYYY-MM-DD date required")
    return date.fromisoformat(value)


def primary_url(value: Any) -> str:
    url = text(value, 1000)
    parsed = urlsplit(url)
    if parsed.scheme != "https" or parsed.hostname not in PRIMARY_HOSTS or parsed.username or parsed.password or parsed.port not in (None, 443):
        raise ValueError("URL must use an explicitly supported primary-source HTTPS host")
    return url


def bytes_json(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf8")


def digest(value: Any) -> str:
    return sha256(bytes_json(value)).hexdigest()


def strict_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def decode(raw: bytes) -> Any:
    if len(raw) > MAX_BYTES:
        raise ValueError("artifact exceeds one MiB")
    return json.loads(raw.decode("utf8"), object_pairs_hook=strict_pairs,
                      parse_constant=lambda _: (_ for _ in ()).throw(ValueError("nonfinite JSON")))


def read_json(path: Path) -> Any:
    with path.open("rb") as handle:
        return decode(handle.read(MAX_BYTES + 1))


def exact_keys(value: Any, expected: frozenset) -> None:
    if not isinstance(value, dict) or set(value) != expected:
        raise ValueError("unexpected or missing fields")


def validate_source(value: Any, now: datetime) -> dict:
    exact_keys(value, SOURCE_KEYS)
    identifier(value["id"])
    text(value["title"], 200)
    primary_url(value["url"])
    if value["mode"] not in ("automatic", "manual_verified") or value["state"] not in ("success", "error"):
        raise ValueError("invalid source status")
    attempted = stamp(value["lastAttemptAt"])
    if attempted > now:
        raise ValueError("source attempt is in the future")
    if value["retrievedAt"] is None:
        if value["state"] != "error" or value["reviewAfter"] is not None or value["contentSha256"] is not None:
            raise ValueError("unobserved source cannot carry successful metadata")
    else:
        retrieved = stamp(value["retrievedAt"])
        if retrieved > attempted:
            raise ValueError("source retrieval is after its check")
        deadline = stamp(value["reviewAfter"])
        if not retrieved < deadline <= retrieved + timedelta(days=7):
            raise ValueError("source review deadline must be within seven days of verification")
        if not isinstance(value["contentSha256"], str) or not re.fullmatch(r"[0-9a-f]{64}", value["contentSha256"]):
            raise ValueError("source content hash missing")
    if value["state"] == "success" and value["error"] is not None:
        raise ValueError("successful source cannot contain an error")
    if value["state"] == "error":
        text(value["error"], 300)
    return deepcopy(value)


def validate_event(value: Any, sources: dict[str, dict], now: datetime) -> dict:
    exact_keys(value, EVENT_KEYS)
    identifier(value["id"])
    if value["kind"] not in ("macro", "earnings"):
        raise ValueError("unsupported event kind")
    text(value["title"], 200)
    symbols = value["symbols"]
    if not isinstance(symbols, list) or len(symbols) > 20 or any(not isinstance(symbol, str) for symbol in symbols):
        raise ValueError("invalid symbol list")
    if len(set(symbols)) != len(symbols) or any(not re.fullmatch(r"[A-Z][A-Z0-9.-]{0,9}", symbol) for symbol in symbols):
        raise ValueError("invalid symbol")
    first, last = day(value["startDate"]), day(value["endDate"])
    if first > last or (last - first).days > 14:
        raise ValueError("invalid event date range")
    if value["timing"] == "exact":
        at = stamp(value["scheduledAt"])
        if not first <= at.astimezone(ZoneInfo("America/New_York")).date() <= last:
            raise ValueError("event instant lies outside Eastern event dates")
    elif value["timing"] != "date_only" or value["scheduledAt"] is not None:
        raise ValueError("exact time must be present only for exact timing")
    source = sources.get(identifier(value["sourceId"]))
    if not source or source["retrievedAt"] is None:
        raise ValueError("event lacks an observed source")
    if primary_url(value["sourceUrl"]) != source["url"]:
        raise ValueError("event/source URL mismatch")
    if stamp(value["availableAt"]) > stamp(source["retrievedAt"]) or stamp(value["availableAt"]) > now:
        raise ValueError("event availability exceeds source verification")
    if value["referencePeriod"] is not None:
        text(value["referencePeriod"], 120)
    for key in ("summary", "watchFor", "limitation"):
        text(value[key])
    if not isinstance(value["scenarios"], list) or len(value["scenarios"]) > 4:
        raise ValueError("invalid qualitative scenario list")
    for scenario in value["scenarios"]:
        exact_keys(scenario, frozenset({"condition", "implication"}))
        text(scenario["condition"], 400)
        text(scenario["implication"], 500)
    return deepcopy(value)


def validate_seeds(value: Any, now: datetime) -> tuple[list[dict], list[dict], list[str]]:
    exact_keys(value, frozenset({"schemaVersion", "sources", "events", "limitations"}))
    if value["schemaVersion"] != "astra-event-radar-seeds.v1":
        raise ValueError("unsupported seed schema")
    if not isinstance(value["sources"], list) or len(value["sources"]) > 50:
        raise ValueError("too many sources")
    sources = [validate_source(item, now) for item in value["sources"]]
    by_source = {item["id"]: item for item in sources}
    if len(by_source) != len(sources):
        raise ValueError("duplicate source identifier")
    if not isinstance(value["events"], list) or len(value["events"]) > 500:
        raise ValueError("too many events")
    events = [validate_event(item, by_source, now) for item in value["events"]]
    if len({item["id"] for item in events}) != len(events):
        raise ValueError("duplicate event identifier")
    if not isinstance(value["limitations"], list) or len(value["limitations"]) > 30:
        raise ValueError("invalid limitations")
    limitations = [text(item) for item in value["limitations"]]
    return sources, events, limitations


def event_boundary(event: dict) -> datetime:
    if event["scheduledAt"] is not None:
        return stamp(event["scheduledAt"])
    return datetime.combine(date.fromisoformat(event["startDate"]), time.min,
                            ZoneInfo("America/New_York")).astimezone(timezone.utc)


def record_hash(record: dict) -> str:
    return digest({key: value for key, value in record.items() if key != "contentSha256"})


def validate_records(records: list[dict], events: dict[str, dict], now: datetime) -> list[dict]:
    if len(records) > 2000:
        raise ValueError("journal export exceeds 2000 records")
    previous = None
    registered = datetime.min.replace(tzinfo=timezone.utc)
    seen = {}
    settled = set()
    for sequence, item in enumerate(records, 1):
        exact_keys(item, RECORD_KEYS)
        if item["sequence"] != sequence or isinstance(item["sequence"], bool) or item["previousSha256"] != previous:
            raise ValueError("journal sequence/hash chain is broken")
        identifier(item["id"])
        if item["id"] in seen or record_hash(item) != item["contentSha256"]:
            raise ValueError("journal identity or digest mismatch")
        observed = stamp(item["registeredAt"])
        if observed < registered or observed > now:
            raise ValueError("journal clock regressed or is in the future")
        event = events.get(identifier(item["eventId"]))
        if event is None:
            raise ValueError("journal references an event outside the retained manifest")
        if stamp(event["availableAt"]) > observed:
            raise ValueError("journal predates the event source availability")
        text(item["statement"], 1500)
        boundary = event_boundary(event)
        if item["kind"] == "hypothesis":
            if observed >= boundary:
                raise ValueError("hypothesis must precede the event")
            if item["sourceUrl"] is not None or item["sourceAvailableAt"] is not None or item["hypothesisId"] is not None:
                raise ValueError("hypothesis must not contain outcome fields")
        elif item["kind"] == "outcome":
            parent = seen.get(identifier(item["hypothesisId"]))
            if not parent or parent["kind"] != "hypothesis" or parent["eventId"] != item["eventId"]:
                raise ValueError("outcome must reference a prior hypothesis for this event")
            if item["hypothesisId"] in settled:
                raise ValueError("hypothesis already has an outcome; corrections require a new versioned study")
            available = stamp(item["sourceAvailableAt"])
            if not boundary <= available <= observed:
                raise ValueError("outcome source must become available after the event and before registration")
            primary_url(item["sourceUrl"])
            settled.add(item["hypothesisId"])
        else:
            raise ValueError("unsupported journal kind")
        previous, registered = item["contentSha256"], observed
        seen[item["id"]] = item
    return deepcopy(records)


@contextmanager
def journal_connection(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(path, timeout=10, isolation_level=None)
    try:
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("PRAGMA synchronous=FULL")
        db.execute("CREATE TABLE IF NOT EXISTS records (sequence INTEGER PRIMARY KEY, id TEXT UNIQUE NOT NULL, body TEXT NOT NULL)")
        db.execute("CREATE TABLE IF NOT EXISTS event_snapshots (id TEXT PRIMARY KEY, body TEXT NOT NULL)")
        db.execute("CREATE TRIGGER IF NOT EXISTS no_record_update BEFORE UPDATE ON records BEGIN SELECT RAISE(ABORT, 'journal records cannot be updated'); END")
        db.execute("CREATE TRIGGER IF NOT EXISTS no_record_delete BEFORE DELETE ON records BEGIN SELECT RAISE(ABORT, 'journal records cannot be deleted'); END")
        db.execute("CREATE TRIGGER IF NOT EXISTS no_snapshot_update BEFORE UPDATE ON event_snapshots BEGIN SELECT RAISE(ABORT, 'event snapshots cannot be updated'); END")
        db.execute("CREATE TRIGGER IF NOT EXISTS no_snapshot_delete BEFORE DELETE ON event_snapshots BEGIN SELECT RAISE(ABORT, 'event snapshots cannot be deleted'); END")
        yield db
    finally:
        # sqlite3's connection context manager does not close the connection.
        # Close explicitly on success and failure to release Windows file locks.
        db.close()


def load_records(db) -> list[dict]:
    rows = db.execute("SELECT body FROM records ORDER BY sequence LIMIT 2001").fetchall()
    return [decode(row[0].encode("utf8")) for row in rows]


def validate_snapshots(db, events: dict[str, dict]) -> None:
    for event_id, body in db.execute("SELECT id,body FROM event_snapshots"):
        if event_id not in events or bytes_json(events[event_id]) != body.encode("utf8"):
            raise ValueError("a journaled event changed; preserve its revision and use a new event identifier")


def append_record(path: Path, seeds: dict, kind: str, event_id: str, statement: str,
                  *, hypothesis_id: str | None = None, source_url: str | None = None,
                  source_available_at: str | None = None) -> dict:
    """Timestamp at append under a write transaction; no caller-supplied clock."""
    with journal_connection(path) as db:
        db.execute("BEGIN IMMEDIATE")
        now = utcnow()
        sources, event_rows, _ = validate_seeds(seeds, now)
        events = {item["id"]: item for item in event_rows}
        validate_snapshots(db, events)
        records = validate_records(load_records(db), events, now)
        event = events.get(identifier(event_id))
        if event is None:
            raise ValueError("event is not in the retained manifest")
        if kind == "hypothesis":
            source = next(item for item in sources if item["id"] == event["sourceId"])
            if source["state"] != "success" or stamp(source["reviewAfter"]) <= now:
                raise ValueError("new hypotheses require current, successful source verification")
        sequence = len(records) + 1
        item = {"id": f"event-record-{sequence:08d}", "sequence": sequence,
                "kind": kind, "eventId": event_id, "registeredAt": iso(now),
                "statement": statement, "sourceUrl": source_url,
                "sourceAvailableAt": source_available_at, "hypothesisId": hypothesis_id,
                "previousSha256": records[-1]["contentSha256"] if records else None}
        item["contentSha256"] = record_hash(item)
        validate_records([*records, item], events, now)
        db.execute("INSERT OR IGNORE INTO event_snapshots(id,body) VALUES (?,?)",
                   (event_id, bytes_json(event).decode("utf8")))
        db.execute("INSERT INTO records(sequence,id,body) VALUES (?,?,?)",
                   (sequence, item["id"], bytes_json(item).decode("utf8")))
        db.execute("COMMIT")
        return item


def compile_artifact(seeds: dict, *, now: datetime | None = None, records: list[dict] | None = None) -> dict:
    now = now or utcnow()
    sources, events, limitations = validate_seeds(seeds, now)
    records = validate_records(records or [], {item["id"]: item for item in events}, now)
    # The source deadline is retained even if expired; export is not a refresh.
    deadlines = [stamp(item["reviewAfter"]) for item in sources if item["reviewAfter"]]
    by_date = sorted(events, key=lambda item: (item["startDate"], item["scheduledAt"] or "", item["id"]))
    local_today = now.astimezone(ZoneInfo("America/New_York")).date().isoformat()
    artifact = {"schemaVersion": VERSION, "generatedAt": iso(now),
        "reviewAfter": iso(min(deadlines)) if deadlines else iso(now),
        "sources": sources, "events": by_date, "records": records,
        "coverage": {"from": min((item["startDate"] for item in events), default=local_today),
            "through": max((item["endDate"] for item in events), default=local_today),
            "eventCount": len(events), "sourceCount": len(sources),
            "failedSourceCount": sum(item["state"] == "error" for item in sources),
            "scope": "Selected official U.S. macro releases and issuer earnings calls; not a complete market calendar."},
        "limitations": limitations, "llmCalls": 0, "executionEnabled": False, "predictionEnabled": False}
    if len(bytes_json(artifact)) > MAX_BYTES:
        raise ValueError("artifact exceeds one MiB")
    return artifact


def atomic_write(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        with temporary.open("xb") as handle:
            handle.write(bytes_json(value) + b"\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--state-dir", type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--once", action="store_true")
    mode.add_argument("--watch", action="store_true", help="Re-export changed local evidence only; does not fetch data")
    parser.add_argument("--interval-seconds", type=int, default=1200)
    parser.add_argument("--append", choices=("hypothesis", "outcome"))
    parser.add_argument("--event")
    parser.add_argument("--statement-file", type=Path)
    parser.add_argument("--hypothesis-id")
    parser.add_argument("--source-url")
    parser.add_argument("--source-available-at")
    args = parser.parse_args(argv)
    if not 300 <= args.interval_seconds <= 86400:
        parser.error("interval must be between 300 and 86400 seconds")
    if args.append:
        if not args.state_dir or not args.event or not args.statement_file or args.watch:
            parser.error("append requires state-dir, event, statement-file and cannot watch")
        statement = args.statement_file.read_text(encoding="utf8")
        item = append_record(args.state_dir / "event-journal.sqlite3", read_json(args.seeds),
            args.append, args.event, statement, hypothesis_id=args.hypothesis_id,
            source_url=args.source_url, source_available_at=args.source_available_at)
        print(json.dumps({"recordId": item["id"], "contentSha256": item["contentSha256"], "llmCalls": 0}))
        return 0
    if not args.output:
        parser.error("export requires output")
    previous = None
    while True:
        if args.watch and args.state_dir and (args.state_dir / "SHUTDOWN").exists():
            return 0
        try:
            seeds = read_json(args.seeds)
            records = []
            if args.state_dir and (args.state_dir / "event-journal.sqlite3").exists():
                with journal_connection(args.state_dir / "event-journal.sqlite3") as db:
                    _, event_rows, _ = validate_seeds(seeds, utcnow())
                    validate_snapshots(db, {item["id"]: item for item in event_rows})
                    records = load_records(db)
            identity = digest({"seeds": seeds, "records": records})
            if identity != previous or not args.output.exists():
                result = compile_artifact(seeds, records=records)
                atomic_write(args.output, result)
                previous = identity
                print(json.dumps({"state": "exported", "events": len(result["events"]), "records": len(records), "llmCalls": 0}), flush=True)
        except (OSError, ValueError, sqlite3.Error) as error:
            print(json.dumps({"state": "error", "reason": type(error).__name__, "previousOutputPreserved": args.output.exists(), "llmCalls": 0}), file=sys.stderr, flush=True)
            if not args.watch:
                return 1
        if not args.watch:
            return 0
        for _ in range(args.interval_seconds):
            if args.state_dir and (args.state_dir / "SHUTDOWN").exists():
                return 0
            clock.sleep(1)


if __name__ == "__main__":
    raise SystemExit(main())

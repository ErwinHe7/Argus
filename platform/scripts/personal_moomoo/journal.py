"""Durable, at-most-once submission claims. An uncertain claim is never retried."""
from __future__ import annotations

import json
import sqlite3
import threading
from pathlib import Path

from .errors import PersonalError


class Journal:
    def __init__(self, path: Path):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
        self.db.row_factory = sqlite3.Row
        self.lock = threading.RLock()
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("PRAGMA synchronous=FULL")
        self.db.executescript("""
            CREATE TABLE IF NOT EXISTS previews (
                id TEXT PRIMARY KEY, session TEXT NOT NULL, account_id TEXT NOT NULL,
                mode TEXT NOT NULL, expires_at TEXT NOT NULL, payload TEXT NOT NULL,
                revoked INTEGER NOT NULL DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS commands (
                id TEXT PRIMARY KEY, preview_id TEXT NOT NULL UNIQUE,
                session TEXT NOT NULL, account_id TEXT NOT NULL, mode TEXT NOT NULL,
                status TEXT NOT NULL, broker_order_id TEXT, message TEXT NOT NULL
            );
        """)

    def put_preview(self, preview: dict, session: str) -> None:
        with self.lock:
            self.db.execute(
                "INSERT INTO previews (id,session,account_id,mode,expires_at,payload) VALUES(?,?,?,?,?,?)",
                (preview["id"], session, preview["account_id"], preview["mode"], preview["expires_at"], json.dumps(preview)),
            )

    def preview(self, identity: str, session: str, include_revoked: bool = False) -> dict:
        with self.lock:
            row = self.db.execute("SELECT * FROM previews WHERE id=? AND session=?", (identity, session)).fetchone()
        if row is None:
            raise PersonalError("preview_not_found", "This preview does not belong to the current browser session.", 403)
        if row["revoked"] and not include_revoked:
            raise PersonalError("preview_revoked", "The connection changed. Create a new order preview.", 409)
        return json.loads(row["payload"])

    def command_for_preview(self, identity: str, session: str) -> dict | None:
        with self.lock:
            row = self.db.execute("SELECT * FROM commands WHERE preview_id=? AND session=?", (identity, session)).fetchone()
        return dict(row) if row else None

    def command(self, identity: str, session: str) -> dict:
        with self.lock:
            row = self.db.execute("SELECT * FROM commands WHERE id=? AND session=?", (identity, session)).fetchone()
        if row is None:
            raise PersonalError("command_not_found", "This order command does not belong to the current browser session.", 403)
        return dict(row)

    def has_unknown(self, account: dict) -> bool:
        with self.lock:
            return self.db.execute(
                "SELECT 1 FROM commands WHERE account_id=? AND mode=? AND status='unknown' LIMIT 1",
                (account["id"], account["mode"]),
            ).fetchone() is not None

    def claim(self, preview: dict, session: str, client_id: str, now: str) -> tuple[dict, bool]:
        with self.lock:
            self.db.execute("BEGIN IMMEDIATE")
            try:
                existing = self.command_for_preview(preview["id"], session)
                if existing:
                    self.db.execute("COMMIT")
                    return existing, False
                current = self.preview(preview["id"], session)
                if current != preview or current["expires_at"] <= now:
                    raise PersonalError("preview_expired", "This preview expired. Review a fresh preview before submitting.", 409)
                if self.has_unknown({"id": preview["account_id"], "mode": preview["mode"]}):
                    raise PersonalError("reconciliation_required", "An earlier submission has an unknown outcome. Reconcile it before another order.", 409)
                self.db.execute(
                    "INSERT INTO commands VALUES(?,?,?,?,?,'unknown',NULL,?)",
                    (client_id, preview["id"], session, preview["account_id"], preview["mode"],
                     "Submission outcome is unknown. Check order status; do not submit this order again."),
                )
                result = self.command(client_id, session)
                self.db.execute("COMMIT")
                return result, True
            except BaseException:
                self.db.execute("ROLLBACK")
                raise

    def resolve(self, identity: str, session: str, status: str, broker_order_id: str, message: str) -> dict:
        with self.lock:
            self.db.execute(
                "UPDATE commands SET status=?,broker_order_id=?,message=? WHERE id=? AND session=?",
                (status, broker_order_id, message, identity, session),
            )
            return self.command(identity, session)

    def revoke(self, session: str) -> None:
        with self.lock:
            self.db.execute("UPDATE previews SET revoked=1 WHERE session=?", (session,))

    def discard(self, identity: str, session: str) -> dict | None:
        """Revoke an unclaimed preview or return its irrevocable submission claim."""
        with self.lock:
            self.db.execute("BEGIN IMMEDIATE")
            try:
                self.preview(identity, session, include_revoked=True)
                command = self.command_for_preview(identity, session)
                if command is None:
                    self.db.execute("UPDATE previews SET revoked=1 WHERE id=? AND session=?", (identity, session))
                self.db.execute("COMMIT")
                return command
            except BaseException:
                self.db.execute("ROLLBACK")
                raise

    def close(self) -> None:
        self.db.close()

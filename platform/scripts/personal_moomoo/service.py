"""Manual order intent, preview, confirmation, and read-only reconciliation."""
from __future__ import annotations

import re
import threading
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Callable

from .errors import PersonalError, unavailable
from .journal import Journal

SESSION = re.compile(r"^[A-Za-z0-9_-]{32,128}$")
SYMBOL = re.compile(r"^[A-Z][A-Z0-9]{0,5}(?:[.-][A-Z])?$")
IDENTIFIER = re.compile(r"^[a-z0-9-]{20,64}$")


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def timestamp(now: datetime) -> str:
    return now.astimezone(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def exact_keys(payload: dict, expected: set[str]) -> None:
    if not isinstance(payload, dict) or set(payload) != expected:
        raise PersonalError("invalid_request", "The request has missing or unsupported fields.")


def validate_intent(payload: dict, cap: Decimal) -> tuple[dict, str]:
    exact_keys(payload, {"symbol", "side", "quantity", "limit_price"})
    symbol, side, quantity, price = (payload[key] for key in ("symbol", "side", "quantity", "limit_price"))
    if not isinstance(symbol, str) or not SYMBOL.fullmatch(symbol):
        raise PersonalError("invalid_symbol", "Enter a U.S. stock or ETF symbol, such as AAPL.")
    if side not in ("BUY", "SELL"):
        raise PersonalError("invalid_side", "Choose Buy or Sell.")
    if not isinstance(quantity, str) or not re.fullmatch(r"[1-9][0-9]{0,5}", quantity):
        raise PersonalError("invalid_quantity", "Quantity must be a positive whole number of shares, up to 999999.")
    if not isinstance(price, str) or not re.fullmatch(r"(?:0|[1-9][0-9]{0,6})(?:\.[0-9]{1,2})?", price) or Decimal(price) <= 0:
        raise PersonalError("invalid_price", "Limit price must be a positive dollar amount with at most two decimal places.")
    notional = Decimal(quantity) * Decimal(price)
    if notional > cap:
        raise PersonalError("order_cap", f"This order exceeds the local ${cap:.2f} order limit.")
    return {"symbol": symbol, "side": side, "quantity": quantity,
            "limit_price": format(Decimal(price), ".2f"), "order_type": "LIMIT",
            "time_in_force": "DAY", "session": "RTH"}, format(notional, ".2f")


def public_command(command: dict) -> dict:
    return {key: command[key] for key in ("id", "preview_id", "status", "broker_order_id", "message")}


class PersonalService:
    def __init__(self, adapter, journal: Journal, cap: Decimal = Decimal("500"), allow_live: bool = False,
                 clock: Callable[[], datetime] = utc_now):
        if not cap.is_finite() or cap <= 0 or cap > Decimal("1000000") or cap.as_tuple().exponent < -2:
            raise ValueError("max order notional must be a positive cent amount up to 1000000")
        self.adapter, self.journal, self.cap, self.allow_live, self.clock = adapter, journal, cap, allow_live, clock
        self.session: str | None = None
        self.account: dict | None = None
        self.unlocked = False
        self.lock = threading.RLock()

    def _session(self, session: str) -> None:
        if not isinstance(session, str) or not SESSION.fullmatch(session):
            raise PersonalError("session_required", "Open this connection from the local Leo browser session.", 401)
        if self.session is not None and self.session != session:
            raise PersonalError("session_in_use", "Another browser session owns this local broker connection. Disconnect it first.", 409)

    def _account(self, session: str, orders: bool = False) -> dict:
        self._session(session)
        if self.account is None:
            raise PersonalError("not_connected", "Choose and connect your moomoo account first.", 409)
        matches = [row for row in self.adapter.accounts() if row["id"] == self.account["id"] and row["mode"] == self.account["mode"]]
        if len(matches) != 1 or matches[0]["status"] != "ACTIVE" or "US" not in matches[0]["markets"]:
            raise PersonalError("account_unavailable", "The selected account is no longer active with U.S. trading access.", 409)
        if orders and self.account["mode"] == "REAL" and not self.allow_live:
            raise PersonalError("live_disabled", "Real account trading is disabled in this local gateway. Restart it explicitly with live trading enabled.", 403)
        return {**self.account, "markets": list(matches[0]["markets"])}

    def status(self, session: str) -> dict:
        with self.lock:
            self._session(session)
            installed, reachable = self.adapter.availability()
            connected = False
            message = "Choose a moomoo account to connect."
            if not installed:
                message = "The official moomoo SDK is not installed in the local gateway."
            elif not reachable:
                message = "Start moomoo OpenD and sign in on this computer."
            elif self.account:
                try:
                    self._account(session)
                    connected = True
                    message = "Connected to your selected moomoo account."
                except Exception:
                    message = "The selected account could not be verified. Check OpenD, then refresh."
            return {"provider": "moomoo", "sdk_available": installed, "opend_reachable": reachable,
                    "sdk_version": self.adapter.version() if hasattr(self.adapter, "version") else None,
                    "connected": connected, "live_enabled": self.allow_live,
                    "account": dict(self.account) if self.account else None, "unlocked": self.unlocked if connected else False,
                    "message": message}

    def accounts(self, session: str) -> dict:
        with self.lock:
            self._session(session)
            return {"accounts": self.adapter.accounts()}

    def connect(self, session: str, payload: dict) -> dict:
        exact_keys(payload, {"account_id", "mode"})
        if not isinstance(payload["account_id"], str) or not re.fullmatch(r"[1-9][0-9]{0,19}", payload["account_id"]) or payload["mode"] not in ("REAL", "SIMULATE"):
            raise PersonalError("invalid_account", "Select an account returned by moomoo.")
        with self.lock:
            self._session(session)
            matches = [row for row in self.adapter.accounts() if row["id"] == payload["account_id"] and row["mode"] == payload["mode"]]
            if len(matches) != 1 or matches[0]["status"] != "ACTIVE" or "US" not in matches[0]["markets"]:
                raise PersonalError("account_unavailable", "Select an active moomoo account with U.S. trading access.", 409)
            self.journal.revoke(session)
            self.session = session
            self.account = {"id": payload["account_id"], "mode": payload["mode"]}
            self.unlocked = False
            return {"connected": True, "account": dict(self.account), "live_enabled": self.allow_live}

    def disconnect(self, session: str, payload: dict) -> dict:
        exact_keys(payload, set())
        with self.lock:
            self._session(session)
            self.journal.revoke(session)
            self.account = None
            self.session = None
            self.unlocked = False
            return {"connected": False}

    def snapshot(self, session: str) -> dict:
        with self.lock:
            account = self._account(session)
            snapshot = self.adapter.snapshot(account)
            if snapshot.get("account", {}).get("id") != account["id"] or snapshot.get("account", {}).get("mode") != account["mode"]:
                raise unavailable()
            return {"as_of": timestamp(self.clock()), **snapshot}

    def unlock(self, session: str, payload: dict) -> dict:
        exact_keys(payload, {"password"})
        password = payload["password"]
        if not isinstance(password, str) or not 1 <= len(password) <= 128:
            raise PersonalError("invalid_password", "Enter your moomoo trade password.")
        with self.lock:
            account = self._account(session, orders=True)
            if account["mode"] != "REAL":
                raise PersonalError("unlock_not_required", "Paper accounts do not require a trade password.")
            try:
                self.adapter.unlock(password)
                self.unlocked = True
            finally:
                payload.clear()
                password = ""
            return {"unlocked": True}

    def _precheck(self, account: dict, intent: dict) -> None:
        snapshot = self.adapter.snapshot(account)
        if snapshot.get("account", {}).get("id") != account["id"] or snapshot.get("account", {}).get("mode") != account["mode"] or snapshot["account"].get("currency") != "USD":
            raise unavailable()
        if intent["side"] == "SELL":
            positions = [row for row in snapshot["positions"] if row["symbol"] == intent["symbol"]]
            if not positions or any(row["available_quantity"] is None for row in positions):
                raise PersonalError("shares_unavailable", "No verified available shares were returned for this sale.", 409)
            available = sum(Decimal(row["available_quantity"]) for row in positions)
            if not available.is_finite() or available < Decimal(intent["quantity"]):
                raise PersonalError("shares_unavailable", "The order exceeds the account's available shares. Short selling is disabled.", 409)
        else:
            power = snapshot["account"].get("buying_power")
            if power is None or not Decimal(power).is_finite():
                raise PersonalError("funds_unavailable", "Buying power could not be verified. Refresh your account before another preview.", 409)
            if Decimal(power) < Decimal(intent["quantity"]) * Decimal(intent["limit_price"]):
                raise PersonalError("insufficient_buying_power", "The limit order value exceeds reported buying power. Broker fees are additional.", 409)

    def preview(self, session: str, payload: dict) -> dict:
        intent, notional = validate_intent(payload, self.cap)
        with self.lock:
            account = self._account(session, orders=True)
            if self.journal.has_unknown(account):
                raise PersonalError("reconciliation_required", "An earlier submission has an unknown outcome. Check its order status before another order.", 409)
            self._precheck(account, intent)
            preview = {"id": uuid.uuid4().hex, "expires_at": timestamp(self.clock() + timedelta(seconds=60)),
                       "account_id": account["id"], "mode": account["mode"], "intent": intent,
                       "max_notional": format(self.cap, ".2f"), "estimated_notional": notional,
                       "warnings": ["Limit order value excludes broker fees; final cost and acceptance are determined by moomoo.",
                                    "DAY limit order, regular U.S. trading hours only. A submitted order may remain unfilled."]}
            self.journal.put_preview(preview, session)
            return preview

    def _resolve(self, command: dict, order: dict) -> dict:
        intent = self.journal.preview(command["preview_id"], command["session"], include_revoked=True)["intent"]
        if (not order.get("id") or order.get("symbol") != intent["symbol"] or order.get("side") != intent["side"]
                or Decimal(order["quantity"]) != Decimal(intent["quantity"])
                or order.get("limit_price") is None or Decimal(order["limit_price"]) != Decimal(intent["limit_price"])):
            return public_command(command)
        rejected = order.get("status") in {"SUBMIT_FAILED", "FAILED"}
        return public_command(self.journal.resolve(command["id"], command["session"], "rejected" if rejected else "submitted",
                                                   order["id"], "moomoo rejected this order." if rejected else "moomoo returned an order ID. Check the order list for fills and current status."))

    def confirm(self, session: str, payload: dict) -> dict:
        exact_keys(payload, {"preview_id", "confirmed"})
        if payload["confirmed"] is not True or not isinstance(payload["preview_id"], str) or not IDENTIFIER.fullmatch(payload["preview_id"]):
            raise PersonalError("confirmation_required", "Review the preview and explicitly confirm this exact order.")
        with self.lock:
            self._session(session)
            existing = self.journal.command_for_preview(payload["preview_id"], session)
            if existing:
                return public_command(existing)
            preview = self.journal.preview(payload["preview_id"], session)
            if preview["expires_at"] <= timestamp(self.clock()):
                raise PersonalError("preview_expired", "This preview expired. Review a fresh preview before submitting.", 409)
            account = self._account(session, orders=True)
            if preview["account_id"] != account["id"] or preview["mode"] != account["mode"]:
                raise PersonalError("account_changed", "The account changed. Create and review a new preview.", 409)
            validate_intent({key: preview["intent"][key] for key in ("symbol", "side", "quantity", "limit_price")}, self.cap)
            self._precheck(account, preview["intent"])
            command, claimed = self.journal.claim(preview, session, "leo-" + uuid.uuid4().hex, timestamp(self.clock()))
            if not claimed:
                return public_command(command)
            try:
                order = self.adapter.place(account, preview["intent"], command["id"])
                return self._resolve(command, order)
            except Exception:
                # The durable unknown record already exists; no retries and no raw errors.
                return public_command(command)

    def command(self, session: str, identity: str) -> dict:
        if not IDENTIFIER.fullmatch(identity):
            raise PersonalError("invalid_command", "Invalid order command ID.")
        with self.lock:
            self._session(session)
            command = self.journal.command(identity, session)
            if command["status"] != "unknown":
                return public_command(command)
            account = self._account(session)
            if account["id"] != command["account_id"] or account["mode"] != command["mode"]:
                raise PersonalError("account_changed", "Reconnect the account used for this order before checking its status.", 409)
            try:
                order = self.adapter.find_order(account, identity)
                return self._resolve(command, order) if order else public_command(command)
            except Exception:
                return public_command(command)

    def preview_command(self, session: str, identity: str) -> dict:
        if not IDENTIFIER.fullmatch(identity):
            raise PersonalError("invalid_preview", "Invalid order preview ID.")
        with self.lock:
            self._session(session)
            self.journal.preview(identity, session, include_revoked=True)
            existing = self.journal.command_for_preview(identity, session)
            return {"command": self.command(session, existing["id"]) if existing else None}

    def discard_preview(self, session: str, identity: str, payload: dict) -> dict:
        exact_keys(payload, set())
        if not IDENTIFIER.fullmatch(identity):
            raise PersonalError("invalid_preview", "Invalid order preview ID.")
        with self.lock:
            self._session(session)
            command = self.journal.discard(identity, session)
            return {"discarded": command is None, "command": public_command(command) if command else None}

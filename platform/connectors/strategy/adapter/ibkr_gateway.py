"""Paper-only Client Portal Gateway transport for the existing Rust connector.

Loopback HTTPS, authenticated isPaper proof, explicit local opt-in, exact account
binding, durable dispatch identities, and no automated broker warning replies.
This module contains no strategy implementation and no IBKR vendor SDK.
"""
from __future__ import annotations

import argparse
import hashlib
import hmac
import http.client
import ipaddress
import json
import os
import re
import sqlite3
import ssl
import sys
import time
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from urllib.parse import urlencode

from paper_sdk import CLIENT, ET, MAX_INPUT, SYMBOL, PaperAdapter, decimal, no_duplicates, stamp, utc

ACCOUNT = re.compile(r"^IBKR:(DU[0-9]{1,20})$")
TERMINAL = {"Filled", "Cancelled", "ApiCancelled"}
STATUSES = TERMINAL | {"PendingSubmit", "PreSubmitted", "Submitted", "PendingCancel", "Inactive", "PreCancelled"}
PAPER_PROOF = "ibkr_authenticated_paper_session_required"
MAX_RESPONSE = 4 * 1024 * 1024


class GatewayError(ValueError):
    """Fixed safe diagnostic codes only; raw broker text never reaches logs."""


class NotTransmitted(GatewayError):
    """The transport proves no HTTP request bytes were attempted."""


def require(condition, code):
    if not condition:
        raise GatewayError(code)


def identity(value):
    matched = ACCOUNT.fullmatch(str(value))
    require(matched is not None, "ibkr_qualified_paper_account_required")
    return matched.group(1)


def numeric_id(value):
    require(not isinstance(value, bool) and isinstance(value, (int, str)), "ibkr_invalid_numeric_identifier")
    result = str(value)
    require(result.isascii() and result.isdigit() and 0 < int(result) < 2**63, "ibkr_invalid_numeric_identifier")
    return result


def money(value):
    result = Decimal(decimal(value))
    require(abs(result) < Decimal("1e100"), "ibkr_amount_unavailable")
    return result


def alias(row, *keys):
    values = [row[k] for k in keys if k in row and row[k] is not None]
    require(bool(values) and all(v == values[0] for v in values), "ibkr_missing_or_conflicting_field")
    return values[0]


def encode_json(value):
    """Encode monetary Decimal as exact JSON numbers, without float conversion."""
    if isinstance(value, Decimal):
        require(value.is_finite(), "ibkr_invalid_json_number")
        return format(value, "f")
    if isinstance(value, dict):
        return "{" + ",".join(json.dumps(k) + ":" + encode_json(v) for k, v in value.items()) + "}"
    if isinstance(value, list):
        return "[" + ",".join(encode_json(v) for v in value) + "]"
    return json.dumps(value, separators=(",", ":"), allow_nan=False)


class GatewayHTTP:
    """No proxy, redirect, host override, credential input, or retry transport."""

    def __init__(self, port=5000, ca_file=None, certificate_sha256=None, timeout=3):
        require(isinstance(port, int) and not isinstance(port, bool) and 1024 <= port <= 65535, "ibkr_invalid_gateway_port")
        require(not (ca_file and certificate_sha256), "ibkr_choose_one_certificate_method")
        self.port, self.timeout, self.pin = port, timeout, certificate_sha256
        if self.pin:
            require(re.fullmatch(r"[a-fA-F0-9]{64}", self.pin) is not None, "ibkr_invalid_certificate_fingerprint")
            self.pin = self.pin.lower()
            self.context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            self.context.check_hostname = False
            self.context.verify_mode = ssl.CERT_NONE
        else:
            self.context = ssl.create_default_context(cafile=ca_file)
        self.last_request = 0.0

    def request(self, method, path, body=None, *, before_send=None):
        # Paths are produced from validated identifiers by GatewayAdapter; this
        # second boundary also excludes warning replies, switching and live APIs.
        allowed = (
            method == "POST" and (path == "/iserver/auth/status" or re.fullmatch(r"/iserver/account/DU[0-9]+/orders", path))
            or method == "DELETE" and re.fullmatch(r"/iserver/account/DU[0-9]+/order/[0-9]+", path)
            or method == "GET" and (path in ("/iserver/accounts", "/portfolio/accounts", "/iserver/account/orders")
                or re.fullmatch(r"/portfolio/DU[0-9]+/(ledger|positions/[0-9]+)", path)
                or re.fullmatch(r"/iserver/account/order/status/[0-9]+", path)
                or re.fullmatch(r"/iserver/contract/[0-9]+/info", path)
                or re.fullmatch(r"/trsrv/stocks\?symbols=[A-Z]+", path)
                or re.fullmatch(r"/iserver/marketdata/snapshot\?conids=[0-9]+&fields=[0-9%,]+", path))
        )
        require(bool(allowed), "ibkr_endpoint_not_allowed")
        delay = .12 - (time.monotonic() - self.last_request)
        if delay > 0:
            time.sleep(delay)
        self.last_request = time.monotonic()
        connection = http.client.HTTPSConnection("localhost", self.port, timeout=self.timeout, context=self.context)
        transmission_started = False
        try:
            connection.connect()
            require(ipaddress.ip_address(connection.sock.getpeername()[0]).is_loopback, "ibkr_loopback_required")
            if self.pin:
                actual = hashlib.sha256(connection.sock.getpeercert(binary_form=True)).hexdigest()
                require(hmac.compare_digest(actual, self.pin), "ibkr_certificate_fingerprint_mismatch")
            data = encode_json(body).encode() if body is not None else None
            if before_send is not None:
                before_send()
            # Once request() begins even an exception can mean a partial write.
            transmission_started = True
            connection.request(method, "/v1/api" + path, body=data,
                               headers={"Accept": "application/json", "Content-Type": "application/json", "User-Agent": "LeoLocalPaperConnector/0.1"})
            response = connection.getresponse()
            raw = response.read(MAX_RESPONSE + 1)
            require(200 <= response.status < 300 and len(raw) <= MAX_RESPONSE, "ibkr_gateway_http_unavailable")
            require("application/json" in response.getheader("Content-Type", ""), "ibkr_gateway_json_required")
            return json.loads(raw, object_pairs_hook=no_duplicates, parse_float=Decimal,
                              parse_constant=lambda _: (_ for _ in ()).throw(GatewayError("ibkr_invalid_json_number")))
        except Exception as error:
            if not transmission_started and (method == "DELETE" or method == "POST" and path.endswith("/orders")):
                raise NotTransmitted(str(error) if isinstance(error, GatewayError) else "ibkr_request_not_transmitted") from None
            raise
        finally:
            connection.close()


class DispatchJournal:
    """Transport-only deduplication; strategy/position accounting stays in Rust."""

    def __init__(self, path):
        self.path = Path(path).resolve()
        self.db = sqlite3.connect(str(path), timeout=2)
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("PRAGMA synchronous=FULL")
        self.db.execute("CREATE TABLE IF NOT EXISTS dispatch (client_id TEXT PRIMARY KEY, account TEXT NOT NULL, intent TEXT NOT NULL, broker_id TEXT, state TEXT NOT NULL, warning_id TEXT, observation TEXT, cancel_started INTEGER NOT NULL DEFAULT 0)")
        self.db.commit()

    @contextmanager
    def operation(self, account):
        """Hold across preflight AND transmission; crashes release the OS lock.

        The durable journal is bound to one connector installation. Each process
        must use that same path; the Rust/cloud account lease is an additional
        boundary across different installations.
        """
        identity("IBKR:" + account)
        path = self.path.with_name(self.path.name + "." + account + ".lock")
        with path.open("a+b") as handle:
            handle.seek(0, os.SEEK_END)
            if handle.tell() == 0:
                handle.write(b"0")
                handle.flush()
            handle.seek(0)
            try:
                if os.name == "nt":
                    import msvcrt
                    msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
                else:
                    import fcntl
                    fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except OSError:
                raise GatewayError("ibkr_account_operation_in_progress") from None
            try:
                yield
            finally:
                handle.seek(0)
                if os.name == "nt":
                    import msvcrt
                    msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
                else:
                    import fcntl
                    fcntl.flock(handle.fileno(), fcntl.LOCK_UN)

    def rows(self, account):
        return self.db.execute("SELECT * FROM dispatch WHERE account=?", (account,)).fetchall()

    def pending(self, account):
        return self.db.execute("SELECT count(*) FROM dispatch WHERE account=? AND state IN ('unknown','warning','acknowledged')", (account,)).fetchone()[0]

    def claim(self, account, intent):
        try:
            with self.db:
                # Account lock and identity insertion are atomic across processes.
                self.db.execute("BEGIN IMMEDIATE")
                require(not self.pending(account), "ibkr_unresolved_dispatch_requires_reconciliation")
                self.db.execute("INSERT INTO dispatch(client_id,account,intent,state) VALUES(?,?,?,'unknown')",
                                (intent["client_id"], account, encode_json(intent)))
        except sqlite3.IntegrityError:
            raise GatewayError("ibkr_existing_command_requires_reconciliation") from None

    def acknowledge(self, client_id, broker_id):
        with self.db:
            self.db.execute("UPDATE dispatch SET broker_id=?,state='acknowledged' WHERE client_id=?", (broker_id, client_id))

    def warning(self, client_id, warning_id):
        with self.db:
            self.db.execute("UPDATE dispatch SET state='warning',warning_id=? WHERE client_id=?", (warning_id, client_id))

    def not_sent(self, client_id):
        with self.db:
            self.db.execute("UPDATE dispatch SET state='not_sent' WHERE client_id=? AND state='unknown' AND broker_id IS NULL", (client_id,))

    def observe(self, account, order):
        row = self.db.execute("SELECT * FROM dispatch WHERE client_id=? AND account=?", (order["client_id"], account)).fetchone()
        if row is None:
            return
        expected = json.loads(row["intent"])
        require(all(str(expected[k]) == str(order[k]) for k in ("symbol", "side")) and money(expected["quantity"]) == money(order["quantity"]), "ibkr_order_intent_mismatch")
        require(row["broker_id"] is None or row["broker_id"] == order["id"], "ibkr_duplicate_broker_order_for_command")
        if row["observation"]:
            previous = json.loads(row["observation"])
            require(money(order["filled_quantity"]) >= money(previous["filled_quantity"]), "ibkr_cumulative_fill_regression")
            require(not previous["terminal"] or order["terminal"], "ibkr_terminal_order_regression")
        with self.db:
            self.db.execute("UPDATE dispatch SET broker_id=?,state='observed',observation=? WHERE client_id=?",
                            (order["id"], encode_json(order), order["client_id"]))

    def claim_cancel(self, account, order):
        with self.db:
            changed = self.db.execute("UPDATE dispatch SET cancel_started=1 WHERE account=? AND client_id=? AND broker_id=? AND cancel_started=0",
                                      (account, order["client_id"], order["id"])).rowcount
        return changed == 1

    def cancel_not_sent(self, account, order):
        with self.db:
            self.db.execute("UPDATE dispatch SET cancel_started=0 WHERE account=? AND client_id=? AND broker_id=?", (account, order["client_id"], order["id"]))

    def close(self):
        self.db.close()


class GatewayAdapter(PaperAdapter):
    def __init__(self, transport=None, *, enable_paper_execution=False, account=None, journal=None,
                 clock=utc, monotonic=time.monotonic, calendar=None, history_directory=None):
        super().__init__(clock=clock, calendar=calendar)
        self.http = transport or GatewayHTTP()
        self.enabled = enable_paper_execution is True
        self.expected_account = identity(account) if account else None
        require(not self.enabled or self.expected_account is not None, "ibkr_explicit_account_required")
        self.journal = journal
        require(not self.enabled or journal is not None, "ibkr_durable_journal_required")
        self.monotonic = monotonic
        self.history_directory = Path(history_directory).resolve() if history_directory else None
        self.session_id = None
        self.contract_cache = {}
        self.portfolio_cache = None
        self.order_cache = None
        self.orders_requested_at = None
        self.last_settled_cash = {}

    def proof(self, account=None):
        status = self.http.request("POST", "/iserver/auth/status")
        require(isinstance(status, dict) and status.get("authenticated") is True and status.get("connected") is True
                and status.get("competing") is False, PAPER_PROOF)
        response = self.http.request("GET", "/iserver/accounts")
        require(isinstance(response, dict) and response.get("isPaper") is True, PAPER_PROOF)
        names, selected, session = response.get("accounts"), response.get("selectedAccount"), response.get("sessionId")
        require(isinstance(names, list) and bool(names) and len(set(names)) == len(names)
                and all(isinstance(n, str) and re.fullmatch(r"DU[0-9]{1,20}", n) for n in names)
                and selected in names and isinstance(session, str) and 0 < len(session) < 256, PAPER_PROOF)
        target = account or self.expected_account or selected
        require(target == selected and target in names, "ibkr_selected_account_mismatch")
        require(self.session_id in (None, session), "ibkr_session_changed_reconnect_required")
        self.session_id = session
        return target

    def portfolio(self, account):
        now = self.monotonic()
        if self.portfolio_cache is None or now - self.portfolio_cache[0] >= 5:
            rows = self.http.request("GET", "/portfolio/accounts")
            require(isinstance(rows, list) and len(rows) < 100, "ibkr_portfolio_accounts_incomplete")
            self.portfolio_cache = now, rows
        matches = [r for r in self.portfolio_cache[1] if r.get("accountId") == account and r.get("id", account) == account]
        require(len(matches) == 1 and matches[0].get("currency") == "USD" and matches[0].get("brokerageAccess") is True
                and matches[0].get("noClientTrading") is False, "ibkr_usd_trading_account_required")
        return matches[0]

    def readiness(self):
        account = self.proof()
        self.portfolio(account)
        return {"broker": "IBKR", "transport": "client_portal_gateway", "connected": True,
                "paperEnvironmentAttested": True, "accountId": "IBKR:" + account,
                "localExecutionEnabled": self.enabled, "executionAuthorized": False,
                "historicalDataConfigured": self.history_directory is not None,
                "unresolvedSubmissions": self.journal.pending(account) if self.journal else 0,
                "externalPrerequisites": ["owner_approved_strategy_mandate", "broker_paper_acceptance_cycle", "commercial_integration_approval_for_public_service"],
                "observedAt": stamp(self.clock())}

    def accounts(self):
        if not self.enabled:
            return []
        account = self.proof()
        self.portfolio(account)
        return [{"accountId": "IBKR:" + account, "environment": "SIMULATE", "currency": "USD"}]

    def account(self, request):
        require(request.get("environment") == "SIMULATE", "real_mode_prohibited")
        require(self.enabled, "ibkr_local_paper_execution_not_enabled")
        account = identity(request.get("account_id"))
        require(account == self.expected_account, "ibkr_local_account_binding_mismatch")
        self.proof(account)
        self.portfolio(account)
        return account

    def live_orders(self, account):
        now = self.monotonic()
        if self.orders_requested_at is not None and now - self.orders_requested_at < 5:
            require(self.order_cache is not None, "ibkr_order_preflight_pending")
            return self.order_cache
        self.orders_requested_at = now
        self.order_cache = None
        response = self.http.request("GET", "/iserver/account/orders")
        require(isinstance(response, dict) and response.get("snapshot") is True and isinstance(response.get("orders"), list), "ibkr_order_preflight_pending")
        rows = response["orders"]
        require(len(rows) < 1000, "ibkr_order_history_truncated")
        # Selected-account scoping is verified before and after snapshot. Reject
        # a mixed-account response instead of hiding inconsistent provider state.
        require(all(alias(r, "acct", "account") == account for r in rows), "ibkr_order_account_mismatch")
        self.order_cache = rows, self.clock()
        return self.order_cache

    def normalize_order(self, row, account, *, known=None):
        require(alias(row, "acct", "account") == account, "ibkr_order_account_mismatch")
        require(alias(row, "secType", "sec_type") == "STK" and alias(row, "cashCcy", "currency") == "USD", "ibkr_unsupported_order_instrument")
        symbol = alias(row, "ticker", "symbol")
        require(isinstance(symbol, str) and SYMBOL.fullmatch(symbol), "ibkr_invalid_order_symbol")
        broker_id = numeric_id(alias(row, "orderId", "order_id"))
        order_id = "IBKR:" + account + ":" + broker_id
        ref = row.get("order_ref", known["client_id"] if known else "")
        require(isinstance(ref, str) and len(ref) <= 256, "ibkr_invalid_order_reference")
        side = {"B": "BUY", "S": "SELL"}.get(row.get("side"), row.get("side"))
        status = alias(row, "status", "order_status")
        quantity, filled = money(alias(row, "totalSize", "total_size")), money(alias(row, "filledQuantity", "cum_fill"))
        require(side in ("BUY", "SELL") and status in STATUSES and quantity > 0 and 0 <= filled <= quantity
                and quantity == quantity.to_integral_value() and filled == filled.to_integral_value(), "ibkr_invalid_order_observation")
        average = money(alias(row, "avgPrice", "average_price")) if filled else None
        require(average is None or average > 0, "ibkr_fill_price_unavailable")
        require(status != "Filled" or filled == quantity, "ibkr_inconsistent_terminal_fill")
        result = {"id": order_id, "client_id": ref, "symbol": symbol, "side": side, "quantity": str(quantity),
                  "filled_quantity": str(filled), "average_fill_price": str(average) if average is not None else None,
                  "status": status, "terminal": status in TERMINAL}
        if known:
            require(known["broker_id"] == order_id, "ibkr_recovery_order_identity_mismatch")
        return result

    def snapshot(self, request):
        account = self.account(request)
        observed = self.clock()
        # Collect commitments before balances/positions. A sell filling between
        # these reads then remains reserved, conservatively understating shares
        # available for another exit. The reverse order can oversell.
        orders, orders_at = self.reconciled_orders(account)
        ledger = self.http.request("GET", f"/portfolio/{account}/ledger")
        require(isinstance(ledger, dict) and isinstance(ledger.get("USD"), dict) and isinstance(ledger.get("BASE"), dict), "ibkr_account_ledger_incomplete")
        usd, base = ledger["USD"], ledger["BASE"]
        require(usd.get("acctcode") == account and base.get("acctcode") == account and usd.get("currency") == "USD", "ibkr_ledger_account_mismatch")
        cash, equity, settled = money(usd.get("cashbalance")), money(base.get("netliquidationvalue")), money(usd.get("settledcash"))
        require(cash >= 0 and equity > 0 and money(base.get("cashbalance")) == cash, "ibkr_cash_only_account_required")
        for key, value in ledger.items():
            if key not in ("BASE", "USD"):
                require(isinstance(value, dict) and money(value.get("cashbalance")) == 0 and money(value.get("netliquidationvalue")) == 0, "ibkr_non_usd_exposure_unsupported")
        times = [observed, orders_at]
        for row in (usd, base):
            timestamp = row.get("timestamp")
            require(isinstance(timestamp, int) and not isinstance(timestamp, bool), "ibkr_ledger_timestamp_unavailable")
            event_time = datetime.fromtimestamp(timestamp, timezone.utc)
            require(0 <= (self.clock() - event_time).total_seconds() <= 10, "ibkr_ledger_stale")
            times.append(event_time)
        positions, conids = [], set()
        for page in range(10):
            rows = self.http.request("GET", f"/portfolio/{account}/positions/{page}")
            require(isinstance(rows, list) and len(rows) <= 100, "ibkr_positions_incomplete")
            for row in rows:
                require(row.get("acctId") == account and row.get("assetClass") == "STK" and row.get("currency") == "USD", "ibkr_position_account_or_asset_mismatch")
                conid = numeric_id(row.get("conid"))
                require(conid not in conids, "ibkr_positions_pagination_changed")
                conids.add(conid)
                symbol = row.get("ticker") or row.get("contractDesc")
                require(isinstance(symbol, str) and SYMBOL.fullmatch(symbol), "ibkr_position_symbol_unavailable")
                quantity = money(row.get("position"))
                require(quantity >= 0 and quantity == quantity.to_integral_value(), "ibkr_long_whole_share_position_required")
                positions.append({"symbol": symbol, "quantity": str(quantity), "available_quantity": str(quantity), "market_value": str(money(row.get("mktValue")))})
            if len(rows) < 100:
                break
        else:
            raise GatewayError("ibkr_positions_pagination_limit")
        for position in positions:
            reserved = sum((money(o["quantity"]) - money(o["filled_quantity"]) for o in orders.values()
                            if o["symbol"] == position["symbol"] and o["side"] == "SELL" and not o["terminal"]), Decimal(0))
            position["available_quantity"] = str(max(Decimal(0), money(position["quantity"]) - reserved))
        self.proof(account)
        require((self.clock() - min(times)).total_seconds() <= 10, "ibkr_snapshot_stale_during_collection")
        self.last_settled_cash[account] = settled
        return {"account_id": "IBKR:" + account, "environment": "SIMULATE", "observed_at": stamp(min(times)),
                "cash": str(cash), "equity": str(equity), "positions": positions, "orders": list(orders.values()), "history_complete": False}

    def reconciled_orders(self, account):
        raw_orders, orders_at = self.live_orders(account)
        orders = {}
        client_ids = set()
        for row in raw_orders:
            order = self.normalize_order(row, account)
            require(order["id"] not in orders, "ibkr_duplicate_order_observation")
            if CLIENT.fullmatch(order["client_id"]):
                require(order["client_id"] not in client_ids, "ibkr_duplicate_broker_order_for_command")
                client_ids.add(order["client_id"])
            orders[order["id"]] = order
            self.journal.observe(account, order)
        for known in self.journal.rows(account):
            if not known["broker_id"] or known["broker_id"] in orders:
                continue
            old = json.loads(known["observation"]) if known["observation"] else None
            if old and old["terminal"]:
                orders[old["id"]] = old
                continue
            broker_id = numeric_id(known["broker_id"].rsplit(":", 1)[-1])
            response = self.http.request("GET", "/iserver/account/order/status/" + broker_id)
            order = self.normalize_order(response, account, known=known)
            orders[order["id"]] = order
            self.journal.observe(account, order)
        return orders, orders_at

    def instrument(self, symbol):
        require(isinstance(symbol, str) and re.fullmatch(r"[A-Z]{1,10}", symbol), "ibkr_supported_symbol_required")
        if symbol not in self.contract_cache:
            response = self.http.request("GET", "/trsrv/stocks?symbols=" + symbol)
            require(isinstance(response, dict) and isinstance(response.get(symbol), list), "ibkr_instrument_unavailable")
            rows = [c for item in response[symbol] if item.get("assetClass") == "STK" for c in item.get("contracts", []) if c.get("isUS") is True]
            require(len(rows) == 1, "ibkr_instrument_ambiguous")
            conid = numeric_id(rows[0].get("conid"))
            details = self.http.request("GET", f"/iserver/contract/{conid}/info")
            require(numeric_id(alias(details, "conid", "con_id")) == conid and alias(details, "ticker", "symbol") == symbol
                    and alias(details, "secType", "instrument_type") == "STK" and details.get("currency") == "USD"
                    and "SMART" in alias(details, "validExchanges", "valid_exchanges").split(","), "ibkr_listed_us_equity_required")
            self.contract_cache[symbol] = conid
        return self.contract_cache[symbol]

    def quote(self, symbol):
        conid = self.instrument(symbol)
        path = "/iserver/marketdata/snapshot?" + urlencode({"conids": conid, "fields": "55,84,85,86,88,6509,7184"})
        rows = self.http.request("GET", path)
        require(isinstance(rows, list) and len(rows) == 1 and numeric_id(rows[0].get("conid")) == conid, "ibkr_quote_unavailable")
        row = rows[0]
        require(row.get("55") == symbol and str(row.get("6509", "")).startswith("RpB") and row.get("7184") in ("1", 1), "ibkr_realtime_consolidated_quote_required")
        timestamp = row.get("_updated")
        require(isinstance(timestamp, int) and not isinstance(timestamp, bool), "ibkr_quote_timestamp_unavailable")
        observed = datetime.fromtimestamp(timestamp / 1000, timezone.utc)
        bid, ask = money(row.get("84")), money(row.get("86"))
        require(0 <= (self.clock() - observed).total_seconds() <= 5 and 0 < bid <= ask, "ibkr_fresh_quote_required")
        def size(value):
            if isinstance(value, str) and re.fullmatch(r"[0-9]{1,3}(,[0-9]{3})+", value):
                value = value.replace(",", "")
            return money(value)
        # Thousands separators are unambiguous; K/M suffixes remain unsupported.
        require(size(row.get("85")) > 0 and size(row.get("88")) > 0, "ibkr_quote_size_unavailable")
        return {"symbol": symbol, "bid": str(bid), "ask": str(ask), "observed_at": stamp(observed),
                "market_open": self.market_open(), "source": "IBKR_CLIENT_PORTAL_CONSOLIDATED_SNAPSHOT"}

    def history(self, symbol):
        require(self.history_directory is not None, "ibkr_validated_history_not_configured")
        require(isinstance(symbol, str) and re.fullmatch(r"[A-Z]{1,10}", symbol), "ibkr_supported_symbol_required")
        path = (self.history_directory / (symbol + ".json")).resolve()
        require(path.parent == self.history_directory and path.stat().st_size <= MAX_INPUT, "ibkr_history_file_invalid")
        payload = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=no_duplicates)
        require(payload.get("symbol") == symbol and isinstance(payload.get("evaluation"), dict), "ibkr_history_identity_mismatch")
        evaluation = payload["evaluation"]
        bars, evidence = evaluation.get("bars"), evaluation.get("evidence", {})
        require(evaluation.get("history_mode") == "current_observed_snapshot" and isinstance(bars, list) and 220 <= len(bars) <= 1000
                and evidence.get("classification") == "observed" and evidence.get("adjustment_verified") is True
                and evidence.get("coverage_verified") is True and evidence.get("availability_verified") is False
                and evidence.get("source") in ("IBKR_TWS_ADJUSTED_LAST_RTH", "VALIDATED_FILE_IMPORT")
                and evidence.get("calendar_source") == "exchange_calendars/XNYS", "ibkr_history_manifest_unverified")
        digest = hashlib.sha256(json.dumps(bars, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        require(hmac.compare_digest(digest, str(evidence.get("dataset_sha256", ""))), "ibkr_history_hash_mismatch")
        calendar, now = self._calendar(), self.clock()
        latest = str(self.completed_session().date())
        dates = [b.get("session_date") for b in bars]
        require(dates[-1] == latest and len(set(dates)) == len(dates)
                and dates == [str(s.date()) for s in calendar.sessions_in_range(dates[0], latest)], "ibkr_history_session_coverage_invalid")
        for bar in bars:
            day = bar["session_date"]
            opened, closed = calendar.session_open(day).to_pydatetime(), calendar.session_close(day).to_pydatetime()
            parse = lambda value: datetime.fromisoformat(value.replace("Z", "+00:00"))
            require(parse(bar["open_at"]) == opened and parse(bar["close_at"]) == closed
                    and closed < parse(bar["available_at"]) <= now, "ibkr_history_availability_invalid")
            op, hi, lo, cl = (money(bar[k]) for k in ("open", "high", "low", "close"))
            require(0 < lo <= min(op, cl) <= max(op, cl) <= hi and isinstance(bar["volume"], int)
                    and not isinstance(bar["volume"], bool) and bar["volume"] >= 0, "ibkr_history_bar_invalid")
        return evaluation

    def place(self, request):
        require(self.enabled and self.journal is not None, "ibkr_local_paper_execution_not_enabled")
        with self.journal.operation(identity(request.get("account_id"))):
            # reconciled_orders merges the latest durable dispatch identities
            # into paced broker observations before cash/positions are read.
            return self._place(request)

    def _place(self, request):
        account = self.account(request)
        intent = request.get("intent", {})
        require(isinstance(intent, dict) and intent.get("account_id") == request["account_id"]
                and CLIENT.fullmatch(str(intent.get("client_id", ""))), "ibkr_intent_identity_mismatch")
        symbol, side, kind = intent.get("symbol"), intent.get("side"), intent.get("order_type")
        require(side in ("BUY", "SELL") and kind in ("NORMAL", "MARKET") and (side != "BUY" or kind == "NORMAL"), "ibkr_paper_order_type_unsupported")
        quantity = money(intent.get("quantity"))
        require(quantity > 0 and quantity == quantity.to_integral_value(), "whole_shares_required")
        conid = self.instrument(symbol)
        snapshot = self.snapshot(request)
        require(not self.journal.pending(account), "ibkr_unresolved_dispatch_requires_reconciliation")
        require(not any(o["client_id"] == intent["client_id"] for o in snapshot["orders"]), "ibkr_existing_command_requires_reconciliation")
        price = money(intent.get("limit_price")) if kind == "NORMAL" else None
        if side == "BUY":
            require(price > 0 and quantity * price <= min(money(snapshot["cash"]), self.last_settled_cash[account]), "ibkr_settled_cash_limit_exceeded")
            require(not any(o["side"] == "BUY" and not o["terminal"] for o in snapshot["orders"]), "ibkr_existing_buy_commitment")
            require(not any(p["symbol"] == symbol and money(p["quantity"]) != 0 for p in snapshot["positions"]), "existing_broker_symbol_exposure_blocked")
            # Data availability is also checked inside this execution boundary.
            self.history(symbol)
        else:
            available = sum((money(p["available_quantity"]) for p in snapshot["positions"] if p["symbol"] == symbol), Decimal(0))
            require(quantity <= available, "unintended_short_prohibited")
        quote = self.quote(symbol)
        self.proof(account)
        now = self.clock()
        require(self.market_open() and 0 <= (now - datetime.fromisoformat(quote["observed_at"].replace("Z", "+00:00"))).total_seconds() <= 5, "ibkr_fresh_regular_quote_required")
        if side == "BUY":
            bid, ask = money(quote["bid"]), money(quote["ask"])
            require((ask - bid) * 20000 <= (ask + bid) * 20, "entry_spread_exceeds_twenty_basis_points")
            deadline = request.get("entry_lease_deadline_ms")
            require(isinstance(deadline, int) and not isinstance(deadline, bool)
                    and now.timestamp() * 1000 < deadline <= now.timestamp() * 1000 + 15000, "entry_lease_expired")
            et = now.astimezone(ET)
            require(et.hour == 9 and 35 <= et.minute < 40, "outside_entry_window")
        body = {"acctId": account, "conid": int(conid), "cOID": intent["client_id"], "orderType": "LMT" if kind == "NORMAL" else "MKT",
                "side": side, "tif": "DAY", "quantity": int(quantity), "outsideRTH": False, "listingExchange": "SMART"}
        if price is not None:
            body["price"] = price
        def before_send():
            send_time = self.clock()
            require(self.market_open() and 0 <= (send_time - datetime.fromisoformat(quote["observed_at"].replace("Z", "+00:00"))).total_seconds() <= 5,
                    "ibkr_quote_expired_before_transmission")
            require((send_time - datetime.fromisoformat(snapshot["observed_at"].replace("Z", "+00:00"))).total_seconds() <= 10,
                    "ibkr_snapshot_expired_before_transmission")
            if side == "BUY":
                require(send_time.timestamp() * 1000 < request["entry_lease_deadline_ms"], "entry_lease_expired")
                et = send_time.astimezone(ET)
                require(et.hour == 9 and 35 <= et.minute < 40, "outside_entry_window")
        self.journal.claim(account, intent)
        self.submission_attempted = True
        try:
            response = self.http.request("POST", f"/iserver/account/{account}/orders", {"orders": [body]}, before_send=before_send)
        except NotTransmitted:
            self.journal.not_sent(intent["client_id"])
            self.submission_attempted = False
            raise
        require(isinstance(response, list) and len(response) == 1 and isinstance(response[0], dict), "ibkr_submission_outcome_unknown")
        result = response[0]
        if "id" in result and "message" in result:
            warning_id = str(result["id"])
            require(re.fullmatch(r"[a-zA-Z0-9-]{1,128}", warning_id), "ibkr_submission_outcome_unknown")
            self.journal.warning(intent["client_id"], warning_id)
            raise GatewayError("ibkr_order_warning_requires_user_review")
        broker_id = numeric_id(result.get("order_id"))
        require(result.get("local_order_id", intent["client_id"]) == intent["client_id"], "ibkr_order_ack_identity_mismatch")
        self.journal.acknowledge(intent["client_id"], "IBKR:" + account + ":" + broker_id)
        # Acknowledgment has no cumulative fill facts. Query specific status,
        # without hammering the five-second live-orders endpoint or inventing 0.
        status = self.http.request("GET", "/iserver/account/order/status/" + broker_id)
        known = next(row for row in self.journal.rows(account) if row["client_id"] == intent["client_id"])
        order = self.normalize_order(status, account, known=known)
        self.journal.observe(account, order)
        return order

    def cancel(self, request):
        require(self.enabled and self.journal is not None, "ibkr_local_paper_execution_not_enabled")
        with self.journal.operation(identity(request.get("account_id"))):
            return self._cancel(request)

    def _cancel(self, request):
        account = self.account(request)
        snapshot = self.snapshot(request)
        order = next((o for o in snapshot["orders"] if o["id"] == request.get("order_id") and CLIENT.fullmatch(o["client_id"])), None)
        require(order is not None, "ibkr_owned_order_not_verified")
        owned = next((r for r in self.journal.rows(account) if r["client_id"] == order["client_id"] and r["broker_id"] == order["id"]), None)
        require(owned is not None, "ibkr_owned_order_not_verified")
        if order["terminal"]:
            return {"cancel_requested": False, "terminal": True}
        self.proof(account)
        if not self.journal.claim_cancel(account, order):
            return {"cancel_requested": True, "terminal": False}
        self.submission_attempted = True
        broker_id = numeric_id(order["id"].rsplit(":", 1)[-1])
        try:
            response = self.http.request("DELETE", f"/iserver/account/{account}/order/{broker_id}")
        except NotTransmitted:
            self.journal.cancel_not_sent(account, order)
            self.submission_attempted = False
            raise
        require(isinstance(response, dict) and numeric_id(response.get("order_id")) == broker_id
                and response.get("account") in (None, account) and "error" not in response, "ibkr_cancel_outcome_unknown")
        return {"cancel_requested": True, "terminal": False}

    def dispatch(self, request):
        self.submission_attempted = False
        require(isinstance(request, dict), "ibkr_invalid_request")
        operation = request.get("operation")
        if operation == "accounts":
            return self.accounts()
        if operation == "readiness":
            return self.readiness()
        if operation == "snapshot":
            return self.snapshot(request)
        if operation == "market":
            self.proof(self.expected_account)
            symbol = request.get("symbol", "")
            quote = self.quote(symbol)
            try:
                history = self.history(symbol)
            except Exception:
                history = None
            entry_session = str(self._calendar().next_session(history["bars"][-1]["session_date"]).date()) if history else None
            return {"quote": quote, "evaluation": history, "entry_session": entry_session,
                    "limitations": [] if history else ["ibkr_validated_adjusted_history_required"]}
        if operation == "place":
            return self.place(request)
        if operation == "cancel":
            return self.cancel(request)
        raise GatewayError("ibkr_unsupported_operation")


def serve(adapter, input_stream, output):
    for line in iter(lambda: input_stream.readline(MAX_INPUT + 1), b""):
        adapter.submission_attempted = False
        try:
            require(len(line) <= MAX_INPUT and line.endswith(b"\n"), "ibkr_oversized_request")
            request = json.loads(line, object_pairs_hook=no_duplicates, parse_float=Decimal)
            result = adapter.dispatch(request)
        except Exception as error:
            result = {"error": str(error) if isinstance(error, GatewayError) else "ibkr_gateway_operation_unavailable",
                      "execution_authorized": False, "submission_attempted": adapter.submission_attempted}
        output.write(encode_json(result) + "\n")
        output.flush()


def main():
    parser = argparse.ArgumentParser(description="Local IBKR Client Portal PAPER adapter; real accounts prohibited.")
    parser.add_argument("--self-check", action="store_true")
    parser.add_argument("--enable-paper-execution", action="store_true")
    parser.add_argument("--account", help="Explicit qualified account, such as IBKR:DU1234567")
    parser.add_argument("--port", type=int, default=5000)
    certificates = parser.add_mutually_exclusive_group()
    certificates.add_argument("--ca-file")
    certificates.add_argument("--certificate-sha256")
    parser.add_argument("--journal")
    parser.add_argument("--history-directory")
    args = parser.parse_args()
    if args.self_check:
        print(json.dumps({"broker": "IBKR", "transport": "client_portal_gateway", "paperOnly": True,
                          "brokerConnected": False, "localExecutionEnabled": args.enable_paper_execution,
                          "executionAuthorized": False, "vendorSdkBundled": False}))
        return
    if args.enable_paper_execution and (not args.account or not args.journal):
        parser.error("Paper execution requires --account and a persistent --journal path")
    journal = DispatchJournal(args.journal) if args.journal else None
    adapter = GatewayAdapter(GatewayHTTP(args.port, args.ca_file, args.certificate_sha256),
                             enable_paper_execution=args.enable_paper_execution, account=args.account,
                             journal=journal, history_directory=args.history_directory)
    try:
        serve(adapter, sys.stdin.buffer, sys.stdout)
    finally:
        if journal:
            journal.close()


if __name__ == "__main__":
    main()

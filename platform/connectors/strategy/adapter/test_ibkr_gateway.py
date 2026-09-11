"""Injected HTTP fixtures only; no gateway, broker order, or performance evidence."""
import copy
import hashlib
import io
import json
import tempfile
import unittest
from datetime import timedelta
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace as NS
from unittest.mock import patch

from ibkr_gateway import DispatchJournal, GatewayAdapter, GatewayError, GatewayHTTP, NotTransmitted, encode_json, serve
from test_ibkr_sdk import FakeCalendar, NOW

ACCOUNT = "DU1234567"
QUALIFIED = "IBKR:" + ACCOUNT
CID = "leo_" + "a" * 32


def live_order(ref=CID, side="BUY", filled="0", status="Submitted", order_id=101):
    return {"acct": ACCOUNT, "account": ACCOUNT, "orderId": order_id, "ticker": "SPY", "secType": "STK",
            "cashCcy": "USD", "totalSize": Decimal("2"), "filledQuantity": Decimal(filled),
            "avgPrice": "100.01" if Decimal(filled) else "0", "side": side, "status": status, "order_ref": ref}


def order_status(side="B", filled="0", status="Submitted", order_id=101):
    return {"account": ACCOUNT, "order_id": order_id, "symbol": "SPY", "sec_type": "STK", "currency": "USD",
            "total_size": "2", "cum_fill": filled, "average_price": "100.01" if Decimal(filled) else "0",
            "side": side, "order_status": status}


class FakeHTTP:
    def __init__(self):
        self.now, self.mono = NOW, 10.0
        self.calls = []
        self.status = {"authenticated": True, "connected": True, "competing": False}
        self.accounts = {"accounts": [ACCOUNT], "selectedAccount": ACCOUNT, "sessionId": "fixture-session", "isPaper": True}
        self.portfolio = [{"id": ACCOUNT, "accountId": ACCOUNT, "currency": "USD", "brokerageAccess": True, "noClientTrading": False}]
        self.ledger = {"USD": {"acctcode": ACCOUNT, "currency": "USD", "cashbalance": Decimal("10000.01"), "settledcash": Decimal("9000.01"), "timestamp": int(NOW.timestamp())},
                       "BASE": {"acctcode": ACCOUNT, "currency": "BASE", "cashbalance": Decimal("10000.01"), "netliquidationvalue": Decimal("10000.01"), "timestamp": int(NOW.timestamp())}}
        self.positions, self.orders = [], {"snapshot": True, "orders": []}
        self.ack = [{"order_id": "101", "order_status": "Submitted", "local_order_id": CID}]
        self.order_status = order_status()
        self.quote = [{"conid": 756733, "55": "SPY", "84": "100.00", "86": "100.01", "85": "1,300", "88": "10",
                       "6509": "RpB", "7184": "1", "_updated": int(NOW.timestamp() * 1000)}]
        self.contracts = {"SPY": [{"assetClass": "STK", "contracts": [{"conid": 756733, "isUS": True, "exchange": "ARCA"}]}]}
        self.details = {"con_id": 756733, "symbol": "SPY", "instrument_type": "STK", "currency": "USD", "valid_exchanges": "SMART,ARCA"}
        self.post_error, self.order_error, self.cancel_error = None, None, None
        self.delay_before_send = 0

    def request(self, method, path, body=None, *, before_send=None):
        if before_send:
            self.now += timedelta(seconds=self.delay_before_send)
            try:
                before_send()
            except GatewayError as error:
                raise NotTransmitted(str(error)) from None
        self.calls.append((method, path, copy.deepcopy(body)))
        if path == "/iserver/auth/status":
            result = self.status
        elif path == "/iserver/accounts":
            result = self.accounts
        elif path == "/portfolio/accounts":
            result = self.portfolio
        elif path.endswith("/ledger"):
            result = self.ledger
        elif "/positions/" in path:
            result = self.positions if path.endswith("/0") else []
        elif path == "/iserver/account/orders":
            if self.order_error:
                raise self.order_error
            result = self.orders
        elif path.startswith("/iserver/account/order/status/"):
            result = self.order_status
            if isinstance(result, Exception):
                raise result
        elif path.startswith("/trsrv/stocks?"):
            result = self.contracts
        elif path.startswith("/iserver/contract/"):
            result = self.details
        elif path.startswith("/iserver/marketdata/snapshot?"):
            result = self.quote
        elif method == "POST" and path.endswith("/orders"):
            if self.post_error:
                raise self.post_error
            result = self.ack
        elif method == "DELETE":
            if self.cancel_error:
                raise self.cancel_error
            result = {"order_id": 101, "account": ACCOUNT, "msg": "Request was submitted"}
        else:
            raise AssertionError("unexpected fixture endpoint: " + path)
        return copy.deepcopy(result)


class GatewayTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "dispatch.sqlite"
        self.journal = DispatchJournal(self.path)
        self.http = FakeHTTP()
        self.adapter = self.make_adapter()
        self.request = {"operation": "place", "environment": "SIMULATE", "account_id": QUALIFIED,
                        "entry_lease_deadline_ms": int(NOW.timestamp() * 1000) + 14000,
                        "intent": {"client_id": CID, "account_id": QUALIFIED, "symbol": "SPY", "side": "BUY",
                                   "quantity": "2", "order_type": "NORMAL", "limit_price": "100.110000000000000001"}}

    def make_adapter(self):
        adapter = GatewayAdapter(self.http, enable_paper_execution=True, account=QUALIFIED, journal=self.journal,
                                 clock=lambda: self.http.now, monotonic=lambda: self.http.mono, calendar=FakeCalendar())
        # Execution tests isolate data validation; separate tests exercise full
        # file history validation with a synthetic calendar and explicit label.
        adapter.history = lambda symbol: {"fixture": True}
        return adapter

    def tearDown(self):
        self.journal.close()
        self.temp.cleanup()

    def posts(self):
        return [c for c in self.http.calls if c[0] == "POST" and c[1].endswith("/orders")]

    def test_default_is_readiness_only_and_no_live_accounts(self):
        default = GatewayAdapter(self.http)
        self.assertEqual(default.accounts(), [])
        self.assertFalse(default.readiness()["executionAuthorized"])
        self.assertTrue(default.readiness()["paperEnvironmentAttested"])
        with self.assertRaisesRegex(GatewayError, "not_enabled"):
            default.dispatch(self.request)
        self.assertEqual(self.posts(), [])
        self.http.accounts["isPaper"] = False
        with self.assertRaisesRegex(GatewayError, "paper_session"):
            self.adapter.accounts()

    def test_authentication_paper_membership_selected_and_currency_guards(self):
        mutations = [("status", "authenticated", False), ("status", "connected", False), ("status", "competing", True),
                     ("accounts", "isPaper", "true"), ("accounts", "selectedAccount", "DU7654321"),
                     ("accounts", "accounts", ["U7654321"])]
        for name, key, value in mutations:
            old = copy.deepcopy(getattr(self.http, name))
            getattr(self.http, name)[key] = value
            with self.assertRaises(GatewayError):
                self.adapter.dispatch(self.request)
            setattr(self.http, name, old)
        self.http.portfolio[0]["currency"] = "EUR"
        self.adapter.portfolio_cache = None
        with self.assertRaisesRegex(GatewayError, "usd_trading"):
            self.adapter.dispatch(self.request)
        self.assertEqual(self.posts(), [])

    def test_real_mode_forged_account_and_session_switch_blocked(self):
        for patch_values in ({"environment": "REAL"}, {"account_id": "IBKR:U1234"}, {"account_id": "IBKR:DU9999"}):
            with self.assertRaises(GatewayError):
                self.adapter.dispatch({**self.request, **patch_values})
        self.adapter.accounts()
        self.http.accounts["sessionId"] = "different-session"
        with self.assertRaisesRegex(GatewayError, "session_changed"):
            self.adapter.snapshot(self.request)
        self.assertEqual(self.posts(), [])

    def test_preflight_empty_is_not_flat_and_pacing_is_preserved(self):
        self.http.orders = {"orders": [], "snapshot": False}
        with self.assertRaisesRegex(GatewayError, "preflight"):
            self.adapter.snapshot(self.request)
        self.http.orders["snapshot"] = True
        with self.assertRaisesRegex(GatewayError, "preflight"):
            self.adapter.snapshot(self.request)
        self.assertEqual(len([c for c in self.http.calls if c[1] == "/iserver/account/orders"]), 1)
        self.http.mono += 5
        self.assertEqual(self.adapter.snapshot(self.request)["orders"], [])
        self.assertEqual(len([c for c in self.http.calls if c[1] == "/iserver/account/orders"]), 2)

    def test_partial_fills_decimal_cash_and_sell_reservation(self):
        self.http.positions = [{"acctId": ACCOUNT, "assetClass": "STK", "currency": "USD", "conid": 756733,
                                "ticker": "SPY", "position": 4, "mktValue": "400.04"}]
        self.http.ledger["BASE"]["netliquidationvalue"] = Decimal("10400.05")
        self.http.orders["orders"] = [live_order(side="SELL", filled="1")]
        result = self.adapter.snapshot(self.request)
        self.assertEqual(result["cash"], "10000.01")
        self.assertEqual(result["positions"][0]["available_quantity"], "3")
        self.assertEqual(result["orders"][0]["filled_quantity"], "1")
        self.assertEqual(result["orders"][0]["average_fill_price"], "100.01")
        self.assertFalse(result["history_complete"])

    def test_stale_ledger_and_foreign_positions_or_orders_block(self):
        self.http.ledger["USD"]["timestamp"] -= 11
        with self.assertRaisesRegex(GatewayError, "ledger_stale"):
            self.adapter.snapshot(self.request)
        self.http.ledger["USD"]["timestamp"] += 11
        self.http.mono += 5
        self.http.orders["orders"] = [dict(live_order(), acct="DU9999", account="DU9999")]
        with self.assertRaisesRegex(GatewayError, "account_mismatch"):
            self.adapter.snapshot(self.request)

    def test_exact_decimal_order_and_ack_is_not_fabricated_fill(self):
        result = self.adapter.dispatch(self.request)
        self.assertEqual(len(self.posts()), 1)
        ticket = self.posts()[0][2]["orders"][0]
        self.assertEqual(ticket["price"], Decimal("100.110000000000000001"))
        self.assertFalse(ticket["outsideRTH"])
        self.assertEqual(ticket["cOID"], CID)
        self.assertEqual(result["filled_quantity"], "0")  # Actual status fixture.
        self.assertFalse(result["terminal"])
        self.assertNotIn("isCcyConv", ticket)
        self.assertEqual(self.journal.pending(ACCOUNT), 0)

    def test_timeout_never_duplicate_after_restart(self):
        self.http.post_error = TimeoutError("private broker response")
        with self.assertRaises(TimeoutError):
            self.adapter.dispatch(self.request)
        self.assertTrue(self.adapter.submission_attempted)
        self.assertEqual(self.journal.pending(ACCOUNT), 1)
        self.journal.close()
        self.journal = DispatchJournal(self.path)
        self.adapter = self.make_adapter()
        self.http.post_error = None
        with self.assertRaisesRegex(GatewayError, "unresolved"):
            self.adapter.dispatch(self.request)
        self.assertEqual(len(self.posts()), 1)

    def test_unknown_submission_reconciles_by_ref_then_remains_nonrepeatable(self):
        self.http.post_error = TimeoutError()
        with self.assertRaises(TimeoutError):
            self.adapter.dispatch(self.request)
        self.http.post_error = None
        self.http.mono += 5
        self.http.orders["orders"] = [live_order()]
        result = self.adapter.snapshot(self.request)
        self.assertEqual(result["orders"][0]["client_id"], CID)
        self.assertEqual(self.journal.pending(ACCOUNT), 0)
        with self.assertRaisesRegex(GatewayError, "existing_command"):
            self.adapter.dispatch(self.request)
        self.assertEqual(len(self.posts()), 1)

    def test_ack_timeout_recovers_known_broker_id(self):
        self.http.order_status = TimeoutError()
        with self.assertRaises(TimeoutError):
            self.adapter.dispatch(self.request)
        self.assertEqual(self.journal.rows(ACCOUNT)[0]["broker_id"], QUALIFIED + ":101")
        self.http.order_status = order_status(filled="2", status="Filled")
        result = self.adapter.snapshot(self.request)
        self.assertEqual(result["orders"][0]["filled_quantity"], "2")
        self.assertEqual(len(self.posts()), 1)

    def test_order_warning_persists_and_no_reply_or_next_order(self):
        self.http.ack = [{"id": "fixture-warning-id", "message": ["Review this order"], "messageIds": ["o163"]}]
        with self.assertRaisesRegex(GatewayError, "warning_requires_user_review"):
            self.adapter.dispatch(self.request)
        self.assertTrue(self.adapter.submission_attempted)
        self.assertEqual(self.journal.rows(ACCOUNT)[0]["state"], "warning")
        another = copy.deepcopy(self.request)
        another["intent"]["client_id"] = "leo_" + "b" * 32
        with self.assertRaisesRegex(GatewayError, "unresolved"):
            self.adapter.dispatch(another)
        self.assertEqual(len(self.posts()), 1)
        self.assertFalse(any("reply" in c[1] or "suppress" in c[1] for c in self.http.calls))

    def test_stale_delayed_frozen_unentitled_crossed_quotes_block(self):
        for key, value in (("6509", "DPB"), ("6509", "ZpB"), ("6509", "NPB"), ("6509", "RPB"),
                           ("_updated", int(NOW.timestamp() * 1000) - 6000), ("84", "101"), ("85", "0")):
            original = self.http.quote[0][key]
            self.http.quote[0][key] = value
            with self.assertRaises((GatewayError, ValueError)):
                self.adapter.dispatch(self.request)
            self.http.quote[0][key] = original
        self.assertEqual(self.posts(), [])

    def test_lease_and_quote_revalidated_after_tls_delay(self):
        self.request["entry_lease_deadline_ms"] = int(NOW.timestamp() * 1000) + 1000
        self.http.delay_before_send = 2
        with self.assertRaisesRegex(GatewayError, "lease_expired"):
            self.adapter.dispatch(self.request)
        self.assertEqual(self.posts(), [])
        self.assertFalse(self.adapter.submission_attempted)
        self.assertEqual(self.journal.rows(ACCOUNT)[0]["state"], "not_sent")

    def test_cash_margin_short_fractional_and_market_buy_block(self):
        for overrides in ({"quantity": "0.5"}, {"quantity": "100"}, {"side": "SELL", "order_type": "MARKET"}, {"order_type": "MARKET"}):
            request = copy.deepcopy(self.request)
            request["intent"].update(overrides)
            with self.assertRaises(GatewayError):
                self.adapter.dispatch(request)
        self.assertEqual(self.posts(), [])

    def test_cancel_timeout_latches_no_duplicate_cancel_and_fill_wins(self):
        self.adapter.dispatch(self.request)
        self.http.mono += 5
        self.http.orders["orders"] = [live_order()]
        cancel = {"operation": "cancel", "environment": "SIMULATE", "account_id": QUALIFIED, "order_id": QUALIFIED + ":101"}
        self.http.cancel_error = TimeoutError()
        with self.assertRaises(TimeoutError):
            self.adapter.dispatch(cancel)
        self.http.cancel_error = None
        self.assertEqual(self.adapter.dispatch(cancel), {"cancel_requested": True, "terminal": False})
        self.assertEqual(len([c for c in self.http.calls if c[0] == "DELETE"]), 1)
        self.http.mono += 5
        self.http.orders["orders"] = [live_order(filled="2", status="Filled")]
        self.assertEqual(self.adapter.dispatch(cancel), {"cancel_requested": False, "terminal": True})

    def test_two_adapters_lock_preflight_and_reserve_observed_working_order(self):
        second_journal = DispatchJournal(self.path)
        second = GatewayAdapter(self.http, enable_paper_execution=True, account=QUALIFIED,
                                journal=second_journal, clock=lambda: self.http.now,
                                monotonic=lambda: self.http.mono, calendar=FakeCalendar())
        second.history = lambda _: {"fixture": True}
        another = copy.deepcopy(self.request)
        another["intent"]["client_id"] = "leo_" + "b" * 32
        # B previously observed flat cash/positions before A's dispatch.
        second.snapshot(another)
        original_observe = self.journal.observe
        raced = []
        def observe_then_race(account, order):
            original_observe(account, order)
            self.assertEqual(self.journal.pending(ACCOUNT), 0)
            with self.assertRaisesRegex(GatewayError, "operation_in_progress"):
                second.dispatch(another)
            raced.append(True)
        try:
            with patch.object(self.journal, "observe", side_effect=observe_then_race):
                self.adapter.dispatch(self.request)
            self.assertEqual(raced, [True])
            # Once A releases the account, B must combine its paced observation
            # with A's persisted broker identity, rather than spend old cash.
            with self.assertRaisesRegex(GatewayError, "existing_buy_commitment"):
                second.dispatch(another)
            self.assertEqual(len(self.posts()), 1)
        finally:
            second_journal.close()

    def test_sell_fill_between_collection_reads_never_creates_available_shares(self):
        self.http.positions = [{"acctId": ACCOUNT, "assetClass": "STK", "currency": "USD", "conid": 756733,
                                "ticker": "SPY", "position": 2, "mktValue": "200.02"}]
        self.http.orders["orders"] = [live_order(side="SELL")]
        original = self.http.request
        def fill_while_positions_return(method, path, *args, **kwargs):
            result = original(method, path, *args, **kwargs)
            if "/positions/" in path:
                self.http.orders["orders"] = [live_order(side="SELL", filled="2", status="Filled")]
                self.http.positions = []
            return result
        with patch.object(self.http, "request", side_effect=fill_while_positions_return):
            snapshot = self.adapter.snapshot(self.request)
        self.assertEqual(snapshot["positions"][0]["available_quantity"], "0")
        paths = [c[1] for c in self.http.calls]
        self.assertLess(paths.index("/iserver/account/orders"), paths.index(f"/portfolio/{ACCOUNT}/positions/0"))
        another = copy.deepcopy(self.request)
        another["intent"].update(client_id="leo_" + "b" * 32, side="SELL", order_type="MARKET")
        with self.assertRaisesRegex(GatewayError, "short_prohibited"):
            self.adapter.dispatch(another)
        self.assertEqual(self.posts(), [])

    def test_cancel_proof_outage_before_transmission_can_recover(self):
        self.adapter.dispatch(self.request)
        cancel = {"operation": "cancel", "environment": "SIMULATE", "account_id": QUALIFIED, "order_id": QUALIFIED + ":101"}
        original = self.adapter.proof
        calls = []
        def last_proof_fails(account=None):
            calls.append(account)
            if len(calls) == 4:
                raise GatewayError("ibkr_authenticated_paper_session_required")
            return original(account)
        with patch.object(self.adapter, "proof", side_effect=last_proof_fails):
            with self.assertRaisesRegex(GatewayError, "paper_session"):
                self.adapter.dispatch(cancel)
        self.assertEqual(self.journal.rows(ACCOUNT)[0]["cancel_started"], 0)
        self.assertFalse(self.adapter.submission_attempted)
        self.assertEqual(self.adapter.dispatch(cancel), {"cancel_requested": True, "terminal": False})
        self.assertEqual(len([c for c in self.http.calls if c[0] == "DELETE"]), 1)

    def test_definitely_unsent_cancel_resets_latch_but_unknown_timeout_does_not(self):
        self.adapter.dispatch(self.request)
        cancel = {"operation": "cancel", "environment": "SIMULATE", "account_id": QUALIFIED, "order_id": QUALIFIED + ":101"}
        self.http.cancel_error = NotTransmitted("ibkr_certificate_fingerprint_mismatch")
        with self.assertRaises(NotTransmitted):
            self.adapter.dispatch(cancel)
        self.assertEqual(self.journal.rows(ACCOUNT)[0]["cancel_started"], 0)
        self.assertFalse(self.adapter.submission_attempted)
        self.http.cancel_error = None
        self.assertTrue(self.adapter.dispatch(cancel)["cancel_requested"])
        self.assertEqual(self.journal.rows(ACCOUNT)[0]["cancel_started"], 1)

    def test_duplicate_ids_and_fill_regression_pause(self):
        self.adapter.dispatch(self.request)
        self.http.mono += 5
        self.http.orders["orders"] = [live_order(filled="1"), live_order(filled="1", order_id=102)]
        with self.assertRaisesRegex(GatewayError, "duplicate_broker"):
            self.adapter.snapshot(self.request)
        self.http.mono += 5
        self.http.orders["orders"] = [live_order(filled="0")]
        with self.assertRaisesRegex(GatewayError, "regression"):
            self.adapter.snapshot(self.request)

    def test_protocol_error_preserves_submission_unknown_and_redacts(self):
        self.http.post_error = RuntimeError("secret account session cookie")
        output = io.StringIO()
        serve(self.adapter, io.BytesIO((json.dumps(self.request) + "\n").encode()), output)
        response = json.loads(output.getvalue())
        self.assertTrue(response["submission_attempted"])
        self.assertFalse(response["execution_authorized"])
        self.assertNotIn("secret", output.getvalue())

    def test_history_manifest_validation_and_hash(self):
        folder = Path(self.temp.name) / "history"
        folder.mkdir()
        self.adapter.history_directory = folder
        del self.adapter.history
        calendar = FakeCalendar()
        bars = []
        for day in calendar.sessions_in_range("2025-07-01", "2026-09-07")[-280:]:
            bars.append({"session_date": str(day.date()), "open_at": calendar.session_open(day).to_pydatetime().isoformat(),
                         "close_at": calendar.session_close(day).to_pydatetime().isoformat(), "available_at": NOW.isoformat(),
                         "open": "100", "high": "101", "low": "99", "close": "100", "volume": 1000})
        digest = hashlib.sha256(json.dumps(bars, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        evaluation = {"history_mode": "current_observed_snapshot", "bars": bars,
                      "evidence": {"source": "VALIDATED_FILE_IMPORT", "classification": "observed", "adjustment_verified": True,
                                   "coverage_verified": True, "availability_verified": False, "calendar_source": "exchange_calendars/XNYS", "dataset_sha256": digest}}
        path = folder / "SPY.json"
        path.write_text(json.dumps({"symbol": "SPY", "evaluation": evaluation}), encoding="utf-8")
        self.assertEqual(len(self.adapter.history("SPY")["bars"]), 280)
        evaluation["bars"][-1]["close"] = "500"
        path.write_text(json.dumps({"symbol": "SPY", "evaluation": evaluation}), encoding="utf-8")
        with self.assertRaisesRegex(GatewayError, "hash_mismatch"):
            self.adapter.history("SPY")


class HTTPTests(unittest.TestCase):
    def test_exact_decimal_json_roundtrip(self):
        raw = encode_json({"price": Decimal("100.110000000000000001"), "quantity": 2, "outsideRTH": False})
        parsed = json.loads(raw, parse_float=Decimal)
        self.assertEqual(parsed["price"], Decimal("100.110000000000000001"))

    def test_paths_never_allow_live_accounts_replies_or_external_urls(self):
        transport = GatewayHTTP()
        for method, path in (("POST", "/iserver/account/U123/orders"), ("POST", "/iserver/reply/secret"),
                             ("GET", "https://evil.example/"), ("DELETE", "/iserver/account/DU123/order/-1"),
                             ("POST", "/iserver/account"), ("POST", "/iserver/questions/suppress")):
            with self.assertRaisesRegex(GatewayError, "endpoint_not_allowed"):
                transport.request(method, path)

    def test_certificate_pin_checked_before_http_request(self):
        calls = []
        connection = NS(sock=NS(getpeername=lambda: ("127.0.0.1", 5000), getpeercert=lambda binary_form: b"certificate"),
                        connect=lambda: None, close=lambda: None, request=lambda *a, **kw: calls.append(a))
        with patch("ibkr_gateway.http.client.HTTPSConnection", return_value=connection):
            with self.assertRaisesRegex(GatewayError, "fingerprint_mismatch"):
                GatewayHTTP(certificate_sha256="0" * 64).request("GET", "/iserver/accounts")
        self.assertEqual(calls, [])

    def test_default_tls_verification_and_remote_peer_rejected(self):
        transport = GatewayHTTP()
        self.assertTrue(transport.context.check_hostname)
        connection = NS(sock=NS(getpeername=lambda: ("8.8.8.8", 5000)), connect=lambda: None, close=lambda: None)
        with patch("ibkr_gateway.http.client.HTTPSConnection", return_value=connection):
            with self.assertRaisesRegex(GatewayError, "loopback"):
                transport.request("GET", "/iserver/accounts")

    def test_transport_distinguishes_before_request_from_partial_write(self):
        calls = []
        connection = NS(sock=NS(getpeername=lambda: ("127.0.0.1", 5000)),
                        connect=lambda: None, close=lambda: None)
        def partial_write(*args, **kwargs):
            calls.append(True)
            raise TimeoutError("private transport detail")
        connection.request = partial_write
        with patch("ibkr_gateway.http.client.HTTPSConnection", return_value=connection):
            def rejected_before_send():
                raise GatewayError("entry_lease_expired")
            with self.assertRaises(NotTransmitted):
                GatewayHTTP().request("POST", "/iserver/account/DU123/orders", {}, before_send=rejected_before_send)
            self.assertEqual(calls, [])
            with self.assertRaises(TimeoutError):
                GatewayHTTP().request("DELETE", "/iserver/account/DU123/order/101")
            self.assertEqual(calls, [True])


if __name__ == "__main__":
    unittest.main()

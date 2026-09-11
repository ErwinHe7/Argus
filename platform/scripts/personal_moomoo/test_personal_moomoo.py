"""Local contract tests using injected fake broker responses; never send orders."""
from __future__ import annotations

import copy
import http.client
import json
import tempfile
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock

from .__main__ import Server
from .adapter import MoomooAdapter, account_id, normalize_account, number
from .errors import PersonalError
from .journal import Journal
from .service import PersonalService, validate_intent

SESSION = "a" * 48
OTHER = "b" * 48
ACCOUNT = {"id": "281756456003951537", "mode": "SIMULATE", "status": "ACTIVE", "markets": ["US"], "label": "Paper"}
INTENT = {"symbol": "AAPL", "side": "BUY", "quantity": "2", "limit_price": "100.00"}


class FakeAdapter:
    def __init__(self):
        self.account_rows = [copy.deepcopy(ACCOUNT)]
        self.place_calls = 0
        self.find_calls = 0
        self.snapshot_calls = 0
        self.unknown = False
        self.found = None
        self.last_client = None
        self.power = "5000"
        self.available = "10"
        self.connected = True

    def availability(self):
        return True, self.connected

    def accounts(self):
        return copy.deepcopy(self.account_rows)

    def snapshot(self, account):
        self.snapshot_calls += 1
        return {"account": {"id": account["id"], "mode": account["mode"], "currency": "USD", "cash": "5000", "buying_power": self.power, "equity": "6000"},
                "positions": [{"symbol": "AAPL", "quantity": "10", "available_quantity": self.available, "market_value": "1000"}], "orders": []}

    def unlock(self, _password):
        return None

    def place(self, _account, intent, client_id):
        self.place_calls += 1
        self.last_client = client_id
        order = {"id": "broker-order-1", "symbol": intent["symbol"], "side": intent["side"], "status": "SUBMITTED", "quantity": intent["quantity"], "filled_quantity": "0", "limit_price": intent["limit_price"]}
        self.found = order
        if self.unknown:
            raise TimeoutError("secret response must never escape")
        return order

    def find_order(self, _account, _client_id):
        self.find_calls += 1
        return self.found


class ServiceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "journal.sqlite3"
        self.journal = Journal(self.path)
        self.now = datetime(2026, 9, 5, 12, tzinfo=timezone.utc)
        self.adapter = FakeAdapter()
        self.service = PersonalService(self.adapter, self.journal, clock=lambda: self.now)
        self.connect()

    def tearDown(self):
        self.journal.close()
        self.temp.cleanup()

    def connect(self):
        return self.service.connect(SESSION, {"account_id": ACCOUNT["id"], "mode": ACCOUNT["mode"]})

    def preview(self, payload=None):
        return self.service.preview(SESSION, copy.deepcopy(payload or INTENT))

    def confirm(self, preview):
        return self.service.confirm(SESSION, {"preview_id": preview["id"], "confirmed": True})

    def test_preview_preserves_exact_order_and_accounts_and_never_places(self):
        preview = self.preview()
        self.assertEqual(preview["account_id"], ACCOUNT["id"])
        self.assertEqual(preview["intent"], {**INTENT, "order_type": "LIMIT", "time_in_force": "DAY", "session": "RTH"})
        self.assertEqual(preview["estimated_notional"], "200.00")
        self.assertEqual(preview["expires_at"], "2026-09-05T12:01:00.000Z")
        self.assertEqual(self.adapter.place_calls, 0)

    def test_duplicate_confirm_and_concurrent_race_place_exactly_once(self):
        preview = self.preview()
        with ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(lambda _: self.confirm(preview), range(16)))
        self.assertTrue(all(result == results[0] for result in results))
        self.assertEqual(results[0]["status"], "submitted")
        self.assertEqual(self.adapter.place_calls, 1)

    def test_expired_preview_rejected_without_broker_call(self):
        preview = self.preview()
        self.now += timedelta(seconds=60)
        with self.assertRaisesRegex(PersonalError, "expired"):
            self.confirm(preview)
        self.assertEqual(self.adapter.place_calls, 0)

    def test_cross_session_cannot_read_confirm_or_disconnect(self):
        preview = self.preview()
        command = self.confirm(preview)
        for action in (
            lambda: self.service.confirm(OTHER, {"preview_id": preview["id"], "confirmed": True}),
            lambda: self.service.command(OTHER, command["id"]),
            lambda: self.service.preview_command(OTHER, preview["id"]),
            lambda: self.service.disconnect(OTHER, {}),
            lambda: self.service.snapshot(OTHER),
        ):
            with self.subTest(action=action), self.assertRaises(PersonalError):
                action()
        self.assertEqual(self.adapter.place_calls, 1)

    def test_disconnect_and_account_switch_revoke_preview(self):
        preview = self.preview()
        self.service.disconnect(SESSION, {})
        self.connect()
        with self.assertRaisesRegex(PersonalError, "connection changed"):
            self.confirm(preview)
        self.assertEqual(self.adapter.place_calls, 0)

    def test_account_identity_change_cannot_confirm(self):
        preview = self.preview()
        self.adapter.account_rows.append({**ACCOUNT, "id": "1234"})
        self.service.account = {"id": "1234", "mode": "SIMULATE"}
        with self.assertRaisesRegex(PersonalError, "account changed"):
            self.confirm(preview)
        self.assertEqual(self.adapter.place_calls, 0)

    def test_deactivated_or_unentitled_account_rejected_on_confirm(self):
        for changes in ({"status": "DISABLED"}, {"markets": ["HK"]}):
            self.adapter.account_rows = [copy.deepcopy(ACCOUNT)]
            preview = self.preview()
            self.adapter.account_rows[0].update(changes)
            with self.subTest(changes=changes), self.assertRaisesRegex(PersonalError, "no longer active"):
                self.confirm(preview)
        self.assertEqual(self.adapter.place_calls, 0)

    def test_real_reads_allowed_but_orders_and_unlock_disabled(self):
        self.adapter.account_rows.append({**ACCOUNT, "id": "98765", "mode": "REAL"})
        self.service.connect(SESSION, {"account_id": "98765", "mode": "REAL"})
        self.assertEqual(self.service.snapshot(SESSION)["account"]["mode"], "REAL")
        for action in (lambda: self.preview(), lambda: self.service.unlock(SESSION, {"password": "secret"})):
            with self.assertRaisesRegex(PersonalError, "disabled"):
                action()
        self.assertEqual(self.adapter.place_calls, 0)

    def test_live_flag_is_rechecked_after_preview(self):
        self.adapter.account_rows.append({**ACCOUNT, "id": "98765", "mode": "REAL"})
        self.service.allow_live = True
        self.service.connect(SESSION, {"account_id": "98765", "mode": "REAL"})
        preview = self.preview()
        self.service.allow_live = False
        with self.assertRaisesRegex(PersonalError, "disabled"):
            self.confirm(preview)
        self.assertEqual(self.adapter.place_calls, 0)

    def test_cap_is_rechecked_after_preview(self):
        preview = self.preview()
        self.service.cap = Decimal("100")
        with self.assertRaisesRegex(PersonalError, "exceeds"):
            self.confirm(preview)
        self.assertEqual(self.adapter.place_calls, 0)

    def test_account_status_and_markets_required_at_connect(self):
        for changes in ({"status": "DISABLED"}, {"markets": ["HK"]}):
            self.adapter.account_rows = [{**ACCOUNT, **changes}]
            with self.subTest(changes=changes), self.assertRaises(PersonalError):
                self.connect()
        self.assertEqual(self.adapter.place_calls, 0)

    def test_ambiguous_result_persists_and_retries_never_resubmit(self):
        preview = self.preview()
        self.adapter.unknown = True
        result = self.confirm(preview)
        self.assertEqual(result["status"], "unknown")
        self.adapter.found = None
        self.assertEqual(self.confirm(preview), result)
        self.assertEqual(self.service.command(SESSION, result["id"]), result)
        with self.assertRaisesRegex(PersonalError, "unknown outcome"):
            self.preview()
        self.assertNotIn("secret", json.dumps(result))
        self.assertEqual(self.adapter.place_calls, 1)

    def test_lost_response_recovery_is_read_only_and_reconciles(self):
        preview = self.preview()
        self.assertEqual(self.service.preview_command(SESSION, preview["id"]), {"command": None})
        self.adapter.unknown = True
        self.confirm(preview)
        result = self.service.preview_command(SESSION, preview["id"])["command"]
        self.assertEqual(result["status"], "submitted")
        self.assertEqual(self.adapter.place_calls, 1)
        self.assertEqual(self.adapter.find_calls, 1)

    def test_restart_keeps_unknown_claim_and_prevents_resubmission(self):
        preview = self.preview()
        self.adapter.unknown = True
        result = self.confirm(preview)
        self.journal.close()
        self.journal = Journal(self.path)
        self.service = PersonalService(self.adapter, self.journal, clock=lambda: self.now)
        self.assertEqual(self.confirm(preview), result)
        self.assertEqual(self.adapter.place_calls, 1)

    def test_changed_broker_result_never_marks_order_submitted(self):
        preview = self.preview()
        self.adapter.unknown = True
        result = self.confirm(preview)
        self.adapter.found["quantity"] = "999"
        self.assertEqual(self.service.command(SESSION, result["id"])["status"], "unknown")

    def test_account_refresh_failure_cannot_rewrite_accepted_command(self):
        preview = self.preview()
        command = self.confirm(preview)
        self.adapter.accounts = Mock(side_effect=RuntimeError("network error"))
        self.assertEqual(self.confirm(preview), command)
        self.assertEqual(self.service.command(SESSION, command["id"]), command)
        self.assertEqual(self.journal.command(command["id"], SESSION)["status"], "submitted")
        self.assertEqual(self.adapter.place_calls, 1)

    def test_account_refresh_failure_cannot_release_unknown_command(self):
        preview = self.preview()
        self.adapter.unknown = True
        command = self.confirm(preview)
        self.adapter.accounts = Mock(side_effect=RuntimeError("network error"))
        with self.assertRaises(RuntimeError):
            self.service.command(SESSION, command["id"])
        self.assertEqual(self.confirm(preview), command)
        self.assertEqual(self.journal.command(command["id"], SESSION)["status"], "unknown")
        self.assertEqual(self.adapter.place_calls, 1)

    def test_long_only_and_missing_buying_power_fail_closed(self):
        self.adapter.available = "1"
        with self.assertRaisesRegex(PersonalError, "available shares"):
            self.preview({**INTENT, "side": "SELL"})
        self.adapter.available = None
        with self.assertRaisesRegex(PersonalError, "verified available shares"):
            self.preview({**INTENT, "side": "SELL"})
        self.adapter.power = None
        with self.assertRaisesRegex(PersonalError, "Buying power"):
            self.preview()
        self.assertEqual(self.adapter.place_calls, 0)

    def test_changed_available_shares_revalidated_at_confirmation(self):
        preview = self.preview({**INTENT, "side": "SELL"})
        self.adapter.available = "0"
        with self.assertRaisesRegex(PersonalError, "available shares"):
            self.confirm(preview)
        self.assertEqual(self.adapter.place_calls, 0)

    def test_invalid_order_shapes_never_reach_broker(self):
        for key, bad_values in {"symbol": ["US.AAPL", "AAPL;DROP", "aapl", "AAPL260101C100000", None],
                                "quantity": [2, "0", "01", "1.5", "1e3", "1000000", True],
                                "limit_price": [100, "1.001", "NaN", "Infinity", "-1", "0", "01.00", "1e2"],
                                "side": ["SHORT", "buy", None]}.items():
            for value in bad_values:
                with self.subTest(key=key, value=value), self.assertRaises(PersonalError):
                    self.preview({**INTENT, key: value})
        for payload in ({**INTENT, "order_type": "MARKET"}, {**INTENT, "quantity": "6"}):
            with self.assertRaises(PersonalError):
                self.preview(payload)
        self.assertEqual(self.adapter.snapshot_calls, 0)

    def test_boolean_confirmation_and_exact_shape_required(self):
        preview = self.preview()
        for value in (1, "true", False):
            with self.assertRaises(PersonalError):
                self.service.confirm(SESSION, {"preview_id": preview["id"], "confirmed": value})
        with self.assertRaises(PersonalError):
            self.service.confirm(SESSION, {"preview_id": preview["id"], "confirmed": True, "quantity": "100"})
        self.assertEqual(self.adapter.place_calls, 0)

    def test_two_database_connections_can_claim_only_once(self):
        preview = self.preview()
        other = Journal(self.path)
        try:
            with ThreadPoolExecutor(max_workers=2) as pool:
                results = list(pool.map(lambda pair: pair[0].claim(preview, SESSION, pair[1], "2026-09-05T12:00:00.000Z"),
                                        [(self.journal, "leo-a"), (other, "leo-b")]))
            self.assertEqual(sum(claimed for _, claimed in results), 1)
            self.assertEqual(results[0][0]["id"], results[1][0]["id"])
        finally:
            other.close()

    def test_discard_revokes_only_owned_preview_and_blocks_late_confirmation(self):
        first, second = self.preview(), self.preview()
        with self.assertRaises(PersonalError):
            self.service.discard_preview(OTHER, first["id"], {})
        self.assertEqual(self.service.discard_preview(SESSION, first["id"], {}), {"discarded": True, "command": None})
        with self.assertRaisesRegex(PersonalError, "connection changed"):
            self.confirm(first)
        self.assertEqual(self.confirm(second)["status"], "submitted")
        self.assertEqual(self.adapter.place_calls, 1)

    def test_discard_after_claim_retains_command_and_never_releases_unknown(self):
        preview = self.preview()
        self.adapter.unknown = True
        command = self.confirm(preview)
        self.assertEqual(self.service.discard_preview(SESSION, preview["id"], {}), {"discarded": False, "command": command})
        self.assertEqual(self.confirm(preview), command)
        self.assertEqual(self.adapter.place_calls, 1)

    def test_concurrent_discard_and_confirm_have_one_terminal_decision(self):
        preview = self.preview()
        gate = threading.Barrier(2)

        def confirm():
            gate.wait()
            try:
                return self.confirm(preview)
            except PersonalError as error:
                return {"error": error.code}

        def discard():
            gate.wait()
            return self.service.discard_preview(SESSION, preview["id"], {})

        with ThreadPoolExecutor(max_workers=2) as pool:
            confirm_future = pool.submit(confirm)
            discard_future = pool.submit(discard)
            confirmed, discarded = confirm_future.result(), discard_future.result()
        if discarded["discarded"]:
            self.assertEqual(confirmed["error"], "preview_revoked")
            self.assertEqual(self.adapter.place_calls, 0)
        else:
            self.assertEqual(discarded["command"], confirmed)
            self.assertEqual(self.adapter.place_calls, 1)


class AdapterTests(unittest.TestCase):
    def test_account_ids_do_not_lose_64bit_precision(self):
        self.assertEqual(account_id(281756456003951537), "281756456003951537")
        for invalid in (float(281756456003951537), True, "1e5", "-1", "0", str(2**64)):
            with self.subTest(value=invalid), self.assertRaises(PersonalError):
                account_id(invalid)

    def test_missing_account_status_or_markets_is_not_eligible(self):
        valid = {"acc_id": 123, "trd_env": "REAL", "acc_status": "ACTIVE", "trdmarket_auth": ["US"]}
        self.assertEqual(normalize_account(valid)["status"], "ACTIVE")
        for key in ("acc_id", "trd_env", "acc_status", "trdmarket_auth"):
            with self.subTest(key=key), self.assertRaises(PersonalError):
                normalize_account({name: value for name, value in valid.items() if name != key})

    def test_missing_and_nonfinite_amounts_stay_null(self):
        for value in (None, "N/A", "NaN", float("inf"), True):
            self.assertIsNone(number(value))
        self.assertEqual(number("0"), "0")

    def test_official_sdk_order_uses_exact_account_and_regular_hours(self):
        sdk_order = {"order_id": "broker-1", "code": "US.AAPL", "trd_side": "BUY", "order_status": "SUBMITTED", "qty": 2, "dealt_qty": 0, "price": 100.0}
        adapter = MoomooAdapter()
        adapter.sdk = SimpleNamespace(RET_OK=0)
        adapter.context = SimpleNamespace(place_order=Mock(return_value=(0, [sdk_order])))
        intent, _ = validate_intent(INTENT, Decimal("500"))
        result = adapter.place(ACCOUNT, intent, "leo-exact-order")
        kwargs = adapter.context.place_order.call_args.kwargs
        self.assertEqual(kwargs["acc_id"], 281756456003951537)
        self.assertEqual(kwargs["trd_env"], "SIMULATE")
        self.assertEqual(kwargs["order_type"], "NORMAL")
        self.assertEqual(kwargs["time_in_force"], "DAY")
        self.assertEqual(kwargs["session"], "RTH")
        self.assertEqual(kwargs["adjust_limit"], 0)
        self.assertFalse(kwargs["fill_outside_rth"])
        self.assertEqual(result["id"], "broker-1")

    def test_sdk_errors_do_not_expose_response_or_password(self):
        adapter = MoomooAdapter()
        adapter.sdk = SimpleNamespace(RET_OK=0)
        adapter.context = SimpleNamespace(get_acc_list=Mock(return_value=(-1, "password=super-secret")))
        with self.assertRaises(PersonalError) as error:
            adapter.accounts()
        self.assertNotIn("secret", str(error.exception))

    def test_native_us_account_currency_is_verified_not_silently_defaulted(self):
        adapter = MoomooAdapter()
        adapter.sdk = SimpleNamespace(RET_OK=0)
        funds = {"currency": "NONE", "cash": 500, "power": 1000, "total_assets": 500}
        adapter.context = SimpleNamespace(accinfo_query=Mock(return_value=(0, [funds])),
                                          position_list_query=Mock(return_value=(0, [])),
                                          order_list_query=Mock(return_value=(0, [])))
        snapshot = adapter.snapshot(ACCOUNT)
        self.assertEqual(snapshot["account"]["currency"], "USD")
        self.assertEqual(snapshot["account"]["currency_source"], "single_us_market_account")
        for account in ({**ACCOUNT, "markets": ["US", "HK"]}, {"id": ACCOUNT["id"], "mode": "SIMULATE"}):
            with self.assertRaises(PersonalError):
                adapter.snapshot(account)
        funds["currency"] = "HKD"
        with self.assertRaises(PersonalError):
            adapter.snapshot(ACCOUNT)

    def test_unlock_never_retains_sdk_reconnect_credentials(self):
        adapter = MoomooAdapter()
        adapter.sdk = SimpleNamespace(RET_OK=0)
        context = SimpleNamespace(_ctx_unlock=None)

        def unlock(**kwargs):
            context._ctx_unlock = (None, kwargs["password_md5"])
            return 0, None

        context.unlock_trade = Mock(side_effect=unlock)
        adapter.context = context
        adapter.unlock("test-secret")
        self.assertNotIn("password", context.unlock_trade.call_args.kwargs)
        self.assertEqual(len(context.unlock_trade.call_args.kwargs["password_md5"]), 32)
        self.assertIsNone(context._ctx_unlock)

    def test_unlock_failure_also_clears_reconnect_cache(self):
        adapter = MoomooAdapter()
        adapter.sdk = SimpleNamespace(RET_OK=0)
        adapter.context = SimpleNamespace(_ctx_unlock=("old-secret", None), unlock_trade=Mock(return_value=(-1, "secret")))
        with self.assertRaises(PersonalError):
            adapter.unlock("new-secret")
        self.assertIsNone(adapter.context._ctx_unlock)


class HttpTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.journal = Journal(Path(self.temp.name) / "orders.sqlite3")
        self.adapter = FakeAdapter()
        self.service = PersonalService(self.adapter, self.journal)
        self.server = Server(0, "t" * 48, self.service)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.journal.close()
        self.temp.cleanup()

    def request(self, method="GET", path="/status", body=None, overrides=None):
        conn = http.client.HTTPConnection("127.0.0.1", self.server.server_port)
        headers = {"Authorization": "Bearer " + "t" * 48, "X-Leo-Session": SESSION}
        if body is not None:
            headers["Content-Type"] = "application/json"
        headers.update(overrides or {})
        conn.request(method, path, body=body, headers=headers)
        response = conn.getresponse()
        result = response.status, json.loads(response.read())
        conn.close()
        return result

    def test_lazy_status_does_not_connect_or_place(self):
        self.adapter.connected = False
        status, body = self.request()
        self.assertEqual(status, 200)
        self.assertFalse(body["connected"])
        self.assertFalse(body["opend_reachable"])
        self.assertEqual(self.adapter.place_calls, 0)

    def test_bearer_origin_and_host_boundaries(self):
        for headers in ({"Authorization": "Bearer wrong"}, {"Origin": "https://evil.test"}, {"Host": "evil.test"}, {"X-Leo-Session": "short"}):
            with self.subTest(headers=headers):
                status, body = self.request(overrides=headers)
                self.assertEqual(status, 401)
                self.assertEqual(set(body), {"error", "message"})

    def test_duplicate_json_and_unknown_fields_fail_closed(self):
        for body in ('{"account_id":"123","account_id":"456","mode":"REAL"}', '{"account_id":NaN,"mode":"REAL"}', '[]'):
            with self.subTest(body=body):
                self.assertEqual(self.request("POST", "/connect", body)[0], 400)
        self.assertEqual(self.adapter.place_calls, 0)

    def test_only_known_routes_exposed(self):
        self.assertEqual(self.request("POST", "/v1/orders", "{}")[0], 404)
        self.assertEqual(self.request("GET", "/status?anything=1")[0], 404)
        self.assertEqual(self.adapter.place_calls, 0)


if __name__ == "__main__":
    unittest.main()

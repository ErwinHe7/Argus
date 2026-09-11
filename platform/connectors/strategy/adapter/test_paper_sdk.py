"""No broker connection: all execution and data calls use injected fake objects."""
import copy
import json
import unittest
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import patch

from paper_sdk import PaperAdapter, decimal, identity, no_duplicates, order, stamp

NOW = datetime(2026, 9, 8, 13, 36, tzinfo=timezone.utc)
ACCOUNT = "18446744073709551614"
CLIENT = "leo_" + "a" * 32


class Trade:
    def __init__(self):
        self.calls = []
        self.rows = []
        self.positions = []
        self.funds = {"currency": "USD", "cash": 10000, "total_assets": 10000}

    def get_acc_list(self):
        return 0, [{"acc_id": int(ACCOUNT), "trd_env": "SIMULATE", "acc_status": "ACTIVE", "trdmarket_auth": ["US"]},
                   {"acc_id": 88, "trd_env": "REAL", "acc_status": "ACTIVE", "trdmarket_auth": ["US"]}]

    def accinfo_query(self, **kwargs):
        self.calls.append(("funds", kwargs))
        return 0, [self.funds]

    def position_list_query(self, **kwargs):
        return 0, self.positions

    def order_list_query(self, **kwargs):
        return 0, self.rows

    def history_order_list_query(self, **kwargs):
        return 0, []

    def place_order(self, **kwargs):
        self.calls.append(("place", kwargs))
        return 0, [dict(order_id="9007199254740993", remark=kwargs["remark"], code=kwargs["code"], trd_side=kwargs["trd_side"], qty=kwargs["qty"], dealt_qty=0, dealt_avg_price=0, order_status="SUBMITTED")]

    def modify_order(self, **kwargs):
        self.calls.append(("cancel", kwargs))
        return 0, []


class Quotes:
    def __init__(self):
        self.metadata = {"code": "US.SPY", "stock_type": "STOCK", "delisting": False, "lot_size": 1}
    def get_stock_basicinfo(self, **kwargs):
        return 0, [self.metadata]


class AdapterTests(unittest.TestCase):
    def setUp(self):
        self.now = NOW
        self.trade, self.quotes = Trade(), Quotes()
        self.adapter = PaperAdapter(SimpleNamespace(RET_OK=0, ModifyOrderOp=SimpleNamespace(CANCEL="CANCEL")), self.trade, self.quotes, clock=lambda: self.now)
        self.adapter.market_open = lambda: True
        self.adapter.quote = lambda symbol: {"symbol": symbol, "bid": "100", "ask": "100.01", "observed_at": stamp(self.now), "market_open": True, "source": "fake"}
        self.request = {"operation": "place", "environment": "SIMULATE", "account_id": ACCOUNT, "entry_lease_deadline_ms": int(NOW.timestamp() * 1000) + 14000,
                        "intent": {"account_id": ACCOUNT, "client_id": CLIENT, "symbol": "SPY", "side": "BUY", "quantity": "2", "limit_price": "100.11", "order_type": "NORMAL"}}

    def test_real_and_unknown_operations_never_touch_sdk(self):
        for operation in ("place", "cancel", "snapshot"):
            with self.assertRaisesRegex(ValueError, "real_mode_prohibited"):
                self.adapter.dispatch({"operation": operation, "environment": "REAL", "account_id": "88"})
        for operation in ("unlock_trade", "transfer", "withdraw", "live", "set_password"):
            with self.assertRaisesRegex(ValueError, "unsupported_operation"):
                self.adapter.dispatch({"operation": operation})
        self.assertEqual(self.trade.calls, [])

    def test_uint64_account_identity_and_exact_paper_order_arguments(self):
        result = self.adapter.dispatch(self.request)
        self.assertEqual(result["id"], "9007199254740993")
        kind, args = self.trade.calls[-1]
        self.assertEqual(kind, "place")
        self.assertEqual(args["acc_id"], int(ACCOUNT))
        self.assertEqual((args["trd_env"], args["session"], args["time_in_force"], args["order_type"]), ("SIMULATE", "RTH", "DAY", "NORMAL"))
        self.assertTrue(self.adapter.submission_attempted)

    def test_failed_preflight_never_claims_egress(self):
        self.request["entry_lease_deadline_ms"] = int(NOW.timestamp() * 1000) - 1
        with self.assertRaisesRegex(ValueError, "entry_lease_expired"):
            self.adapter.dispatch(self.request)
        self.assertFalse(self.adapter.submission_attempted)
        self.assertFalse(any(kind == "place" for kind, _ in self.trade.calls))

    def test_lease_expiring_during_snapshot_blocks_final_egress(self):
        original = self.trade.accinfo_query
        def slow(**kwargs):
            result = original(**kwargs)
            self.now += timedelta(seconds=16)
            return result
        self.trade.accinfo_query = slow
        with self.assertRaisesRegex(ValueError, "quote_expired|entry_lease"):
            self.adapter.dispatch(self.request)
        self.assertFalse(self.adapter.submission_attempted)

    def test_existing_manual_position_and_short_sell_rejected(self):
        self.trade.positions = [{"code": "US.SPY", "qty": 1, "can_sell_qty": 1, "market_val": 100}]
        with self.assertRaisesRegex(ValueError, "existing_broker_symbol"):
            self.adapter.dispatch(self.request)
        self.request["intent"].update(side="SELL", order_type="MARKET", limit_price=None)
        with self.assertRaisesRegex(ValueError, "unintended_short"):
            self.adapter.dispatch(self.request)

    def test_warrants_options_delisted_and_unknown_metadata_rejected(self):
        for kind in ("WARRANT", "DRVT", "OPTION", "FUTURE", "UNKNOWN", "BOND"):
            self.quotes.metadata["stock_type"] = kind
            with self.assertRaisesRegex(ValueError, "listed_us_equity"):
                self.adapter.instrument("SPY")
        self.quotes.metadata.update(stock_type="STOCK", delisting=True)
        with self.assertRaisesRegex(ValueError, "listed_us_equity"):
            self.adapter.instrument("SPY")

    def test_paper_cannot_submit_native_stop_or_oco(self):
        for kind in ("STOP", "STOP_LIMIT", "OCO", "TRAILING_STOP", "MARKET"):
            self.request["intent"]["order_type"] = kind
            with self.assertRaisesRegex(ValueError, "paper_order_type"):
                self.adapter.dispatch(self.request)

    def test_wide_spread_blocks_entry_but_does_not_disable_risk_reduction(self):
        self.adapter.quote = lambda symbol: {"symbol": symbol, "bid": "99", "ask": "101", "observed_at": stamp(self.now), "market_open": True, "source": "fake"}
        with self.assertRaisesRegex(ValueError, "spread_exceeds"):
            self.adapter.dispatch(self.request)
        self.request["intent"].update(side="SELL", order_type="MARKET", limit_price=None)
        self.trade.positions = [{"code": "US.SPY", "qty": 2, "can_sell_qty": 2, "market_val": 198}]
        self.adapter.dispatch(self.request)
        self.assertEqual(self.trade.calls[-1][0], "place")

    def test_cancel_request_does_not_fake_terminal_ack(self):
        self.trade.rows = [{"order_id": "10", "remark": CLIENT, "code": "US.SPY", "trd_side": "BUY", "qty": 2, "dealt_qty": 1, "dealt_avg_price": 99, "order_status": "FILLED_PART"}]
        result = self.adapter.dispatch({"operation": "cancel", "environment": "SIMULATE", "account_id": ACCOUNT, "order_id": "10"})
        self.assertEqual(result, {"cancel_requested": True, "terminal": False})
        self.assertEqual(self.trade.rows[0]["dealt_qty"], 1)
        self.assertEqual(self.trade.calls[-1][1]["trd_env"], "SIMULATE")

    def test_missing_balances_are_unavailable_not_zero(self):
        self.trade.funds.pop("cash")
        with self.assertRaisesRegex(ValueError, "required_amount"):
            self.adapter.snapshot(self.request)

    def test_order_cumulative_average_required_for_any_fill(self):
        with self.assertRaisesRegex(ValueError, "missing_average"):
            order({"order_id": "1", "code": "US.SPY", "qty": 1, "dealt_qty": 1, "order_status": "FILLED_ALL"})

    def test_identity_and_duplicate_json_rejected(self):
        for value in (True, 123.0, "-1", "0", str(2**64)):
            with self.assertRaises(ValueError):
                identity(value)
        with self.assertRaisesRegex(ValueError, "duplicate_json_key"):
            json.loads('{"environment":"SIMULATE","environment":"REAL"}', object_pairs_hook=no_duplicates)

    def test_current_history_receipt_is_truthful_and_missing_latest_fails(self):
        import exchange_calendars
        calendar = exchange_calendars.get_calendar("XNYS")
        self.adapter.calendar = calendar
        self.adapter.sdk.KLType = SimpleNamespace(K_DAY="K_DAY")
        self.adapter.sdk.AuType = SimpleNamespace(QFQ="QFQ")
        sessions = calendar.sessions_in_range("2025-06-01", "2026-09-04")
        rows = [{"time_key": str(s.date()), "open": 100, "high": 101, "low": 99, "close": 100, "volume": 10000} for s in sessions]
        self.quotes.request_history_kline = lambda *args, **kwargs: (0, rows, None)
        result = self.adapter.history("SPY")
        self.assertEqual(result["history_mode"], "current_observed_snapshot")
        self.assertFalse(result["evidence"]["availability_verified"])
        self.assertEqual(result["bars"][-1]["available_at"], stamp(NOW))
        self.assertEqual(result["bars"][-1]["session_date"], "2026-09-04")
        self.assertEqual(str(calendar.next_session("2026-09-04").date()), "2026-09-08")
        self.adapter.histories.clear()
        rows.pop()
        with self.assertRaisesRegex(ValueError, "latest_completed"):
            self.adapter.history("SPY")


if __name__ == "__main__":
    unittest.main()

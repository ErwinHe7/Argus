"""Offline callback fixtures, not broker-backed acceptance or profitability evidence."""
import copy
import io
import json
import threading
import unittest
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from types import SimpleNamespace as NS

from ibkr_sdk import BLOCKED, IBKRAdapter, IbkrError, TwsEvents, TwsSession, amount, serve

NOW = datetime(2026, 9, 8, 13, 36, tzinfo=timezone.utc)
ACCOUNT = "DU1234567"


def stock(symbol="SPY", con_id=756733):
    return NS(symbol=symbol, secType="STK", currency="USD", conId=con_id, primaryExchange="ARCA")


def order(account=ACCOUNT, permanent=101):
    return NS(account=account, permId=permanent, orderId=3, clientId=9, orderRef="leo_" + "a" * 32,
              totalQuantity=Decimal("2"), filledQuantity=Decimal("0"), action="BUY")


class FakeWrapper:
    pass


class FakeClient:
    def __init__(self, wrapper):
        self.wrapper = wrapper
        self.calls = []
        self.connected = False
        self.omit = None
        self.names = [ACCOUNT, "DU2222", "U9999"]
        self.opened, self.completed, self.fills = [], [], []
        self.base = "USD"
        self.ticks = (int(NOW.timestamp()), 100.0, 100.01, Decimal("10"), Decimal("9"), NS(bidPastLow=False, askPastHigh=False))
        self.histories = []
        self.details = [NS(contract=stock(), validExchanges="SMART,ARCA")]

    def connect(self, host, port, client):
        self.calls.append(("connect", host, port, client))
        self.connected = True
        self.wrapper.nextValidId(100)

    def run(self):
        pass

    def isConnected(self):
        return self.connected

    def disconnect(self):
        self.connected = False

    def reqManagedAccts(self):
        self.calls.append(("accounts",))
        if self.omit != "accounts":
            self.wrapper.managedAccounts(",".join(self.names))

    def reqAccountUpdates(self, subscribe, account):
        self.calls.append(("account", subscribe, account))
        if not subscribe:
            return
        self.wrapper.updateAccountValue("Currency", self.base, "BASE", account)
        self.wrapper.updateAccountValue("TotalCashValue", "10000.01", "USD", account)
        self.wrapper.updateAccountValue("NetLiquidation", "10200.01", "USD", account)
        self.wrapper.updatePortfolio(stock(), Decimal("2"), 100, 200, 99, 2, 0, account)
        # An unsolicited other-account callback must never be included.
        self.wrapper.updateAccountValue("TotalCashValue", "999999", "USD", "DU2222")
        self.wrapper.accountDownloadEnd("DU2222")
        if self.omit != "account":
            self.wrapper.accountDownloadEnd(account)

    def reqAllOpenOrders(self):
        self.calls.append(("all_open_orders",))
        for contract, opened, state in self.opened:
            # IBKR is asynchronous; status can precede openOrder.
            self.wrapper.orderStatus(opened.orderId, state.status, Decimal("1"), Decimal("1"), 100.005,
                                     opened.permId, 0, 100.005, opened.clientId, "")
            self.wrapper.openOrder(opened.orderId, contract, opened, state)
        if self.omit != "open_orders":
            self.wrapper.openOrderEnd()

    def reqCompletedOrders(self, api_only):
        self.calls.append(("completed_orders", api_only))
        for row in self.completed:
            self.wrapper.completedOrder(*row)
        if self.omit != "completed_orders":
            self.wrapper.completedOrdersEnd()

    def reqExecutions(self, req, query):
        self.calls.append(("executions", query.acctCode))
        for contract, execution in self.fills:
            self.wrapper.execDetails(req, contract, execution)
        if self.omit != "executions":
            self.wrapper.execDetailsEnd(req)

    def reqContractDetails(self, req, query):
        self.calls.append(("contract", query.symbol))
        for detail in self.details:
            self.wrapper.contractDetails(req, detail)
        if self.omit != "contract":
            self.wrapper.contractDetailsEnd(req)

    def reqTickByTickData(self, req, contract, kind, number, ignore_size):
        self.calls.append(("tick", kind, number, ignore_size))
        if self.omit != "quote":
            self.wrapper.tickByTickBidAsk(req, *self.ticks)

    def reqHistoricalData(self, req, *args):
        self.calls.append(("history", args))
        for bar in self.histories:
            self.wrapper.historicalData(req, bar)
        if self.omit != "history":
            self.wrapper.historicalDataEnd(req, "", "")

    def placeOrder(self, *args):
        raise AssertionError("No test may submit an order")

    def cancelOrder(self, *args):
        raise AssertionError("No test may cancel an order")


def fake_session():
    modules = NS(client=NS(EClient=FakeClient), wrapper=NS(EWrapper=FakeWrapper),
                 contract=NS(Contract=NS), execution=NS(ExecutionFilter=NS))
    session = TwsSession(timeout=.01, modules=modules)
    session.connect()
    return session


class FakeCalendar:
    """Synthetic weekdays calendar, deliberately not market acceptance evidence."""

    @staticmethod
    def day(value):
        return value.date() if isinstance(value, datetime) else datetime.fromisoformat(str(value)).date()

    def is_session(self, value):
        return self.day(value).weekday() < 5

    def sessions_in_range(self, begin, end):
        value, last = self.day(begin), self.day(end)
        rows = []
        while value <= last:
            if value.weekday() < 5:
                rows.append(datetime.combine(value, datetime.min.time(), timezone.utc))
            value += timedelta(days=1)
        return rows

    def session_open(self, value):
        day = self.day(value)
        return NS(to_pydatetime=lambda: datetime(day.year, day.month, day.day, 13, 30, tzinfo=timezone.utc))

    def session_close(self, value):
        day = self.day(value)
        return NS(to_pydatetime=lambda: datetime(day.year, day.month, day.day, 20, tzinfo=timezone.utc))


def execution(number="1.1", account=ACCOUNT, cumulative="1", average=100.005):
    return NS(acctNumber=account, permId=101, execId=number, cumQty=Decimal(cumulative), avgPrice=average,
              isPriceRevisionPending=False)


class InspectorTests(unittest.TestCase):
    def setUp(self):
        self.session = fake_session()
        self.adapter = IBKRAdapter(self.session, clock=lambda: NOW, calendar=FakeCalendar())
        self.request = {"operation": "inspect", "account_id": "IBKR:" + ACCOUNT}

    def test_no_executable_account_and_separate_blockers(self):
        self.assertEqual(self.adapter.dispatch({"operation": "accounts"}), [])
        result = self.adapter.dispatch({"operation": "readiness"})
        self.assertEqual([r["accountId"] for r in result["candidateAccounts"]], ["IBKR:" + ACCOUNT, "IBKR:DU2222"])
        self.assertFalse(result["paperEnvironmentAttested"])
        self.assertFalse(result["executionAuthorized"])
        self.assertIn(BLOCKED, result["blockers"])
        self.assertIn("ibkr_commercial_integration_approval_required", result["blockers"])
        self.assertTrue(all(r["environment"] == "UNVERIFIED" for r in result["candidateAccounts"]))

    def test_all_execution_operations_refused_before_connect(self):
        adapter = IBKRAdapter(NS(accounts=lambda: self.fail("must not connect")))
        for operation in ("place", "cancel", "market", "snapshot"):
            with self.assertRaisesRegex(IbkrError, BLOCKED):
                adapter.dispatch({"operation": operation, "environment": "SIMULATE", "account_id": "IBKR:" + ACCOUNT})
        self.assertFalse(adapter.submission_attempted)

    def test_read_account_membership_and_live_accounts_refused(self):
        for account in ("IBKR:U9999", "IBKR:DU9999", ACCOUNT, "MOOMOO:123", "IBKR:DU1/../U9999"):
            with self.assertRaises(IbkrError):
                self.adapter.inspect({"account_id": account})
        self.assertFalse(any(c[0] == "account" for c in self.session.api.calls))

    def test_decimal_balances_and_owner_isolation(self):
        own, foreign = order(), order("DU2222", 202)
        self.session.api.opened = [(stock(), foreign, NS(status="Submitted")), (stock(), own, NS(status="Submitted"))]
        self.session.api.fills = [(stock(), execution(account="DU2222", average=999)), (stock(), execution())]
        result = self.adapter.inspect(self.request)
        self.assertEqual(result["cash"], "10000.01")
        self.assertEqual(result["equity"], "10200.01")
        self.assertEqual(result["environment"], "UNVERIFIED")
        self.assertIsNone(result["positions"][0]["available_quantity"])
        self.assertEqual(len(result["orders"]), 1)
        self.assertEqual(result["orders"][0]["filled_quantity"], "1")
        self.assertEqual(result["orders"][0]["average_fill_price"], "100.005")
        self.assertEqual(result["orders"][0]["id"], "IBKR:DU1234567:101")
        self.assertFalse(result["history_complete"])
        self.assertIn(("account", False, ACCOUNT), self.session.api.calls)

    def test_missing_each_end_callback_fails_closed_and_disconnects(self):
        for missing in ("accounts", "account", "open_orders", "completed_orders", "executions"):
            with self.subTest(missing=missing):
                session = fake_session()
                session.api.omit = missing
                adapter = IBKRAdapter(session, clock=lambda: NOW)
                with self.assertRaisesRegex(IbkrError, "end_callback_timeout"):
                    adapter.inspect(self.request)
                self.assertFalse(session.api.isConnected())
                with self.assertRaisesRegex(IbkrError, "reconnect_required"):
                    adapter.inspect(self.request)

    def test_unset_values_and_non_usd_fail(self):
        with self.assertRaises(IbkrError):
            amount(1.7976931348623157e308)
        self.assertIsNone(amount(1.7976931348623157e308, optional=True))
        self.session.api.base = "EUR"
        with self.assertRaisesRegex(IbkrError, "base_currency"):
            self.adapter.inspect(self.request)

    def test_correction_rejected_duplicate_execution_accepted(self):
        own = order()
        self.session.api.opened = [(stock(), own, NS(status="Submitted"))]
        item = execution()
        self.session.api.fills = [(stock(), item), (stock(), copy.deepcopy(item))]
        self.assertEqual(self.adapter.inspect(self.request)["orders"][0]["filled_quantity"], "1")
        self.session.api.fills.append((stock(), execution("1.2")))
        with self.assertRaisesRegex(IbkrError, "correction_unresolved"):
            self.adapter.inspect(self.request)

    def test_missing_fill_information_remains_null(self):
        own = order()
        own.filledQuantity = 1.7976931348623157e308
        self.session.api.completed = [(stock(), own, NS(status="Filled"))]
        result = self.adapter.inspect(self.request)["orders"][0]
        self.assertIsNone(result["filled_quantity"])
        self.assertIsNone(result["average_fill_price"])

    def test_bidask_timestamp_and_single_subscription(self):
        quote = self.adapter.quote("SPY")
        self.assertEqual(quote["observed_at"], "2026-09-08T13:36:00Z")
        self.assertTrue(quote["market_open"])
        self.adapter.quote("SPY")
        self.assertEqual(len([c for c in self.session.api.calls if c[0] == "tick"]), 1)

    def test_stale_future_crossed_empty_and_flagged_quotes_rejected(self):
        cases = [(-6, 100, 101, 1, 1, False, False), (1, 100, 101, 1, 1, False, False),
                 (0, 102, 101, 1, 1, False, False), (0, 100, 101, 0, 1, False, False),
                 (0, 100, 101, 1, 1, True, False)]
        for offset, bid, ask, bs, az, low, high in cases:
            session = fake_session()
            session.api.ticks = (int(NOW.timestamp()) + offset, bid, ask, bs, az, NS(bidPastLow=low, askPastHigh=high))
            with self.assertRaises(IbkrError):
                IBKRAdapter(session, clock=lambda: NOW, calendar=FakeCalendar()).quote("SPY")

    def test_ambiguous_and_non_us_contract_rejected(self):
        self.session.api.details.append(copy.deepcopy(self.session.api.details[0]))
        with self.assertRaisesRegex(IbkrError, "ambiguous"):
            self.adapter.quote("SPY")
        self.session.api.details.pop()
        self.session.api.details[0].contract.primaryExchange = "LSE"
        with self.assertRaisesRegex(IbkrError, "listed_us"):
            self.adapter.quote("SPY")

    def test_history_warmup_completed_and_coverage(self):
        calendar = FakeCalendar()
        dates = calendar.sessions_in_range("2025-07-01", "2026-09-08")
        self.session.api.histories = [NS(date=d.strftime("%Y%m%d"), open=100, high=101, low=99, close=100, volume=1000) for d in dates]
        result = self.adapter.history("SPY")
        self.assertEqual(result["bars"][-1]["session_date"], "2026-09-07")
        self.assertEqual(len(result["bars"]), 280)
        self.assertFalse(result["evidence"]["availability_verified"])
        self.assertEqual(result["evidence"]["classification"], "observed")
        self.adapter.histories.clear()
        self.session.api.histories.pop(-10)
        with self.assertRaisesRegex(IbkrError, "session_gap"):
            self.adapter.history("SPY")

    def test_history_outage_preserves_quote_but_not_evaluation(self):
        result = self.adapter.inspect_market({**self.request, "symbol": "SPY"})
        self.assertIsNotNone(result["quote"])
        self.assertIsNone(result["evaluation"])
        self.assertFalse(result["execution_authorized"])

    def test_ndjson_redacts_provider_errors_and_rejects_duplicate_fields(self):
        adapter = IBKRAdapter(NS(accounts=lambda: (_ for _ in ()).throw(RuntimeError("secret session credential"))))
        data = io.BytesIO(b'{"operation":"readiness"}\n{"operation":"accounts","operation":"place"}\n{"operation":"place"}\n')
        out = io.StringIO()
        serve(adapter, data, out)
        self.assertNotIn("secret", out.getvalue())
        responses = [json.loads(s) for s in out.getvalue().splitlines()]
        self.assertEqual(len(responses), 3)
        self.assertEqual(responses[-1]["error"], BLOCKED)
        self.assertTrue(all(r["submission_attempted"] is False for r in responses))


class CallbackTests(unittest.TestCase):
    def test_late_unscoped_end_cannot_complete_new_request(self):
        events = TwsEvents()
        events.begin("open_orders")
        with self.assertRaisesRegex(IbkrError, "timeout"):
            events.wait("open_orders", .001)
        events.openOrderEnd()
        with self.assertRaisesRegex(IbkrError, "reconnect_required"):
            events.begin("open_orders")

    def test_real_async_end_and_reqid_isolation(self):
        events = TwsEvents()
        events.begin(100)
        events.historicalData(101, NS(close=999))
        worker = threading.Thread(target=lambda: (events.historicalData(100, NS(close=10)), events.historicalDataEnd(100, "", "")))
        worker.start()
        rows = events.wait(100, .1)
        worker.join()
        self.assertEqual([r.close for r in rows], [10])

    def test_delayed_market_type_and_connectivity_errors_fail_closed(self):
        events = TwsEvents()
        events.begin(100)
        events.marketDataType(100, 3)
        with self.assertRaisesRegex(IbkrError, "unavailable"):
            events.wait(100, .01)
        events.error(-1, 0, 1100, "connection lost")
        self.assertTrue(events.failed)

    def test_default_paper_ports_never_prove_paper_identity(self):
        for port in (7496, 4001, 443):
            with self.assertRaises(IbkrError):
                TwsSession(port=port)
        with self.assertRaises(IbkrError):
            TwsSession(client_id=0)


if __name__ == "__main__":
    unittest.main()

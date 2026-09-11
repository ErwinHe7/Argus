"""Local IBKR TWS inspector. No order submission, modification, or cancellation.

The official ibapi package is installed separately by its licensed user. A DU
identifier or configurable paper port is not an authenticated environment flag;
therefore this adapter intentionally exposes no executable SIMULATE accounts.
"""
from __future__ import annotations

import argparse
import contextlib
import copy
import hashlib
import importlib
import json
import os
import re
import sys
import threading
import time
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from types import SimpleNamespace

from paper_sdk import MAX_INPUT, SYMBOL, ET, decimal, no_duplicates, stamp, utc

CANDIDATE = re.compile(r"^IBKR:(DU[0-9]{1,20})$")
BLOCKED = "ibkr_paper_environment_not_attested"
US_EXCHANGES = {"NYSE", "NASDAQ", "ISLAND", "ARCA", "AMEX", "BATS", "IEX", "EDGEA", "EDGX"}
INFO_CODES = {2104, 2106, 2107, 2108, 2158}


class IbkrError(ValueError):
    """Only fixed, non-provider diagnostic codes may cross the stdio boundary."""


class TwsEvents:
    """Bounded, single-reader callback collector shared with fake-ibapi tests."""

    def __init__(self):
        self.cv = threading.Condition()
        self.pending = {}
        self.ready = False
        self.failed = False
        self.account_names = ()
        self.statuses = {}
        self.next_request = 1000

    def begin(self, key):
        with self.cv:
            if self.failed or key in self.pending:
                raise IbkrError("ibkr_session_reconnect_required")
            self.pending[key] = {"rows": [], "done": False, "error": False}

    def add(self, key, value, *, end=False, replace=False):
        with self.cv:
            slot = self.pending.get(key)
            if slot is not None and not slot["done"]:
                if value is not None:
                    if replace:
                        slot["rows"] = [copy.deepcopy(value)]
                    elif len(slot["rows"]) < 5000:
                        slot["rows"].append(copy.deepcopy(value))
                    else:
                        slot["error"] = True
                slot["done"] = end
                self.cv.notify_all()

    def request_id(self):
        with self.cv:
            self.next_request += 1
            return self.next_request

    def wait(self, key, timeout, *, stream=False):
        deadline = time.monotonic() + timeout
        with self.cv:
            while True:
                slot = self.pending[key]
                if self.failed or slot["error"]:
                    raise IbkrError("ibkr_request_unavailable")
                if slot["done"] or (stream and slot["rows"]):
                    result = copy.deepcopy(slot["rows"])
                    if not stream:
                        del self.pending[key]
                    return result
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    # Unscoped end events (accounts/open/completed orders) must
                    # never finish a later request after a timeout. Reconnect.
                    self.failed = True
                    raise IbkrError("ibkr_end_callback_timeout")
                self.cv.wait(remaining)

    def nextValidId(self, orderId):
        with self.cv:
            self.ready = True
            self.cv.notify_all()

    def managedAccounts(self, accountsList):
        names = tuple(x.strip() for x in accountsList.split(",") if x.strip())
        with self.cv:
            self.account_names = names
        self.add("accounts", names, end=True)

    def connectionClosed(self):
        with self.cv:
            self.failed = True
            self.cv.notify_all()

    def error(self, reqId, *args):
        # 10.33 added errorTime before errorCode; older supported APIs omit it.
        code = args[1] if len(args) >= 3 and isinstance(args[1], int) else args[0] if args else None
        if code in INFO_CODES:
            return
        with self.cv:
            if reqId in self.pending:
                self.pending[reqId]["error"] = True
            else:
                self.failed = True
            self.cv.notify_all()

    def updateAccountValue(self, key, val, currency, accountName):
        self.add(("account", accountName), ("value", key, val, currency))

    def updatePortfolio(self, contract, position, marketPrice, marketValue,
                        averageCost, unrealizedPNL, realizedPNL, accountName):
        self.add(("account", accountName), ("position", contract, position, marketValue))

    def accountDownloadEnd(self, accountName):
        self.add(("account", accountName), None, end=True)

    def openOrder(self, orderId, contract, order, orderState):
        self.add("open_orders", (contract, order, orderState))

    def openOrderEnd(self):
        self.add("open_orders", None, end=True)

    def completedOrder(self, contract, order, orderState):
        self.add("completed_orders", (contract, order, orderState))

    def completedOrdersEnd(self):
        self.add("completed_orders", None, end=True)

    def orderStatus(self, orderId, status, filled, remaining, avgFillPrice,
                    permId, parentId, lastFillPrice, clientId, whyHeld, mktCapPrice=0):
        # permId identifies an order across client IDs; orderId alone is unsafe.
        if permId <= 0:
            return
        with self.cv:
            if len(self.statuses) >= 5000 and permId not in self.statuses:
                self.failed = True
            else:
                self.statuses[permId] = (status, filled, avgFillPrice)
            self.cv.notify_all()

    def execDetails(self, reqId, contract, execution):
        self.add(reqId, (contract, execution))

    def execDetailsEnd(self, reqId):
        self.add(reqId, None, end=True)

    def contractDetails(self, reqId, contractDetails):
        self.add(reqId, contractDetails)

    def contractDetailsEnd(self, reqId):
        self.add(reqId, None, end=True)

    def historicalData(self, reqId, bar):
        self.add(reqId, bar)

    def historicalDataEnd(self, reqId, start, end):
        self.add(reqId, None, end=True)

    def marketDataType(self, reqId, marketDataType):
        if marketDataType != 1:
            self.error(reqId, 0, 10167, "")

    def tickByTickBidAsk(self, reqId, tickTime, bidPrice, askPrice, bidSize, askSize, attributes):
        self.add(reqId, (tickTime, bidPrice, askPrice, bidSize, askSize,
                         bool(attributes.bidPastLow), bool(attributes.askPastHigh)), replace=True)


class TwsSession:
    """Official EClient transport with an explicit read-only method allowlist."""

    def __init__(self, port=7497, client_id=73, timeout=5, modules=None):
        if port not in (7497, 4002) or isinstance(client_id, bool) or not 1 <= client_id <= 2**31 - 1:
            raise IbkrError("ibkr_inspector_connection_settings_invalid")
        self.port, self.client_id, self.timeout = port, client_id, timeout
        self.modules = modules
        self.events = None
        self.api = None
        self.contracts = {}
        self.subscriptions = {}

    def connect(self):
        if self.api is not None:
            if self.events.failed or not self.api.isConnected():
                raise IbkrError("ibkr_session_reconnect_required")
            return
        try:
            modules = self.modules or SimpleNamespace(
                client=importlib.import_module("ibapi.client"), wrapper=importlib.import_module("ibapi.wrapper"),
                contract=importlib.import_module("ibapi.contract"), execution=importlib.import_module("ibapi.execution"))
        except ImportError:
            raise IbkrError("ibkr_official_sdk_not_installed") from None
        self.modules = modules

        class App(TwsEvents, modules.wrapper.EWrapper, modules.client.EClient):
            def __init__(self):
                modules.wrapper.EWrapper.__init__(self)
                modules.client.EClient.__init__(self, self)
                TwsEvents.__init__(self)

        self.api = self.events = App()
        self.api.connect("127.0.0.1", self.port, self.client_id)
        threading.Thread(target=self.api.run, daemon=True, name="leo-ibkr-inspector").start()
        deadline = time.monotonic() + self.timeout
        with self.events.cv:
            while not self.events.ready and not self.events.failed:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    self.events.failed = True
                    break
                self.events.cv.wait(remaining)
        if self.events.failed:
            self.close()
            raise IbkrError("ibkr_handshake_timeout")

    def collect(self, key, send):
        self.connect()
        self.events.begin(key)
        try:
            send()
            return self.events.wait(key, self.timeout)
        except Exception:
            self.close()
            raise

    def accounts(self):
        self.connect()
        result = self.collect("accounts", self.api.reqManagedAccts)
        names = list(result[0]) if len(result) == 1 else []
        if not names or len(names) != len(set(names)):
            raise IbkrError("ibkr_managed_accounts_invalid")
        return names

    def account_rows(self, account):
        key = ("account", account)
        try:
            return self.collect(key, lambda: self.api.reqAccountUpdates(True, account))
        finally:
            if self.api is not None and self.api.isConnected():
                self.api.reqAccountUpdates(False, account)

    def order_rows(self):
        # Never reqOpenOrders/client 0: binding can cancel and resubmit orders.
        self.connect()
        with self.events.cv:
            self.events.statuses.clear()
        opened = self.collect("open_orders", self.api.reqAllOpenOrders)
        completed = self.collect("completed_orders", lambda: self.api.reqCompletedOrders(False))
        with self.events.cv:
            statuses = copy.deepcopy(self.events.statuses)
        return completed, opened, statuses

    def executions(self, account):
        self.connect()
        query = self.modules.execution.ExecutionFilter()
        query.acctCode = account
        key = self.events.request_id()
        return self.collect(key, lambda: self.api.reqExecutions(key, query))

    def instrument(self, symbol):
        if not isinstance(symbol, str) or not SYMBOL.fullmatch(symbol):
            raise IbkrError("ibkr_invalid_symbol")
        self.connect()
        if symbol not in self.contracts:
            query = self.modules.contract.Contract()
            query.symbol, query.secType, query.currency, query.exchange = symbol, "STK", "USD", "SMART"
            key = self.events.request_id()
            rows = self.collect(key, lambda: self.api.reqContractDetails(key, query))
            if len(rows) != 1:
                raise IbkrError("ibkr_instrument_ambiguous")
            contract = rows[0].contract
            if (contract.secType != "STK" or contract.currency != "USD" or contract.symbol != symbol
                    or contract.conId <= 0 or contract.primaryExchange not in US_EXCHANGES
                    or "SMART" not in rows[0].validExchanges.split(",")):
                raise IbkrError("ibkr_listed_us_equity_required")
            self.contracts[symbol] = contract
        return self.contracts[symbol]

    def quote_row(self, symbol):
        contract = self.instrument(symbol)
        if symbol not in self.subscriptions:
            key = self.events.request_id()
            self.events.begin(key)
            self.subscriptions[symbol] = key
            # BidAsk tick-by-tick is real-time only; never request delayed/frozen
            # data and never convert a local receive timestamp into exchange time.
            self.api.reqTickByTickData(key, contract, "BidAsk", 0, False)
        return self.events.wait(self.subscriptions[symbol], self.timeout, stream=True)[-1]

    def history_rows(self, symbol):
        contract = self.instrument(symbol)
        key = self.events.request_id()
        return self.collect(key, lambda: self.api.reqHistoricalData(
            key, contract, "", "2 Y", "1 day", "ADJUSTED_LAST", 1, 1, False, []))

    def close(self):
        if self.events is not None:
            self.events.connectionClosed()
        if self.api is not None:
            self.api.disconnect()


def amount(value, *, optional=False):
    result = decimal(value, optional=optional)
    # IBKR's UNSET_DOUBLE is finite, unlike NaN. It is not a price or quantity.
    if result is not None and abs(Decimal(result)) >= Decimal("1e100"):
        if optional:
            return None
        raise IbkrError("ibkr_amount_unavailable")
    return result


class IBKRAdapter:
    def __init__(self, session=None, clock=utc, calendar=None, port=7497, client_id=73):
        self.session = session or TwsSession(port=port, client_id=client_id)
        self.clock, self.calendar = clock, calendar
        self.submission_attempted = False
        self.histories = {}

    def accounts(self):
        # Only execution-compatible accounts belong to this existing protocol.
        return []

    def readiness(self):
        names = self.session.accounts()
        return {"broker": "IBKR", "connected": True, "capability": "read_only",
                "executionAuthorized": False, "paperEnvironmentAttested": False,
                "executableAccounts": [], "candidateAccounts": [
                    {"accountId": "IBKR:" + name, "environment": "UNVERIFIED", "paperCandidate": True}
                    for name in names if re.fullmatch(r"DU[0-9]{1,20}", name)],
                "blockers": [BLOCKED, "ibkr_commercial_integration_approval_required"],
                "observedAt": stamp(self.clock())}

    def account(self, request):
        match = CANDIDATE.fullmatch(str(request.get("account_id", "")))
        if not match:
            raise IbkrError("ibkr_candidate_account_required")
        name = match.group(1)
        if name not in self.session.accounts():
            raise IbkrError("ibkr_account_not_in_authenticated_session")
        return name

    def inspect(self, request):
        account = self.account(request)
        started = self.clock()
        rows = self.session.account_rows(account)
        values, positions = {}, {}
        for row in rows:
            if row[0] == "value":
                _, key, value, currency = row
                values[key, currency] = value
            else:
                _, contract, quantity, market_value = row
                if contract.secType != "STK" or contract.currency != "USD" or not SYMBOL.fullmatch(contract.symbol):
                    raise IbkrError("ibkr_unsupported_portfolio_instrument")
                positions[contract.conId] = {"symbol": contract.symbol, "quantity": amount(quantity),
                                            "available_quantity": None, "market_value": amount(market_value)}
        # A USD component is not a complete USD-base account. Require its base
        # currency and preserve unknown values rather than display a zero.
        if values.get(("Currency", "BASE")) != "USD":
            raise IbkrError("ibkr_usd_base_currency_not_verified")
        cash = amount(values.get(("TotalCashValue", "USD")))
        equity = amount(values.get(("NetLiquidation", "USD")))
        completed, opened, statuses = self.session.order_rows()
        executions = self.session.executions(account)
        fills, correction_ids = {}, {}
        for contract, execution in executions:
            if execution.acctNumber != account:
                continue
            if execution.isPriceRevisionPending:
                raise IbkrError("ibkr_execution_correction_unresolved")
            family = execution.execId.rpartition(".")[0]
            if not family or (family in correction_ids and correction_ids[family] != execution.execId):
                raise IbkrError("ibkr_execution_correction_unresolved")
            correction_ids[family] = execution.execId
            old = fills.get(execution.permId)
            if old is None or Decimal(amount(execution.cumQty)) > Decimal(amount(old.cumQty)):
                fills[execution.permId] = execution
            elif Decimal(amount(execution.cumQty)) == Decimal(amount(old.cumQty)) and amount(execution.avgPrice) != amount(old.avgPrice):
                raise IbkrError("ibkr_execution_correction_unresolved")
        orders = {}
        for contract, order, state in completed + opened:
            if order.account != account:
                continue
            if contract.secType != "STK" or contract.currency != "USD" or order.permId <= 0:
                raise IbkrError("ibkr_unsupported_order_identity")
            status = statuses.get(order.permId)
            execution = fills.get(order.permId)
            filled = amount(status[1]) if status else amount(getattr(order, "filledQuantity", None), optional=True)
            average = amount(status[2], optional=True) if status else None
            if execution is not None:
                cumulative = amount(execution.cumQty)
                if filled is not None and Decimal(filled) < Decimal(cumulative):
                    raise IbkrError("ibkr_conflicting_cumulative_fill")
                if filled is None or Decimal(filled) == Decimal(cumulative):
                    filled, average = cumulative, amount(execution.avgPrice)
            if filled is not None and Decimal(filled) == 0:
                average = None
            # Unknown fill facts remain null in the inspector. They are never
            # translated to a BrokerOrder consumable by the execution ledger.
            key = "IBKR:" + account + ":" + str(order.permId)
            orders[key] = {"id": key, "client_id": str(order.orderRef), "symbol": contract.symbol,
                           "side": str(order.action), "quantity": amount(order.totalQuantity),
                           "filled_quantity": filled, "average_fill_price": average,
                           "status": str(status[0] if status else state.status),
                           "broker_order_id": str(order.orderId), "broker_client_id": str(order.clientId),
                           "permanent_id": str(order.permId)}
        return {"account_id": "IBKR:" + account, "environment": "UNVERIFIED", "capability": "read_only",
                "execution_authorized": False, "observed_at": stamp(self.clock()), "collection_started_at": stamp(started),
                "cash": cash, "equity": equity, "positions": list(positions.values()),
                "orders": list(orders.values()), "history_complete": False,
                "limitations": ["recent_order_history_only", "available_exposure_unverified", "not_an_atomic_snapshot"]}

    def _calendar(self):
        if self.calendar is None:
            self.calendar = importlib.import_module("exchange_calendars").get_calendar("XNYS")
        return self.calendar

    def quote(self, symbol):
        tick, bid, ask, bid_size, ask_size, past_low, past_high = self.session.quote_row(symbol)
        observed = datetime.fromtimestamp(tick, timezone.utc)
        now = self.clock()
        age = (now - observed).total_seconds()
        bid, ask = amount(bid), amount(ask)
        if not 0 <= age <= 5 or past_low or past_high or Decimal(bid) <= 0 or Decimal(ask) < Decimal(bid):
            raise IbkrError("ibkr_fresh_bid_ask_unavailable")
        if Decimal(amount(bid_size)) <= 0 or Decimal(amount(ask_size)) <= 0:
            raise IbkrError("ibkr_quoted_size_unavailable")
        calendar = self._calendar()
        day = now.astimezone(ET).date().isoformat()
        regular = calendar.is_session(day) and calendar.session_open(day).to_pydatetime() <= now < calendar.session_close(day).to_pydatetime()
        return {"symbol": symbol, "bid": bid, "ask": ask, "observed_at": stamp(observed),
                "market_open": bool(regular), "source": "IBKR_TWS_TICK_BY_TICK_BID_ASK"}

    def history(self, symbol):
        now, calendar = self.clock(), self._calendar()
        sessions = calendar.sessions_in_range((now.date() - timedelta(days=15)).isoformat(), now.astimezone(ET).date().isoformat())
        completed = [s for s in sessions if calendar.session_close(s).to_pydatetime() + timedelta(minutes=1) <= now]
        if not completed:
            raise IbkrError("ibkr_completed_session_unavailable")
        latest = str(completed[-1].date())
        if self.histories.get(symbol, (None,))[0] == latest:
            return self.histories[symbol][1]
        bars = []
        for row in self.session.history_rows(symbol):
            day = datetime.strptime(str(row.date), "%Y%m%d").date().isoformat()
            if not calendar.is_session(day):
                raise IbkrError("ibkr_history_calendar_mismatch")
            close = calendar.session_close(day).to_pydatetime()
            if close + timedelta(minutes=1) > now:
                continue
            prices = {key: amount(getattr(row, key)) for key in ("open", "high", "low", "close")}
            op, hi, lo, cl = (Decimal(prices[k]) for k in ("open", "high", "low", "close"))
            volume = Decimal(amount(row.volume))
            if not 0 < lo <= min(op, cl) <= max(op, cl) <= hi or volume < 0 or volume != volume.to_integral_value():
                raise IbkrError("ibkr_invalid_history_bar")
            bars.append({"session_date": day, "open_at": stamp(calendar.session_open(day).to_pydatetime()),
                         "close_at": stamp(close), "available_at": stamp(now), **prices, "volume": int(volume)})
        bars.sort(key=lambda b: b["session_date"])
        if len(bars) < 220 or len({b["session_date"] for b in bars}) != len(bars) or bars[-1]["session_date"] != latest:
            raise IbkrError("ibkr_daily_warmup_incomplete")
        bars = bars[-280:]
        expected = [str(s.date()) for s in calendar.sessions_in_range(bars[0]["session_date"], latest)]
        if expected != [b["session_date"] for b in bars]:
            raise IbkrError("ibkr_daily_session_gap")
        digest = hashlib.sha256(json.dumps(bars, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        result = {"history_mode": "current_observed_snapshot", "bars": bars,
                  "evidence": {"source": "IBKR_TWS_ADJUSTED_LAST_RTH", "dataset_sha256": digest,
                               "calendar_source": "exchange_calendars/XNYS", "adjustment_verified": True,
                               "coverage_verified": True, "availability_verified": False,
                               "classification": "observed", "license_scope": "account_entitlement_only"}}
        self.histories[symbol] = latest, result
        return result

    def inspect_market(self, request):
        self.account(request)
        symbol = request.get("symbol", "")
        quote = self.quote(symbol)
        try:
            evaluation = self.history(symbol)
        except Exception:
            evaluation = None
        return {"quote": quote, "evaluation": evaluation, "execution_authorized": False,
                "limitations": [] if evaluation else ["validated_daily_history_unavailable"]}

    def dispatch(self, request):
        if not isinstance(request, dict):
            raise IbkrError("ibkr_invalid_request")
        operation = request.get("operation")
        if operation in ("place", "cancel", "snapshot", "market"):
            raise IbkrError(BLOCKED)
        if operation == "accounts":
            return self.accounts()
        if operation == "readiness":
            return self.readiness()
        if operation == "inspect":
            return self.inspect(request)
        if operation == "inspect_market":
            return self.inspect_market(request)
        raise IbkrError("ibkr_unsupported_operation")


def serve(adapter, input_stream, output):
    for line in iter(lambda: input_stream.readline(MAX_INPUT + 1), b""):
        try:
            if len(line) > MAX_INPUT or not line.endswith(b"\n"):
                raise IbkrError("ibkr_oversized_request")
            request = json.loads(line, object_pairs_hook=no_duplicates)
            result = adapter.dispatch(request)
        except Exception as error:
            code = str(error) if isinstance(error, IbkrError) else "ibkr_inspection_unavailable"
            result = {"error": code, "execution_authorized": False, "submission_attempted": False}
        output.write(json.dumps(result, separators=(",", ":"), allow_nan=False) + "\n")
        output.flush()


def main():
    parser = argparse.ArgumentParser(description="IBKR local read-only inspector; no executable accounts.")
    parser.add_argument("--port", type=int, choices=(7497, 4002), default=7497)
    parser.add_argument("--client-id", type=int, default=73)
    parser.add_argument("--self-check", action="store_true")
    args = parser.parse_args()
    if args.self_check:
        try:
            importlib.import_module("ibapi.client")
            available = True
        except ImportError:
            available = False
        print(json.dumps({"broker": "IBKR", "officialSdkAvailable": available,
                          "capability": "read_only", "brokerConnected": False, "executionAuthorized": False}))
        return
    output = sys.stdout
    adapter = IBKRAdapter(port=args.port, client_id=args.client_id)
    # Vendor threads can print after requests return; redirect for process life.
    with open(os.devnull, "w") as sink, contextlib.redirect_stdout(sink), contextlib.redirect_stderr(sink):
        try:
            serve(adapter, sys.stdin.buffer, output)
        finally:
            adapter.session.close()


if __name__ == "__main__":
    main()

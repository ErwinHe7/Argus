"""Narrow NDJSON sidecar. SIMULATE only, no password/unlock/live operations.

OpenD is installed and authenticated by the user. This process never accepts
network connections. Its only caller is the local Rust connector over stdio.
"""
from __future__ import annotations

import contextlib
import argparse
import hashlib
import importlib
import json
import logging
import re
import sys
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
from zoneinfo import ZoneInfo

ET = ZoneInfo("America/New_York")
SYMBOL = re.compile(r"^[A-Z][A-Z0-9.-]{0,9}$")
CLIENT = re.compile(r"^leo_[a-f0-9]{32}$")
MAX_INPUT = 4 * 1024 * 1024
TERMINAL = {"FILLED_ALL", "CANCELLED_ALL", "CANCELLED_PART", "FAILED", "SUBMIT_FAILED", "DELETED"}


def decimal(value, *, optional=False):
    if value is None or isinstance(value, bool):
        if optional:
            return None
        raise ValueError("required_amount_unavailable")
    try:
        result = Decimal(str(value))
    except (ValueError, InvalidOperation):
        raise ValueError("invalid_amount") from None
    if not result.is_finite():
        if optional:
            return None
        raise ValueError("invalid_amount")
    return format(result, "f")


def records(frame):
    rows = frame if isinstance(frame, list) else frame.to_dict(orient="records")
    if not isinstance(rows, list) or any(not isinstance(r, dict) for r in rows):
        raise ValueError("invalid_provider_records")
    return rows


def identity(value):
    if hasattr(value, "item"):
        value = value.item()
    if isinstance(value, bool) or not isinstance(value, (int, str)):
        raise ValueError("invalid_account_id")
    result = str(value)
    if not result.isascii() or not result.isdigit() or not 0 < int(result) < 2**64:
        raise ValueError("invalid_account_id")
    return result


def utc():
    return datetime.now(timezone.utc)


def stamp(value):
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def order(row):
    result = {"id": str(row.get("order_id", "")), "client_id": str(row.get("remark", "")),
              "symbol": str(row.get("code", "")).removeprefix("US."), "side": str(row.get("trd_side", "")),
              "quantity": decimal(row.get("qty")), "filled_quantity": decimal(row.get("dealt_qty")),
              "average_fill_price": decimal(row.get("dealt_avg_price"), optional=True),
              "status": str(row.get("order_status", "")), "terminal": row.get("order_status") in TERMINAL}
    if not result["id"] or not result["symbol"] or not result["status"]:
        raise ValueError("invalid_order")
    if Decimal(result["filled_quantity"]) > 0 and (result["average_fill_price"] is None or Decimal(result["average_fill_price"]) <= 0):
        raise ValueError("missing_average_fill_price")
    return result


class PaperAdapter:
    def __init__(self, sdk=None, trade=None, quotes=None, clock=utc, calendar=None, security_firm="FUTUINC"):
        self.sdk, self.trade, self.quotes, self.clock = sdk, trade, quotes, clock
        self.calendar = calendar
        self.subscribed = set()
        self.histories = {}
        self.instruments = {}
        self.submission_attempted = False
        self.security_firm = security_firm

    def connect(self):
        if self.trade is not None:
            return
        logging.getLogger("FTFileLog").disabled = True
        logging.getLogger("FTConsoleLog").disabled = True
        self.sdk = importlib.import_module("moomoo")
        self.trade = self.sdk.OpenSecTradeContext(filter_trdmarket=self.sdk.TrdMarket.US, host="127.0.0.1", port=11111, security_firm=getattr(self.sdk.SecurityFirm, self.security_firm))
        self.quotes = self.sdk.OpenQuoteContext(host="127.0.0.1", port=11111)

    def call(self, target, method, **kwargs):
        ret, data = getattr(target, method)(**kwargs)
        if ret != self.sdk.RET_OK:
            raise ValueError("provider_unavailable")
        return data

    def accounts(self):
        self.connect()
        rows = records(self.call(self.trade, "get_acc_list"))
        result = []
        for row in rows:
            if row.get("trd_env") == "SIMULATE" and row.get("acc_status") == "ACTIVE" and "US" in row.get("trdmarket_auth", []):
                result.append({"accountId": identity(row["acc_id"]), "environment": "SIMULATE", "currency": "USD"})
        if len({r["accountId"] for r in result}) != len(result):
            raise ValueError("duplicate_account")
        return result

    def account(self, request):
        if request.get("environment") != "SIMULATE":
            raise ValueError("real_mode_prohibited")
        account_id = identity(request.get("account_id"))
        if not any(a["accountId"] == account_id for a in self.accounts()):
            raise ValueError("paper_account_not_verified")
        return account_id

    def snapshot(self, request):
        account_id = self.account(request)
        query = {"acc_id": int(account_id), "trd_env": "SIMULATE", "refresh_cache": True}
        funds = records(self.call(self.trade, "accinfo_query", **query, currency="USD"))
        if len(funds) != 1:
            raise ValueError("account_balance_unavailable")
        fund = funds[0]
        # US paper accounts are verified by the US filter and explicit SIMULATE ID;
        # request USD, but never accept an explicit conflicting provider currency.
        if fund.get("currency") not in (None, "", "NONE", "N/A", "USD"):
            raise ValueError("unexpected_currency")
        positions = []
        for row in records(self.call(self.trade, "position_list_query", **query, currency="USD")):
            positions.append({"symbol": str(row["code"]).removeprefix("US."), "quantity": decimal(row.get("qty")),
                              "available_quantity": decimal(row.get("can_sell_qty")), "market_value": decimal(row.get("market_val"))})
        current = records(self.call(self.trade, "order_list_query", **query))
        # The paper API has no deals feed. Retain cumulative order facts and obtain
        # history for restart recovery; absence in this bounded range proves nothing.
        historical = records(self.call(self.trade, "history_order_list_query", acc_id=int(account_id), trd_env="SIMULATE",
                                       start=(self.clock().date() - timedelta(days=30)).isoformat(), end=self.clock().date().isoformat()))
        by_id = {}
        for row in historical + current:
            key = str(row.get("order_id", ""))
            old = by_id.get(key)
            if old is None or str(row.get("updated_time", "")) >= str(old.get("updated_time", "")):
                by_id[key] = row
        return {"account_id": account_id, "environment": "SIMULATE", "observed_at": stamp(self.clock()),
                "cash": decimal(fund.get("cash")), "equity": decimal(fund.get("total_assets")),
                "positions": positions, "orders": [order(row) for row in by_id.values()], "history_complete": False}

    def _calendar(self):
        if self.calendar is None:
            self.calendar = importlib.import_module("exchange_calendars").get_calendar("XNYS")
        return self.calendar

    def instrument(self, symbol):
        self.connect()
        if not SYMBOL.fullmatch(symbol):
            raise ValueError("invalid_symbol")
        today = self.clock().astimezone(ET).date().isoformat()
        if self.instruments.get(symbol) == today:
            return
        rows = records(self.call(self.quotes, "get_stock_basicinfo", market="US", code_list=["US." + symbol]))
        if len(rows) != 1:
            raise ValueError("instrument_metadata_unavailable")
        row = rows[0]
        if row.get("code") != "US." + symbol or row.get("stock_type") not in ("STOCK", "ETF") or row.get("delisting") is not False or Decimal(decimal(row.get("lot_size"))) != 1:
            raise ValueError("listed_us_equity_required")
        self.instruments[symbol] = today

    def completed_session(self):
        calendar, now = self._calendar(), self.clock()
        sessions = calendar.sessions_in_range((now.date() - timedelta(days=15)).isoformat(), now.astimezone(ET).date().isoformat())
        completed = [s for s in sessions if calendar.session_close(s).to_pydatetime() + timedelta(minutes=1) <= now]
        if not completed:
            raise ValueError("completed_session_unavailable")
        return completed[-1]

    def market_open(self):
        calendar = self._calendar()
        now = self.clock()
        date = now.astimezone(ET).date().isoformat()
        if not calendar.is_session(date):
            return False
        return calendar.session_open(date).to_pydatetime() <= now < calendar.session_close(date).to_pydatetime()

    def quote(self, symbol):
        self.connect()
        if not SYMBOL.fullmatch(symbol):
            raise ValueError("invalid_symbol")
        code = "US." + symbol
        if code not in self.subscribed:
            self.call(self.quotes, "subscribe", code_list=[code], subtype_list=[self.sdk.SubType.ORDER_BOOK], subscribe_push=False)
            self.subscribed.add(code)
        book = self.call(self.quotes, "get_order_book", code=code, num=1)
        bids, asks = book.get("Bid", []), book.get("Ask", [])
        if not bids or not asks:
            raise ValueError("executable_quote_unavailable")
        times = []
        for key in ("svr_recv_time_bid", "svr_recv_time_ask"):
            text = book.get(key)
            if not isinstance(text, str) or not text:
                raise ValueError("quote_timestamp_unavailable")
            observed = datetime.fromisoformat(text)
            if observed.tzinfo is None:
                observed = observed.replace(tzinfo=ET)
            times.append(observed)
        return {"symbol": symbol, "bid": decimal(bids[0][0]), "ask": decimal(asks[0][0]), "observed_at": stamp(min(times)),
                "market_open": self.market_open(), "source": "MOOMOO_OPEND_ORDER_BOOK"}

    def history(self, symbol):
        now = self.clock()
        today = now.astimezone(ET).date().isoformat()
        latest = str(self.completed_session().date())
        cached = self.histories.get(symbol)
        if cached and cached[0] == latest:
            return cached[1]
        calendar = self._calendar()
        start = (now.date() - timedelta(days=540)).isoformat()
        ret, frame, next_key = self.quotes.request_history_kline("US." + symbol, start=start, end=today,
                         ktype=self.sdk.KLType.K_DAY, autype=self.sdk.AuType.QFQ, max_count=1000)
        if ret != self.sdk.RET_OK or next_key is not None:
            raise ValueError("daily_history_incomplete")
        bars = []
        for row in records(frame):
            date = str(row["time_key"])[:10]
            if not calendar.is_session(date):
                raise ValueError("calendar_history_mismatch")
            close_at = calendar.session_close(date).to_pydatetime()
            if close_at + timedelta(minutes=1) > now:
                continue
            bars.append({"session_date": date, "open_at": stamp(calendar.session_open(date).to_pydatetime()),
                         "close_at": stamp(close_at), "available_at": stamp(now),
                         **{key: decimal(row.get(key)) for key in ("open", "high", "low", "close")}, "volume": int(row["volume"])})
        bars.sort(key=lambda b: b["session_date"])
        if len(bars) < 220 or len({b["session_date"] for b in bars}) != len(bars):
            raise ValueError("daily_warmup_unavailable")
        bars = bars[-280:]
        if bars[-1]["session_date"] != latest:
            raise ValueError("latest_completed_session_missing")
        expected = [str(x.date()) for x in calendar.sessions_in_range(bars[0]["session_date"], bars[-1]["session_date"])]
        if expected != [b["session_date"] for b in bars]:
            raise ValueError("daily_session_gap")
        digest = hashlib.sha256(json.dumps(bars, separators=(",", ":"), sort_keys=True).encode()).hexdigest()
        result = {"history_mode": "current_observed_snapshot", "bars": bars, "evidence": {"source": "MOOMOO_OPEND_HISTORY_K_DAY_QFQ", "dataset_sha256": digest,
                    "calendar_source": "exchange_calendars/XNYS", "adjustment_verified": True, "coverage_verified": True,
                    "availability_verified": False, "classification": "observed", "license_scope": "personal_research"}}
        self.histories[symbol] = (latest, result)
        return result

    def place(self, request):
        account_id = self.account(request)
        intent = request.get("intent", {})
        if intent.get("account_id") != account_id or not CLIENT.fullmatch(str(intent.get("client_id", ""))):
            raise ValueError("intent_identity_mismatch")
        symbol = intent.get("symbol", "")
        if not SYMBOL.fullmatch(symbol) or intent.get("side") not in ("BUY", "SELL"):
            raise ValueError("invalid_intent")
        self.instrument(symbol)
        quantity = Decimal(decimal(intent.get("quantity")))
        if quantity <= 0 or quantity != quantity.to_integral_value():
            raise ValueError("whole_shares_required")
        order_type = intent.get("order_type")
        if order_type not in ("NORMAL", "MARKET") or (intent["side"] == "BUY" and order_type != "NORMAL"):
            raise ValueError("paper_order_type_not_supported")
        quote = self.quote(symbol)
        age = (self.clock() - datetime.fromisoformat(quote["observed_at"].replace("Z", "+00:00"))).total_seconds()
        if not quote["market_open"] or not 0 <= age <= 5 or Decimal(quote["bid"]) <= 0 or Decimal(quote["ask"]) < Decimal(quote["bid"]):
            raise ValueError("fresh_regular_quote_required")
        snapshot = self.snapshot(request)
        if any(o["client_id"] == intent["client_id"] for o in snapshot["orders"]):
            raise ValueError("existing_command_requires_reconciliation")
        if intent["side"] == "SELL":
            available = sum(Decimal(p["available_quantity"]) for p in snapshot["positions"] if p["symbol"] == symbol)
            if quantity > available:
                raise ValueError("unintended_short_prohibited")
        price = Decimal(decimal(intent.get("limit_price"))) if order_type == "NORMAL" else Decimal("0")
        if intent["side"] == "BUY" and (price <= 0 or quantity * price > Decimal(snapshot["cash"])):
            raise ValueError("cash_only_limit_exceeded")
        # Repeat the time/lease checks after blocking SDK work, immediately before
        # the sole submission call. A precheck cannot survive provider latency.
        now = self.clock()
        quote_age = (now - datetime.fromisoformat(quote["observed_at"].replace("Z", "+00:00"))).total_seconds()
        if not self.market_open() or not 0 <= quote_age <= 5:
            raise ValueError("quote_expired_during_validation")
        if intent["side"] == "BUY":
            bid, ask = Decimal(quote["bid"]), Decimal(quote["ask"])
            if (ask - bid) * 20000 > (ask + bid) * 20:
                raise ValueError("entry_spread_exceeds_twenty_basis_points")
            deadline = request.get("entry_lease_deadline_ms")
            if isinstance(deadline, bool) or not isinstance(deadline, int) or not now.timestamp() * 1000 < deadline <= now.timestamp() * 1000 + 15000:
                raise ValueError("entry_lease_expired")
            et = now.astimezone(ET)
            if et.hour != 9 or not 35 <= et.minute < 40:
                raise ValueError("outside_entry_window")
            if any(p["symbol"] == symbol and Decimal(p["quantity"]) != 0 for p in snapshot["positions"]):
                raise ValueError("existing_broker_symbol_exposure_blocked")
        self.submission_attempted = True
        result = records(self.call(self.trade, "place_order", acc_id=int(account_id), trd_env="SIMULATE", code="US." + symbol,
                         price=float(price), qty=int(quantity), trd_side=intent["side"], order_type=order_type,
                         time_in_force="DAY", session="RTH", adjust_limit=0, remark=intent["client_id"]))
        if len(result) != 1:
            raise ValueError("submission_outcome_unknown")
        normalized = order(result[0])
        if not normalized["client_id"]:
            normalized["client_id"] = intent["client_id"]
        return normalized

    def cancel(self, request):
        account_id = self.account(request)
        order_id = str(request.get("order_id", ""))
        snapshot = self.snapshot(request)
        target = next((o for o in snapshot["orders"] if o["id"] == order_id and CLIENT.fullmatch(o["client_id"])), None)
        if target is None:
            raise ValueError("owned_order_not_verified")
        if target["terminal"]:
            return {"cancel_requested": False, "terminal": True}
        self.call(self.trade, "modify_order", modify_order_op=self.sdk.ModifyOrderOp.CANCEL, order_id=order_id,
                  qty=0, price=0, acc_id=int(account_id), trd_env="SIMULATE")
        return {"cancel_requested": True, "terminal": False}

    def dispatch(self, request):
        self.submission_attempted = False
        if not isinstance(request, dict):
            raise ValueError("invalid_request")
        operation = request.get("operation")
        if operation == "accounts":
            return self.accounts()
        if operation == "snapshot":
            return self.snapshot(request)
        if operation == "market":
            symbol = request.get("symbol", "")
            self.instrument(symbol)
            quote = self.quote(symbol)
            # A failed history request must not prevent the caller from applying
            # a persisted software stop with an otherwise valid executable quote.
            try:
                history = self.history(symbol)
            except Exception:
                history = None
            entry_session = str(self._calendar().next_session(history["bars"][-1]["session_date"]).date()) if history else None
            return {"quote": quote, "evaluation": history, "entry_session": entry_session}
        if operation == "place":
            return self.place(request)
        if operation == "cancel":
            return self.cancel(request)
        raise ValueError("unsupported_operation")


def no_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate_json_key")
        result[key] = value
    return result


def main():
    parser = argparse.ArgumentParser(description="Local paper-only SDK sidecar; no inbound listener.")
    parser.add_argument("--security-firm", choices=["FUTUINC", "FUTUSECURITIES", "FUTUSG", "FUTUAU", "FUTUCA", "FUTUMY", "FUTUJP"], default="FUTUINC")
    parser.add_argument("--self-check", action="store_true", help="Import packaged libraries and validate the offline calendar without connecting OpenD")
    args = parser.parse_args()
    if args.self_check:
        import importlib.metadata
        importlib.import_module("moomoo")
        calendar = importlib.import_module("exchange_calendars").get_calendar("XNYS")
        assert str(calendar.next_session("2026-09-04").date()) == "2026-09-08"
        print(json.dumps({"paperOnly": True, "brokerConnected": False, "sdkVersion": importlib.metadata.version("moomoo-api"), "calendarVersion": importlib.metadata.version("exchange-calendars"), "calendarSmokePassed": True}))
        return
    output = sys.stdout
    adapter = PaperAdapter(security_firm=args.security_firm)
    while True:
        line = sys.stdin.buffer.readline(MAX_INPUT + 1)
        if not line:
            break
        try:
            if len(line) > MAX_INPUT or not line.endswith(b"\n"):
                raise ValueError("oversized_request")
            request = json.loads(line, object_pairs_hook=no_duplicates)
            # Some vendor versions write startup banners to stdout. They must not
            # corrupt the JSON protocol, expose raw SDK messages, or reach logs.
            with open(__import__("os").devnull, "w") as sink, contextlib.redirect_stdout(sink), contextlib.redirect_stderr(sink):
                result = adapter.dispatch(request)
        except Exception:
            result = {"error": "paper_sdk_operation_unavailable", "execution_authorized": False, "submission_attempted": adapter.submission_attempted}
        output.write(json.dumps(result, separators=(",", ":"), allow_nan=False) + "\n")
        output.flush()


if __name__ == "__main__":
    main()

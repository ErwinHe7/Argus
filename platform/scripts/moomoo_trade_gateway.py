#!/usr/bin/env python3
"""Loopback-only Moomoo trade boundary for AXIO7.

The gateway owns the official SDK trade context.  Rust remains responsible for
model promotion, portfolio risk, sizing, OMS persistence, and reconciliation.
Real trading is disabled unless the process is started in real mode with two
independent runtime tokens and a pinned account ID.
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import math
import os
import re
import signal
import threading
from dataclasses import dataclass
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

CLIENT_ORDER_ID = re.compile(r"^[A-Za-z0-9_.:-]{8,64}$")
TOKEN_MINIMUM_LENGTH = 32


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def clean_value(value: Any) -> Any:
    if value is None:
        return None
    if hasattr(value, "item"):
        try:
            value = value.item()
        except (TypeError, ValueError):
            pass
    if hasattr(value, "isoformat") and not isinstance(value, (str, bytes)):
        try:
            return value.isoformat()
        except (TypeError, ValueError):
            pass
    if isinstance(value, float) and not math.isfinite(value):
        return None
    if isinstance(value, (str, int, float, bool)):
        return value
    return str(value)


def records(frame: Any) -> list[dict[str, Any]]:
    if frame is None:
        return []
    if isinstance(frame, list):
        rows = frame
    elif isinstance(frame, dict):
        rows = [frame]
    elif hasattr(frame, "to_dict"):
        rows = frame.to_dict(orient="records")
    else:
        return []
    return [{str(key): clean_value(value) for key, value in row.items()} for row in rows]


def first_number(row: dict[str, Any], *names: str) -> float:
    for name in names:
        value = row.get(name)
        if value is not None:
            try:
                number = float(value)
                if math.isfinite(number):
                    return number
            except (TypeError, ValueError):
                continue
    return 0.0


def first_text(row: dict[str, Any], *names: str) -> str:
    for name in names:
        value = row.get(name)
        if value is not None and str(value).strip():
            return str(value).strip()
    return ""


@dataclass(frozen=True)
class GatewayConfig:
    bind_host: str
    bind_port: int
    opend_host: str
    opend_port: int
    mode: str
    account_id: int | None
    security_firm: str
    allowed_symbols: frozenset[str]
    max_order_notional: float
    long_only: bool
    event_log: Path
    gateway_token: str
    live_arm_token: str | None

    @property
    def trade_environment(self) -> str:
        return "REAL" if self.mode == "real" else "SIMULATE"


class OrderGuard:
    def __init__(self, config: GatewayConfig):
        self.config = config

    def validate(self, payload: dict[str, Any]) -> dict[str, Any]:
        client_order_id = str(payload.get("client_order_id", ""))
        symbol = str(payload.get("symbol", "")).upper()
        side = str(payload.get("side", "")).upper()
        order_type = str(payload.get("order_type", "LIMIT")).upper()
        time_in_force = str(payload.get("time_in_force", "DAY")).upper()
        try:
            quantity = float(payload.get("quantity"))
            limit_price = float(payload.get("limit_price"))
        except (TypeError, ValueError) as error:
            raise ValueError("quantity and limit_price must be numeric") from error

        if not CLIENT_ORDER_ID.fullmatch(client_order_id):
            raise ValueError("client_order_id must be 8-64 safe ASCII characters")
        if symbol not in self.config.allowed_symbols:
            raise ValueError(f"symbol {symbol} is not in the gateway allowlist")
        if side not in {"BUY", "SELL"}:
            raise ValueError("side must be BUY or SELL")
        if order_type != "LIMIT" or time_in_force != "DAY":
            raise ValueError("the canary gateway accepts DAY limit orders only")
        if not quantity.is_integer() or quantity <= 0:
            raise ValueError("US equity quantity must be a positive whole number")
        if not math.isfinite(limit_price) or limit_price <= 0:
            raise ValueError("limit_price must be finite and positive")
        notional = quantity * limit_price
        if notional > self.config.max_order_notional + 1e-9:
            raise ValueError(
                f"order notional {notional:.2f} exceeds gateway cap "
                f"{self.config.max_order_notional:.2f}"
            )
        return {
            "client_order_id": client_order_id,
            "symbol": symbol,
            "side": side,
            "quantity": int(quantity),
            "limit_price": round(limit_price, 2),
            "order_type": order_type,
            "time_in_force": time_in_force,
        }


class AppendOnlyEvents:
    def __init__(self, path: Path):
        self.path = path
        self.lock = threading.Lock()
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def append(self, event_type: str, payload: Any) -> None:
        row = {
            "event_id": hashlib.sha256(
                f"{event_type}\0{utc_now()}\0{json.dumps(payload, sort_keys=True, default=str)}".encode()
            ).hexdigest(),
            "event_type": event_type,
            "received_at": utc_now(),
            "payload": payload,
        }
        encoded = (json.dumps(row, separators=(",", ":"), default=str) + "\n").encode()
        with self.lock, self.path.open("ab", buffering=0) as handle:
            handle.write(encoded)
            os.fsync(handle.fileno())


class MoomooTradeService:
    def __init__(self, config: GatewayConfig):
        try:
            import moomoo
        except ImportError as error:
            raise RuntimeError(
                "official moomoo-api package is missing; install moomoo-api==10.9.6908"
            ) from error

        self.moomoo = moomoo
        self.config = config
        self.guard = OrderGuard(config)
        self.events = AppendOnlyEvents(config.event_log)
        self.lock = threading.RLock()
        self.context = moomoo.OpenSecTradeContext(
            filter_trdmarket=moomoo.TrdMarket.US,
            host=config.opend_host,
            port=config.opend_port,
            security_firm=getattr(moomoo.SecurityFirm, config.security_firm),
        )
        self.context.set_handler(self._order_handler())
        self.context.set_handler(self._deal_handler())
        self.account_id = self._select_account(config.account_id)
        if config.mode == "real":
            self._unlock_real_trading()
        self.events.append(
            "gateway_started",
            {
                "provider": "MOOMOO_OPEND",
                "mode": config.mode,
                "account_id": self.account_id,
                "allowed_symbols": sorted(config.allowed_symbols),
                "max_order_notional": config.max_order_notional,
                "sdk_version": getattr(moomoo, "__version__", "unknown"),
            },
        )

    def _order_handler(self):
        service = self
        base = self.moomoo.TradeOrderHandlerBase

        class Handler(base):
            def on_recv_rsp(self, response):
                ret, data = super().on_recv_rsp(response)
                service.events.append(
                    "order_callback",
                    {"ret": ret, "data": records(data)},
                )
                return ret, data

        return Handler()

    def _deal_handler(self):
        service = self
        base = self.moomoo.TradeDealHandlerBase

        class Handler(base):
            def on_recv_rsp(self, response):
                ret, data = super().on_recv_rsp(response)
                service.events.append(
                    "deal_callback",
                    {"ret": ret, "data": records(data)},
                )
                return ret, data

        return Handler()

    def _sdk_call(self, name: str, result: tuple[Any, Any]) -> list[dict[str, Any]]:
        ret, data = result
        if ret != self.moomoo.RET_OK:
            raise RuntimeError(f"Moomoo {name} failed: {data}")
        return records(data)

    def _select_account(self, pinned: int | None) -> int:
        accounts = self._sdk_call("get_acc_list", self.context.get_acc_list())
        environment = self.config.trade_environment
        eligible = [
            row
            for row in accounts
            if not first_text(row, "trd_env")
            or first_text(row, "trd_env").upper() == environment
        ]
        if pinned is not None:
            eligible = [row for row in eligible if int(first_number(row, "acc_id")) == pinned]
        if not eligible:
            raise RuntimeError(
                f"no {environment} US trading account matched account_id={pinned!r}"
            )
        selected = int(first_number(eligible[0], "acc_id"))
        if selected <= 0:
            raise RuntimeError("Moomoo returned an invalid account ID")
        if self.config.mode == "real" and pinned != selected:
            raise RuntimeError("real trading refuses an unpinned account")
        return selected

    def _unlock_real_trading(self) -> None:
        password_md5 = os.environ.get("MOOMOO_TRADE_PASSWORD_MD5", "").strip()
        password = os.environ.get("MOOMOO_TRADE_PASSWORD", "").strip()
        if not password_md5 and not password:
            raise RuntimeError(
                "real mode requires MOOMOO_TRADE_PASSWORD_MD5 or a session-only "
                "MOOMOO_TRADE_PASSWORD"
            )
        ret, data = self.context.unlock_trade(
            password=password or None,
            password_md5=password_md5 or None,
        )
        if ret != self.moomoo.RET_OK:
            raise RuntimeError(f"Moomoo unlock_trade failed: {data}")
        self.events.append("trade_unlocked", {"account_id": self.account_id})

    def close(self) -> None:
        try:
            self.context.close()
        finally:
            self.events.append("gateway_stopped", {"account_id": self.account_id})

    def health(self) -> dict[str, Any]:
        return {
            "status": "READY",
            "provider": "MOOMOO_OPEND",
            "mode": self.config.mode,
            "trade_environment": self.config.trade_environment,
            "account_id": self.account_id,
            "loopback_only": True,
            "real_orders_armed": self.config.mode == "real",
            "sdk_version": getattr(self.moomoo, "__version__", "unknown"),
            "server_time": utc_now(),
        }

    def accounts(self) -> list[dict[str, Any]]:
        with self.lock:
            return self._sdk_call("get_acc_list", self.context.get_acc_list())

    def _query(self, method: str, **kwargs: Any) -> list[dict[str, Any]]:
        with self.lock:
            result = getattr(self.context, method)(
                trd_env=self.config.trade_environment,
                acc_id=self.account_id,
                **kwargs,
            )
            return self._sdk_call(method, result)

    def snapshot(self) -> dict[str, Any]:
        account_rows = self._query("accinfo_query", refresh_cache=True, currency="USD")
        position_rows = self._query("position_list_query", refresh_cache=True, currency="USD")
        order_rows = self._query("order_list_query", refresh_cache=True)
        deal_rows = self._query("deal_list_query", refresh_cache=True)
        account = account_rows[0] if account_rows else {}
        normalized_account = {
            "account_id": self.account_id,
            "cash": first_number(account, "cash", "avl_withdrawal_cash"),
            "equity": first_number(account, "total_assets", "net_liquidation"),
            "buying_power": first_number(account, "power", "available_funds", "net_cash_power"),
            "market_value": first_number(account, "market_val", "securities_assets"),
            "currency": first_text(account, "currency") or "USD",
        }
        positions = [self._normalize_position(row) for row in position_rows]
        orders = [self._normalize_order(row) for row in order_rows]
        fills = [self._normalize_fill(row) for row in deal_rows]
        as_of = utc_now()
        snapshot = {
            "snapshot_id": hashlib.sha256(
                json.dumps(
                    [self.account_id, as_of, normalized_account, positions, orders, fills],
                    sort_keys=True,
                ).encode()
            ).hexdigest(),
            "as_of": as_of,
            "source": "MOOMOO_OPEND_TRADE_API",
            "authoritative": True,
            "mode": self.config.mode,
            "account": normalized_account,
            "positions": positions,
            "orders": orders,
            "fills": fills,
        }
        self.events.append("broker_snapshot", snapshot)
        return snapshot

    @staticmethod
    def _normalize_position(row: dict[str, Any]) -> dict[str, Any]:
        return {
            "symbol": first_text(row, "code", "symbol").upper(),
            "quantity": first_number(row, "qty", "quantity"),
            "available_quantity": first_number(row, "can_sell_qty", "available_quantity"),
            "average_price": first_number(row, "cost_price", "average_price"),
            "mark_price": first_number(row, "nominal_price", "market_price", "price"),
            "market_value": first_number(row, "market_val", "market_value"),
            "realized_pnl": first_number(row, "realized_pl", "realized_pnl"),
            "unrealized_pnl": first_number(row, "pl_val", "unrealized_pnl"),
            "position_side": first_text(row, "position_side"),
        }

    @staticmethod
    def _normalize_order(row: dict[str, Any]) -> dict[str, Any]:
        return {
            "broker_order_id": first_text(row, "order_id"),
            "client_order_id": first_text(row, "remark"),
            "symbol": first_text(row, "code", "symbol").upper(),
            "side": first_text(row, "trd_side", "side").upper(),
            "order_type": first_text(row, "order_type").upper(),
            "status": first_text(row, "order_status", "status").upper(),
            "quantity": first_number(row, "qty", "quantity"),
            "filled_quantity": first_number(row, "dealt_qty", "filled_quantity"),
            "limit_price": first_number(row, "price", "limit_price"),
            "average_fill_price": first_number(row, "dealt_avg_price", "average_fill_price"),
            "created_at": first_text(row, "create_time", "created_at"),
            "updated_at": first_text(row, "updated_time", "updated_at"),
            "last_error": first_text(row, "last_err_msg", "last_error"),
        }

    @staticmethod
    def _normalize_fill(row: dict[str, Any]) -> dict[str, Any]:
        return {
            "fill_id": first_text(row, "deal_id", "fill_id"),
            "broker_order_id": first_text(row, "order_id"),
            "symbol": first_text(row, "code", "symbol").upper(),
            "side": first_text(row, "trd_side", "side").upper(),
            "quantity": first_number(row, "qty", "quantity"),
            "price": first_number(row, "price"),
            "created_at": first_text(row, "create_time", "created_at"),
        }

    def _find_existing_order(self, client_order_id: str) -> dict[str, Any] | None:
        rows = self._query("order_list_query", refresh_cache=True)
        for row in rows:
            normalized = self._normalize_order(row)
            if hmac.compare_digest(normalized["client_order_id"], client_order_id):
                return normalized
        return None

    def place_order(self, payload: dict[str, Any], live_arm: str | None) -> dict[str, Any]:
        order = self.guard.validate(payload)
        if self.config.mode == "real":
            if not self.config.live_arm_token or not live_arm or not hmac.compare_digest(
                self.config.live_arm_token, live_arm
            ):
                raise PermissionError("real order requires the independent live arming token")
        with self.lock:
            existing = self._find_existing_order(order["client_order_id"])
            if existing is not None:
                return {"idempotent_replay": True, "order": existing}
            if self.config.long_only and order["side"] == "SELL":
                positions = self._query(
                    "position_list_query",
                    code=order["symbol"],
                    refresh_cache=True,
                    currency="USD",
                )
                available = sum(first_number(row, "can_sell_qty") for row in positions)
                if order["quantity"] > available + 1e-9:
                    raise ValueError("long-only gateway refuses a sell larger than available shares")
            result = self.context.place_order(
                price=order["limit_price"],
                qty=order["quantity"],
                code=order["symbol"],
                trd_side=(
                    self.moomoo.TrdSide.BUY
                    if order["side"] == "BUY"
                    else self.moomoo.TrdSide.SELL
                ),
                order_type=self.moomoo.OrderType.NORMAL,
                trd_env=self.config.trade_environment,
                acc_id=self.account_id,
                remark=order["client_order_id"],
                time_in_force=self.moomoo.TimeInForce.DAY,
                session=self.moomoo.Session.RTH,
            )
            rows = self._sdk_call("place_order", result)
            if not rows:
                raise RuntimeError("Moomoo place_order returned no order record")
            normalized = self._normalize_order(rows[0])
            self.events.append(
                "order_submission_response",
                {"request": order, "response": normalized},
            )
            return {"idempotent_replay": False, "order": normalized}

    def cancel_order(self, broker_order_id: str, live_arm: str | None) -> dict[str, Any]:
        if self.config.mode == "real":
            if not self.config.live_arm_token or not live_arm or not hmac.compare_digest(
                self.config.live_arm_token, live_arm
            ):
                raise PermissionError("real cancellation requires the live arming token")
        if not broker_order_id or len(broker_order_id) > 80:
            raise ValueError("invalid broker order ID")
        with self.lock:
            result = self.context.modify_order(
                self.moomoo.ModifyOrderOp.CANCEL,
                broker_order_id,
                0,
                0,
                trd_env=self.config.trade_environment,
                acc_id=self.account_id,
            )
            rows = self._sdk_call("cancel_order", result)
            normalized = self._normalize_order(rows[0]) if rows else {"broker_order_id": broker_order_id}
            self.events.append("cancel_submission_response", normalized)
            return normalized


class GatewayHttpServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address: tuple[str, int], service: MoomooTradeService):
        super().__init__(address, GatewayRequestHandler)
        self.service = service


class GatewayRequestHandler(BaseHTTPRequestHandler):
    server: GatewayHttpServer
    protocol_version = "HTTP/1.1"

    def log_message(self, _format: str, *_args: Any) -> None:
        return

    def _authorized(self) -> bool:
        expected = self.server.service.config.gateway_token
        provided = self.headers.get("Authorization", "")
        return hmac.compare_digest(provided, f"Bearer {expected}")

    def _reply(self, status: int, payload: Any) -> None:
        encoded = json.dumps(payload, separators=(",", ":"), default=str).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(encoded)

    def _require_auth(self) -> bool:
        if self._authorized():
            return True
        self._reply(401, {"status": "UNAUTHORIZED"})
        return False

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0 or length > 65_536:
            raise ValueError("request body must be between 1 and 65536 bytes")
        value = json.loads(self.rfile.read(length))
        if not isinstance(value, dict):
            raise ValueError("request body must be a JSON object")
        return value

    def do_GET(self) -> None:  # noqa: N802
        if not self._require_auth():
            return
        path = urlparse(self.path).path
        try:
            if path == "/health":
                self._reply(200, self.server.service.health())
            elif path == "/v1/accounts":
                self._reply(200, {"accounts": self.server.service.accounts()})
            elif path == "/v1/snapshot":
                self._reply(200, self.server.service.snapshot())
            else:
                self._reply(404, {"status": "NOT_FOUND"})
        except Exception as error:  # broker errors must become fail-closed responses
            self.server.service.events.append("gateway_error", {"path": path, "error": str(error)})
            self._reply(503, {"status": "BROKER_UNAVAILABLE", "detail": str(error)})

    def do_POST(self) -> None:  # noqa: N802
        if not self._require_auth():
            return
        path = urlparse(self.path).path
        live_arm = self.headers.get("X-Axio-Live-Arm")
        try:
            if path == "/v1/orders":
                self._reply(200, self.server.service.place_order(self._read_json(), live_arm))
                return
            match = re.fullmatch(r"/v1/orders/([^/]+)/cancel", path)
            if match:
                self._reply(200, self.server.service.cancel_order(match.group(1), live_arm))
                return
            self._reply(404, {"status": "NOT_FOUND"})
        except PermissionError as error:
            self._reply(403, {"status": "NOT_ARMED", "detail": str(error)})
        except (ValueError, json.JSONDecodeError) as error:
            self._reply(422, {"status": "RISK_REJECTED", "detail": str(error)})
        except Exception as error:
            self.server.service.events.append("gateway_error", {"path": path, "error": str(error)})
            self._reply(503, {"status": "BROKER_UNAVAILABLE", "detail": str(error)})


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="AXIO7 Moomoo loopback trade gateway")
    parser.add_argument("--bind-host", default="127.0.0.1")
    parser.add_argument("--bind-port", type=int, default=8765)
    parser.add_argument("--opend-host", default="127.0.0.1")
    parser.add_argument("--opend-port", type=int, default=11111)
    parser.add_argument("--mode", choices=("simulate", "real"), default="simulate")
    parser.add_argument("--account-id", type=int)
    parser.add_argument("--security-firm", default="FUTUINC")
    parser.add_argument("--allow-symbols", default="US.SPY")
    parser.add_argument("--max-order-notional", type=float, default=500.0)
    parser.add_argument("--allow-short", action="store_true")
    parser.add_argument("--event-log", default="quant_engine_rs/data/execution/moomoo_events.jsonl")
    parser.add_argument("--self-test", action="store_true")
    return parser.parse_args()


def build_config(args: argparse.Namespace) -> GatewayConfig:
    if args.bind_host != "127.0.0.1" or args.opend_host != "127.0.0.1":
        raise RuntimeError("gateway and OpenD must both remain on 127.0.0.1")
    token = os.environ.get("AXIO_BROKER_GATEWAY_TOKEN", "")
    if len(token) < TOKEN_MINIMUM_LENGTH:
        raise RuntimeError("AXIO_BROKER_GATEWAY_TOKEN must contain at least 32 characters")
    symbols = frozenset(value.strip().upper() for value in args.allow_symbols.split(",") if value.strip())
    if not symbols or any(not symbol.startswith("US.") for symbol in symbols):
        raise RuntimeError("allow-symbols must contain canonical US.* symbols")
    if not math.isfinite(args.max_order_notional) or args.max_order_notional <= 0:
        raise RuntimeError("max-order-notional must be finite and positive")
    live_arm = os.environ.get("AXIO_LIVE_ARMING_TOKEN", "").strip() or None
    if args.mode == "real":
        if os.environ.get("AXIO_LIVE_TRADING_ENABLED") != "I_UNDERSTAND_REAL_ORDERS":
            raise RuntimeError("real mode requires AXIO_LIVE_TRADING_ENABLED=I_UNDERSTAND_REAL_ORDERS")
        if args.account_id is None or args.account_id <= 0:
            raise RuntimeError("real mode requires an exact positive --account-id")
        if live_arm is None or len(live_arm) < TOKEN_MINIMUM_LENGTH:
            raise RuntimeError("real mode requires AXIO_LIVE_ARMING_TOKEN with at least 32 characters")
    return GatewayConfig(
        bind_host=args.bind_host,
        bind_port=args.bind_port,
        opend_host=args.opend_host,
        opend_port=args.opend_port,
        mode=args.mode,
        account_id=args.account_id,
        security_firm=args.security_firm,
        allowed_symbols=symbols,
        max_order_notional=args.max_order_notional,
        long_only=not args.allow_short,
        event_log=Path(args.event_log).resolve(),
        gateway_token=token,
        live_arm_token=live_arm,
    )


def self_test(config: GatewayConfig) -> None:
    guard = OrderGuard(config)
    valid = guard.validate(
        {
            "client_order_id": "axio-self-test-001",
            "symbol": next(iter(config.allowed_symbols)),
            "side": "BUY",
            "quantity": 1,
            "limit_price": min(10.0, config.max_order_notional),
            "order_type": "LIMIT",
            "time_in_force": "DAY",
        }
    )
    assert valid["quantity"] == 1
    try:
        guard.validate({**valid, "order_type": "MARKET"})
    except ValueError:
        pass
    else:
        raise AssertionError("market order should have been rejected")
    print(json.dumps({"status": "SELF_TEST_PASSED", "mode": config.mode}))


def main() -> int:
    args = parse_args()
    config = build_config(args)
    if args.self_test:
        self_test(config)
        return 0
    service = MoomooTradeService(config)
    server = GatewayHttpServer((config.bind_host, config.bind_port), service)

    def stop(_signum: int, _frame: Any) -> None:
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    try:
        server.serve_forever(poll_interval=0.25)
    finally:
        server.server_close()
        service.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

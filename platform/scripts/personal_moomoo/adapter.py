"""Official SDK adapter. No credentials, broker payloads, or errors are logged."""
from __future__ import annotations

import importlib
import importlib.metadata
import importlib.util
import hashlib
import logging
import socket
from decimal import Decimal, InvalidOperation
from typing import Any

from .errors import PersonalError, unavailable

SDK_VERSION = "10.9.6908"
SUPPORTED_SDK_VERSIONS = {"10.09.6908", "10.9.6908", "10.10.7008"}


def text(value: Any) -> str:
    return value.strip() if isinstance(value, str) else ""


def rows(frame: Any) -> list[dict]:
    if isinstance(frame, list):
        result = frame
    elif hasattr(frame, "to_dict"):
        result = frame.to_dict(orient="records")
    else:
        raise unavailable()
    if not all(isinstance(row, dict) for row in result):
        raise unavailable()
    return result


def number(value: Any) -> str | None:
    if value is None or isinstance(value, bool):
        return None
    try:
        decimal = Decimal(str(value))
    except (InvalidOperation, ValueError):
        return None
    if not decimal.is_finite():
        return None
    return format(decimal, "f")


def account_id(value: Any) -> str:
    # SDK IDs are uint64. Do not pass through a float or a JavaScript Number.
    if hasattr(value, "item"):
        value = value.item()
    if isinstance(value, bool) or not isinstance(value, (int, str)):
        raise unavailable()
    result = str(value)
    if not result.isascii() or not result.isdecimal() or not 0 < int(result) < 2**64:
        raise unavailable()
    return str(int(result))


def normalize_account(row: dict) -> dict:
    mode = text(row.get("trd_env"))
    status = text(row.get("acc_status"))
    markets = row.get("trdmarket_auth")
    if mode not in {"REAL", "SIMULATE"} or not status or not isinstance(markets, list):
        raise unavailable()
    if not all(isinstance(market, str) and market for market in markets):
        raise unavailable()
    identity = account_id(row.get("acc_id"))
    return {
        "id": identity,
        "mode": mode,
        "label": f"{'Paper' if mode == 'SIMULATE' else 'Real'} account ending {identity[-4:]}",
        "status": status,
        "markets": markets,
    }


def normalize_order(row: dict) -> dict:
    identity = text(row.get("order_id"))
    symbol = text(row.get("code"))
    side = text(row.get("trd_side"))
    status = text(row.get("order_status"))
    quantity = number(row.get("qty"))
    filled = number(row.get("dealt_qty"))
    if not identity or not symbol or not status or not side or quantity is None or filled is None:
        raise unavailable()
    return {
        "id": identity,
        "symbol": symbol.removeprefix("US."),
        "side": side,
        "status": status,
        "quantity": quantity,
        "filled_quantity": filled,
        "limit_price": number(row.get("price")),
    }


class MoomooAdapter:
    def __init__(self):
        self.sdk = None
        self.context = None

    def availability(self) -> tuple[bool, bool]:
        installed = importlib.util.find_spec("moomoo") is not None
        try:
            with socket.create_connection(("127.0.0.1", 11111), timeout=0.25):
                reachable = True
        except OSError:
            reachable = False
        return installed, reachable

    def version(self) -> str | None:
        try:
            return importlib.metadata.version("moomoo-api")
        except importlib.metadata.PackageNotFoundError:
            return None

    def _context(self):
        if self.context is not None:
            return self.context
        installed, reachable = self.availability()
        if not installed:
            raise PersonalError("sdk_missing", f"Install moomoo-api=={SDK_VERSION} in the local gateway environment.", 503)
        if not reachable:
            raise PersonalError("opend_unavailable", "Start moomoo OpenD and sign in on this computer (127.0.0.1:11111).", 503)
        try:
            # This dedicated process returns safe errors itself. The pinned SDK
            # otherwise persists debug messages, including raw broker failures.
            logging.getLogger("FTFileLog").disabled = True
            logging.getLogger("FTConsoleLog").disabled = True
            self.sdk = importlib.import_module("moomoo")
            if getattr(self.sdk, "__version__", "") not in SUPPORTED_SDK_VERSIONS:
                raise PersonalError("sdk_version", f"The local gateway requires moomoo-api=={SDK_VERSION}.", 503)
            self.context = self.sdk.OpenSecTradeContext(
                filter_trdmarket=self.sdk.TrdMarket.US,
                host="127.0.0.1", port=11111,
                security_firm=self.sdk.SecurityFirm.FUTUINC,
            )
            return self.context
        except PersonalError:
            raise
        except Exception:
            raise unavailable() from None

    def _call(self, method: str, **kwargs) -> list[dict]:
        try:
            context = self._context()
            ret, data = getattr(context, method)(**kwargs)
            if ret != self.sdk.RET_OK:
                raise unavailable()
            return rows(data)
        except PersonalError:
            raise
        except Exception:
            raise unavailable() from None

    def accounts(self) -> list[dict]:
        result = [normalize_account(row) for row in self._call("get_acc_list")]
        if len({(row["id"], row["mode"]) for row in result}) != len(result):
            raise unavailable()
        return result

    def snapshot(self, account: dict) -> dict:
        query = {"acc_id": int(account["id"]), "trd_env": account["mode"], "refresh_cache": True}
        funds = self._call("accinfo_query", **query, currency="USD")
        if len(funds) != 1:
            raise unavailable()
        fund = funds[0]
        currency = text(fund.get("currency"))
        currency_source = "broker"
        if currency in {"", "NONE", "N/A"} and account.get("markets") == ["US"]:
            # Official get-funds defines currency only for universal/futures
            # accounts. A verified single US market account uses native USD.
            currency = "USD"
            currency_source = "single_us_market_account"
        if currency != "USD":
            raise unavailable()
        positions = []
        for row in self._call("position_list_query", **query, currency="USD"):
            symbol = text(row.get("code"))
            quantity = number(row.get("qty"))
            if not symbol or quantity is None:
                raise unavailable()
            positions.append({"symbol": symbol.removeprefix("US."), "quantity": quantity,
                              "available_quantity": number(row.get("can_sell_qty")),
                              "market_value": number(row.get("market_val"))})
        orders = [normalize_order(row) for row in self._call("order_list_query", **query)]
        return {
            "account": {"id": account["id"], "mode": account["mode"], "currency": currency, "currency_source": currency_source,
                        "cash": number(fund.get("cash")), "buying_power": number(fund.get("power")),
                        "equity": number(fund.get("total_assets"))},
            "positions": positions, "orders": orders,
        }

    def unlock(self, password: str) -> None:
        context = None
        try:
            context = self._context()
            # Match the official SDK's UTF-8 MD5 transformation, without handing
            # the plaintext to its reconnect credential cache.
            ret, _ = context.unlock_trade(password_md5=hashlib.md5(password.encode("utf-8")).hexdigest())
            if ret != self.sdk.RET_OK:
                raise PersonalError("unlock_failed", "OpenD did not unlock trading. Check the password or unlock trading in the OpenD window.", 403)
        except PersonalError:
            raise
        except Exception:
            raise unavailable() from None
        finally:
            # Both supported SDK versions retain credentials here for automatic
            # re-unlock after reconnect. Personal manual trading does not do so.
            if context is not None and hasattr(context, "_ctx_unlock"):
                context._ctx_unlock = None
            password = ""

    def place(self, account: dict, intent: dict, client_id: str) -> dict:
        # There is exactly one call to place_order; a transport error is ambiguous.
        result = self._call(
            "place_order", acc_id=int(account["id"]), trd_env=account["mode"],
            price=float(Decimal(intent["limit_price"])), qty=int(intent["quantity"]),
            code="US." + intent["symbol"], trd_side=intent["side"],
            order_type="NORMAL", time_in_force="DAY", session="RTH",
            fill_outside_rth=False, adjust_limit=0, remark=client_id,
        )
        if len(result) != 1:
            raise unavailable()
        return normalize_order(result[0])

    def find_order(self, account: dict, client_id: str) -> dict | None:
        result = self._call("order_list_query", acc_id=int(account["id"]), trd_env=account["mode"], refresh_cache=True)
        matches = [row for row in result if row.get("remark") == client_id]
        if len(matches) > 1:
            raise unavailable()
        return normalize_order(matches[0]) if matches else None

    def close(self) -> None:
        if self.context is not None:
            self.context.close()
            self.context = None

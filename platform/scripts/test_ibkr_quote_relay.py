from __future__ import annotations

import importlib.util
import unittest
from datetime import UTC, datetime
from pathlib import Path
from unittest import mock

SCRIPT_PATH = Path(__file__).with_name("ibkr_quote_relay.py")
SPEC = importlib.util.spec_from_file_location("ibkr_quote_relay_under_test", SCRIPT_PATH)
assert SPEC and SPEC.loader
relay_module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(relay_module)


class FakeGateway:
    def __init__(self, availability: str = "RpB") -> None:
        self.availability = availability
        self.snapshot_calls = 0

    def request(self, path: str = "", **_kwargs):
        if path == "iserver/auth/status":
            if _kwargs.get("method") != "POST" or _kwargs.get("body") != {}:
                raise AssertionError("IBKR auth status must use a read-only POST")
            return {"authenticated": True, "connected": True, "competing": False}
        if path in ("iserver/accounts", "tickle"):
            return {}
        if path.startswith("iserver/secdef/search?"):
            symbol = path.split("symbol=", 1)[1]
            conid = {"SPY": 756733, "NVDA": 4815747}[symbol]
            return [{"symbol": symbol, "conid": conid, "sections": [{"secType": "STK"}]}]
        if path.startswith("iserver/marketdata/snapshot?"):
            self.snapshot_calls += 1
            now_ms = int(datetime.now(UTC).timestamp() * 1000)
            return [
                {
                    "conid": conid,
                    "_updated": now_ms,
                    "31": "100.01",
                    "84": "100.00",
                    "85": "12",
                    "86": "100.02",
                    "88": "10",
                    "6509": self.availability,
                }
                for conid in (756733, 4815747)
            ]
        raise AssertionError(f"unexpected Gateway path {path}")


class FakeIngest:
    def __init__(self) -> None:
        self.body = None
        self.headers = None

    def request(self, _path: str = "", **kwargs):
        self.body = kwargs["body"]
        self.headers = kwargs["headers"]
        return {
            "batch_id": self.body["batch_id"],
            "quote_count": len(self.body["quotes"]),
        }


class IbkrQuoteRelayTests(unittest.TestCase):
    def test_gateway_url_is_https_loopback_only(self):
        accepted = relay_module.validate_gateway_url(
            "https://127.0.0.1:5000/v1/api"
        )
        self.assertEqual(accepted, "https://127.0.0.1:5000/v1/api")
        for unsafe in (
            "http://127.0.0.1:5000/v1/api",
            "https://18.225.108.70:5000/v1/api",
            "https://gateway.example/v1/api",
            "https://user:secret@127.0.0.1:5000/v1/api",
        ):
            with self.assertRaises(Exception):
                relay_module.validate_gateway_url(unsafe)

    def test_ingest_url_requires_https_without_credentials(self):
        self.assertEqual(
            relay_module.validate_ingest_url(
                "https://axio7.com/api/market/ibkr/relay"
            ),
            "https://axio7.com/api/market/ibkr/relay",
        )
        with self.assertRaises(Exception):
            relay_module.validate_ingest_url(
                "http://axio7.com/api/market/ibkr/relay"
            )
        with self.assertRaises(Exception):
            relay_module.validate_ingest_url(
                "https://token@axio7.com/api/market/ibkr/relay"
            )

    def test_numeric_parser_handles_ibkr_prefix_and_units(self):
        self.assertEqual(relay_module.parse_ibkr_number("C123.45"), 123.45)
        self.assertEqual(relay_module.parse_ibkr_number("1.5K"), 1500)
        self.assertIsNone(relay_module.parse_ibkr_number("N/A"))
        self.assertIsNone(relay_module.parse_ibkr_number(float("nan")))

    def test_payload_is_quote_only_and_complete(self):
        gateway = FakeGateway()
        ingest = FakeIngest()
        relay = relay_module.IbkrQuoteRelay(
            gateway, ingest, ("SPY", "NVDA"), "x" * 32
        )
        with mock.patch.object(relay_module.time, "sleep", return_value=None):
            receipt = relay.push_once()
        self.assertEqual(receipt["quote_count"], 2)
        self.assertGreaterEqual(gateway.snapshot_calls, 2)
        self.assertEqual(
            set(ingest.body),
            {
                "schema_version",
                "batch_id",
                "source",
                "bridge_version",
                "captured_at",
                "session_authenticated",
                "quotes",
            },
        )
        self.assertNotIn("account", str(ingest.body).lower())
        self.assertNotIn("cookie", str(ingest.body).lower())
        self.assertNotIn("order", str(ingest.body).lower())
        self.assertEqual(ingest.headers["Authorization"], f"Bearer {'x' * 32}")

    def test_delayed_or_unentitled_quote_fails_before_post(self):
        gateway = FakeGateway(availability="D")
        ingest = FakeIngest()
        relay = relay_module.IbkrQuoteRelay(
            gateway, ingest, ("SPY", "NVDA"), "x" * 32
        )
        with (
            mock.patch.object(relay_module.time, "sleep", return_value=None),
            self.assertRaises(relay_module.RelayError),
        ):
            relay.push_once()
        self.assertIsNone(ingest.body)

    def test_session_must_be_authenticated_connected_and_noncompeting(self):
        class BadGateway(FakeGateway):
            def request(self, path: str = "", **kwargs):
                if path == "iserver/auth/status":
                    return {
                        "authenticated": True,
                        "connected": True,
                        "competing": True,
                    }
                return super().request(path, **kwargs)

        relay = relay_module.IbkrQuoteRelay(
            BadGateway(), FakeIngest(), ("SPY",), "x" * 32
        )
        with self.assertRaises(relay_module.RelayError):
            relay.require_session()


if __name__ == "__main__":
    unittest.main()

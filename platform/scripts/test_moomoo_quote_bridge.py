from __future__ import annotations

import argparse
import ast
import importlib.util
import io
import json
import sys
import threading
import types
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

SCRIPT_PATH = Path(__file__).with_name("moomoo_quote_bridge.py")
SPEC = importlib.util.spec_from_file_location("moomoo_quote_bridge_under_test", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bridge)


class ArgumentSafetyTests(unittest.TestCase):
    def test_loopback_host_is_required(self) -> None:
        self.assertEqual(bridge.validate_loopback_host("127.0.0.1"), "127.0.0.1")
        self.assertEqual(bridge.validate_loopback_host("::1"), "::1")
        self.assertEqual(bridge.validate_loopback_host("LOCALHOST"), "localhost")
        for unsafe in ("0.0.0.0", "192.168.1.4", "8.8.8.8", "opend.example"):
            with self.subTest(unsafe=unsafe):
                with self.assertRaises(argparse.ArgumentTypeError):
                    bridge.validate_loopback_host(unsafe)

    def test_symbols_are_normalized_deduplicated_and_bounded(self) -> None:
        self.assertEqual(
            bridge.parse_symbols("us.spy, US.MU,us.spy"),
            ("US.SPY", "US.MU"),
        )
        for unsafe in ("", "US.SPY,", "SPY", "US..SPY", "US.SPY;CALC"):
            with self.subTest(unsafe=unsafe):
                with self.assertRaises(argparse.ArgumentTypeError):
                    bridge.parse_symbols(unsafe)
        too_many = ",".join(f"US.A{i}" for i in range(bridge.MAX_SYMBOLS + 1))
        with self.assertRaises(argparse.ArgumentTypeError):
            bridge.parse_symbols(too_many)

    def test_quote_push_arguments_are_explicit(self) -> None:
        args = bridge.parse_args(
            [
                "QuotePush",
                "--host",
                "127.0.0.1",
                "--port",
                "11111",
                "--symbols",
                "US.SPY,US.SOXX",
            ]
        )
        self.assertEqual(args.command, "QuotePush")
        self.assertEqual(args.port, 11111)
        self.assertEqual(args.symbols, ("US.SPY", "US.SOXX"))
        with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            bridge.parse_args(["QuotePush", "--host", "127.0.0.1"])


class JsonMappingTests(unittest.TestCase):
    def test_kline_mapping_matches_rust_wire_schema(self) -> None:
        event = bridge.map_kline_row(
            {
                "code": "US.SPY",
                "time_key": "2026-07-21 09:31:00.000",
                "open": 742.0,
                "high": 742.5,
                "low": 741.8,
                "close": 742.2,
                "volume": 12_000,
                "turnover": 8_900_000,
                "k_type": "K_1M",
            }
        )
        self.assertEqual(
            set(event),
            {
                "event",
                "symbol",
                "event_timestamp_et",
                "open",
                "high",
                "low",
                "close",
                "volume",
                "turnover",
                "source_version",
            },
        )
        self.assertEqual(event["event"], "k_1m")
        self.assertEqual(event["event_timestamp_et"], "2026-07-21 09:31:00")
        encoded = json.dumps(event, allow_nan=False)
        self.assertEqual(json.loads(encoded)["source_version"], bridge.SOURCE_VERSION)

    def test_corrupt_kline_is_rejected(self) -> None:
        base = {
            "code": "US.SPY",
            "time_key": "2026-07-21 09:31:00",
            "open": 100,
            "high": 101,
            "low": 99,
            "close": 100.5,
            "volume": 10,
            "turnover": 1_000,
            "k_type": "K_1M",
        }
        with self.assertRaises(ValueError):
            bridge.map_kline_row({**base, "high": 98})
        with self.assertRaises(ValueError):
            bridge.map_kline_row({**base, "volume": float("nan")})
        with self.assertRaises(ValueError):
            bridge.map_kline_row({**base, "k_type": "K_DAY"})

    def test_basic_and_ticker_mapping_reuse_native_event_names(self) -> None:
        basic = bridge.map_stock_quote_row(
            {
                "code": "US.MU",
                "data_date": "2026-07-22",
                "data_time": "15:59:59.125",
                "last_price": 998.0,
                "open_price": 980.0,
                "high_price": 1_010.0,
                "low_price": 975.0,
                "volume": 2_000_000,
                "turnover": 1_990_000_000,
            }
        )
        ticker = bridge.map_ticker_row(
            {
                "code": "US.MU",
                "time": "2026-07-22 15:59:59.126",
                "price": 998.0,
                "volume": 100,
                "turnover": 99_800,
                "ticker_direction": "BUY",
                "sequence": 7_664_702_433_469_137_170,
                "type": "AUTOMATCH",
            }
        )
        self.assertEqual(basic["event"], "basic")
        self.assertEqual(ticker["event"], "ticker")
        self.assertEqual(ticker["sequence"], 7_664_702_433_469_137_170)
        json.dumps([basic, ticker], allow_nan=False)

    def test_only_emitter_can_write_protocol_stdout(self) -> None:
        protocol = io.StringIO()
        diagnostics = io.StringIO()

        def fake_runner(host, port, symbols, emitter):
            print("sdk diagnostic")
            emitter.emit({"event": "ticker", "symbol": symbols[0]})
            return 0

        with (
            mock.patch.object(bridge, "run_quote_push", side_effect=fake_runner),
            redirect_stdout(protocol),
            redirect_stderr(diagnostics),
        ):
            result = bridge.main(
                [
                    "QuotePush",
                    "--host",
                    "127.0.0.1",
                    "--port",
                    "11111",
                    "--symbols",
                    "US.SPY",
                ]
            )
        self.assertEqual(result, 0)
        self.assertEqual(
            json.loads(protocol.getvalue()),
            {"event": "ticker", "symbol": "US.SPY"},
        )
        self.assertIn("sdk diagnostic", diagnostics.getvalue())
        self.assertNotIn("sdk diagnostic", protocol.getvalue())


class CapabilityBoundaryTests(unittest.TestCase):
    def test_source_imports_only_quote_sdk_capabilities(self) -> None:
        tree = ast.parse(SCRIPT_PATH.read_text(encoding="utf-8"))
        top_level_moomoo_imports = [
            node
            for node in tree.body
            if isinstance(node, (ast.Import, ast.ImportFrom))
            and (
                getattr(node, "module", "") == "moomoo"
                or any(alias.name == "moomoo" for alias in node.names)
            )
        ]
        self.assertEqual(top_level_moomoo_imports, [])

        imported: set[str] = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom) and node.module == "moomoo":
                imported.update(alias.name for alias in node.names)
        self.assertEqual(
            imported,
            {
                "RET_OK",
                "CurKlineHandlerBase",
                "OpenQuoteContext",
                "StockQuoteHandlerBase",
                "SubType",
                "TickerHandlerBase",
                "__version__",
            },
        )

        forbidden_calls = {
            "opensectradecontext",
            "unlock_trade",
            "place_order",
            "modify_order",
            "get_acc_list",
        }
        called: set[str] = set()
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call):
                continue
            if isinstance(node.func, ast.Name):
                called.add(node.func.id.lower())
            elif isinstance(node.func, ast.Attribute):
                called.add(node.func.attr.lower())
        self.assertTrue(forbidden_calls.isdisjoint(called))

    def test_runtime_subscribes_only_three_quote_pushes_without_opend(self) -> None:
        class HandlerBase:
            def on_recv_rsp(self, response):
                return 0, response

        class FakeContext:
            instance = None

            def __init__(self, host, port):
                self.host = host
                self.port = port
                self.handlers = []
                self.subscription = None
                self.closed = False
                FakeContext.instance = self

            def set_handler(self, handler):
                self.handlers.append(handler)

            def subscribe(self, symbols, subtypes, subscribe_push):
                self.subscription = (symbols, subtypes, subscribe_push)
                return 0, "ok"

            def close(self):
                self.closed = True

        fake_moomoo = types.ModuleType("moomoo")
        fake_moomoo.RET_OK = 0
        fake_moomoo.CurKlineHandlerBase = HandlerBase
        fake_moomoo.OpenQuoteContext = FakeContext
        fake_moomoo.StockQuoteHandlerBase = HandlerBase
        fake_moomoo.TickerHandlerBase = HandlerBase
        fake_moomoo.SubType = types.SimpleNamespace(
            QUOTE="QUOTE", TICKER="TICKER", K_1M="K_1M"
        )
        fake_moomoo.__version__ = "10.09.6908"
        stopped = threading.Event()
        stopped.set()

        with mock.patch.dict(sys.modules, {"moomoo": fake_moomoo}):
            result = bridge.run_quote_push(
                "127.0.0.1",
                11111,
                ("US.SPY", "US.MU"),
                bridge.JsonLineEmitter(io.StringIO()),
                stop_event=stopped,
            )

        context = FakeContext.instance
        self.assertEqual(result, 0)
        self.assertIsNotNone(context)
        self.assertEqual(len(context.handlers), 3)
        self.assertEqual(
            context.subscription,
            (
                ["US.SPY", "US.MU"],
                ["QUOTE", "TICKER", "K_1M"],
                True,
            ),
        )
        self.assertTrue(context.closed)


if __name__ == "__main__":
    unittest.main()

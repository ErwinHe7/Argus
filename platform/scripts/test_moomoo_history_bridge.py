from __future__ import annotations

import argparse
import ast
import importlib.util
import io
import json
import sys
import types
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

SCRIPT_DIR = Path(__file__).parent
SCRIPT_PATH = SCRIPT_DIR / "moomoo_history_bridge.py"
sys.path.insert(0, str(SCRIPT_DIR))
SPEC = importlib.util.spec_from_file_location(
    "moomoo_history_bridge_under_test", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bridge)


class ArgumentSafetyTests(unittest.TestCase):
    def test_only_loopback_and_explicit_bounded_dates_are_accepted(self) -> None:
        args = bridge.parse_args(
            [
                "HistoryKline",
                "--host",
                "127.0.0.1",
                "--port",
                "11111",
                "--symbols",
                "us.nvda,US.SPY",
                "--start",
                "2026-07-20",
                "--end",
                "2026-07-24",
            ]
        )
        self.assertEqual(args.symbols, ("US.NVDA", "US.SPY"))
        self.assertEqual(args.page_size, 1000)
        for unsafe_host in ("0.0.0.0", "192.168.1.2", "opend.example"):
            with self.subTest(unsafe_host=unsafe_host):
                with self.assertRaises(SystemExit), redirect_stderr(io.StringIO()):
                    bridge.parse_args(
                        [
                            "HistoryKline",
                            "--host",
                            unsafe_host,
                            "--port",
                            "11111",
                            "--symbols",
                            "US.NVDA",
                            "--start",
                            "2026-07-20",
                            "--end",
                            "2026-07-24",
                        ]
                    )
        with self.assertRaises(SystemExit), redirect_stderr(io.StringIO()):
            bridge.parse_args(
                [
                    "HistoryKline",
                    "--host",
                    "127.0.0.1",
                    "--port",
                    "11111",
                    "--symbols",
                    "US.NVDA",
                    "--start",
                    "2026-07-25",
                    "--end",
                    "2026-07-24",
                ]
            )

    def test_page_and_export_limits_are_bounded(self) -> None:
        for value in ("0", "1001", "not-a-number"):
            with self.subTest(page_size=value):
                with self.assertRaises(argparse.ArgumentTypeError):
                    bridge.validate_page_size(value)
        for value in ("0", str(bridge.MAX_EXPORT_ROWS + 1)):
            with self.subTest(max_rows=value):
                with self.assertRaises(argparse.ArgumentTypeError):
                    bridge.validate_max_rows(value)


class SchemaAndTimeSemanticsTests(unittest.TestCase):
    def test_history_row_matches_replay_schema_without_fake_availability(self) -> None:
        event = bridge.map_history_kline_row(
            {
                "code": "US.NVDA",
                "time_key": "2026-07-23 15:15:00",
                "open": 185.1,
                "high": 185.8,
                "low": 184.9,
                "close": 185.6,
                "volume": 12_345,
                "turnover": 2_290_000,
            },
            "2026-07-27T06:30:00.123Z",
        )
        self.assertEqual(event["event"], "k_1m")
        self.assertEqual(event["symbol"], "US.NVDA")
        self.assertEqual(event["event_timestamp_et"], event["provider_time_key_et"])
        self.assertEqual(
            event["api_response_received_at_utc"],
            "2026-07-27T06:30:00.123Z",
        )
        self.assertIsNone(event["original_point_in_time_available_at"])
        self.assertIn(
            "ORIGINAL_POINT_IN_TIME_AVAILABILITY_UNKNOWN",
            event["availability_semantics"],
        )
        self.assertNotIn("provider_received_at", event)
        json.dumps(event, allow_nan=False)

    def test_dry_run_connects_to_nothing_and_emits_no_jsonl(self) -> None:
        protocol = io.StringIO()
        diagnostics = io.StringIO()
        with (
            mock.patch.object(bridge, "run_history_export") as runner,
            redirect_stdout(protocol),
            redirect_stderr(diagnostics),
        ):
            result = bridge.main(
                [
                    "HistoryKline",
                    "--host",
                    "::1",
                    "--port",
                    "11111",
                    "--symbols",
                    "US.NVDA",
                    "--start",
                    "2026-07-23",
                    "--end",
                    "2026-07-24",
                    "--dry-run",
                ]
            )
        self.assertEqual(result, 0)
        self.assertEqual(protocol.getvalue(), "")
        self.assertIn("emits_data=false", diagnostics.getvalue())
        runner.assert_not_called()


class QuoteOnlyRuntimeTests(unittest.TestCase):
    def test_paginated_runtime_uses_only_unadjusted_k1m_quote_history(self) -> None:
        class FakeFrame:
            def __init__(self, rows):
                self.rows = rows

            def to_dict(self, orient):
                self.orient = orient
                return self.rows

        class FakeContext:
            instance = None

            def __init__(self, host, port):
                self.host = host
                self.port = port
                self.calls = []
                self.closed = False
                FakeContext.instance = self

            def request_history_kline(self, **kwargs):
                self.calls.append(kwargs)
                if kwargs["page_req_key"] is None:
                    return (
                        0,
                        FakeFrame(
                            [
                                {
                                    "code": "US.NVDA",
                                    "time_key": "2026-07-23 09:31:00",
                                    "open": 180,
                                    "high": 181,
                                    "low": 179,
                                    "close": 180.5,
                                    "volume": 100,
                                    "turnover": 18_050,
                                }
                            ]
                        ),
                        b"page-2",
                    )
                return (
                    0,
                    FakeFrame(
                        [
                            {
                                "code": "US.NVDA",
                                "time_key": "2026-07-23 09:32:00",
                                "open": 180.5,
                                "high": 182,
                                "low": 180,
                                "close": 181.5,
                                "volume": 200,
                                "turnover": 36_300,
                            }
                        ]
                    ),
                    None,
                )

            def close(self):
                self.closed = True

        fake_moomoo = types.ModuleType("moomoo")
        fake_moomoo.RET_OK = 0
        fake_moomoo.AuType = types.SimpleNamespace(NONE="NONE")
        fake_moomoo.KLType = types.SimpleNamespace(K_1M="K_1M")
        fake_moomoo.OpenQuoteContext = FakeContext
        fake_moomoo.__version__ = "10.09.6908"
        output = io.StringIO()

        with mock.patch.dict(sys.modules, {"moomoo": fake_moomoo}):
            rows = bridge.run_history_export(
                "127.0.0.1",
                11111,
                ("US.NVDA",),
                "2026-07-23",
                "2026-07-23",
                1000,
                10,
                False,
                bridge.JsonLineEmitter(output),
            )

        context = FakeContext.instance
        self.assertEqual(rows, 2)
        self.assertIsNotNone(context)
        self.assertEqual(len(context.calls), 2)
        for call in context.calls:
            self.assertEqual(call["ktype"], "K_1M")
            self.assertEqual(call["autype"], "NONE")
            self.assertFalse(call["extended_time"])
        self.assertEqual(
            [json.loads(line)["event"] for line in output.getvalue().splitlines()],
            ["k_1m", "k_1m"],
        )
        self.assertTrue(context.closed)

    def test_source_imports_no_trade_capability(self) -> None:
        tree = ast.parse(SCRIPT_PATH.read_text(encoding="utf-8"))
        imported: set[str] = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom) and node.module == "moomoo":
                imported.update(alias.name for alias in node.names)
        self.assertEqual(
            imported,
            {
                "RET_OK",
                "AuType",
                "KLType",
                "OpenQuoteContext",
                "__version__",
            },
        )

        forbidden_calls = {
            "opensectradecontext",
            "unlock_trade",
            "place_order",
            "modify_order",
            "get_acc_list",
            "position_list_query",
            "order_list_query",
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


if __name__ == "__main__":
    unittest.main()

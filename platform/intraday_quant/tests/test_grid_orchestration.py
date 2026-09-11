from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
import json
import unittest

from intraday_quant.strategy_lab.grid import run_grid_engine


class GridOrchestrationTests(unittest.TestCase):
    def test_dispatches_only_grid_research_and_preserves_rust_report(self):
        result = dict(schema_version="leo-grid-result.v1", strategy="GRID-R1",
                      execution_authorized=False, paper_execution_available=False,
                      promotion_eligible=False, metrics={"total_pnl": "-125.000000"})
        with patch("intraday_quant.strategy_lab.grid.subprocess.run",
                   return_value=SimpleNamespace(returncode=0, stdout=json.dumps(result))) as call:
            self.assertEqual(run_grid_engine(Path("engine"), {"schema_version": "leo-grid-request.v1"}), result)
            self.assertEqual(json.loads(call.call_args.kwargs["input"])["operation"], "grid_replay")
            self.assertEqual(call.call_args.kwargs["encoding"], "utf-8")

    def test_input_cannot_override_operation_or_accept_invalid_numbers(self):
        for request in ({"schema_version": "leo-grid-request.v1", "operation": "replay"},
                        {"schema_version": "leo-grid-request.v1", "lower": float("nan")},
                        {"schema_version": "other"}):
            with self.assertRaises(ValueError):
                run_grid_engine(Path("unused"), request)

    def test_malformed_or_authorizing_output_is_rejected(self):
        for raw in ('[]', 'not json', '{"schema_version":"leo-grid-result.v1","execution_authorized":true}'):
            with patch("intraday_quant.strategy_lab.grid.subprocess.run",
                       return_value=SimpleNamespace(returncode=0, stdout=raw)):
                with self.assertRaises(ValueError):
                    run_grid_engine(Path("engine"), {"schema_version": "leo-grid-request.v1"})

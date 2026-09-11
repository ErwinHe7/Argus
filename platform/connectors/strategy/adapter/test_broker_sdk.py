import sys
import types
import unittest
from unittest.mock import patch

import broker_sdk


class SelectionTests(unittest.TestCase):
    def run_adapter(self, arguments, expected, forwarded):
        calls = []
        modules = {name: types.SimpleNamespace(main=lambda n=name: calls.append((n, sys.argv[1:])))
                   for name in ("paper_sdk", "ibkr_gateway")}
        original = ["broker_sdk.py", *arguments]
        with patch.dict(sys.modules, modules), patch.object(sys, "argv", original):
            broker_sdk.main()
            self.assertIs(sys.argv, original)
        self.assertEqual(calls, [(expected, forwarded)])

    def test_existing_moomoo_configuration_is_compatible(self):
        self.run_adapter(["--security-firm", "FUTUINC"], "paper_sdk", ["--security-firm", "FUTUINC"])

    def test_ibkr_flags_reach_only_the_selected_adapter(self):
        self.run_adapter(["--broker=ibkr-gateway", "--self-check"], "ibkr_gateway", ["--self-check"])

    def test_invalid_provider_cannot_fall_back_to_moomoo(self):
        with patch.object(sys, "argv", ["broker_sdk.py", "--broker", "other"]):
            with self.assertRaises(SystemExit) as error:
                broker_sdk.main()
        self.assertEqual(error.exception.code, 2)


if __name__ == "__main__":
    unittest.main()

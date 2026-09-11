import json
import socket
import unittest
from unittest.mock import patch

import broker_readiness as readiness


class ReadinessTests(unittest.TestCase):
    def test_open_port_never_claims_broker_authentication_or_paper_identity(self):
        def listening(port):
            return {"host": "127.0.0.1", "port": port, "status": "tcp_listener_present_identity_unverified"}
        result = readiness.report(programs={"programs": []}, probe=listening, versions=lambda: [])
        for broker in result["brokers"]:
            self.assertEqual(broker["authenticated"], "not_checked")
            self.assertEqual(broker["paperAccount"], "not_checked")
            self.assertFalse(broker["tradingAuthorized"])
        self.assertIn("port number is not proof", result["brokers"][1]["nextStep"])

    def test_moomoo_desktop_is_not_opend(self):
        self.assertEqual(readiness.classify_program("moomoo"), "moomoo-desktop")
        self.assertEqual(readiness.classify_program("moomoo OpenD"), "moomoo-opend")
        self.assertEqual(readiness.classify_program("Trader Workstation"), "ibkr-gateway")
        self.assertIsNone(readiness.classify_program("Unrelated personal application"))

    def test_socket_probe_only_connects_to_loopback_without_sending_data(self):
        with patch.object(socket, "create_connection") as connect:
            self.assertEqual(readiness.probe_port(11111)["status"], "tcp_listener_present_identity_unverified")
            connect.assert_called_once_with(("127.0.0.1", 11111), timeout=0.5)
            connect.return_value.__enter__.return_value.send.assert_not_called()
            connect.return_value.__enter__.return_value.sendall.assert_not_called()
        for port in (7496, 4001, 80, 443):
            with self.assertRaises(ValueError):
                readiness.probe_port(port)

    def test_unavailable_listener_has_actionable_next_step_not_zero_balances(self):
        with patch.object(socket, "create_connection", side_effect=ConnectionRefusedError):
            port = readiness.probe_port(4002)
        self.assertEqual(port["status"], "no_tcp_listener_observed")
        self.assertIn("Paper Trading", readiness.next_step("ibkr-tws", [port]))
        self.assertNotIn("balance", json.dumps(port))

    def test_client_portal_is_separate_from_tws_and_requires_verified_tls(self):
        result = readiness.next_step("ibkr", [{"status": "no_tcp_listener_observed"}])
        self.assertIn("Client Portal Gateway", result)
        self.assertIn("verified TLS", result)
        self.assertIn("TWS is a different gateway", result)
        self.assertEqual(readiness.PORTS["ibkr"], (5000,))

    def test_metadata_probe_does_not_import_broker_sdk(self):
        with patch.object(readiness.importlib.metadata, "version", return_value="0.0.0"):
            self.assertTrue(all(x["status"] == "missing_or_different_version" for x in readiness.sdk_versions()))


if __name__ == "__main__":
    unittest.main()

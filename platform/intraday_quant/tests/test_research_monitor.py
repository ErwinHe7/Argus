import http.client
import json
import tempfile
import threading
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from intraday_quant.strategy_lab.monitor import MonitorServer, snapshot


class ResearchMonitorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.state = Path(self.temp.name).resolve()
        self.raw = {"schema_version": "leo-continuous-research-status.v1", "state": "waiting",
                    "heartbeat_at": datetime.now(timezone.utc).isoformat(), "interval_seconds": 30,
                    "execution_authorized": False, "promotion_eligible": False, "llm_calls": 0,
                    "counters": {"trials": 1, "completed": 1}, "jobs": []}
        self.write()
        self.server = MonitorServer(0, self.state)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.temp.cleanup)
        self.addCleanup(self.close_server)

    def close_server(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def write(self):
        (self.state / "status.json").write_text(json.dumps(self.raw))

    def request(self, method, path, body=None, headers=None):
        connection = http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=3)
        try:
            connection.request(method, path, body, headers or {})
            response = connection.getresponse()
            return response.status, response.read(), dict(response.getheaders())
        finally:
            connection.close()

    def control_headers(self):
        return {"Content-Type": "application/json", "Origin": f"http://127.0.0.1:{self.server.server_port}",
                "X-Leo-Control": self.server.control_token}

    def test_loopback_host_origin_and_token_gate_controls(self):
        status, _, headers = self.request("GET", "/api/status", headers={"Host": "attacker.example"})
        self.assertEqual(status, 403)
        self.assertNotIn("Access-Control-Allow-Origin", headers)
        self.assertEqual(self.request("GET", "/api/status", headers={"Origin": "https://attacker.example"})[0], 403)
        self.assertEqual(self.request("POST", "/api/control", '{"action":"pause"}', {"Content-Type": "application/json"})[0], 403)
        self.assertFalse((self.state / "STOP").exists())
        self.assertEqual(self.request("POST", "/api/control", '{"action":"pause"}', self.control_headers())[0], 202)
        self.assertTrue((self.state / "STOP").exists())
        self.assertEqual(self.request("POST", "/api/control", '{"action":"resume"}', self.control_headers())[0], 202)
        self.assertFalse((self.state / "STOP").exists())

    def test_stale_values_preserved_but_resume_rejected(self):
        self.raw["heartbeat_at"] = (datetime.now(timezone.utc) - timedelta(seconds=80)).isoformat()
        self.write()
        result = snapshot(self.state)
        self.assertFalse(result["fresh"])
        self.assertEqual(result["counters"]["trials"], 1)
        (self.state / "STOP").touch()
        self.assertEqual(self.request("POST", "/api/control", '{"action":"resume"}', self.control_headers())[0], 409)
        self.assertTrue((self.state / "STOP").exists())

    def test_no_file_or_order_endpoint_and_no_extra_control_fields(self):
        for path in ("/../status.json", "/api/order", "/api/report?path=C:/private"):
            self.assertEqual(self.request("GET", path)[0], 404)
        self.assertEqual(self.request("POST", "/api/control", '{"action":"buy"}', self.control_headers())[0], 400)
        self.assertEqual(self.request("POST", "/api/control", '{"action":"pause","command":"x"}', self.control_headers())[0], 400)

    def test_invalid_authority_or_future_heartbeat_fails_closed(self):
        self.raw["execution_authorized"] = True
        self.write()
        self.assertEqual(snapshot(self.state)["state"], "unavailable")
        self.raw["execution_authorized"] = False
        self.raw["heartbeat_at"] = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
        self.write()
        self.assertFalse(snapshot(self.state)["fresh"])

    def test_only_capability_metadata_and_no_local_paths_are_exposed(self):
        directory = self.state / "results" / "one"
        directory.mkdir(parents=True)
        result_path = directory / "result.json"
        result_path.write_text(json.dumps({"schema_version": "leo-continuous-research-result.v1",
            "source_capability": {"schema_version": "leo-strategy-source-capability.v1", "source": "Test source",
                "symbols": [{"symbol": "TEST", "observed_sessions": 12, "blockers": ["fewer_than_220_completed_sessions"], "bars": [{"close": "PRIVATE"}]}]}}))
        self.raw["jobs"] = [{"id": "source", "kind": "source-capability", "state": "insufficient_evidence", "result_path": str(result_path)}]
        self.raw["state_dir"] = str(self.state)
        self.write()
        exposed = snapshot(self.state)
        self.assertEqual(exposed["coverage"][0]["observed_sessions"], 12)
        self.assertEqual(exposed["attention_count"], 1)
        self.assertNotIn("PRIVATE", json.dumps(exposed))
        self.assertNotIn(str(self.state), json.dumps(exposed))

    def test_dashboard_csp_and_missing_status(self):
        status, body, headers = self.request("GET", "/")
        self.assertEqual(status, 200)
        self.assertIn(self.server.control_token.encode(), body)
        self.assertIn("frame-ancestors 'none'", headers["Content-Security-Policy"])
        (self.state / "status.json").unlink()
        self.assertFalse(snapshot(self.state)["fresh"])


if __name__ == "__main__":
    unittest.main()

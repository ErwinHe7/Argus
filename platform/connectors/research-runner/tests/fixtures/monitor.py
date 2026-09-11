"""Loopback-only process fixture; no market data, credentials or external requests."""
import argparse
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--config", required=True)
parser.add_argument("--port", required=True)
args = parser.parse_args()
state = Path(json.loads(Path(args.config).read_text(encoding="utf-8-sig"))["state_dir"])
from .redirector_helper import detach_runtime
detach_runtime()

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        self.send_response(204)
        self.end_headers()

with HTTPServer(("127.0.0.1", int(args.port)), Handler) as server:
    server.timeout = 0.1
    while not (state / "MONITOR_SHUTDOWN").exists():
        server.handle_request()

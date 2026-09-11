"""Run with python -m scripts.personal_moomoo from platform/."""
from __future__ import annotations

import argparse
import hmac
import json
import os
import re
import signal
import threading
from decimal import Decimal, InvalidOperation
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from .adapter import MoomooAdapter
from .errors import PersonalError, unavailable
from .journal import Journal
from .service import PersonalService


def strict_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON field")
        result[key] = value
    return result


def invalid_constant(_value):
    raise ValueError("non-finite JSON")


class Server(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = False

    def __init__(self, port: int, token: str, service: PersonalService):
        self.token, self.service = token, service
        super().__init__(("127.0.0.1", port), Handler)


class Handler(BaseHTTPRequestHandler):
    server: Server
    protocol_version = "HTTP/1.0"

    def setup(self):
        super().setup()
        self.connection.settimeout(15)

    def log_message(self, _format, *_args):
        pass

    def _reply(self, status: int, payload: dict):
        encoded = json.dumps(payload, separators=(",", ":"), allow_nan=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(encoded)

    def _auth(self) -> str:
        if (self.client_address[0] != "127.0.0.1"
                or len(self.headers.get_all("Host", [])) != 1
                or self.headers.get("Host") != f"127.0.0.1:{self.server.server_port}"
                or self.headers.get("Origin") is not None
                or len(self.headers.get_all("Authorization", [])) != 1
                or not hmac.compare_digest(self.headers.get("Authorization", ""), "Bearer " + self.server.token)):
            raise PersonalError("unauthorized", "This local gateway accepts authenticated requests from Leo only.", 401)
        sessions = self.headers.get_all("X-Leo-Session", [])
        if len(sessions) != 1:
            raise PersonalError("session_required", "A local browser session is required.", 401)
        return sessions[0]

    def _body(self) -> dict:
        content_type = self.headers.get("Content-Type", "").split(";", 1)[0].strip().lower()
        lengths = self.headers.get_all("Content-Length", [])
        if content_type != "application/json" or self.headers.get("Transfer-Encoding") or len(lengths) != 1:
            raise PersonalError("invalid_request", "Send one JSON request body.")
        try:
            length = int(lengths[0])
            if not 1 <= length <= 8192:
                raise ValueError()
            value = json.loads(self.rfile.read(length), object_pairs_hook=strict_object, parse_constant=invalid_constant)
            if not isinstance(value, dict):
                raise ValueError()
            return value
        except (ValueError, UnicodeDecodeError):
            raise PersonalError("invalid_request", "The request must be a valid JSON object smaller than 8 KB.") from None

    def _run(self, post: bool):
        try:
            session = self._auth()
            service = self.server.service
            if post:
                methods = {"/connect": service.connect, "/disconnect": service.disconnect,
                           "/unlock": service.unlock, "/previews": service.preview, "/confirm": service.confirm}
                discard_path = re.fullmatch(r"/previews/([a-z0-9-]{20,64})/discard", self.path)
                if self.path not in methods and not discard_path:
                    raise PersonalError("not_found", "Unknown local broker endpoint.", 404)
                payload = self._body()
                try:
                    result = (service.discard_preview(session, discard_path.group(1), payload)
                              if discard_path else methods[self.path](session, payload))
                finally:
                    payload.clear()
            elif self.path in {"/status", "/accounts", "/snapshot"}:
                result = {"/status": service.status, "/accounts": service.accounts, "/snapshot": service.snapshot}[self.path](session)
            elif re.fullmatch(r"/commands/[a-z0-9-]{20,64}", self.path):
                result = service.command(session, self.path.removeprefix("/commands/"))
            elif re.fullmatch(r"/previews/[a-z0-9-]{20,64}/command", self.path):
                result = service.preview_command(session, self.path.split("/")[2])
            else:
                raise PersonalError("not_found", "Unknown local broker endpoint.", 404)
            self._reply(200, result)
        except PersonalError as error:
            self._reply(error.status, {"error": error.code, "message": error.message})
        except Exception:
            error = unavailable()
            self._reply(error.status, {"error": error.code, "message": error.message})

    def do_GET(self):  # noqa: N802
        self._run(False)

    def do_POST(self):  # noqa: N802
        self._run(True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Leo personal moomoo gateway (loopback only, no autonomous orders)")
    parser.add_argument("--port", type=int, default=8766)
    parser.add_argument("--journal", type=Path, default=Path(".quant-runtime/personal-moomoo/orders.sqlite3"))
    parser.add_argument("--max-order-notional", default="500.00")
    parser.add_argument("--allow-live", action="store_true", help="Permit explicitly confirmed REAL orders; off by default")
    args = parser.parse_args()
    token = os.environ.get("LEO_PERSONAL_GATEWAY_TOKEN", "")
    if len(token) < 32 or len(token) > 256 or not token.isascii() or any(ord(char) < 33 or ord(char) > 126 for char in token):
        parser.error("Set LEO_PERSONAL_GATEWAY_TOKEN to 32-256 random printable ASCII characters")
    if not 1024 <= args.port <= 65535:
        parser.error("port must be between 1024 and 65535")
    try:
        cap = Decimal(args.max_order_notional)
        service = PersonalService(MoomooAdapter(), Journal(args.journal.resolve()), cap, args.allow_live)
    except (InvalidOperation, ValueError):
        parser.error("max-order-notional must be a positive cent amount up to 1000000")
    server = Server(args.port, token, service)

    def stop(_signal, _frame):
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    print(json.dumps({"status": "listening", "host": "127.0.0.1", "port": args.port, "live_enabled": args.allow_live}), flush=True)
    try:
        server.serve_forever(poll_interval=0.25)
    finally:
        server.server_close()
        service.adapter.close()
        service.journal.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

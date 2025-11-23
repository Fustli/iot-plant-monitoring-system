#!/usr/bin/env python3
"""Tiny mock cloud server for testing gateway forwarding and poller.

Provides:
- POST /telemetry   : accepts JSON telemetry from the gateway and logs it
- GET  /commands    : returns a JSON command or list of commands for the gateway poller

Usage:
    python mock_server.py

By default the server listens on 0.0.0.0:8000. You can set the
`MOCK_COMMANDS` environment variable to change the JSON the server returns
for `/commands` (must be valid JSON). If unset, a sample command is returned.
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
import urllib.parse
import sys
from typing import Tuple


DEFAULT_COMMANDS = [
    {"topic": "home/actuators/led1/set", "payload": {"state": "on"}, "qos": 1}
]


def load_commands() -> object:
    raw = os.getenv("MOCK_COMMANDS")
    if not raw:
        return DEFAULT_COMMANDS
    try:
        return json.loads(raw)
    except Exception:
        print("Invalid JSON in MOCK_COMMANDS, falling back to default", file=sys.stderr)
        return DEFAULT_COMMANDS


class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, data: object, content_type: str = "application/json"):
        body = json.dumps(data).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/telemetry":
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length) if length else b""
            try:
                payload = json.loads(raw.decode("utf-8")) if raw else None
            except Exception:
                payload = raw.decode("utf-8", errors="ignore")

            print("[MOCK] Received telemetry:", payload)
            # echo back a simple acknowledgement
            self._send(200, {"status": "ok"})
            return

        # not found
        self._send(404, {"error": "not found"})

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/commands":
            cmds = load_commands()
            # Return commands as-is (either single object or list)
            self._send(200, cmds)
            print("[MOCK] Served /commands ->", cmds)
            return

        if parsed.path == "/":
            self._send(200, {"info": "mock cloud server", "routes": ["/telemetry (POST)", "/commands (GET)"]})
            return

        self._send(404, {"error": "not found"})


def run(host: str = "0.0.0.0", port: int = 8000):
    server = HTTPServer((host, port), Handler)
    print(f"Mock server listening on http://{host}:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Shutting down mock server")
    finally:
        server.server_close()


if __name__ == "__main__":
    port = int(os.getenv("MOCK_PORT", "8000"))
    host = os.getenv("MOCK_HOST", "0.0.0.0")
    run(host, port)

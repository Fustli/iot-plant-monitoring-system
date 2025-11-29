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
import threading
import time
from typing import Tuple, List
import requests


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


# Registered callback URLs that the cloud will POST commands to
_registered_callbacks: List[str] = []


def _invoke_callbacks(payload: object):
    """POST `payload` (JSON) to all registered callback URLs in background."""
    def _post(cb_url: str, data: object):
        try:
            r = requests.post(cb_url, json=data, timeout=5)
            print(f"[MOCK] Posted to {cb_url} -> status {r.status_code}")
        except Exception as e:
            print(f"[MOCK] Failed to post to {cb_url}: {e}")

    for cb in list(_registered_callbacks):
        t = threading.Thread(target=_post, args=(cb, payload), daemon=True)
        t.start()


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

        if parsed.path == "/register":
            # Expect JSON body: {"callback": "http://.../commands"}
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length) if length else b""
            try:
                data = json.loads(raw.decode("utf-8")) if raw else {}
            except Exception:
                data = {}

            cb = data.get("callback")
            if not cb:
                self._send(400, {"error": "callback required"})
                return

            if cb not in _registered_callbacks:
                _registered_callbacks.append(cb)
                print(f"[MOCK] Registered callback: {cb}")

            # Optionally trigger an immediate command to the gateway to test callback
            # Send a sample command asynchronously
            sample = load_commands()
            _invoke_callbacks(sample)

            self._send(200, {"status": "registered", "callback": cb})
            return

        if parsed.path == "/trigger":
            # Trigger sending a command to registered callbacks. Body is optional JSON payload
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length) if length else b""
            try:
                data = json.loads(raw.decode("utf-8")) if raw else load_commands()
            except Exception:
                data = load_commands()

            print("[MOCK] Triggering callbacks ->", data)
            _invoke_callbacks(data)
            self._send(200, {"status": "triggered"})
            return

        # not found
        self._send(404, {"error": "not found"})

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/":
            self._send(200, {"info": "mock cloud server", "routes": ["/telemetry (POST)", "/register (POST)", "/trigger (POST)"]})
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

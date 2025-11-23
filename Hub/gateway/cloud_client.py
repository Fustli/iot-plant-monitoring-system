"""Simple cloud client that uses a JSON spec to determine endpoint details.

The client is intentionally small: it reads a spec (if present) and exposes
`send(payload)` so upper layers don't need to know request details.
"""
import json
import os
import requests
from typing import Optional


class CloudClient:
    """Minimal cloud client used by the gateway.

    Behavior:
    - Load a small JSON spec if `spec_path` is provided and exists.
    - Allow overriding the endpoint via `endpoint_override` or `CLOUD_ENDPOINT` env var.
    - Support an optional API key via env `CLOUD_API_KEY` and header name `CLOUD_API_KEY_HEADER`.
    - Expose `send(payload)` and `get(path)` helpers.
    """

    def __init__(self, spec_path: Optional[str] = None, endpoint_override: Optional[str] = None):
        self.session = requests.Session()
        self.spec = {}
        if spec_path and os.path.exists(spec_path):
            try:
                with open(spec_path, "r", encoding="utf-8") as fh:
                    self.spec = json.load(fh)
            except Exception:
                self.spec = {}

        # Determine endpoint: explicit override -> env var -> spec default -> None
        env_endpoint = os.getenv("CLOUD_ENDPOINT")
        if endpoint_override:
            self.endpoint = endpoint_override
        elif env_endpoint:
            self.endpoint = env_endpoint
        else:
            self.endpoint = self.spec.get("default_endpoint")

        self.default_headers = {"Content-Type": "application/json"}
        api_key = os.getenv("CLOUD_API_KEY")
        if api_key:
            header_name = os.getenv("CLOUD_API_KEY_HEADER", "x-api-key")
            self.default_headers[header_name] = api_key

    def send(self, payload: dict, timeout: int = 5):
        """POST JSON payload to the configured endpoint. Returns requests.Response.

        Raises RuntimeError if no endpoint configured.
        """
        if not self.endpoint:
            raise RuntimeError("No cloud endpoint configured for CloudClient")

        r = self.session.post(self.endpoint, json=payload, headers=self.default_headers, timeout=timeout)
        return r

    def get(self, path: str, timeout: int = 5):
        """GET helper. `path` may be a full URL or a path appended to the configured endpoint."""
        if not path:
            raise ValueError("path is required for GET")

        if path.startswith("http"):
            url = path
        else:
            if not self.endpoint:
                raise RuntimeError("No cloud endpoint configured for GET requests")
            url = f"{self.endpoint.rstrip('/')}/{path.lstrip('/')}"
        return self.session.get(url, headers=self.default_headers, timeout=timeout)

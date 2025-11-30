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
    - Use a configured endpoint via `endpoint_override` or `CLOUD_ENDPOINT` env var.
    - Support an optional API key via env `CLOUD_API_KEY` and header name `CLOUD_API_KEY_HEADER`.
    - Expose `send(payload)`, `post(path, payload)` and `get(path)` helpers.
    """

    def __init__(self, endpoint_override: Optional[str] = None):
        self.session = requests.Session()

        # Determine endpoint: explicit override -> env var -> None
        env_endpoint = os.getenv("CLOUD_ENDPOINT")
        if endpoint_override:
            self.endpoint = endpoint_override
        elif env_endpoint:
            self.endpoint = env_endpoint
        else:
            self.endpoint = None

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

    def post(self, path: str, payload: dict, headers=None, timeout: int = 5):
        """POST JSON payload to a path on the configured endpoint.

        `path` may be a full URL or a path appended to the configured endpoint.
        Returns requests.Response.
        """
        if not path:
            raise ValueError("path is required for post")

        if path.startswith("http"):
            url = path
        else:
            if not self.endpoint:
                raise RuntimeError("No cloud endpoint configured for POST requests")
            url = f"{self.endpoint.rstrip('/')}/{path.lstrip('/')}"

        if headers is None:
            headers = self.default_headers

        return self.session.post(url, json=payload, headers=headers, timeout=timeout)

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

    def register(self, callback_url: str, path: str | None = None, timeout: int = 5):
        """Register a gateway callback URL with the cloud.
        The registration path is chosen in this order:
        1. explicit `path` argument
        2. environment variable `CLOUD_REGISTRATION_PATH`
        3. default 'register'

        The request body will be JSON: {"callback": <callback_url>}.
        Returns requests.Response.
        """
        if not callback_url:
            raise ValueError("callback_url is required for register")

        reg_path = path or os.getenv("CLOUD_REGISTRATION_PATH") or "register"

        if reg_path.startswith("http"):
            url = reg_path
        else:
            if not self.endpoint:
                raise RuntimeError("No cloud endpoint configured for registration")
            url = f"{self.endpoint.rstrip('/')}/{reg_path.lstrip('/')}"

        payload = {"callback": callback_url}
        return self.session.post(url, json=payload, headers=self.default_headers, timeout=timeout)

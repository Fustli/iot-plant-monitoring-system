#!/usr/bin/env python3
"""Invoke an Azure IoT Hub direct method on a device.

Reads configuration from environment variables or Docker secrets.

Env / secret fallback order:
- IOTHUB_CONNECTION_STRING or /run/secrets/iothub_connection_string
- DEVICE_ID or /run/secrets/device_id
- METHOD_NAME (default: "reboot")
- METHOD_PAYLOAD (JSON string) or empty

This script uses plain HTTP to call the IoT Hub direct method REST API and
generates a SAS token from the service shared access key.
"""
import os
import time
import hmac
import base64
import hashlib
import urllib.parse
import requests
import json
import sys


def read_secret(env_name: str, secret_name: str) -> str | None:
    v = os.getenv(env_name)
    if v:
        return v
    secret_path = f"/run/secrets/{secret_name}"
    try:
        with open(secret_path, "r", encoding="utf-8") as fh:
            return fh.read().strip()
    except Exception:
        return None


def parse_connection_string(conn_str: str):
    parts = dict(kv.split("=", 1) for kv in conn_str.split(";") if kv)
    return parts.get("HostName"), parts.get("SharedAccessKeyName"), parts.get("SharedAccessKey")


def generate_sas_token(resource_uri: str, key: str, key_name: str = None, expiry_in_seconds: int = 3600):
    expiry = int(time.time()) + expiry_in_seconds
    to_sign = f"{resource_uri}\n{expiry}"
    key_bytes = base64.b64decode(key)
    signature = base64.b64encode(hmac.new(key_bytes, to_sign.encode("utf-8"), hashlib.sha256).digest())
    sig = urllib.parse.quote_plus(signature)
    token = f"SharedAccessSignature sr={urllib.parse.quote_plus(resource_uri)}&sig={sig}&se={expiry}"
    if key_name:
        token += f"&skn={urllib.parse.quote_plus(key_name)}"
    return token


def invoke_direct_method(conn_str: str, device_id: str, method_name: str, payload=None, response_timeout=200, connect_timeout=5):
    hostname, key_name, key = parse_connection_string(conn_str)
    if not (hostname and key):
        raise ValueError("Invalid connection string")

    resource_uri = hostname
    sas = generate_sas_token(resource_uri, key, key_name, expiry_in_seconds=3600)

    url = f"https://{hostname}/twins/{urllib.parse.quote(device_id)}/methods?api-version=2020-09-30"
    body = {
        "methodName": method_name,
        "responseTimeoutInSeconds": response_timeout,
        "payload": payload or {}
    }
    headers = {
        "Authorization": sas,
        "Content-Type": "application/json"
    }

    resp = requests.post(url, headers=headers, json=body, timeout=connect_timeout + response_timeout)
    resp.raise_for_status()
    return resp.json()


def main():
    time.sleep(10)  # Wait for dependent services to be ready
    print("Starting invoke_method.py...")

    conn = read_secret("IOTHUB_CONNECTION_STRING", "iothub_connection_string")
    if not conn:
        print("IOTHUB_CONNECTION_STRING not found in env or secrets", file=sys.stderr)
        sys.exit(2)

    device = read_secret("DEVICE_ID", "device_id") or os.getenv("DEVICE_ID")
    if not device:
        print("DEVICE_ID not provided", file=sys.stderr)
        sys.exit(2)

    method = "execute"
    payload_raw = '{"topic": "home/actuators/led1/set","payload": {"state": "on"}}'
    if payload_raw:
        try:
            payload = json.loads(payload_raw)
        except Exception:
            payload = payload_raw
    else:
        payload = {"requested_by": "invoke_method.py"}

    print(f"Invoking method {method} on {device}...")
    try:
        res = invoke_direct_method(conn, device, method, payload)
        print(json.dumps(res, indent=2))
    except Exception as e:
        print("Invocation failed:", e, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

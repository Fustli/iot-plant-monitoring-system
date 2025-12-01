"""Helpers to invoke Azure IoT Hub direct methods from the server.

This module provides a minimal, dependency-light helper to build a
SharedAccessSignature and call the IoT Hub service REST API to invoke a
direct method on a device (often a hub gateway) registered with IoT Hub.

The implementation is intentionally small and synchronous so it can be
used from existing FastAPI request handlers or background threads.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import time
from typing import Any, Dict, Optional
from urllib.parse import quote_plus, parse_qsl

import requests


def _parse_connection_string(conn: str) -> Dict[str, str]:
    parts = dict(parse_qsl(conn.replace(";", "&")))
    # keys in connection string are case-sensitive in some clients; normalize
    return {k: v for k, v in parts.items()}


def _create_sas_token(hostname: str, key_name: Optional[str], shared_key: str, expiry_seconds: int = 3600) -> str:
    expiry = int(time.time()) + int(expiry_seconds)
    resource_uri = hostname.lower()

    to_sign = quote_plus(resource_uri) + "\n" + str(expiry)
    key = base64.b64decode(shared_key)
    signature = base64.b64encode(hmac.new(key, to_sign.encode("utf-8"), hashlib.sha256).digest()).decode()

    token = f"SharedAccessSignature sr={quote_plus(resource_uri)}&sig={quote_plus(signature)}&se={expiry}"
    if key_name:
        token = token + f"&skn={quote_plus(key_name)}"
    return token


def invoke_direct_method(
    iothub_connection_string: str,
    target_device_id: str,
    method_name: str,
    payload: Any,
    response_timeout_seconds: int = 30,
    sas_ttl_seconds: int = 3600,
    request_timeout: int = 30,
) -> Dict[str, Any]:
    """Invoke a direct method on a device via the IoT Hub service REST API.

    Args:
        iothub_connection_string: Service-style connection string for the IoT Hub
            (e.g. "HostName=...;SharedAccessKeyName=...;SharedAccessKey=...").
        target_device_id: The device (or hub) device id to invoke the method on.
        method_name: The method name to invoke on the device client.
        payload: JSON-serializable payload to send as the method payload.
        response_timeout_seconds: How long IoT Hub should wait for device response.
        sas_ttl_seconds: TTL for the generated SAS token.
        request_timeout: timeout in seconds for the HTTP request.

    Returns:
        Parsed JSON response from IoT Hub containing the device response.

    Raises:
        Exception on non-2xx responses or network errors.
    """
    parsed = _parse_connection_string(iothub_connection_string)
    hostname = parsed.get("HostName") or parsed.get("hostName")
    key_name = parsed.get("SharedAccessKeyName") or parsed.get("sharedAccessKeyName")
    shared_key = parsed.get("SharedAccessKey") or parsed.get("sharedaccesskey")

    if not hostname or not shared_key:
        raise ValueError("Invalid IoT Hub connection string; missing HostName or SharedAccessKey")

    sas = _create_sas_token(hostname, key_name, shared_key, expiry_seconds=sas_ttl_seconds)

    url = f"https://{hostname}/twins/{target_device_id}/methods?api-version=2020-09-30"

    body = {
        "methodName": method_name,
        "responseTimeoutInSeconds": int(response_timeout_seconds),
        "payload": payload,
    }

    headers = {
        "Authorization": sas,
        "Content-Type": "application/json",
    }

    resp = requests.post(url, json=body, headers=headers, timeout=request_timeout)
    if not resp.ok:
        raise Exception(f"Invoke direct method failed: {resp.status_code} {resp.text}")

    return resp.json()
import base64, hmac, hashlib, urllib.parse, time, requests
from fastapi import HTTPException
from typing import Any, Dict

def invoke_direct_method(iothub_conn_str: str, target_device_id: str, method_topic: str, method_payload: Any, timeout=10) -> Dict:
    # parse connection string
    parts = dict([p.split("=", 1) for p in iothub_conn_str.split(";") if "=" in p])
    host = parts.get("HostName")
    sk_name = parts.get("SharedAccessKeyName")
    sk = parts.get("SharedAccessKey")
    if not host or not sk:
        raise HTTPException(status_code=400, detail="Invalid IoT Hub connection string")
    if not sk_name:
        raise HTTPException(status_code=400, detail="Service connection string required (contains SharedAccessKeyName)")

    expiry = int(time.time()) + 60 * 5
    resource = f"{host}/devices/{target_device_id}"
    string_to_sign = urllib.parse.quote_plus(resource) + "\n" + str(expiry)
    key = base64.b64decode(sk)
    signature = base64.b64encode(hmac.new(key, string_to_sign.encode("utf-8"), hashlib.sha256).digest())
    sas = f"SharedAccessSignature sr={urllib.parse.quote_plus(resource)}&sig={urllib.parse.quote_plus(signature.decode())}&se={expiry}&skn={urllib.parse.quote_plus(sk_name)}"

    api_version = "2020-09-30"
    url = f"https://{host}/twins/{urllib.parse.quote(target_device_id)}/methods?api-version={api_version}"
    body = {
        "topic": method_topic,
        "responseTimeoutInSeconds": 30,
        "payload": method_payload,
    }
    headers = {"Authorization": sas, "Content-Type": "application/json", "Accept": "application/json"}
    resp = requests.post(url, json=body, headers=headers, timeout=timeout)
    if resp.status_code < 200 or resp.status_code >= 300:
        raise HTTPException(status_code=502, detail=f"IoT Hub invoke failed: status={resp.status_code} body={resp.text}")
    return resp.json()
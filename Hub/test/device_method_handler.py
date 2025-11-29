#!/usr/bin/env python3
"""Device-side sample that listens for Direct Methods from IoT Hub.

This script prefers to read its device connection string from Docker secrets
(`device_connection_string`) or the `DEVICE_CONNECTION_STRING` env var.

Requires: `azure-iot-device` package. When running in docker-compose the service
is configured to `pip install` the dependency at container start.
"""
import os
import sys
import json

try:
    from azure.iot.device import IoTHubDeviceClient, MethodResponse
except Exception:
    print("Missing package azure-iot-device. Install with: pip install azure-iot-device", file=sys.stderr)
    raise


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


def main():
    conn_str = read_secret("DEVICE_CONNECTION_STRING", "device_connection_string")
    if not conn_str:
        print("DEVICE_CONNECTION_STRING not found in env or secrets", file=sys.stderr)
        sys.exit(2)

    client = IoTHubDeviceClient.create_from_connection_string(conn_str)

    def handle_method_request(method_request):
        print("Received method:", method_request.name, "payload:", method_request.payload)
        # Example: echo the payload back in a success response
        result_payload = {"status": "ok", "method": method_request.name, "received": method_request.payload}
        response = MethodResponse.create_from_method_request(method_request, status=200, payload=result_payload)
        client.send_method_response(response)

    try:
        print("Device client connecting and waiting for direct methods...")
        client.connect()
        while True:
            method_request = client.receive_method_request()  # blocking
            handle_method_request(method_request)
    except KeyboardInterrupt:
        print("Shutting down")
    finally:
        try:
            client.shutdown()
        except Exception:
            pass


if __name__ == "__main__":
    main()

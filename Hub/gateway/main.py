import os
from gateway import run


def _env(name: str, default: str) -> str:
    return os.getenv(name, default)


if __name__ == "__main__":
    BROKER_HOST = _env("MQTT_BROKER_HOST", "broker")
    HUB_ID = _env("HUB_ID", "unknown_hub")
    CLOUD_ENDPOINT = _env("CLOUD_ENDPOINT", "http://localhost/api")
    GATEWAY_LISTEN_HOST = _env("GATEWAY_LISTEN_HOST", "0.0.0.0")
    GATEWAY_LISTEN_PORT = int(_env("GATEWAY_LISTEN_PORT", "8080"))
    GATEWAY_ADVERTISED_URL = os.getenv("GATEWAY_ADVERTISED_URL")

    run(BROKER_HOST, HUB_ID, CLOUD_ENDPOINT, None, None, 5, 1, GATEWAY_LISTEN_HOST, GATEWAY_LISTEN_PORT, GATEWAY_ADVERTISED_URL)
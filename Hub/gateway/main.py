import os
from gateway import run


def _env(name: str, default: str) -> str:
    return os.getenv(name, default)


if __name__ == "__main__":
    BROKER_HOST = _env("MQTT_BROKER_HOST", "broker")
    HUB_ID = _env("HUB_ID", "unknown_hub")
    CLOUD_ENDPOINT = _env("CLOUD_ENDPOINT", "http://localhost/api")

    run(BROKER_HOST, HUB_ID, CLOUD_ENDPOINT)
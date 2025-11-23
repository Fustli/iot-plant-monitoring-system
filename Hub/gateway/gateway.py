"""Gateway: subscribe to MQTT topics and (optionally) forward to cloud.

Configuration comes from environment variables (or function args),
logging is configured via `logging_config.get_logger`, 
and cloud interactions are handled by `CloudClient`.
"""
import os
import json
import time
import threading

import paho.mqtt.client as mqtt

from logging_config import get_logger
from cloud_client import CloudClient


logger = get_logger("gateway")

def _make_callbacks(hub_id: str, cloud_client: CloudClient | None, mqtt_topics: list):
    """Create MQTT callback functions bound to the provided hub and cloud client.

    Parameters:
    - hub_id: Identifier for this gateway/hub; injected into forwarded payloads.
    - cloud_client: Optional CloudClient used to forward incoming messages to the cloud.
    - mqtt_topics: List of MQTT topic filters to subscribe to on connect.

    Returns:
    A tuple of two callables `(on_connect, on_message)` suitable for assigning to
    `mqtt.Client.on_connect` and `mqtt.Client.on_message`.
    """

    def on_connect(client, userdata, flags, rc):
        """MQTT on_connect callback: subscribe to configured topics on success.

        Parameters:
        - client: The MQTT client instance.
        - userdata: User-defined data passed to callbacks (unused).
        - flags: Response flags from the broker.
        - rc: Connection result code (0 indicates success).
        """
        if rc == 0:
            logger.info("Connected to MQTT broker; subscribing to topics: %s", mqtt_topics)
            for t in mqtt_topics:
                client.subscribe(t)
        else:
            logger.error("MQTT connection failed. RC: %s", rc)

    def on_message(client, userdata, msg):
        """Handle incoming MQTT messages.

        Attempts to parse message payloads as JSON and augments them with the
        configured `hub_id`. If a `cloud_client` with an `endpoint` is present,
        the payload is forwarded to the cloud using `cloud_client.send`.

        For non-JSON payloads a wrapper object is used: `{"raw": <payload_str>, "hub_id": <hub_id>}`.

        Parameters:
        - client: The MQTT client instance that received the message.
        - userdata: User-defined data passed to callbacks (unused).
        - msg: The `paho.mqtt.client.MQTTMessage` instance containing `topic` and `payload`.
        """
        payload_str = msg.payload.decode(errors="ignore")
        logger.info("Received message on %s", msg.topic)
        logger.debug("Payload: %s", payload_str)
        try:
            payload = json.loads(payload_str)
            payload["hub_id"] = hub_id
        except Exception:
            # send raw payload if not JSON
            payload = {"raw": payload_str, "hub_id": hub_id}

        if cloud_client and getattr(cloud_client, "endpoint", None):
            try:
                resp = cloud_client.send(payload)
                logger.info("Forwarded to cloud; status=%s", getattr(resp, "status_code", "?"))
            except Exception:
                logger.exception("Failed to forward payload to cloud")
        else:
            logger.debug("No cloud endpoint configured; skipping forward")

    return on_connect, on_message

def _parse_config(
    broker_host: str | None,
    hub_id: str | None,
    cloud_endpoint: str | None,
    topics: list | None,
    poll_path: str | None,
    poll_interval: int,
    start_delay: int,
):
    """Collect configuration from args and environment variables."""
    cfg = {}
    cfg["broker_host"] = broker_host or os.getenv("MQTT_BROKER_HOST", "broker")
    cfg["broker_port"] = int(os.getenv("MQTT_BROKER_PORT", os.getenv("MQTT_PORT", "1883")))
    cfg["hub_id"] = hub_id or os.getenv("HUB_ID", "hub")
    cfg["cloud_endpoint"] = cloud_endpoint or os.getenv("CLOUD_ENDPOINT")
    topics_env = os.getenv("MQTT_TOPICS", "home/sensors/#")
    cfg["topics"] = topics or [t.strip() for t in topics_env.split(",") if t.strip()]
    cfg["poll_path"] = poll_path or os.getenv("CLOUD_COMMANDS_ENDPOINT", os.getenv("CLOUD_COMMANDS_PATH", ""))
    cfg["poll_interval"] = int(os.getenv("CLOUD_COMMANDS_POLL_INTERVAL", str(poll_interval)))
    cfg["start_delay"] = int(start_delay)
    return cfg


def _init_cloud_client(cloud_endpoint: str | None) -> CloudClient | None:
    """Create a CloudClient if an endpoint or spec path is available."""
    spec = os.getenv("CLOUD_SPEC_PATH")
    if cloud_endpoint or spec:
        return CloudClient(spec_path=spec, endpoint_override=cloud_endpoint)
    return None


def _init_mqtt_client(hub_id: str, cloud_client: CloudClient | None, topics: list) -> mqtt.Client:
    """Create and configure an MQTT client with callbacks."""
    client = mqtt.Client()
    on_connect, on_message = _make_callbacks(hub_id, cloud_client, topics)
    client.on_connect = on_connect
    client.on_message = on_message
    return client


def _process_poll_response(resp, client: mqtt.Client):
    """Process a poll response and publish any commands found."""
    data = resp.json() if resp and getattr(resp, "status_code", None) == 200 else None
    if not data:
        return
    commands = data if isinstance(data, list) else [data]
    for cmd in commands:
        topic = cmd.get("topic")
        payload = cmd.get("payload")
        if not topic or payload is None:
            logger.warning("Invalid command from cloud: %s", cmd)
            continue
        out = payload if isinstance(payload, str) else json.dumps(payload)
        client.publish(topic, out, qos=cmd.get("qos", 0), retain=cmd.get("retain", False))
        logger.info("Published command to %s", topic)


def _poller_loop(cloud_client: CloudClient, poll_path: str, poll_interval: int, client: mqtt.Client):
    """Continuously poll the cloud for commands and publish them to MQTT.

    This loop calls `cloud_client.get(poll_path)` every `poll_interval` seconds
    and delegates any returned commands to `_process_poll_response` which
    publishes them to the provided MQTT `client`.

    Parameters:
    - cloud_client: Configured CloudClient used to request commands.
    - poll_path: Path or endpoint on the cloud to poll for commands.
    - poll_interval: Number of seconds to wait between polls.
    - client: MQTT client used to publish commands received from cloud.
    """
    logger.info("Starting cloud->MQTT poller path=%s interval=%s", poll_path, poll_interval)
    while True:
        try:
            resp = cloud_client.get(poll_path)
            _process_poll_response(resp, client)
        except Exception:
            logger.exception("Error polling commands from cloud")
        time.sleep(poll_interval)


def _start_poller_if_needed(client: mqtt.Client, cloud_client: CloudClient | None, poll_path: str, poll_interval: int):
    """Start a background poller thread that reads commands from cloud and publishes them."""
    if not (poll_path and cloud_client):
        return None

    t = threading.Thread(
        target=_poller_loop, args=(cloud_client, poll_path, poll_interval, client), daemon=True, name="cloud-poller"
    )
    t.start()
    return t


def _run_loop(client: mqtt.Client):
    """Run the main loop until interrupted, then stop the client loop."""
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        logger.info("Shutting down gateway")
    finally:
        try:
            client.loop_stop()
        except Exception:
            pass


def run(
    broker_host: str = None,
    hub_id: str = None,
    cloud_endpoint: str = None,
    topics: list = None,
    poll_path: str = None,
    poll_interval: int = 5,
    start_delay: int = 1,
):
    """Run gateway with simple, environment-driven defaults.

    See `_parse_config` for environment variables used when args are None.
    """
    cfg = _parse_config(broker_host, hub_id, cloud_endpoint, topics, poll_path, poll_interval, start_delay)

    logger.info(
        "Gateway starting: broker=%s:%s hub_id=%s topics=%s",
        cfg["broker_host"],
        cfg["broker_port"],
        cfg["hub_id"],
        cfg["topics"],
    )
    if cfg["cloud_endpoint"]:
        logger.info("Cloud endpoint: %s", cfg["cloud_endpoint"])

    time.sleep(cfg["start_delay"])

    cloud_client = _init_cloud_client(cfg["cloud_endpoint"])

    client = _init_mqtt_client(cfg["hub_id"], cloud_client, cfg["topics"])

    try:
        client.connect(cfg["broker_host"], cfg["broker_port"], 60)
    except Exception:
        logger.exception(
            "Could not connect to broker at %s:%s", cfg["broker_host"], cfg["broker_port"]
        )
        return

    client.loop_start()

    _start_poller_if_needed(client, cloud_client, cfg["poll_path"], cfg["poll_interval"])

    _run_loop(client)


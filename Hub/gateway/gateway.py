"""Gateway: subscribe to MQTT topics and (optionally) forward to cloud.

Configuration comes from environment variables (or function args),
logging is configured via `logging_config.get_logger`, 
and cloud interactions are handled by `CloudClient`.
"""
import os
import json
import time
import threading
from typing import Iterable

import paho.mqtt.client as mqtt

from logging_config import get_logger
from cloud_client import CloudClient


def _read_secret(env_name: str, secret_name: str) -> str | None:
    v = os.getenv(env_name)
    if v:
        return v
    secret_path = f"/run/secrets/{secret_name}"
    try:
        with open(secret_path, "r", encoding="utf-8") as fh:
            return fh.read().strip()
    except Exception:
        return None


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

    # sensor state store to deduplicate and monitor last seen
    sensor_state = {}

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

        # determine sensor key (prefer explicit device id fields, else topic)
        device_id = None
        if isinstance(payload, dict):
            for k in ("device_id", "id", "sensor_id"):
                if k in payload:
                    device_id = str(payload[k])
                    break
        if not device_id:
            # fallback to topic last segment
            try:
                device_id = msg.topic.split("/")[-1]
            except Exception:
                device_id = msg.topic
        payload["unique_id"] = device_id

        # check for change: assume payload contains a 'value' or send whole payload
        new_val = None
        if isinstance(payload, dict) and "data" in payload:
            new_val = payload.get("data")
        else:
            # use JSON string as comparison key
            try:
                new_val = json.dumps(payload, sort_keys=True)
            except Exception:
                new_val = str(payload)

        prev = sensor_state.get(device_id)
        now_ts = time.time()
        changed = True
        if prev is not None:
            if prev.get("data") == new_val:
                changed = False

        # update last seen and value
        sensor_state[device_id] = {"data": new_val, "last_seen": now_ts, "anomaly_reported": prev.get("anomaly_reported") if prev else False}
        if not changed:
            logger.debug("No change for sensor %s; skipping cloud upload", device_id)
            return

        if cloud_client and getattr(cloud_client, "endpoint", None):
            try:
                # Post sensor telemetry to the backend device ingestion endpoint
                resp = cloud_client.post("/api/device/receive-data", payload)
                logger.info("Forwarded telemetry to cloud; status=%s", getattr(resp, "status_code", "?"))
                # clear any previous anomaly flag on success
                if sensor_state.get(device_id):
                    sensor_state[device_id]["anomaly_reported"] = False
            except Exception:
                logger.exception("Failed to forward payload to cloud")
        else:
            logger.debug("No cloud endpoint configured; skipping forward")

    # background thread to detect silent sensors and post anomaly
    def _anomaly_watcher():
        CHECK_INTERVAL = 30
        SILENCE_THRESHOLD = int(os.getenv("HUB_SILENCE_SECONDS", str(5 * 60)))
        while True:
            try:
                now_ts = time.time()
                for key, st in list(sensor_state.items()):
                    last = st.get("last_seen")
                    if last is None:
                        continue
                    if (now_ts - last) > SILENCE_THRESHOLD and not st.get("anomaly_reported"):
                        # send anomaly to cloud if possible
                        # Build a DeviceData-like anomaly payload so backend can
                        # persist it similarly to normal telemetry but marked
                        # as an anomaly. measurement value is placeholder 0.0.
                        try:
                            dev_id = int(key) if isinstance(key, str) and key.isdigit() else key
                        except Exception:
                            dev_id = key

                        anomaly = {"unique_id": dev_id, "last_seen": last, "is_anomaly": True}
                        try:
                            if cloud_client and getattr(cloud_client, "endpoint", None):
                                cloud_client.post("/api/device/anomaly", anomaly)
                                logger.info("Posted anomaly for %s", key)
                                sensor_state[key]["anomaly_reported"] = True
                        except Exception:
                            logger.exception("Failed to post anomaly for %s", key)
                time.sleep(CHECK_INTERVAL)
            except Exception:
                logger.exception("Anomaly watcher error, continuing")
                time.sleep(CHECK_INTERVAL)

    # start anomaly watcher thread
    t = threading.Thread(target=_anomaly_watcher, daemon=True, name="anomaly-watcher")
    t.start()

    return on_connect, on_message

def _parse_config(
    broker_host: str | None,
    hub_id: str | None,
    cloud_endpoint: str | None,
    topics: list | None,
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
    cfg["start_delay"] = int(start_delay)
    return cfg


def _init_cloud_client(cloud_endpoint: str | None) -> CloudClient | None:
    """Create a CloudClient if an endpoint is available."""
    if cloud_endpoint:
        return CloudClient(endpoint_override=cloud_endpoint)
    # If no explicit endpoint was passed, CloudClient will look at CLOUD_ENDPOINT env var.
    env_endpoint = os.getenv("CLOUD_ENDPOINT")
    if env_endpoint:
        return CloudClient(endpoint_override=None)
    return None


def _init_mqtt_client(hub_id: str, cloud_client: CloudClient | None, topics: list) -> mqtt.Client:
    """Create and configure an MQTT client with callbacks."""
    client = mqtt.Client()
    on_connect, on_message = _make_callbacks(hub_id, cloud_client, topics)
    client.on_connect = on_connect
    client.on_message = on_message
    return client


def _start_http_server(client: mqtt.Client, listen_host: str, listen_port: int):
    # HTTP server removed: gateway no longer exposes an HTTP API. Keep a no-op
    # function so other code paths that may call it remain safe.
    logger.debug("HTTP server support disabled in gateway (IoT Hub only)")
    return None


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


def _start_http_and_register(client: mqtt.Client, cloud_client: CloudClient | None, listen_host: str, listen_port: int, advertised_url: str | None):
    """Start HTTP server and, if possible, register callback URL with cloud.

    If `advertised_url` is provided it will be posted to the cloud registration endpoint.
    If not provided the function will try to construct a URL from `listen_host` and `listen_port` but
    will log a warning that automatic discovery may not be reachable from cloud.
    """
    # Removed: registration/push model not used. Keep a no-op for compatibility.
    logger.debug("_start_http_and_register is a no-op (IoT Hub only)")
    return None


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


def _start_iothub_device_listener(mqtt_client: mqtt.Client):
    """Start an Azure IoT Hub device client that listens for direct methods.

    The device connection string is read from `DEVICE_CONNECTION_STRING` env
    or `/run/secrets/device_connection_string`.
    When a direct method arrives, expect a JSON payload with `topic` and `payload`.
    Publish to MQTT and return a MethodResponse to the cloud.
    """
    conn_str = _read_secret("DEVICE_CONNECTION_STRING", "device_connection_string")
    if not conn_str:
        logger.debug("No device connection string provided; skipping IoT Hub listener")
        return None

    try:
        from azure.iot.device import IoTHubDeviceClient, MethodResponse
    except Exception:
        logger.exception("azure-iot-device not available; install azure-iot-device to enable IoT method handling")
        return None

    try:
        device_client = IoTHubDeviceClient.create_from_connection_string(conn_str)
        device_client.connect()
    except Exception:
        logger.exception("Failed to create/connect IoT Hub device client")
        return None

    def _listener_loop():
        logger.info("IoT Hub device listener started")
        try:
            while True:
                try:
                    method_request = device_client.receive_method_request()  # blocking
                except Exception:
                    logger.exception("Error receiving method request; reconnecting...")
                    time.sleep(5)
                    continue

                logger.info("Received direct method: %s", getattr(method_request, "name", "?"))
                try:
                    payload = method_request.payload
                    if isinstance(payload, str):
                        try:
                            payload = json.loads(payload)
                        except Exception:
                            payload = {"raw": payload}

                    topic = payload.get("topic") if isinstance(payload, dict) else None
                    message = payload.get("payload") if isinstance(payload, dict) else None

                    if not topic or message is None:
                        logger.warning("Invalid method payload; expected {'topic':..., 'payload':...} got=%s", payload)
                        resp = MethodResponse.create_from_method_request(method_request, status=400, payload={"error": "invalid payload"})
                        device_client.send_method_response(resp)
                        continue

                    out = message if isinstance(message, str) else json.dumps(message)
                    mqtt_client.publish(topic, out)
                    logger.info("Published command from direct method to %s", topic)
                    resp = MethodResponse.create_from_method_request(method_request, status=200, payload={"status": "published"})
                    device_client.send_method_response(resp)
                except Exception:
                    logger.exception("Failed to handle direct method payload")
                    try:
                        resp = MethodResponse.create_from_method_request(method_request, status=500, payload={"error": "internal"})
                        device_client.send_method_response(resp)
                    except Exception:
                        pass
        finally:
            try:
                device_client.shutdown()
            except Exception:
                pass

    t = threading.Thread(target=_listener_loop, daemon=True, name="iothub-listener")
    t.start()
    return t


def run(
    broker_host: str = None,
    hub_id: str = None,
    cloud_endpoint: str = None,
    topics: list = None,
    start_delay: int = 1,
):
    """Run gateway with simple, environment-driven defaults.

    See `_parse_config` for environment variables used when args are None.
    """
    cfg = _parse_config(broker_host, hub_id, cloud_endpoint, topics, start_delay)

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

    # If cloud client exists, attempt to activate/register this hub on startup.
    def _activate_hub_on_startup():
        if not cloud_client:
            logger.debug("No cloud client configured; skipping hub activation")
            return

        serial = cfg.get("hub_id")
        # Optionally include IoT Hub device id/connection string if available from secrets
        iothub_device_id = _read_secret("DEVICE_ID", "device_id") or os.getenv("IOTHUB_DEVICE_ID")
        iothub_connection_string = _read_secret("DEVICE_CONNECTION_STRING", "device_connection_string") or os.getenv("DEVICE_CONNECTION_STRING")

        payload = {"serial": serial}
        if iothub_device_id:
            payload["iothub_device_id"] = iothub_device_id
        if iothub_connection_string:
            # Do not log connection string
            payload["iothub_connection_string"] = iothub_connection_string

        try:
            if not getattr(cloud_client, "endpoint", None):
                logger.debug("Cloud client has no endpoint set; skipping activation POST")
                return
            logger.info("Posting hub activation to %s", cloud_client.endpoint+"/api/hub/activate")
            # Try a few times in case cloud is not yet reachable
            for attempt in range(1, 4):
                try:
                    resp = cloud_client.post("/api/hub/activate", payload=payload, headers=cloud_client.default_headers, timeout=5)
                    logger.info("Activation response status=%s", getattr(resp, "status_code", "?"))
                    if resp is not None and resp.status_code in (200, 201, 202):
                        logger.info("Hub activation succeeded")
                        return
                    else:
                        logger.warning("Activation attempt %s failed: status=%s body=%s", attempt, getattr(resp, "status_code", "?"), getattr(resp, "text", ""))
                except Exception:
                    logger.exception("Activation attempt %s exception", attempt)
                time.sleep(2 * attempt)
            logger.warning("Hub activation attempts exhausted")
        except Exception:
            logger.exception("Failed to post hub activation")

    # Run activation in foreground before connecting so backend knows hub is coming up
    try:
        _activate_hub_on_startup()
    except Exception:
        logger.exception("Activation routine failed; continuing startup")

    client = _init_mqtt_client(cfg["hub_id"], cloud_client, cfg["topics"])

    try:
        client.connect(cfg["broker_host"], cfg["broker_port"], 60)
    except Exception:
        logger.exception(
            "Could not connect to broker at %s:%s", cfg["broker_host"], cfg["broker_port"]
        )
        return

    client.loop_start()

    # Start IoT Hub direct method listener (device-side behavior)
    _start_iothub_device_listener(client)

    _run_loop(client)


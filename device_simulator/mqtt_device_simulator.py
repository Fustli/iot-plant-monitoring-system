#!/usr/bin/env python3
"""
Lightweight MQTT device simulator.

Usage examples:
  python device_simulator/mqtt_device_simulator.py '{"broker":"localhost","port":1883,"publish_topic":"telemetry","command_topic":"actuators/device1/sed","device_id":"device1","interval":5,"sensors":{"temperature": [25.0, "C"], "moisture": [40, "%"]}},"actuators":["moisture","light"]}'

  python device_simulator/mqtt_device_simulator.py --config-file ./device_config.json

While running you can type commands on stdin:
  set <sensor> <value>    # set a sensor value
  inc <sensor> <delta>    # increment sensor
  dec <sensor> <delta>    # decrement sensor
  show                    # print current sensors
  quit / exit             # stop simulator

The simulator also subscribes to the `command_topic` (if provided) and accepts JSON messages
of the form: {"metric": "temperature|humidity|moisture|light", "delta": float} to update sensors remotely.
"""
from __future__ import annotations

import argparse
from email import parser
import json
import logging
import threading
import time
from datetime import datetime
from typing import Any, Dict, List, Optional

try:
    import paho.mqtt.client as mqtt
except Exception as e:  # pragma: no cover - runtime helpful message
    raise SystemExit(
        "paho-mqtt is required. Install with: pip install paho-mqtt\nOriginal error: %s" % e
    )


class MQTTDeviceSimulator:
    def __init__(self, config: Dict[str, Any]):
        self.broker = config.get("broker", "localhost")
        self.port = int(config.get("port", 1883))
        self.publish_topic = config.get("publish_topic")
        self.command_topic = config.get("command_topic")
        self.device_id = config.get("device_id", "sim-device")
        self.interval = float(config.get("interval", 5))

        sensors = config.get("sensors", {})
        # Ensure numeric types where possible
        self.sensors: Dict[str, Dict[str, Any]] = dict(sensors)
        self.sensors_lock = threading.Lock()

        actuators = config.get("actuators", [])
        self.actuators: List[str] = list(actuators)
        self.actuators_lock = threading.Lock()

        self.client = mqtt.Client()
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message

        self.logger: Optional[logging.Logger] = None

        self._running = threading.Event()
        self._running.set()

    def on_connect(self, client, userdata, flags, rc):
        self.log(f"Connected to MQTT broker {self.broker}:{self.port} (rc={rc})")
        if self.command_topic:
            client.subscribe(self.command_topic)
            self.log(f"Subscribed to command topic: {self.command_topic}")

    def on_message(self, client, userdata, message):
        payload = message.payload.decode("utf-8", errors="ignore")
        self.log(f"Received command message on {message.topic}: {payload}")
        try:
            data = json.loads(payload)
        except Exception as e:
            self.log(f"Invalid JSON command payload: {e}")
            return

        # support {"metric": "temperature|humidity|moisture|light", "delta": float}
        # if actuator exists, and has a sensor for the metric, apply delta to sensor data
        if (isinstance(data, dict)
            and "metric" in data
            and "delta" in data
            and data["metric"] in self.actuators
        ):
            self.log(f"Actuator command received: {data}")
            metric = data["metric"]
            delta = data["delta"]
            with self.sensors_lock:
                if metric in self.sensors:
                    try:
                        cur = float(self.sensors[metric]["value"])
                        cur += float(delta)
                        # keep int if original was int
                        if isinstance(self.sensors[metric]["value"], int):
                            cur = int(cur)
                        self.sensors[metric]["value"] = cur
                        self.log(f"Updated sensor '{metric}' to {cur} via actuator command")
                    except Exception as e:
                        self.log(f"Error updating sensor value: {e}")
                else:
                    self.log(f"Sensor '{metric}' not found to update via actuator command")
        

    def start(self):
        self.log("Starting simulator... connecting to broker")
        self.client.connect(self.broker, self.port)
        # Use network loop in background thread
        self.client.loop_start()

        self._pub_thread = threading.Thread(target=self._publisher_loop, daemon=True)
        self._pub_thread.start()

    def stop(self):
        self.log("Stopping simulator...")
        self._running.clear()
        try:
            self.client.loop_stop()
            self.client.disconnect()
        except Exception:
            pass

    def _publisher_loop(self):
        while self._running.is_set():
            with self.sensors_lock:
                for sensor in self.sensors.keys():
                    payload = {
                        "device_id": self.device_id,
                        "data_type": sensor,
                        "data": self.sensors[sensor].get("value"),
                        "data_unit": self.sensors[sensor].get("unit"),
                        }
                
                    try:
                        self.client.publish(self.publish_topic, json.dumps(payload))
                        self.log(f"Published to {self.publish_topic}: {payload}")
                    except Exception as e:
                        self.log(f"Publish error: {e}")
            time.sleep(self.interval)

    # helper methods for CLI
    def set_sensor(self, name: str, value: Any):
        with self.sensors_lock:
            # attempt numeric conversion
            try:
                if isinstance(self.sensors[name]["value"], int):
                    value = int(value)
                elif isinstance(self.sensors[name]["value"], float):
                    value = float(value)
            except Exception as e:
                self.log(f"Exception converting sensor value: {e}")
            self.sensors[name]["value"] = value

    def inc_sensor(self, name: str, delta: float):
        with self.sensors_lock:
            cur = self.sensors[name]["value"]
            try:
                cur = float(cur)
                cur += delta
                # keep int if original was int
                if isinstance(self.sensors[name]["value"], int):
                    cur = int(cur)
            except Exception as e:
                self.log(f"Exception incrementing sensor value: {e}")
                return
            self.sensors[name]["value"] = cur

    def log(self, msg: str):
        if self.logger:
                self.logger.info(msg)
        else:
            print(msg)

# MQTT-based log handler (publishes log messages to a topic)
class MQTTLogHandler(logging.Handler):
    def __init__(self, client: Optional[mqtt.Client], topic: Optional[str]):
        super().__init__()
        self.client = client
        self.topic = topic

    def emit(self, record: logging.LogRecord) -> None:
        try:
            msg = self.format(record)
            if self.client and self.topic:
                # publish without blocking
                try:
                    self.client.publish(self.topic, msg)
                except Exception:
                    # fall back to stdout if publish fails
                    pass
        except Exception:
            pass        



def parse_config_from_arg(arg: str) -> Dict[str, Any]:
    # If arg looks like JSON, parse directly; otherwise treat as path
    arg = arg.strip()
    if arg.startswith("{") or arg.startswith("["):
        return json.loads(arg)
    # try file
    with open(arg, "r", encoding="utf-8") as fh:
        return json.load(fh)


def repl(sim: MQTTDeviceSimulator):
    print("Interactive commands: set/inc/dec/show/quit")
    try:
        while sim._running.is_set():
            line = input("sim> ").strip()
            if not line:
                continue
            parts = line.split()
            cmd = parts[0].lower()
            if cmd in ("quit", "exit"):
                sim.stop()
                break
            if cmd == "show":
                with sim.sensors_lock:
                    print(json.dumps(sim.sensors, indent=2))
                continue
            if cmd == "set" and len(parts) >= 3:
                name = parts[1]
                val = " ".join(parts[2:])
                # try to parse JSON value for complex types
                try:
                    parsed = json.loads(val)
                except Exception:
                    # fallback to simple number or string
                    try:
                        if "." in val:
                            parsed = float(val)
                        else:
                            parsed = int(val)
                    except Exception:
                        parsed = val
                sim.set_sensor(name, parsed)
                continue
            if cmd in ("inc", "dec") and len(parts) >= 3:
                name = parts[1]
                try:
                    delta = float(parts[2])
                except Exception:
                    print("Invalid delta")
                    continue
                if cmd == "dec":
                    delta = -delta
                sim.inc_sensor(name, delta)
                continue

            print("Unknown command")
    except (EOFError, KeyboardInterrupt):
        sim.stop()


def main():
    """
    - `--log-file <path>` — write logs to a file
    - `--log-topic <mqtt_topic>` — publish log lines to an MQTT topic (you can `mosquitto_sub` to view them in another terminal)
    - `--no-stdout` — disable printing logs to stdout (useful when viewing logs in another terminal)
    """
    parser = argparse.ArgumentParser(description="MQTT device simulator")
    parser.add_argument("config", help="JSON string or path to JSON config file")
    parser.add_argument("--log-file", help="Path to write logs to (optional)")
    parser.add_argument("--log-topic", help="MQTT topic to publish logs to (optional)")
    parser.add_argument("--no-stdout", action="store_true", help="Disable printing logs to stdout")
    args = parser.parse_args()

    config = parse_config_from_arg(args.config)

    # setup simulator
    sim = MQTTDeviceSimulator(config)

    # configure logging
    logger = logging.getLogger("mqtt_sim")
    logger.setLevel(logging.INFO)
    # remove default handlers
    for h in list(logger.handlers):
        logger.removeHandler(h)

    formatter = logging.Formatter("%(asctime)s %(levelname)s %(message)s")

    if not args.no_stdout:
        sh = logging.StreamHandler()
        sh.setFormatter(formatter)
        logger.addHandler(sh)

    if args.log_file:
        fh = logging.FileHandler(args.log_file)
        fh.setFormatter(formatter)
        logger.addHandler(fh)
    
    if args.log_topic:
        mhandler = MQTTLogHandler(sim.client, args.log_topic)
        mhandler.setFormatter(formatter)
        logger.addHandler(mhandler)

    sim.logger = logger

    sim.start()

    # run REPL in main thread; supports keyboard input
    repl(sim)


if __name__ == "__main__":
    main()

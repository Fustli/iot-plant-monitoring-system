#!/usr/bin/env python3
"""
Lightweight MQTT device simulator.

Usage examples:
  python device_simulator/mqtt_device_simulator.py '{"broker":"localhost","port":1883,"publish_topic":"telemetry","command_topic":"actuators/device1/sed","device_id":"device1","interval":5,"sensors":{"temp":25.0,"moisture":40},"actuators":["moisture","light"]}'

  python device_simulator/mqtt_device_simulator.py --config-file ./device_config.json

While running you can type commands on stdin:
  set <sensor> <value>    # set a sensor value
  inc <sensor> <delta>    # increment sensor
  dec <sensor> <delta>    # decrement sensor
  show                    # print current sensors
  quit / exit             # stop simulator

The simulator also subscribes to the `command_topic` (if provided) and accepts JSON messages
of the form: {"set": {"temp": 30}} to update sensors remotely.
"""
from __future__ import annotations

import argparse
import json
import threading
import time
from datetime import datetime
from typing import Any, Dict, List

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
        self.sensors: Dict[str, Any] = dict(sensors)
        self.sensors_lock = threading.Lock()

        actuators = config.get("actuators", [])
        self.actuators: List[str] = list(actuators)
        self.actuators_lock = threading.Lock()

        self.client = mqtt.Client()
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message

        self._running = threading.Event()
        self._running.set()

    def on_connect(self, client, userdata, flags, rc):
        print(f"Connected to MQTT broker {self.broker}:{self.port} (rc={rc})")
        if self.command_topic:
            client.subscribe(self.command_topic)
            print(f"Subscribed to command topic: {self.command_topic}")

    def on_message(self, client, userdata, message):
        payload = message.payload.decode("utf-8", errors="ignore")
        print(f"Received command message on {message.topic}: {payload}")
        try:
            data = json.loads(payload)
        except Exception as e:
            print("Invalid JSON command payload:", e)
            return

        # support {"metric": "temperature|humidity|moisture|light", "delta": float}
        # if actuator exists, and has a sensor for the metric, apply delta to sensor data
        if (isinstance(data, dict)
            and "metric" in data
            and "delta" in data
            and data["metric"] in self.actuators
        ):
            print("Actuator command received:", data)
            metric = data["metric"]
            delta = data["delta"]
            with self.sensors_lock:
                if metric in self.sensors:
                    try:
                        cur = float(self.sensors[metric])
                        cur += float(delta)
                        # keep int if original was int
                        if isinstance(self.sensors[metric], int):
                            cur = int(cur)
                        self.sensors[metric] = cur
                        print(f"Updated sensor '{metric}' to {cur} via actuator command")
                    except Exception as e:
                        print("Error updating sensor value:", e)
                else:
                    print(f"Sensor '{metric}' not found to update via actuator command")
        

    def start(self):
        print("Starting simulator... connecting to broker")
        self.client.connect(self.broker, self.port)
        # Use network loop in background thread
        self.client.loop_start()

        self._pub_thread = threading.Thread(target=self._publisher_loop, daemon=True)
        self._pub_thread.start()

    def stop(self):
        print("Stopping simulator...")
        self._running.clear()
        try:
            self.client.loop_stop()
            self.client.disconnect()
        except Exception:
            pass

    def _publisher_loop(self):
        while self._running.is_set():
            with self.sensors_lock:
                payload = {
                    "device_id": self.device_id,
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                    "sensors": self.sensors,
                }
            try:
                self.client.publish(self.publish_topic, json.dumps(payload))
                print(f"Published to {self.publish_topic}: {payload}")
            except Exception as e:
                print("Publish error:", e)
            time.sleep(self.interval)

    # helper methods for CLI
    def set_sensor(self, name: str, value: Any):
        with self.sensors_lock:
            # attempt numeric conversion
            try:
                if isinstance(self.sensors.get(name), int):
                    value = int(value)
                elif isinstance(self.sensors.get(name), float):
                    value = float(value)
            except Exception:
                pass
            self.sensors[name] = value

    def inc_sensor(self, name: str, delta: float):
        with self.sensors_lock:
            cur = self.sensors.get(name, 0)
            try:
                cur = float(cur)
                cur += delta
                # keep int if original was int
                if isinstance(self.sensors.get(name), int):
                    cur = int(cur)
            except Exception:
                print("Cannot increment non-numeric sensor")
                return
            self.sensors[name] = cur


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
    parser = argparse.ArgumentParser(description="MQTT device simulator")
    parser.add_argument("config", help="JSON string or path to JSON config file")
    args = parser.parse_args()

    config = parse_config_from_arg(args.config)

    sim = MQTTDeviceSimulator(config)
    sim.start()

    # run REPL in main thread; supports keyboard input
    repl(sim)


if __name__ == "__main__":
    main()

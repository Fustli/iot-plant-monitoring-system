# MQTT Device Simulator

This small script simulates an IoT device that publishes sensor data over MQTT and accepts
commands to change sensor values at runtime.

Location:

- `Hub/test/mqtt_device_simulator.py`

Requirements:

- Python 3.8+
- `paho-mqtt` (install with `pip install paho-mqtt`)

Quick start examples:

1) Run with inline JSON config:

```bash
device_simulator/mqtt_device_simulator.py '{"broker":"localhost","port":1883,"publish_topic":"telemetry","command_topic":"actuators/device1/sed","device_id":"device1","interval":5,"sensors":{"temp":25.0,"moisture":40},"actuators":["moisture","light"]}'
```

2) Run with config file `device_config.json`:

```json
{
  "broker": "localhost",
  "port": 1883,
  "publish_topic": "telemetry",
  "command_topic": "actuators/device1/set",
  "device_id": "device1",
  "interval": 5,
  "sensors": {"temperature": 25.0, "moisture": 40},
  "actuators": ["moisture", "light"]
}
```

```bash
python device_simulator/mqtt_device_simulator.py device_simulator/device_config.json
```

Interactive commands (type at the `sim>` prompt):

- `set <sensor> <value>` — set a sensor to a value (value may be JSON)
- `inc <sensor> <delta>` — increment numeric sensor
- `dec <sensor> <delta>` — decrement numeric sensor
- `show` — print current sensors
- `quit` / `exit` — stop simulator

Remote MQTT commands:

- If `command_topic` is provided, simulator subscribes to that topic and accepts JSON
  messages like `{"metric": "temperature|humidity|moisture|light", "delta": float}` to update sensors remotely.

Logging options (to keep the interactive prompt usable):
- `--log-file <path>` — write logs to a file
- `--log-topic <mqtt_topic>` — publish log lines to an MQTT topic (you can `mosquitto_sub` to view them in another terminal)
- `--no-stdout` — disable printing logs to stdout (useful when viewing logs in another terminal)

Example: publish logs to `home/logs/device1` and view them in another terminal:

```bash
# run simulator and publish logs to MQTT
python device_simulator/mqtt_device_simulator.py '{"broker":"localhost","port":1883,"publish_topic":"home/sensors/device1","command_topic":"home/commands/device1","device_id":"device1","interval":5,"sensors":{"temp":25.0,"moisture":40}}' --log-topic home/logs/device1 --no-stdout

# in another terminal, subscribe to the log topic
mosquitto_sub -h localhost -t home/logs/device1 -v
```

Example: write logs to a file and tail in another terminal:

```bash
python device_simulator/mqtt_device_simulator.py '{"broker":"localhost","port":1883,"publish_topic":"home/sensors/device1","command_topic":"home/commands/device1","device_id":"device1","interval":5,"sensors":{"temp":25.0,"moisture":40}}' --log-file ./device1.log --no-stdout

tail -f ./device1.log
```

Notes:

- The script prints published payloads to stdout so you can see activity.
- If you run the project's Mosquitto broker (Hub/mosquitto), point `broker` to it.

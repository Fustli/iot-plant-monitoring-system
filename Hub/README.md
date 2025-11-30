# Hub (gateway + broker)

This folder contains a local MQTT broker (Mosquitto) and the gateway service that subscribes to sensor topics and forwards telemetry to a cloud endpoint.

## Quick start (from this `Hub` directory):

```bash
docker compose up --build
```
## Configuration

Environment variables used by the gateway (can be set in `docker-compose.yml` or the shell):
- `MQTT_BROKER_HOST`: hostname of the broker service (default: `broker`)
- `MQTT_BROKER_PORT`: MQTT broker port (default: `1883`)
- `HUB_ID`: identifier attached to forwarded payloads (default: `hub`)
- `CLOUD_ENDPOINT`: HTTP endpoint to POST telemetry to (no default)
- `MQTT_TOPICS`: comma-separated list of topics to subscribe to (default: `home/sensors/#`)
- `CLOUD_COMMANDS_ENDPOINT` or `CLOUD_COMMANDS_PATH`: endpoint or API path used by the gateway poller for cloud->MQTT commands
- `CLOUD_COMMANDS_POLL_INTERVAL`: poll interval in seconds (default: `5`)
- `CLOUD_API_KEY`: optional API key for the cloud endpoint
- `CLOUD_API_KEY_HEADER`: header name for the API key (default: `x-api-key`)
- `LOG_LEVEL`: logging verbosity (e.g. `DEBUG`, `INFO`, `WARNING`)

## Behavior 

The gateway subscribes to `MQTT_TOPICS`, decodes incoming payloads (attempt JSON), attaches a `hub_id`, and forwards the payload to the configured cloud endpoint using `CloudClient`.

The gateway can also poll a cloud endpoint and publish any returned commands to MQTT. E.g.:

```json
{
	"topic": "home/actuators/led1/set",
	"payload": { "state": "on" }
}
```
Will result in the hub sending `{ "state": "on" }` to `home/actuators/led1/set` over MQTT.


## Testing locally

1. Run the mock server (default listens on `0.0.0.0:8000`):

```bash
python gateway/test/mock_server.py
```

2. Set the following environment variables in the `docker-compose.yml` file:

```yml
- CLOUD_ENDPOINT=http://host.docker.internal:8000/telemetry
- CLOUD_COMMANDS_ENDPOINT=http://host.docker.internal:8000/commands
- MQTT_TOPICS=home/sensors/+,home/actuators/+,telemetry
```

3. Start the Hub with `docker-compose up --build`

4. The hub will now poll the GET endpoint every couple of seconds and get  mock response

5. If you want to test MQTT message forwarding to the server, run the test script:

```bash
python gateway/test/send_test_message.py
```



To change what `/commands` returns, set `MOCK_COMMANDS` to JSON before starting the mock server. Example (single command):

```bash
export MOCK_COMMANDS='{"topic":"home/actuators/led1/set","payload":"on"}'
python gateway/mock_server.py
```
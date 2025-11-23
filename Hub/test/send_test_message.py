"""Small helper to publish a test telemetry message to the MQTT broker.

Usage examples:
 - publish default JSON to localhost: python send_test_message.py
 - publish custom topic and broker: python send_test_message.py --broker localhost --port 1883 --topic "home/sensors/test"
 - publish a literal JSON string as payload: python send_test_message.py --payload '{"device_id":"d1","sensor":"moisture","value":42}'
"""
import os
import json
import time
import argparse
import paho.mqtt.client as mqtt


def build_default_payload():
    return {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "device_id": "test-device",
        "sensor": "temperature",
        "value": 23.5,
    }


def main():
    parser = argparse.ArgumentParser(description="Publish a test telemetry message to an MQTT broker")
    parser.add_argument("--broker", default=os.getenv("MQTT_BROKER_HOST", "localhost"), help="MQTT broker host (default: localhost)")
    parser.add_argument("--port", type=int, default=int(os.getenv("MQTT_BROKER_PORT", "1883")), help="MQTT broker port (default: 1883)")
    parser.add_argument("--topic", default=os.getenv("TEST_TOPIC", "telemetry"), help="MQTT topic to publish to")
    parser.add_argument("--payload", default=None, help="Payload as JSON string (default: auto-generated) ")
    parser.add_argument("--qos", type=int, default=0, help="MQTT QoS")
    args = parser.parse_args()

    if args.payload:
        try:
            payload_obj = json.loads(args.payload)
        except Exception:
            # treat payload as raw string if not valid JSON
            payload_obj = args.payload
    else:
        payload_obj = build_default_payload()

    client = mqtt.Client()
    try:
        client.connect(args.broker, args.port, 60)
        client.loop_start()

        out = payload_obj if isinstance(payload_obj, str) else json.dumps(payload_obj)
        info = client.publish(args.topic, out, qos=args.qos)
        print(f"Published to {args.topic}; mid={getattr(info, 'mid', None)} rc={getattr(info, 'rc', None)}")

        # wait a short while to ensure the message is sent
        time.sleep(1)

    except Exception as e:
        print(f"Failed to publish message: {e}")
    finally:
        try:
            client.loop_stop()
            client.disconnect()
        except Exception:
            pass


if __name__ == "__main__":
    main()

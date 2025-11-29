Usage notes for test services

This folder contains two helper scripts used to test Azure IoT Hub direct-methods:

- `invoke_method.py` - a simple cloud-side script which invokes a direct method on a device using the IoT Hub REST API.
- `device_method_handler.py` - a device-side sample that connects to IoT Hub and waits for direct methods.

Configuration via Docker secrets
-------------------------------
The `Hub/docker-compose.yml` defines Docker secrets that are expected to be placed under `Hub/secrets/`.
Create the following files (not checked into git):

Hub/secrets/iothub_connection_string
  - Contains the IoT Hub service connection string (policy with Service permissions).

Hub/secrets/device_connection_string
  - Contains the device connection string used by the device simulator.

Hub/secrets/device_id
  - Contains the device id (plain text).

Example (create files locally):

```bash
mkdir -p Hub/secrets
echo "HostName=...;SharedAccessKeyName=iothubowner;SharedAccessKey=..." > Hub/secrets/iothub_connection_string
echo "HostName=...;DeviceId=my-device;SharedAccessKey=..." > Hub/secrets/device_connection_string
echo "my-device" > Hub/secrets/device_id
```

Security
--------
- Do NOT commit the created `Hub/secrets/*` files to git. Add them to your local .gitignore if needed.
- For production use, prefer hardware-backed keys (X.509 + TPM) instead of symmetric connection strings.

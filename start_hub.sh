#!/usr/bin/env bash
# Start the Hub with either a native mosquitto broker or a containerized broker
# Usage:
#   ./start_hub.sh containerized        # start containerized mosquitto + gateway
#   ./start_hub.sh native               # start gateway connected to native mosquitto
#   ./start_hub.sh containerized down   # stop containerized stack
#   ./start_hub.sh native down          # stop native gateway stack

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $0 {containerized|native} [down]

Modes:
  containerized   Start the Mosquitto broker as a container and the gateway (default if unspecified)
  native          Start only the gateway and connect it to a native/local Mosquitto broker

Optional second arg `down` will stop the docker-compose stack for the chosen mode.

Examples:
  $0 containerized
  $0 containerized down
  $0 native
  $0 native down
EOF
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

MODE="$1"
CMD="up"
if [ "${2:-}" = "down" ]; then
  CMD="down"
fi

check_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker not found in PATH. Please install Docker Desktop or Docker Engine." >&2
    exit 2
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon not reachable. Start Docker Desktop or the Docker daemon." >&2
    exit 3
  fi
}

check_docker

# Find a python executable to run the IP helper
find_python() {
  for p in python python3 py; do
    if command -v "$p" >/dev/null 2>&1; then
      PYTHON_BIN="$p"
      return 0
    fi
  done
  PYTHON_BIN=""
}

find_python

case "$MODE" in
  containerized|c)
    COMPOSE_FILE="$SCRIPT_DIR/Hub/containerizedbroker.docker-compose.yml"
    ;;
  native|n)
    COMPOSE_FILE="$SCRIPT_DIR/Hub/nativebroker.docker-compose.yml"
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown mode: $MODE" >&2
    usage
    exit 1
    ;;
esac

# Paths used when starting/stopping a host mosquitto in native mode
MOSQ_CONF="$SCRIPT_DIR/Hub/mosquitto/config/mosquitto.conf"
MOSQ_LOG="$SCRIPT_DIR/Hub/mosquitto/mosquitto.log"
MOSQ_PIDFILE="$SCRIPT_DIR/Hub/mosquitto/mosquitto.pid"

if [ "$CMD" = "up" ]; then
  if [ "$MODE" = "native" ] || [ "$MODE" = "n" ]; then
    # When gateway runs in Docker, use host.docker.internal so container can reach host's mosquitto
    : "Setting MQTT_BROKER_HOST=host.docker.internal and MQTT_BROKER_PORT=1883"
    export MQTT_BROKER_HOST="${MQTT_BROKER_HOST:-host.docker.internal}"
    export MQTT_BROKER_PORT="${MQTT_BROKER_PORT:-1883}"
    echo "Starting gateway (native broker mode). Gateway will connect to MQTT at $MQTT_BROKER_HOST:$MQTT_BROKER_PORT"
    # Start a host mosquitto process using the same config as the containerized compose
    MOSQ_CONF="$SCRIPT_DIR/Hub/mosquitto/config/mosquitto.conf"
    MOSQ_LOG="$SCRIPT_DIR/Hub/mosquitto/mosquitto.log"
    MOSQ_PIDFILE="$SCRIPT_DIR/Hub/mosquitto/mosquitto.pid"

    start_mosquitto_native() {
      if [ -f "$MOSQ_PIDFILE" ]; then
        pid=$(cat "$MOSQ_PIDFILE" 2>/dev/null || true)
        if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
          echo "Mosquitto already running (pid=$pid). Skipping start."
          return 0
        else
          rm -f "$MOSQ_PIDFILE"
        fi
      fi
      # Locate mosquitto binary. Support Unix PATH and common Windows Git Bash locations.
      MOSQUITTO_BIN=""
      if command -v mosquitto >/dev/null 2>&1; then
        MOSQUITTO_BIN=$(command -v mosquitto)
      elif command -v mosquitto.exe >/dev/null 2>&1; then
        MOSQUITTO_BIN=$(command -v mosquitto.exe)
      else
        # Common Windows install locations (Git Bash mounts C: as /c)
        if [ -f "/c/Program Files/mosquitto/mosquitto.exe" ]; then
          MOSQUITTO_BIN="/c/Program Files/mosquitto/mosquitto.exe"
        elif [ -f "/c/Program Files (x86)/mosquitto/mosquitto.exe" ]; then
          MOSQUITTO_BIN="/c/Program Files (x86)/mosquitto/mosquitto.exe"
        elif [ -f "/c/mosquitto/mosquitto.exe" ]; then
          MOSQUITTO_BIN="/c/mosquitto/mosquitto.exe"
        fi
      fi

      if [ -z "${MOSQUITTO_BIN}" ]; then
        # Try to see if Mosquitto is installed as a Windows service and start it.
        if command -v sc >/dev/null 2>&1; then
          if sc query mosquitto >/dev/null 2>&1; then
            echo "Mosquitto Windows service detected. Attempting to start service..."
            sc start mosquitto || true
            sleep 0.5
            if sc query mosquitto | grep -q "RUNNING"; then
              echo "Mosquitto service started."
              return 0
            fi
          fi
        fi

        echo "mosquitto binary not found on host. Please install Mosquitto or run containerized mode." >&2
        echo "On Windows you can install the Mosquitto binary from https://mosquitto.org/download/ or use the containerized mode: '$0 containerized'" >&2
        exit 2
      fi

      echo "Starting host mosquitto using config: $MOSQ_CONF"
      mkdir -p "$(dirname "$MOSQ_LOG")"
      # Respect paths with spaces by quoting the binary
      nohup "${MOSQUITTO_BIN}" -v -c "$MOSQ_CONF" >"$MOSQ_LOG" 2>&1 &
      echo $! >"$MOSQ_PIDFILE"
      sleep 0.3
      pid=$(cat "$MOSQ_PIDFILE")
      if kill -0 "$pid" >/dev/null 2>&1; then
        echo "Mosquitto started (pid=$pid). Logs: $MOSQ_LOG"
      else
        echo "Failed starting mosquitto. Check $MOSQ_LOG" >&2
        exit 3
      fi
    }

    start_mosquitto_native || true

    docker compose -f "$COMPOSE_FILE" up --build -d
    # Print broker IP for device setup
    if [ -n "${PYTHON_BIN:-}" ]; then
      "$PYTHON_BIN" "$SCRIPT_DIR/Hub/util/print-ip.py" || true
    else
      echo "Python not found - cannot print broker IP."
    fi
  else
    echo "Starting containerized broker + gateway using compose file: $COMPOSE_FILE"
    docker compose -f "$COMPOSE_FILE" up --build -d
    # Print broker IP for device setup
    if [ -n "${PYTHON_BIN:-}" ]; then
      "$PYTHON_BIN" "$SCRIPT_DIR/Hub/util/print-ip.py" || true
    else
      echo "Python not found - cannot print broker IP."
    fi
  fi
  echo "Done. Use 'docker ps' to see running containers and 'docker compose -f $COMPOSE_FILE logs -f' to follow logs."
else
  # down
  echo "Stopping stack defined in $COMPOSE_FILE"
  docker compose -f "$COMPOSE_FILE" down
  echo "Stopped."
fi

if [ "$CMD" = "down" ]; then
  if [ "$MODE" = "native" ] || [ "$MODE" = "n" ]; then
    # Stop host mosquitto if we started it (pidfile present)
    if [ -f "$MOSQ_PIDFILE" ]; then
      pid=$(cat "$MOSQ_PIDFILE" 2>/dev/null || true)
      if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
        echo "Stopping host mosquitto (pid=$pid)"
        kill "$pid" || true
        sleep 0.2
        rm -f "$MOSQ_PIDFILE"
        echo "Mosquitto stopped."
      else
        echo "No running mosquitto found for pidfile; removing stale pidfile."
        rm -f "$MOSQ_PIDFILE" || true
      fi
    else
      echo "No mosquitto pidfile found; nothing to stop on host."
    fi
  fi
fi

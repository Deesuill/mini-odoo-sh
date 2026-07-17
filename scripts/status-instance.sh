#!/bin/bash

set -euo pipefail

MINI_ODOO_HOME="${MINI_ODOO_HOME:-/opt/mini-odoo-sh}"

source "$MINI_ODOO_HOME/lib/common.sh"
source "$MINI_ODOO_HOME/lib/logging.sh"
source "$MINI_ODOO_HOME/lib/instance.sh"
source "$MINI_ODOO_HOME/lib/docker.sh"
source "$MINI_ODOO_HOME/lib/registry.sh"

load_platform_config

show_usage() {
    echo "Usage: status-instance.sh <instance-name>" >&2
}

if [ $# -ne 1 ]; then
    show_usage
    exit 1
fi

INSTANCE_NAME="$1"
INSTANCE_PATH=$(instance_path "$INSTANCE_NAME")
INSTANCE_ENV=$(instance_env "$INSTANCE_NAME")

if ! instance_exists "$INSTANCE_NAME"; then
    INSTANCE_NAME="$INSTANCE_NAME" \
    INSTANCE_PATH="$INSTANCE_PATH" \
    python3 <<'PYTHON'
import json
import os

print(json.dumps({
    "name": os.environ["INSTANCE_NAME"],
    "path": os.environ["INSTANCE_PATH"],
    "status": "missing",
    "error": "Instance directory does not exist."
}, indent=2))
PYTHON

    exit 1
fi

REPOSITORY=""
ODOO_PORT=""

if [ -f "$INSTANCE_ENV" ]; then
    REPOSITORY=$(
        instance_config_value "$INSTANCE_NAME" "REPOSITORY" 2>/dev/null || true
    )

    ODOO_PORT=$(
        instance_config_value "$INSTANCE_NAME" "ODOO_PORT" 2>/dev/null || true
    )
fi

REGISTERED=false

if registry_has_instance "$INSTANCE_NAME"; then
    REGISTERED=true
fi

COMPOSE_JSON="[]"
COMPOSE_AVAILABLE=true

if [ -f "$INSTANCE_PATH/docker-compose.yml" ] || \
   [ -f "$INSTANCE_PATH/docker-compose.yaml" ] || \
   [ -f "$INSTANCE_PATH/compose.yml" ] || \
   [ -f "$INSTANCE_PATH/compose.yaml" ]; then

    cd "$INSTANCE_PATH"

    set +e
    COMPOSE_JSON=$(docker_compose_ps_json 2>/dev/null)
    COMPOSE_STATUS=$?
    set -e

    if [ "$COMPOSE_STATUS" -ne 0 ]; then
        COMPOSE_JSON="[]"
        COMPOSE_AVAILABLE=false
    fi
else
    COMPOSE_AVAILABLE=false
fi

HTTP_REACHABLE=false
HTTP_STATUS_CODE=""
HTTP_URL=""

if [[ "$ODOO_PORT" =~ ^[0-9]+$ ]]; then
    HTTP_URL="http://127.0.0.1:$ODOO_PORT"

    set +e
    HTTP_STATUS_CODE=$(
        curl \
            --silent \
            --output /dev/null \
            --write-out "%{http_code}" \
            --connect-timeout 2 \
            --max-time 5 \
            "$HTTP_URL"
    )
    CURL_STATUS=$?
    set -e

    if [ "$CURL_STATUS" -eq 0 ] &&
       [ "$HTTP_STATUS_CODE" -ge 200 ] &&
       [ "$HTTP_STATUS_CODE" -lt 500 ]; then
        HTTP_REACHABLE=true
    fi
fi

INSTANCE_NAME="$INSTANCE_NAME" \
INSTANCE_PATH="$INSTANCE_PATH" \
INSTANCE_ENV="$INSTANCE_ENV" \
REPOSITORY="$REPOSITORY" \
ODOO_PORT="$ODOO_PORT" \
REGISTERED="$REGISTERED" \
COMPOSE_AVAILABLE="$COMPOSE_AVAILABLE" \
COMPOSE_JSON="$COMPOSE_JSON" \
HTTP_REACHABLE="$HTTP_REACHABLE" \
HTTP_STATUS_CODE="$HTTP_STATUS_CODE" \
HTTP_URL="$HTTP_URL" \
python3 <<'PYTHON'
import json
import os
import sys


def boolean_env(name):
    return os.environ.get(name, "false").lower() == "true"


def normalize_state(value):
    value = str(value or "").strip().lower()

    if value in {"running", "up"}:
        return "running"

    if value in {"exited", "stopped", "dead", "created"}:
        return "stopped"

    if value in {"restarting"}:
        return "restarting"

    if value in {"paused"}:
        return "paused"

    return value or "unknown"


def parse_compose_output(raw_output):
    raw_output = raw_output.strip()

    if not raw_output:
        return []

    try:
        parsed = json.loads(raw_output)

        if isinstance(parsed, list):
            return parsed

        if isinstance(parsed, dict):
            return [parsed]

    except json.JSONDecodeError:
        pass

    services = []

    # Neke Docker Compose verzije vraćaju po jedan JSON objekat po liniji.
    for line in raw_output.splitlines():
        line = line.strip()

        if not line:
            continue

        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue

        if isinstance(item, dict):
            services.append(item)

    return services


instance_name = os.environ["INSTANCE_NAME"]
instance_path = os.environ["INSTANCE_PATH"]
instance_env = os.environ["INSTANCE_ENV"]
repository = os.environ.get("REPOSITORY", "")
port_value = os.environ.get("ODOO_PORT", "")
registered = boolean_env("REGISTERED")
compose_available = boolean_env("COMPOSE_AVAILABLE")
http_reachable = boolean_env("HTTP_REACHABLE")
http_status_code = os.environ.get("HTTP_STATUS_CODE", "")
http_url = os.environ.get("HTTP_URL", "")

try:
    port = int(port_value) if port_value else None
except ValueError:
    port = None

compose_services = parse_compose_output(
    os.environ.get("COMPOSE_JSON", "[]")
)

services = {}
running_services = 0

for service_data in compose_services:
    service_name = (
        service_data.get("Service")
        or service_data.get("Name")
        or "unknown"
    )

    raw_state = (
        service_data.get("State")
        or service_data.get("Status")
        or ""
    )

    state = normalize_state(raw_state)

    services[service_name] = state

    if state == "running":
        running_services += 1

if not compose_available:
    overall_status = "unavailable"
elif not compose_services:
    overall_status = "stopped"
elif running_services == len(compose_services):
    overall_status = "running"
elif running_services > 0:
    overall_status = "partial"
else:
    overall_status = "stopped"

result = {
    "name": instance_name,
    "repository": repository or None,
    "port": port,
    "path": instance_path,
    "registered": registered,
    "configuration_exists": os.path.isfile(instance_env),
    "compose_available": compose_available,
    "status": overall_status,
    "services": services,
    "http": {
        "reachable": http_reachable,
        "status_code": (
            int(http_status_code)
            if http_status_code.isdigit()
            else None
        ),
        "url": http_url or None
    }
}

print(json.dumps(result, indent=2, sort_keys=False))

if overall_status == "running" and http_reachable:
    sys.exit(0)

sys.exit(1)
PYTHON

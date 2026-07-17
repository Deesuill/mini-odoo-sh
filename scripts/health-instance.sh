#!/bin/bash

set -e

MINI_ODOO_HOME="/opt/mini-odoo-sh"

source "$MINI_ODOO_HOME/lib/common.sh"
source "$MINI_ODOO_HOME/lib/logging.sh"
source "$MINI_ODOO_HOME/lib/instance.sh"

load_platform_config

if [ $# -ne 1 ]; then
    echo "Usage:"
    echo "./health-instance.sh <instance-name>"
    exit 1
fi

INSTANCE_NAME="$1"

instance_require "$INSTANCE_NAME"

ODOO_CONTAINER="${INSTANCE_NAME}-odoo"
POSTGRES_CONTAINER="${INSTANCE_NAME}-postgres"
PORT=$(instance_port "$INSTANCE_NAME")

HEALTH_FAILED=0

log_info "Checking instance: $INSTANCE_NAME"

echo
echo "Docker status:"

if docker ps \
    --filter "name=^/${ODOO_CONTAINER}$" \
    --filter "status=running" \
    --format '{{.Names}}' \
    | grep -Fxq "$ODOO_CONTAINER"; then

    echo "  Odoo container: OK"
else
    echo "  Odoo container: DOWN"
    HEALTH_FAILED=1
fi

if docker ps \
    --filter "name=^/${POSTGRES_CONTAINER}$" \
    --filter "status=running" \
    --format '{{.Names}}' \
    | grep -Fxq "$POSTGRES_CONTAINER"; then

    echo "  PostgreSQL container: OK"
else
    echo "  PostgreSQL container: DOWN"
    HEALTH_FAILED=1
fi

echo
echo "Odoo HTTP check:"

if curl \
    --silent \
    --show-error \
    --fail \
    --max-time 10 \
    "http://127.0.0.1:$PORT" \
    >/dev/null; then

    echo "  Odoo web: OK"
else
    echo "  Odoo web: DOWN"
    HEALTH_FAILED=1
fi

echo

if [ "$HEALTH_FAILED" -eq 0 ]; then
    log_success "Instance is healthy: $INSTANCE_NAME"
    exit 0
fi

log_error "Instance health check failed: $INSTANCE_NAME"

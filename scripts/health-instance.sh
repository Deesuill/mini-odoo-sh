#!/bin/bash

INSTANCE_NAME=$1

if [ $# -ne 1 ]; then
    echo "Usage: health-instance.sh <instance>"
    exit 1
fi


CONTAINER_ODOO="${INSTANCE_NAME}-odoo"
CONTAINER_POSTGRES="${INSTANCE_NAME}-postgres"


echo "Checking instance: $INSTANCE_NAME"
echo ""


echo "Docker status:"


if docker ps --format '{{.Names}}' | grep -q "$CONTAINER_ODOO"; then
    echo "  Odoo container: OK"
else
    echo "  Odoo container: DOWN"
fi


if docker ps --format '{{.Names}}' | grep -q "$CONTAINER_POSTGRES"; then
    echo "  PostgreSQL container: OK"
else
    echo "  PostgreSQL container: DOWN"
fi


echo ""

echo "Odoo HTTP check:"


PORT=$(grep ODOO_PORT \
/opt/mini-odoo-instances/$INSTANCE_NAME/instance.env \
| cut -d= -f2)


if curl -s http://localhost:$PORT >/dev/null; then
    echo "  Odoo web: OK"
else
    echo "  Odoo web: DOWN"
fi

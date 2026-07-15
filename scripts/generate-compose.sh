#!/bin/bash

set -e

INSTANCE_NAME=$1
ODOO_PORT=$2

if [ $# -ne 2 ]; then
    echo "Usage: ./generate-compose.sh <instance-name> <odoo-port>"
    exit 1
fi

TEMPLATE="/opt/mini-odoo-sh/templates/docker-compose.yml.tpl"
OUTPUT="/opt/mini-odoo-instances/$INSTANCE_NAME/docker-compose.yml"

if [ ! -f "$TEMPLATE" ]; then
    echo "Template file not found: $TEMPLATE"
    exit 1
fi

sed \
    -e "s/{{INSTANCE_NAME}}/$INSTANCE_NAME/g" \
    -e "s/{{ODOO_PORT}}/$ODOO_PORT/g" \
    "$TEMPLATE" > "$OUTPUT"

echo "docker-compose.yml generated successfully."
echo "Output: $OUTPUT"

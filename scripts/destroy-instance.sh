#!/bin/bash

set -e

INSTANCE_NAME=$1

BASE_PATH="/opt/mini-odoo-instances"
INSTANCE_PATH="$BASE_PATH/$INSTANCE_NAME"


if [ $# -ne 1 ]; then
    echo "Usage:"
    echo "./destroy-instance.sh <instance-name>"
    exit 1
fi


if [ ! -d "$INSTANCE_PATH" ]; then
    echo "Instance not found: $INSTANCE_NAME"
    exit 1
fi


echo "Destroying instance: $INSTANCE_NAME"


cd "$INSTANCE_PATH"


echo "Stopping containers..."

docker compose down -v


echo "Removing instance files..."

cd "$BASE_PATH"

rm -rf "$INSTANCE_NAME"


echo "Instance destroyed successfully."

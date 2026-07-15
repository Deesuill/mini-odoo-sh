#!/bin/bash

set -e

INSTANCE_NAME=$1
MODULES=$2


if [ $# -ne 2 ]; then
    echo "Usage:"
    echo "./upgrade-modules.sh <instance-name> <modules>"
    exit 1
fi


INSTANCE_PATH="/opt/mini-odoo-instances/$INSTANCE_NAME"


if [ ! -d "$INSTANCE_PATH" ]; then
    echo "Instance not found: $INSTANCE_NAME"
    exit 1
fi


cd "$INSTANCE_PATH"


echo "Updating modules:"
echo "$MODULES"


docker compose run --rm odoo \
    -u "$MODULES" \
    --stop-after-init


echo "Modules updated successfully."

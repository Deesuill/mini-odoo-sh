#!/bin/bash

set -e

INSTANCE_NAME=$1

if [ $# -ne 1 ]; then
    echo "Usage:"
    echo "./upgrade-modules.sh <instance-name>"
    exit 1
fi


INSTANCE_PATH="/opt/mini-odoo-instances/$INSTANCE_NAME"


if [ ! -d "$INSTANCE_PATH" ]; then
    echo "Instance not found: $INSTANCE_NAME"
    exit 1
fi


cd "$INSTANCE_PATH"


echo "Updating Odoo modules..."


docker compose run --rm odoo \
    -u all \
    --stop-after-init


echo "Modules updated successfully."

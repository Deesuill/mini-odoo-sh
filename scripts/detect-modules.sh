#!/bin/bash

set -e


INSTANCE_NAME=$1


if [ $# -ne 1 ]; then
    echo "Usage: detect-modules.sh <instance>"
    exit 1
fi


ADDONS_PATH="/opt/mini-odoo-instances/$INSTANCE_NAME/addons"


if [ ! -d "$ADDONS_PATH" ]; then
    echo "No addons folder found"
    exit 0
fi


echo "Detected modules:"


for module in "$ADDONS_PATH"/*; do

    if [ -f "$module/__manifest__.py" ]; then

        basename "$module"

    fi

done

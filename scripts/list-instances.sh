#!/bin/bash

BASE_PATH="/opt/mini-odoo-instances"

echo "Available Odoo instances:"
echo "--------------------------------"

for INSTANCE in "$BASE_PATH"/*; do

    if [ -d "$INSTANCE" ]; then

        NAME=$(basename "$INSTANCE")

        if [ -f "$INSTANCE/instance.env" ]; then
            echo ""
            echo "Instance: $NAME"
            cat "$INSTANCE/instance.env"
        else
            echo ""
            echo "Instance: $NAME"
            echo "No configuration found"
        fi

        echo "--------------------------------"
    fi

done

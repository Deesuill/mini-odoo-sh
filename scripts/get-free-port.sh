#!/bin/bash

PORT=18080

while true; do
    if ! ss -tuln | grep -q ":$PORT "; then
        echo "$PORT"
        exit 0
    fi

    PORT=$((PORT + 1))
done

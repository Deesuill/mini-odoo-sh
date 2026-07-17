#!/bin/bash

set -e

START_PORT="${ODOO_START_PORT:-18080}"
MAX_PORT="${ODOO_MAX_PORT:-19000}"

PORT="$START_PORT"

while [ "$PORT" -le "$MAX_PORT" ]; do
    if ! ss -H -lnt "sport = :$PORT" | grep -q .; then
        echo "$PORT"
        exit 0
    fi

    PORT=$((PORT + 1))
done

echo "No free port available between $START_PORT and $MAX_PORT." >&2
exit 1

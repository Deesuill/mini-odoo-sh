#!/bin/bash

set -e

MINI_ODOO_HOME="/opt/mini-odoo-sh"

source "$MINI_ODOO_HOME/lib/common.sh"
source "$MINI_ODOO_HOME/lib/logging.sh"
source "$MINI_ODOO_HOME/lib/instance.sh"
source "$MINI_ODOO_HOME/lib/registry.sh"

load_platform_config

log_info "Available Odoo instances:"

FOUND_INSTANCE=0

while IFS=$'\t' read -r INSTANCE_NAME REPOSITORY PORT; do
    if [ -z "$INSTANCE_NAME" ]; then
        continue
    fi

    FOUND_INSTANCE=1
    INSTANCE_PATH=$(instance_path "$INSTANCE_NAME")

    echo
    echo "--------------------------------"
    echo "Instance: $INSTANCE_NAME"
    echo "Repository: $REPOSITORY"
    echo "Port: $PORT"
    echo "Path: $INSTANCE_PATH"

    if [ -d "$INSTANCE_PATH" ]; then
        echo "Files: OK"
    else
        echo "Files: MISSING"
        log_warning "Instance is registered, but its directory does not exist."
    fi

    if [ -f "$INSTANCE_PATH/instance.env" ]; then
        echo "Configuration: OK"
    else
        echo "Configuration: MISSING"
    fi
done < <(registry_list_instances)

echo
echo "--------------------------------"

if [ "$FOUND_INSTANCE" -eq 0 ]; then
    log_warning "No registered instances found."
fi

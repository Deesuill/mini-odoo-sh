#!/bin/bash

set -e

MINI_ODOO_HOME="/opt/mini-odoo-sh"

source "$MINI_ODOO_HOME/lib/common.sh"
source "$MINI_ODOO_HOME/lib/logging.sh"
source "$MINI_ODOO_HOME/lib/registry.sh"

load_platform_config

if [ $# -ne 3 ]; then
    echo "Usage:"
    echo "./register-instance.sh <instance-name> <repository> <port>"
    exit 1
fi

INSTANCE_NAME="$1"
REPOSITORY="$2"
PORT="$3"

if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    log_error "Invalid port: $PORT"
fi

registry_register_instance \
    "$INSTANCE_NAME" \
    "$REPOSITORY" \
    "$PORT"

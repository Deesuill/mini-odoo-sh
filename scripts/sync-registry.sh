#!/bin/bash

set -e

MINI_ODOO_HOME="/opt/mini-odoo-sh"

source "$MINI_ODOO_HOME/lib/common.sh"
source "$MINI_ODOO_HOME/lib/logging.sh"
source "$MINI_ODOO_HOME/lib/instance.sh"
source "$MINI_ODOO_HOME/lib/registry.sh"

load_platform_config

show_usage() {
    echo "Usage:"
    echo "  ./sync-registry.sh <instance-name>"
    echo "  ./sync-registry.sh --all"
}

if [ $# -ne 1 ]; then
    show_usage
    exit 1
fi

TARGET="$1"

if [ "$TARGET" = "--all" ]; then
    log_info "Synchronizing all instance configurations with registry..."

    registry_sync_all_from_env

    exit 0
fi

if [[ "$TARGET" == --* ]]; then
    log_error "Unknown option: $TARGET"
fi

log_info "Synchronizing registry from instance configuration..."
log_info "Instance: $TARGET"

registry_sync_instance_from_env "$TARGET"

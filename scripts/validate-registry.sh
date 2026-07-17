#!/bin/bash

set -e

MINI_ODOO_HOME="/opt/mini-odoo-sh"

source "$MINI_ODOO_HOME/lib/common.sh"
source "$MINI_ODOO_HOME/lib/logging.sh"
source "$MINI_ODOO_HOME/lib/registry.sh"

load_platform_config

log_info "Validating instance registry..."

set +e
VALIDATION_OUTPUT=$(registry_validate)
VALIDATION_STATUS=$?
set -e

while IFS=$'\t' read -r STATUS INSTANCE_NAME DETAILS; do
    if [ -z "$STATUS" ]; then
        continue
    fi

    case "$STATUS" in
        OK)
            log_success "$INSTANCE_NAME"
            ;;

        UNREGISTERED)
            log_warning "Unregistered instance: $INSTANCE_NAME"
            echo "  $DETAILS"
            ;;

        MISSING_DIRECTORY)
            log_warning "Missing directory: $INSTANCE_NAME"
            echo "  $DETAILS"
            ;;

        MISSING_CONFIG)
            log_warning "Missing configuration: $INSTANCE_NAME"
            echo "  $DETAILS"
            ;;

        NAME_MISMATCH)
            log_warning "Instance name mismatch: $INSTANCE_NAME"
            echo "  $DETAILS"
            ;;

        REPOSITORY_MISMATCH)
            log_warning "Repository mismatch: $INSTANCE_NAME"
            echo "  $DETAILS"
            ;;

        PORT_MISMATCH)
            log_warning "Port mismatch: $INSTANCE_NAME"
            echo "  $DETAILS"
            ;;

        ERROR)
            log_error "$INSTANCE_NAME"
            ;;

        *)
            log_warning "$STATUS: $INSTANCE_NAME $DETAILS"
            ;;
    esac
done <<< "$VALIDATION_OUTPUT"

if [ "$VALIDATION_STATUS" -eq 0 ]; then
    exit 0
fi

if [ "$VALIDATION_STATUS" -eq 2 ]; then
    log_error "Registry validation could not be completed."
fi

log_warning "Registry validation found inconsistencies."
exit 1

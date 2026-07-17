#!/bin/bash

set -e

MINI_ODOO_HOME="/opt/mini-odoo-sh"

source "$MINI_ODOO_HOME/lib/common.sh"
source "$MINI_ODOO_HOME/lib/logging.sh"
source "$MINI_ODOO_HOME/lib/docker.sh"
source "$MINI_ODOO_HOME/lib/instance.sh"

load_platform_config

if [ $# -ne 2 ]; then
    echo "Usage:"
    echo "./manage-instance.sh <start|stop|restart|status> <instance-name>"
    exit 1
fi

ACTION="$1"
INSTANCE_NAME="$2"

instance_require "$INSTANCE_NAME"
instance_cd "$INSTANCE_NAME"

case "$ACTION" in
    start)
        log_info "Starting instance: $INSTANCE_NAME"
        docker_compose_up
        log_success "Instance started: $INSTANCE_NAME"
        ;;

    stop)
        log_info "Stopping instance: $INSTANCE_NAME"
        docker_compose_down
        log_success "Instance stopped: $INSTANCE_NAME"
        ;;

    restart)
        log_info "Restarting instance: $INSTANCE_NAME"
        docker_compose_restart
        log_success "Instance restarted: $INSTANCE_NAME"
        ;;

    status)
        log_info "Status of instance: $INSTANCE_NAME"
        docker_compose_ps
        ;;

    *)
        log_error "Unknown action: $ACTION. Allowed actions: start, stop, restart, status."
        ;;
esac

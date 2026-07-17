#!/bin/bash

set -e

MINI_ODOO_HOME="/opt/mini-odoo-sh"

source "$MINI_ODOO_HOME/lib/common.sh"
source "$MINI_ODOO_HOME/lib/logging.sh"
source "$MINI_ODOO_HOME/lib/docker.sh"
source "$MINI_ODOO_HOME/lib/instance.sh"

load_platform_config

if [ $# -ne 1 ]; then
    echo "Usage:"
    echo "./backup-instance.sh <instance-name>"
    exit 1
fi

INSTANCE_NAME="$1"

instance_require "$INSTANCE_NAME"

BACKUP_ROOT="${BACKUPS_PATH:-/opt/mini-odoo-backups}"
BACKUP_DIR="$BACKUP_ROOT/$INSTANCE_NAME"
BACKUP_FILE="$BACKUP_DIR/database.sql"

POSTGRES_CONTAINER="${INSTANCE_NAME}-postgres"

log_info "Creating backup directory..."
mkdir -p "$BACKUP_DIR"

log_info "Creating database backup for instance: $INSTANCE_NAME"

docker_exec "$POSTGRES_CONTAINER" \
    pg_dump \
    -U odoo \
    postgres \
    > "$BACKUP_FILE"

if [ ! -s "$BACKUP_FILE" ]; then
    rm -f -- "$BACKUP_FILE"
    log_error "Database backup is empty or was not created."
fi

log_success "Backup finished successfully."
log_info "Location: $BACKUP_FILE"

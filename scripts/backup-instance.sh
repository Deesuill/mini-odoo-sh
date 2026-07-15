#!/bin/bash

set -e


INSTANCE_NAME=$1


if [ $# -ne 1 ]; then
    echo "Usage: backup-instance.sh <instance>"
    exit 1
fi


BACKUP_DIR="/opt/mini-odoo-backups/$INSTANCE_NAME"

mkdir -p "$BACKUP_DIR"


echo "Creating database backup..."


docker exec ${INSTANCE_NAME}-postgres \
pg_dump \
-U odoo \
postgres \
> "$BACKUP_DIR/database.sql"


echo "Backup finished."

echo "Location:"
echo "$BACKUP_DIR"

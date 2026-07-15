#!/bin/bash

set -e

INSTANCE_NAME=$1

if [ -z "$INSTANCE_NAME" ]; then
    echo "Usage: ./deploy-instance.sh <instance-name>"
    exit 1
fi

INSTANCE_PATH="/opt/mini-odoo-instances/$INSTANCE_NAME"

echo "Deploying $INSTANCE_NAME..."

cd "$INSTANCE_PATH"

git pull

docker compose up -d

echo "Deployment completed."

#!/bin/bash

set -e

INSTANCE_NAME=$1

BASE_PATH="/opt/mini-odoo-instances"
INSTANCE_PATH="$BASE_PATH/$INSTANCE_NAME"


if [ $# -ne 1 ]; then
    echo "Usage:"
    echo "./deploy-instance.sh <instance-name>"
    exit 1
fi


if [ ! -d "$INSTANCE_PATH" ]; then
    echo "Instance not found: $INSTANCE_NAME"
    exit 1
fi


echo "Deploying instance: $INSTANCE_NAME"


cd "$INSTANCE_PATH"


echo "Pulling latest changes..."
git pull


echo "Restarting containers..."
docker compose up -d


echo "Deployment finished successfully."

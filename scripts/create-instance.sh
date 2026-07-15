#!/bin/bash

set -e

INSTANCE_NAME=$1
REPOSITORY=$2

if [ $# -ne 2 ]; then
    echo "Usage:"
    echo "./create-instance.sh <instance-name> <git-repository>"
    exit 1
fi


BASE_PATH="/opt/mini-odoo-instances"
INSTANCE_PATH="$BASE_PATH/$INSTANCE_NAME"


if [ -d "$INSTANCE_PATH" ]; then
    echo "Instance already exists: $INSTANCE_NAME"
    exit 1
fi


echo "Creating instance: $INSTANCE_NAME"
echo "Repository: $REPOSITORY"


echo "Creating directory..."
mkdir -p "$INSTANCE_PATH"


echo "Cloning repository..."
git clone "$REPOSITORY" "$INSTANCE_PATH"

echo "Initializing project structure..."

 /opt/mini-odoo-sh/scripts/init-project.sh "$INSTANCE_PATH"

echo "Creating data folders..."
mkdir -p "$INSTANCE_PATH/data/postgres"
mkdir -p "$INSTANCE_PATH/data/odoo"
mkdir -p "$INSTANCE_PATH/addons"
mkdir -p "$INSTANCE_PATH/config"

echo "Finding available port..."
PORT=$(/opt/mini-odoo-sh/scripts/get-free-port.sh)

echo "Using port: $PORT"


echo "Generating docker-compose.yml..."
/opt/mini-odoo-sh/scripts/generate-compose.sh "$INSTANCE_NAME" "$PORT"


echo "Creating instance configuration..."

cat > "$INSTANCE_PATH/instance.env" <<EOF
INSTANCE_NAME=$INSTANCE_NAME
ODOO_PORT=$PORT
REPOSITORY=$REPOSITORY
EOF


echo "Starting containers..."

cd "$INSTANCE_PATH"

docker compose up -d


echo ""
echo "================================="
echo "Instance created successfully!"
echo "Name: $INSTANCE_NAME"
echo "Port: $PORT"
echo "================================="

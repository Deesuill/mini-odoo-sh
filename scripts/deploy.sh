#!/bin/bash

set -e

echo "Starting deployment..."

cd /opt/mini-odoo-sh

echo "Pulling latest changes..."
git pull

echo "Restarting containers..."
docker compose -f docker/docker-compose.yml up -d

echo "Deployment finished successfully."

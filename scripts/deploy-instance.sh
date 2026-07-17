#!/bin/bash

set -e

MINI_ODOO_HOME="/opt/mini-odoo-sh"

source "$MINI_ODOO_HOME/lib/common.sh"
source "$MINI_ODOO_HOME/lib/logging.sh"
source "$MINI_ODOO_HOME/lib/docker.sh"
source "$MINI_ODOO_HOME/lib/github.sh"
source "$MINI_ODOO_HOME/lib/instance.sh"

load_platform_config

INSTANCE_NAME=$1

if [ $# -ne 1 ]; then
    echo "Usage:"
    echo "./deploy-instance.sh <instance-name>"
    exit 1
fi

instance_require "$INSTANCE_NAME"

INSTANCE_PATH=$(instance_path "$INSTANCE_NAME")

log_info "Deploying instance: $INSTANCE_NAME"

instance_cd "$INSTANCE_NAME"

log_info "Saving current version..."

CURRENT_COMMIT=$(git rev-parse HEAD)

log_info "Current commit: $CURRENT_COMMIT"

log_info "Pulling latest changes..."

git pull

log_info "Restarting containers..."

docker_compose_up

log_info "Detecting modules..."

MODULES=$("$MINI_ODOO_HOME/scripts/detect-modules.sh" "$INSTANCE_NAME" | tail -n +2)

if [ -n "$MODULES" ]; then

    log_info "Modules found:"
    echo "$MODULES"

    "$MINI_ODOO_HOME/scripts/upgrade-modules.sh" \
        "$INSTANCE_NAME" \
        "$MODULES"

else

    log_info "No custom modules found."

fi

log_info "Checking containers..."

sleep 5

if ! docker_compose_ps | grep -q "Up"; then

    log_error "Deployment failed! Rolling back..."

    git reset --hard "$CURRENT_COMMIT"

    docker_compose_up

    exit 1

fi

log_success "Deployment finished successfully."

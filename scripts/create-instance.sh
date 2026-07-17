#!/bin/bash

set -e

MINI_ODOO_HOME="/opt/mini-odoo-sh"

source "$MINI_ODOO_HOME/lib/common.sh"
source "$MINI_ODOO_HOME/lib/logging.sh"
source "$MINI_ODOO_HOME/lib/docker.sh"
source "$MINI_ODOO_HOME/lib/github.sh"
source "$MINI_ODOO_HOME/lib/instance.sh"
source "$MINI_ODOO_HOME/lib/registry.sh"

load_platform_config

INSTANCE_NAME=$1
REPOSITORY=$2

if [ $# -ne 2 ]; then
    echo "Usage:"
    echo "./create-instance.sh <instance-name> <git-repository>"
    exit 1
fi

INSTANCE_PATH=$(instance_path "$INSTANCE_NAME")

if instance_exists "$INSTANCE_NAME"; then
    log_error "Instance already exists: $INSTANCE_NAME"
fi

log_info "Creating instance: $INSTANCE_NAME"
log_info "Repository: $REPOSITORY"

log_info "Creating directory..."
mkdir -p "$INSTANCE_PATH"

log_info "Cloning repository..."
git clone "$REPOSITORY" "$INSTANCE_PATH"

log_info "Initializing project structure..."
"$MINI_ODOO_HOME/scripts/init-project.sh" "$INSTANCE_PATH"

log_info "Creating data folders..."
mkdir -p "$INSTANCE_PATH/data/postgres"
mkdir -p "$INSTANCE_PATH/data/odoo"
mkdir -p "$INSTANCE_PATH/addons"
mkdir -p "$INSTANCE_PATH/config"

log_info "Finding available port..."
PORT=$("$MINI_ODOO_HOME/scripts/get-free-port.sh")

log_info "Using port: $PORT"

log_info "Generating docker-compose.yml..."
"$MINI_ODOO_HOME/scripts/generate-compose.sh" "$INSTANCE_NAME" "$PORT"

log_info "Creating instance configuration..."

cat > "$INSTANCE_PATH/instance.env" <<EOF
INSTANCE_NAME=$INSTANCE_NAME
ODOO_PORT=$PORT
REPOSITORY=$REPOSITORY
EOF

log_info "Registering instance..."
registry_register_instance \
    "$INSTANCE_NAME" \
    "$REPOSITORY" \
    "$PORT"

log_info "Configuring GitHub integration..."
github_bootstrap_instance "$INSTANCE_NAME" "$REPOSITORY"

log_info "Starting containers..."

cd "$INSTANCE_PATH"

docker_compose_up

log_info "Saving generated files to repository..."

git add .

if git diff --cached --quiet; then
    log_info "No changes to commit."
else
    git commit -m "Initialize mini-odoo instance"
    git push origin main
fi

echo
echo "================================="
log_success "Instance created successfully"
echo "Name: $INSTANCE_NAME"
echo "Port: $PORT"
echo "================================="

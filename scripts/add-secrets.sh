#!/bin/bash

set -e

MINI_ODOO_HOME="/opt/mini-odoo-sh"

source "$MINI_ODOO_HOME/lib/common.sh"
source "$MINI_ODOO_HOME/lib/logging.sh"
source "$MINI_ODOO_HOME/lib/github.sh"

load_platform_config

if [ $# -ne 2 ]; then
    echo "Usage:"
    echo "./add-secrets.sh <instance-name> <repo-name>"
    exit 1
fi

INSTANCE_NAME="$1"
REPO_NAME="$2"

log_info "Configuring GitHub secrets for instance: $INSTANCE_NAME"

github_add_actions_secrets "$REPO_NAME"

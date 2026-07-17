#!/bin/bash

set -e

MINI_ODOO_HOME="/opt/mini-odoo-sh"

source "$MINI_ODOO_HOME/lib/common.sh"
source "$MINI_ODOO_HOME/lib/logging.sh"
source "$MINI_ODOO_HOME/lib/github.sh"

load_platform_config

if [ $# -ne 2 ]; then
    echo "Usage:"
    echo "./add-deploy-key.sh <instance-name> <repo-name>"
    exit 1
fi

INSTANCE_NAME="$1"
REPO_NAME="$2"

github_add_deploy_key "$INSTANCE_NAME" "$REPO_NAME"

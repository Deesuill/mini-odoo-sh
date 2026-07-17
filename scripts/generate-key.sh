#!/bin/bash

set -e

MINI_ODOO_HOME="/opt/mini-odoo-sh"

source "$MINI_ODOO_HOME/lib/common.sh"
source "$MINI_ODOO_HOME/lib/logging.sh"
source "$MINI_ODOO_HOME/lib/github.sh"

load_platform_config

if [ $# -ne 1 ]; then
    echo "Usage:"
    echo "./generate-key.sh <instance-name>"
    exit 1
fi

INSTANCE_NAME="$1"

github_generate_deploy_key "$INSTANCE_NAME"

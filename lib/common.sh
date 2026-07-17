#!/bin/bash

#
# Mini Odoo Platform
# Common library
#

set -e

export MINI_ODOO_HOME="/opt/mini-odoo-sh"
export INSTANCES_PATH="/opt/mini-odoo-instances"

PLATFORM_ENV="$MINI_ODOO_HOME/config/platform.env"

load_platform_config() {

    if [ ! -f "$PLATFORM_ENV" ]; then
        echo "Platform configuration not found:"
        echo "$PLATFORM_ENV"
        exit 1
    fi

    source "$PLATFORM_ENV"
}

instance_path() {

    echo "$INSTANCES_PATH/$1"

}

instance_exists() {

    [ -d "$(instance_path "$1")" ]

}

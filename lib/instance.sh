#!/bin/bash

instance_env() {

    echo "$(instance_path "$1")/instance.env"

}

load_instance() {

    instance_require "$1"

    source "$(instance_env "$1")"

}

instance_require() {

    local INSTANCE_NAME="$1"

    if ! instance_exists "$INSTANCE_NAME"; then
        log_error "Instance not found: $INSTANCE_NAME"
    fi

}

instance_cd() {

    cd "$(instance_path "$1")"

}

instance_repo() {

    load_instance "$1"
    echo "$REPOSITORY"

}

instance_port() {

    load_instance "$1"
    echo "$ODOO_PORT"

}

instance_name() {

    load_instance "$1"
    echo "$INSTANCE_NAME"

}

instance_compose() {

    echo "$(instance_path "$1")/docker-compose.yml"

}

instance_config_value() {
    local instance_name="$1"
    local variable_name="$2"
    local env_file

    env_file=$(instance_env "$instance_name")

    if [ ! -f "$env_file" ]; then
        log_error "Instance configuration not found: $env_file"
    fi

    VARIABLE_NAME="$variable_name" \
    ENV_FILE="$env_file" \
    python3 <<'PYTHON'
import os
import sys

env_file = os.environ["ENV_FILE"]
variable_name = os.environ["VARIABLE_NAME"]

with open(env_file, "r", encoding="utf-8") as file:
    for raw_line in file:
        line = raw_line.strip()

        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)

        if key.strip() == variable_name:
            print(value.strip())
            sys.exit(0)

sys.exit(1)
PYTHON
}

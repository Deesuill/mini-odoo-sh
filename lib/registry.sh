#!/bin/bash

registry_path() {
    echo "${REGISTRY_PATH:-$MINI_ODOO_HOME/instances.json}"
}

registry_initialize() {
    local registry

    registry=$(registry_path)

    if [ ! -f "$registry" ]; then
        log_info "Creating instance registry: $registry"

        mkdir -p "$(dirname "$registry")"
        printf '{}\n' > "$registry"
    fi
}

registry_register_instance() {
    local instance_name="$1"
    local repository="$2"
    local port="$3"
    local registry

    registry_initialize
    registry=$(registry_path)

    INSTANCE_NAME="$instance_name" \
    REPOSITORY="$repository" \
    ODOO_PORT="$port" \
    REGISTRY_FILE="$registry" \
    python3 <<'PYTHON'
import json
import os
import tempfile

registry_file = os.environ["REGISTRY_FILE"]
instance_name = os.environ["INSTANCE_NAME"]
repository = os.environ["REPOSITORY"]
port = int(os.environ["ODOO_PORT"])

with open(registry_file, "r", encoding="utf-8") as file:
    data = json.load(file)

data[instance_name] = {
    "repository": repository,
    "port": port
}

registry_directory = os.path.dirname(registry_file)
fd, temporary_file = tempfile.mkstemp(
    dir=registry_directory,
    prefix=".instances-",
    suffix=".json"
)

try:
    with os.fdopen(fd, "w", encoding="utf-8") as file:
        json.dump(data, file, indent=4)
        file.write("\n")

    os.replace(temporary_file, registry_file)
except Exception:
    if os.path.exists(temporary_file):
        os.remove(temporary_file)
    raise
PYTHON

    log_success "Instance registered: $instance_name"
}

registry_unregister_instance() {
    local instance_name="$1"
    local registry

    registry_initialize
    registry=$(registry_path)

    INSTANCE_NAME="$instance_name" \
    REGISTRY_FILE="$registry" \
    python3 <<'PYTHON'
import json
import os
import tempfile

registry_file = os.environ["REGISTRY_FILE"]
instance_name = os.environ["INSTANCE_NAME"]

with open(registry_file, "r", encoding="utf-8") as file:
    data = json.load(file)

data.pop(instance_name, None)

registry_directory = os.path.dirname(registry_file)
fd, temporary_file = tempfile.mkstemp(
    dir=registry_directory,
    prefix=".instances-",
    suffix=".json"
)

try:
    with os.fdopen(fd, "w", encoding="utf-8") as file:
        json.dump(data, file, indent=4)
        file.write("\n")

    os.replace(temporary_file, registry_file)
except Exception:
    if os.path.exists(temporary_file):
        os.remove(temporary_file)
    raise
PYTHON

    log_success "Instance removed from registry: $instance_name"
}

registry_has_instance() {
    local instance_name="$1"
    local registry

    registry_initialize
    registry=$(registry_path)

    INSTANCE_NAME="$instance_name" \
    REGISTRY_FILE="$registry" \
    python3 <<'PYTHON'
import json
import os
import sys

registry_file = os.environ["REGISTRY_FILE"]
instance_name = os.environ["INSTANCE_NAME"]

with open(registry_file, "r", encoding="utf-8") as file:
    data = json.load(file)

sys.exit(0 if instance_name in data else 1)
PYTHON
}

registry_list_instances() {
    local registry

    registry_initialize
    registry=$(registry_path)

    REGISTRY_FILE="$registry" \
    python3 <<'PYTHON'
import json
import os

registry_file = os.environ["REGISTRY_FILE"]

with open(registry_file, "r", encoding="utf-8") as file:
    data = json.load(file)

for instance_name in sorted(data):
    instance = data[instance_name]

    repository = instance.get("repository", "")
    port = instance.get("port", "")

    print(f"{instance_name}\t{repository}\t{port}")
PYTHON
}

registry_instance_repository() {
    local instance_name="$1"
    local registry

    registry_initialize
    registry=$(registry_path)

    INSTANCE_NAME="$instance_name" \
    REGISTRY_FILE="$registry" \
    python3 <<'PYTHON'
import json
import os
import sys

registry_file = os.environ["REGISTRY_FILE"]
instance_name = os.environ["INSTANCE_NAME"]

with open(registry_file, "r", encoding="utf-8") as file:
    data = json.load(file)

instance = data.get(instance_name)

if instance is None:
    sys.exit(1)

print(instance.get("repository", ""))
PYTHON
}

registry_instance_port() {
    local instance_name="$1"
    local registry

    registry_initialize
    registry=$(registry_path)

    INSTANCE_NAME="$instance_name" \
    REGISTRY_FILE="$registry" \
    python3 <<'PYTHON'
import json
import os
import sys

registry_file = os.environ["REGISTRY_FILE"]
instance_name = os.environ["INSTANCE_NAME"]

with open(registry_file, "r", encoding="utf-8") as file:
    data = json.load(file)

instance = data.get(instance_name)

if instance is None:
    sys.exit(1)

print(instance.get("port", ""))
PYTHON
}

registry_validate() {
    local registry

    registry_initialize
    registry=$(registry_path)

    REGISTRY_FILE="$registry" \
    INSTANCES_DIRECTORY="$INSTANCES_PATH" \
    python3 <<'PYTHON'
import json
import os
import sys

registry_file = os.environ["REGISTRY_FILE"]
instances_directory = os.environ["INSTANCES_DIRECTORY"]

try:
    with open(registry_file, "r", encoding="utf-8") as file:
        registry = json.load(file)
except json.JSONDecodeError as error:
    print(f"ERROR\tRegistry contains invalid JSON: {error}")
    sys.exit(2)

if not isinstance(registry, dict):
    print("ERROR\tRegistry root must be a JSON object.")
    sys.exit(2)

problems = 0

# Registry -> filesystem provera
for instance_name, registry_data in sorted(registry.items()):
    instance_path = os.path.join(instances_directory, instance_name)
    env_path = os.path.join(instance_path, "instance.env")

    if not os.path.isdir(instance_path):
        print(
            f"MISSING_DIRECTORY\t{instance_name}\t"
            f"Registered instance directory does not exist."
        )
        problems += 1
        continue

    if not os.path.isfile(env_path):
        print(
            f"MISSING_CONFIG\t{instance_name}\t"
            f"instance.env does not exist."
        )
        problems += 1
        continue

    env_data = {}

    with open(env_path, "r", encoding="utf-8") as file:
        for raw_line in file:
            line = raw_line.strip()

            if not line or line.startswith("#") or "=" not in line:
                continue

            key, value = line.split("=", 1)
            env_data[key.strip()] = value.strip()

    env_name = env_data.get("INSTANCE_NAME", "")
    env_repository = env_data.get("REPOSITORY", "")
    env_port = env_data.get("ODOO_PORT", "")

    registry_repository = str(registry_data.get("repository", ""))
    registry_port = str(registry_data.get("port", ""))

    if env_name and env_name != instance_name:
        print(
            f"NAME_MISMATCH\t{instance_name}\t"
            f"instance.env contains INSTANCE_NAME={env_name}"
        )
        problems += 1

    if env_repository != registry_repository:
        print(
            f"REPOSITORY_MISMATCH\t{instance_name}\t"
            f"registry={registry_repository}; env={env_repository}"
        )
        problems += 1

    if env_port != registry_port:
        print(
            f"PORT_MISMATCH\t{instance_name}\t"
            f"registry={registry_port}; env={env_port}"
        )
        problems += 1

# Filesystem -> registry provera
if os.path.isdir(instances_directory):
    for entry in sorted(os.listdir(instances_directory)):
        instance_path = os.path.join(instances_directory, entry)

        if not os.path.isdir(instance_path):
            continue

        if entry not in registry:
            print(
                f"UNREGISTERED\t{entry}\t"
                f"Instance directory exists but is not registered."
            )
            problems += 1

if problems == 0:
    print("OK\tRegistry and instance directories are synchronized.")
    sys.exit(0)

sys.exit(1)
PYTHON
}

registry_sync_instance_from_env() {
    local instance_name="$1"
    local configured_name
    local repository
    local port

    instance_require "$instance_name"

    configured_name=$(
        instance_config_value "$instance_name" "INSTANCE_NAME"
    ) || {
        log_error "INSTANCE_NAME is missing from instance.env."
    }

    repository=$(
        instance_config_value "$instance_name" "REPOSITORY"
    ) || {
        log_error "REPOSITORY is missing from instance.env."
    }

    port=$(
        instance_config_value "$instance_name" "ODOO_PORT"
    ) || {
        log_error "ODOO_PORT is missing from instance.env."
    }

    if [ "$configured_name" != "$instance_name" ]; then
        log_error \
            "Instance name mismatch. Directory=$instance_name, configuration=$configured_name"
    fi

    if [ -z "$repository" ]; then
        log_error "Repository cannot be empty."
    fi

    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log_error "Invalid Odoo port in instance.env: $port"
    fi

    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "Odoo port is outside the valid range: $port"
    fi

    registry_register_instance \
        "$instance_name" \
        "$repository" \
        "$port"
}

registry_sync_all_from_env() {
    local instance_directory
    local instance_name
    local synced_count=0
    local skipped_count=0
    local failed_count=0

    if [ ! -d "$INSTANCES_PATH" ]; then
        log_error "Instances directory does not exist: $INSTANCES_PATH"
    fi

    for instance_directory in "$INSTANCES_PATH"/*; do
        if [ ! -d "$instance_directory" ]; then
            continue
        fi

        instance_name=$(basename "$instance_directory")

        echo
        log_info "Synchronizing instance: $instance_name"

        if [ ! -f "$instance_directory/instance.env" ]; then
            log_warning "Skipping instance without instance.env: $instance_name"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        if (
            registry_sync_instance_from_env "$instance_name";
        ); then
            synced_count=$((synced_count + 1))
        else
            log_warning "Failed to synchronize instance: $instance_name"
            failed_count=$((failed_count + 1))
        fi
    done

    echo
    log_info "Registry synchronization summary:"
    echo "  Synchronized: $synced_count"
    echo "  Skipped:      $skipped_count"
    echo "  Failed:       $failed_count"

    if [ "$failed_count" -gt 0 ]; then
        return 1
    fi

    return 0
}

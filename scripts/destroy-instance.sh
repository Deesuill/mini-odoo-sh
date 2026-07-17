```bash
#!/bin/bash

set -e

MINI_ODOO_HOME="/opt/mini-odoo-sh"

source "$MINI_ODOO_HOME/lib/common.sh"
source "$MINI_ODOO_HOME/lib/logging.sh"
source "$MINI_ODOO_HOME/lib/docker.sh"
source "$MINI_ODOO_HOME/lib/instance.sh"
source "$MINI_ODOO_HOME/lib/registry.sh"


load_platform_config

if [ $# -ne 1 ]; then
    echo "Usage:"
    echo "./destroy-instance.sh <instance-name>"
    exit 1
fi

INSTANCE_NAME="$1"

instance_require "$INSTANCE_NAME"

INSTANCE_PATH=$(instance_path "$INSTANCE_NAME")

log_warning "Destroying instance: $INSTANCE_NAME"
log_warning "All containers, volumes and instance files will be removed."

instance_cd "$INSTANCE_NAME"

log_info "Stopping containers and removing volumes..."
docker_compose_down_volumes

log_info "Removing instance files..."
rm -rf -- "$INSTANCE_PATH"

log_info "Removing instance from registry..."
registry_unregister_instance "$INSTANCE_NAME"

log_success "Instance destroyed successfully: $INSTANCE_NAME"
```
